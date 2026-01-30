//
//  PlayerPresenter.swift
//  KinoPubTV
//
//  Presents AVPlayerViewController with enriched audio track names
//  and custom transport bar menus for quality/audio selection.
//

import Foundation
import AVFoundation
import AVKit
import UIKit
import ObjectiveC

/// Presents video content using AVPlayerViewController with enriched metadata
@MainActor
final class PlayerPresenter {
    
    // MARK: - Singleton
    
    static let shared = PlayerPresenter()
    private init() {}
    
    // MARK: - Private State
    
    private var currentPlayerVC: AVPlayerViewController?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var currentPlaybackData: PlaybackData?
    private var autoPlayNextProvider: (() async -> PlaybackData?)?
    
    // MARK: - Public API
    
    /// Presents video player with data from PlaybackService
    func present(
        playbackData: PlaybackData,
        autoPlayNext: (() async -> PlaybackData?)? = nil,
        from viewController: UIViewController
    ) {
        // Cleanup any existing player
        cleanup()
        
        currentPlaybackData = playbackData
        autoPlayNextProvider = autoPlayNext
        
        // Start HLS proxy if we have audio tracks to enrich
        Task {
            if !playbackData.audioTracks.isEmpty {
                if !HLSProxyServer.shared.isReady {
                    await HLSProxyServer.shared.startAsync()
                }
            }
            
            presentPlayerSync(playbackData: playbackData, from: viewController)
        }
    }
    
    /// Convenience method that fetches data and presents player
    func presentVideo(
        item: Item,
        video: Video,
        preferredQuality: String? = nil,
        autoPlayNext: (() async -> PlaybackData?)? = nil,
        from viewController: UIViewController
    ) {
        Task {
            do {
                let playbackData = try await PlaybackService.shared.preparePlayback(
                    for: item,
                    video: video,
                    preferredQuality: preferredQuality
                )
                present(playbackData: playbackData, autoPlayNext: autoPlayNext, from: viewController)
            } catch {
                showError(error, from: viewController)
            }
        }
    }
    
    /// Convenience method for episodes
    func presentEpisode(
        item: Item,
        season: Season,
        episode: Episode,
        preferredQuality: String? = nil,
        autoPlayNext: (() async -> PlaybackData?)? = nil,
        from viewController: UIViewController
    ) {
        Task {
            do {
                let playbackData = try await PlaybackService.shared.preparePlayback(
                    for: item,
                    season: season,
                    episode: episode,
                    preferredQuality: preferredQuality
                )
                present(playbackData: playbackData, autoPlayNext: autoPlayNext, from: viewController)
            } catch {
                showError(error, from: viewController)
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func presentPlayerSync(playbackData: PlaybackData, from viewController: UIViewController) {
        // Create player item with potentially proxied URL
        let playerItem = createPlayerItem(for: playbackData)
        let player = AVPlayer(playerItem: playerItem)
        
        // Create and configure player view controller
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        playerVC.allowsPictureInPicturePlayback = true
        
        currentPlayerVC = playerVC
        
        // Build custom transport bar menus
        var customMenus: [UIMenu] = []
        
        // Quality picker menu
        if playbackData.availableQualities.count > 1 {
            let qualityMenu = buildQualityMenu(
                qualities: playbackData.availableQualities,
                currentQuality: playbackData.currentQuality,
                player: player,
                playbackData: playbackData
            )
            customMenus.append(qualityMenu)
        }
        
        // Audio track menu with enriched names
        if !playbackData.audioTracks.isEmpty {
            Task {
                await setupAudioTrackMenu(
                    playerVC: playerVC,
                    player: player,
                    playerItem: playerItem,
                    playbackData: playbackData,
                    existingMenus: customMenus
                )
            }
        }
        
        if !customMenus.isEmpty {
            playerVC.transportBarCustomMenuItems = customMenus
        }
        
        // Resume from saved position
        if let resumeTime = playbackData.resumeTime {
            player.seek(to: resumeTime)
        }
        
        // Setup progress saving
        setupTimeObserver(player: player, playbackData: playbackData)
        
        // Setup end-of-playback handling
        setupEndObserver(player: player, playerVC: playerVC)
        
        // Setup dismissal cleanup
        let delegate = PlayerDismissalDelegate { [weak self] in
            self?.cleanup()
        }
        playerVC.presentationController?.delegate = delegate
        objc_setAssociatedObject(playerVC, &dismissalDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Present and start playback
        viewController.present(playerVC, animated: true) {
            player.play()
        }
    }
    
    private func createPlayerItem(for playbackData: PlaybackData) -> AVPlayerItem {
        var streamURL = playbackData.streamURL
        
        // Use HLS proxy to inject enriched audio track names
        if !playbackData.audioTracks.isEmpty, HLSProxyServer.shared.isReady {
            let originalTracks = playbackData.audioTracks.map { $0.originalTrack }
            if let proxiedURL = HLSProxyServer.shared.proxiedURL(for: streamURL, audioTracks: originalTracks) {
                streamURL = proxiedURL
                print("🎬 Using proxied URL for enriched audio track names")
            }
        }
        
        let asset = AVURLAsset(url: streamURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Set external metadata (title, description, artwork)
        playerItem.externalMetadata = playbackData.metadata.toAVMetadata()
        
        // Pre-select preferred audio track
        if let preferredIndex = playbackData.preferredAudioTrackIndex {
            Task {
                do {
                    _ = try await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions)
                    guard let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible) else { return }
                    let options = audioGroup.options
                    if preferredIndex < options.count {
                        playerItem.select(options[preferredIndex], in: audioGroup)
                    }
                } catch {
                    // Fallback to default selection
                }
            }
        }
        
        return playerItem
    }
    
    private func buildQualityMenu(
        qualities: [QualityOption],
        currentQuality: String,
        player: AVPlayer,
        playbackData: PlaybackData
    ) -> UIMenu {
        let actions = qualities.map { quality -> UIAction in
            let isSelected = quality.quality == currentQuality
            return UIAction(
                title: quality.displayName,
                image: isSelected ? UIImage(systemName: "checkmark") : nil,
                state: isSelected ? .on : .off
            ) { [weak self, weak player] _ in
                guard let self = self, let player = player else { return }
                self.switchQuality(to: quality, player: player, playbackData: playbackData)
            }
        }
        
        return UIMenu(
            title: "Качество",
            image: UIImage(systemName: "slider.horizontal.3"),
            children: actions
        )
    }
    
    private func switchQuality(to quality: QualityOption, player: AVPlayer, playbackData: PlaybackData) {
        let currentTime = player.currentTime()
        
        // Create new playback data with different quality
        var streamURL = quality.url
        
        // Use HLS proxy for the new quality too
        if !playbackData.audioTracks.isEmpty, HLSProxyServer.shared.isReady {
            let originalTracks = playbackData.audioTracks.map { $0.originalTrack }
            if let proxiedURL = HLSProxyServer.shared.proxiedURL(for: streamURL, audioTracks: originalTracks) {
                streamURL = proxiedURL
            }
        }
        
        let asset = AVURLAsset(url: streamURL)
        let newItem = AVPlayerItem(asset: asset)
        newItem.externalMetadata = playbackData.metadata.toAVMetadata()
        
        player.replaceCurrentItem(with: newItem)
        player.seek(to: currentTime) { _ in
            player.play()
        }
        
        // Update the menu
        if let playerVC = currentPlayerVC {
            let newMenu = buildQualityMenu(
                qualities: playbackData.availableQualities,
                currentQuality: quality.quality,
                player: player,
                playbackData: playbackData
            )
            playerVC.transportBarCustomMenuItems = [newMenu]
        }
    }
    
    private func setupAudioTrackMenu(
        playerVC: AVPlayerViewController,
        player: AVPlayer,
        playerItem: AVPlayerItem,
        playbackData: PlaybackData,
        existingMenus: [UIMenu]
    ) async {
        guard let asset = playerItem.asset as? AVURLAsset else { return }
        
        do {
            _ = try await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions)
            guard let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible) else { return }
            
            let hlsOptions = audioGroup.options
            let enrichedTracks = playbackData.audioTracks
            
            // Match HLS options to enriched tracks by language
            var matchedPairs: [(track: EnrichedAudioTrack, option: AVMediaSelectionOption)] = []
            var usedOptionIndices = Set<Int>()
            
            for track in enrichedTracks {
                for (optIdx, option) in hlsOptions.enumerated() {
                    guard !usedOptionIndices.contains(optIdx) else { continue }
                    
                    let hlsLang = getLanguageCode(from: option)
                    if hlsLang == track.languageCode || hlsLang.hasPrefix(track.languageCode) || track.languageCode.hasPrefix(hlsLang) {
                        matchedPairs.append((track, option))
                        usedOptionIndices.insert(optIdx)
                        break
                    }
                }
            }
            
            // Fallback to index-based matching if no language matches
            if matchedPairs.isEmpty {
                for (idx, option) in hlsOptions.enumerated() {
                    if idx < enrichedTracks.count {
                        matchedPairs.append((enrichedTracks[idx], option))
                    }
                }
            }
            
            guard !matchedPairs.isEmpty else { return }
            
            var selectedIndex = playbackData.preferredAudioTrackIndex ?? 0
            
            // Build the audio menu
            func buildAudioMenu() -> UIMenu {
                var reduceLoudSoundsEnabled = AppSettings.shared.reduceLoudSounds
                
                let trackActions = matchedPairs.enumerated().map { (idx, pair) -> UIAction in
                    let isSelected = pair.track.index == selectedIndex
                    return UIAction(
                        title: pair.track.menuTitle,
                        state: isSelected ? .on : .off
                    ) { [weak playerVC, weak player] _ in
                        guard let playerVC = playerVC,
                              let currentItem = player?.currentItem else { return }
                        
                        currentItem.select(pair.option, in: audioGroup)
                        selectedIndex = pair.track.index
                        
                        // Rebuild menu with new selection
                        var menus = existingMenus
                        menus.append(buildAudioMenu())
                        playerVC.transportBarCustomMenuItems = menus
                    }
                }
                
                let tracksSubmenu = UIMenu(
                    title: "Дорожка",
                    image: UIImage(systemName: "waveform"),
                    children: trackActions
                )
                
                let reduceLoudAction = UIAction(
                    title: "Уменьшить громкие звуки",
                    image: UIImage(systemName: reduceLoudSoundsEnabled ? "speaker.wave.2.fill" : "speaker.wave.2"),
                    state: reduceLoudSoundsEnabled ? .on : .off
                ) { [weak playerVC, weak player] _ in
                    reduceLoudSoundsEnabled.toggle()
                    AppSettings.shared.reduceLoudSounds = reduceLoudSoundsEnabled
                    
                    if let currentItem = player?.currentItem {
                        self.applyAudioCompression(to: currentItem, enabled: reduceLoudSoundsEnabled)
                    }
                    
                    if let playerVC = playerVC {
                        var menus = existingMenus
                        menus.append(buildAudioMenu())
                        playerVC.transportBarCustomMenuItems = menus
                    }
                }
                
                let settingsSubmenu = UIMenu(
                    title: "Настройки",
                    image: UIImage(systemName: "slider.horizontal.3"),
                    children: [reduceLoudAction]
                )
                
                return UIMenu(
                    title: "Аудио",
                    image: UIImage(systemName: "speaker.wave.2"),
                    children: [tracksSubmenu, settingsSubmenu]
                )
            }
            
            await MainActor.run {
                var menus = existingMenus
                menus.append(buildAudioMenu())
                playerVC.transportBarCustomMenuItems = menus
                
                // Apply initial audio compression if enabled
                if AppSettings.shared.reduceLoudSounds {
                    applyAudioCompression(to: playerItem, enabled: true)
                }
            }
            
        } catch {
            // Failed to load audio options
        }
    }
    
    private func getLanguageCode(from option: AVMediaSelectionOption) -> String {
        if let tag = option.extendedLanguageTag?.lowercased() {
            return normalizeLanguageCode(tag)
        }
        if let locale = option.locale {
            if #available(tvOS 16, *) {
                return normalizeLanguageCode(locale.language.languageCode?.identifier ?? "")
            } else {
                return normalizeLanguageCode(locale.languageCode ?? "")
            }
        }
        return ""
    }
    
    private func normalizeLanguageCode(_ code: String) -> String {
        let lowered = code.lowercased()
        switch lowered {
        case "rus", "ru": return "ru"
        case "eng", "en": return "en"
        case "ukr", "uk": return "uk"
        default: return String(lowered.prefix(2))
        }
    }
    
    private func setupTimeObserver(player: AVPlayer, playbackData: PlaybackData) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 15, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let seconds = Int(time.seconds)
            guard seconds > 0 else { return }
            
            Task { @MainActor in
                do {
                    let token = try await AuthService.shared.getValidToken()
                    try await ContentService.shared.markTime(
                        itemID: playbackData.itemID,
                        videoID: playbackData.videoID,
                        time: seconds,
                        season: playbackData.seasonNumber,
                        accessToken: token
                    )
                } catch {
                    // Best-effort, ignore errors
                }
            }
        }
    }
    
    private func setupEndObserver(player: AVPlayer, playerVC: AVPlayerViewController) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self, weak player] note in
            guard let self = self,
                  let player = player,
                  let endedItem = note.object as? AVPlayerItem,
                  endedItem == player.currentItem,
                  let playbackData = self.currentPlaybackData else { return }
            
            Task { @MainActor in
                // Mark as watched
                do {
                    let token = try await AuthService.shared.getValidToken()
                    try await ContentService.shared.toggleWatched(
                        itemID: playbackData.itemID,
                        season: playbackData.seasonNumber,
                        video: playbackData.videoID,
                        accessToken: token
                    )
                } catch {
                    // Best-effort
                }
                
                // Auto-play next if enabled
                guard AppSettings.shared.autoPlayNextEpisode,
                      let provider = self.autoPlayNextProvider,
                      let nextData = await provider() else { return }
                
                self.currentPlaybackData = nextData
                let nextItem = self.createPlayerItem(for: nextData)
                player.replaceCurrentItem(with: nextItem)
                
                if let resumeTime = nextData.resumeTime {
                    player.seek(to: resumeTime) { _ in
                        player.play()
                    }
                } else {
                    player.play()
                }
            }
        }
    }
    
    private func applyAudioCompression(to playerItem: AVPlayerItem, enabled: Bool) {
        guard enabled else {
            playerItem.audioMix = nil
            return
        }
        
        Task {
            do {
                let tracks = try await playerItem.asset.loadTracks(withMediaType: .audio)
                guard let audioTrack = tracks.first else { return }
                
                let audioMix = AVMutableAudioMix()
                let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
                parameters.setVolume(0.75, at: .zero)
                audioMix.inputParameters = [parameters]
                
                await MainActor.run {
                    playerItem.audioMix = audioMix
                }
            } catch {
                // Ignore
            }
        }
    }
    
    private func showError(_ error: Error, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Ошибка воспроизведения",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
    
    private func cleanup() {
        if let observer = timeObserver, let player = currentPlayerVC?.player {
            player.removeTimeObserver(observer)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        timeObserver = nil
        endObserver = nil
        currentPlayerVC = nil
        currentPlaybackData = nil
        autoPlayNextProvider = nil
        
        HLSProxyServer.shared.clearAudioTracks()
    }
}

// MARK: - Dismissal Delegate

private var dismissalDelegateKey: UInt8 = 0

private final class PlayerDismissalDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
