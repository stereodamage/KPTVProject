//
//  AudioTrackPicker.swift
//  KinoPubTV
//

import SwiftUI
import Foundation
@preconcurrency import AVKit
import ObjectiveC

struct PlaybackContext {
    let url: URL
    let audioTracks: [AudioTrack]?
    let metadata: [AVMetadataItem]
    let startTime: CMTime?
    let itemID: Int?
    let seasonNumber: Int?
    let videoID: Int?
    let availableFiles: [VideoFile]?
    let currentQuality: String?
}

/// Helper to play content directly
struct AudioTrackPlaybackHelper {
    
    /// Plays content directly, letting the native player handle audio track selection
    static func playWithAudioSelection(
        url: URL,
        audioTracks: [AudioTrack]?,
        metadata: [AVMetadataItem],
        startTime: CMTime? = nil,
        itemID: Int? = nil,
        seasonNumber: Int? = nil,
        videoID: Int? = nil,
        availableFiles: [VideoFile]? = nil,
        currentQuality: String? = nil,
        autoPlayNext: (() -> PlaybackContext?)? = nil,
        from viewController: UIViewController
    ) {
        let context = PlaybackContext(
            url: url,
            audioTracks: audioTracks,
            metadata: metadata,
            startTime: startTime,
            itemID: itemID,
            seasonNumber: seasonNumber,
            videoID: videoID,
            availableFiles: availableFiles,
            currentQuality: currentQuality
        )
        
        // Auto-select Russian track if device language is Russian
        let preferredIndex = preferredRussianTrackIndex(in: audioTracks)
        presentPlayer(context: context, startPreferredAudioTrackIndex: preferredIndex, autoPlayNext: autoPlayNext, from: viewController)
    }
    
    private static func presentPlayer(
        context: PlaybackContext,
        startPreferredAudioTrackIndex: Int?,
        autoPlayNext: (() -> PlaybackContext?)?,
        from viewController: UIViewController
    ) {
        var currentContext = context
        var currentPreferredAudioTrackIndex = startPreferredAudioTrackIndex
        
        func makePlayerItem(for ctx: PlaybackContext, preferredAudioTrackIndex: Int?) -> (asset: AVURLAsset, item: AVPlayerItem) {
            let asset = AVURLAsset(url: ctx.url)
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.externalMetadata = ctx.metadata
            
            if let trackIndex = preferredAudioTrackIndex {
                Task {
                    do {
                        _ = try await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions)
                        guard let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible) else { return }
                        let options = audioGroup.options
                        if trackIndex < options.count {
                            playerItem.select(options[trackIndex], in: audioGroup)
                        }
                    } catch {
                        // Ignore selection failure; fallback to default
                    }
                }
            }
            return (asset, playerItem)
        }
        
        let first = makePlayerItem(for: currentContext, preferredAudioTrackIndex: startPreferredAudioTrackIndex)
        let player = AVPlayer(playerItem: first.item)
        
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        playerVC.allowsPictureInPicturePlayback = true
        
        // Build transport bar menus
        var customMenus: [UIMenu] = []
        
        // Add quality picker menu if multiple qualities available
        if let files = context.availableFiles, files.count > 1 {
            let qualityActions = files.map { file -> UIAction in
                let isSelected = file.quality == context.currentQuality
                let title = qualityDisplayName(file.quality)
                return UIAction(
                    title: title,
                    image: isSelected ? UIImage(systemName: "checkmark") : nil,
                    state: isSelected ? .on : .off
                ) { [weak playerVC] _ in
                    guard let playerVC = playerVC,
                          let urlString = file.url.preferredURL,
                          let newURL = URL(string: urlString) else { return }
                    
                    // Get current playback time
                    let currentTime = player.currentTime()
                    
                    // Create new context with updated URL and quality
                    let newContext = PlaybackContext(
                        url: newURL,
                        audioTracks: currentContext.audioTracks,
                        metadata: currentContext.metadata,
                        startTime: currentTime,
                        itemID: currentContext.itemID,
                        seasonNumber: currentContext.seasonNumber,
                        videoID: currentContext.videoID,
                        availableFiles: files,
                        currentQuality: file.quality
                    )
                    currentContext = newContext
                    
                    // Switch to new quality
                    let newItem = makePlayerItem(for: newContext, preferredAudioTrackIndex: currentPreferredAudioTrackIndex)
                    player.replaceCurrentItem(with: newItem.item)
                    player.seek(to: currentTime) { _ in
                        player.play()
                    }
                    
                    // Update menu to reflect new selection
                    updateQualityMenu(on: playerVC, files: files, currentQuality: file.quality, player: player, currentContext: &currentContext, preferredAudioTrackIndex: &currentPreferredAudioTrackIndex)
                }
            }
            
            let qualityMenu = UIMenu(
                title: "Качество",
                image: UIImage(systemName: "slider.horizontal.3"),
                children: qualityActions
            )
            customMenus.append(qualityMenu)
        }
        
        // Add custom audio track menu with enriched descriptions from API
        if let apiTracks = context.audioTracks, !apiTracks.isEmpty {
            // We'll populate this after the asset loads
            Task {
                await setupAudioTrackMenu(
                    playerVC: playerVC,
                    player: player,
                    asset: first.asset,
                    playerItem: first.item,
                    apiTracks: apiTracks,
                    existingMenus: customMenus,
                    selectedIndex: startPreferredAudioTrackIndex ?? 0
                )
            }
        }
        
        if !customMenus.isEmpty {
            playerVC.transportBarCustomMenuItems = customMenus
        }
        
        // Resume from start time if provided
        if let startTime = currentContext.startTime {
            player.seek(to: startTime)
        }
        
        // Periodically save playback position to server
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 15, preferredTimescale: 1),
            queue: .main
        ) { time in
            guard let itemID = currentContext.itemID,
                  let videoID = currentContext.videoID else { return }
            let seconds = Int(time.seconds)
            guard seconds > 0 else { return }
            Task { @MainActor in
                do {
                    let token = try await AuthService.shared.getValidToken()
                    try await ContentService.shared.markTime(
                        itemID: itemID,
                        videoID: videoID,
                        time: seconds,
                        season: currentContext.seasonNumber,
                        accessToken: token
                    )
                } catch {
                    // Best-effort; ignore network errors
                }
            }
        }
        
        // Mark watched + optional auto-play next
        let endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { note in
            guard let endedItem = note.object as? AVPlayerItem,
                  endedItem == player.currentItem else { return }
            
            Task { @MainActor in
                if let itemID = currentContext.itemID {
                    do {
                        let token = try await AuthService.shared.getValidToken()
                        try await ContentService.shared.toggleWatched(
                            itemID: itemID,
                            season: currentContext.seasonNumber,
                            video: currentContext.videoID,
                            accessToken: token
                        )
                    } catch {
                        // Best-effort
                    }
                }
                
                guard AppSettings.shared.autoPlayNextEpisode,
                      let nextContext = autoPlayNext?() else { return }
                currentContext = nextContext
                
                let next = makePlayerItem(for: nextContext, preferredAudioTrackIndex: startPreferredAudioTrackIndex)
                player.replaceCurrentItem(with: next.item)
                if let startTime = nextContext.startTime {
                    player.seek(to: startTime) { _ in
                        player.play()
                    }
                } else {
                    player.play()
                }
            }
        }
        
        viewController.present(playerVC, animated: true) {
            player.play()
        }
        
        // Clean up observers when the controller is dismissed
        let delegate = PlayerPresentationDelegate {
            player.removeTimeObserver(timeObserver)
            NotificationCenter.default.removeObserver(endObserver)
        }
        playerVC.presentationController?.delegate = delegate
        objc_setAssociatedObject(playerVC, &playerPresentationDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private static func setupAudioTrackMenu(
        playerVC: AVPlayerViewController,
        player: AVPlayer,
        asset: AVURLAsset,
        playerItem: AVPlayerItem,
        apiTracks: [AudioTrack],
        existingMenus: [UIMenu],
        selectedIndex: Int
    ) async {
        do {
            _ = try await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions)
            guard let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible) else { return }
            
            let hlsOptions = audioGroup.options
            
            // Helper to get language code from AVMediaSelectionOption
            func getLanguageCode(from option: AVMediaSelectionOption) -> String {
                if let tag = option.extendedLanguageTag?.lowercased() {
                    return tag
                }
                if let locale = option.locale {
                    if #available(tvOS 16, *) {
                        return locale.language.languageCode?.identifier.lowercased() ?? ""
                    } else {
                        return locale.languageCode?.lowercased() ?? ""
                    }
                }
                return ""
            }
            
            // Match HLS options to API tracks
            // Strategy: Match by language code, then by index within same language
            var matchedTracks: [(apiTrack: AudioTrack, hlsOption: AVMediaSelectionOption, apiIndex: Int)] = []
            
            for (apiIndex, apiTrack) in apiTracks.enumerated() {
                let apiLang = apiTrack.lang?.lowercased() ?? ""
                
                // Find HLS options with matching language
                let matchingOptions = hlsOptions.filter { option in
                    let hlsLang = getLanguageCode(from: option)
                    return hlsLang.hasPrefix(apiLang) || apiLang.hasPrefix(hlsLang) ||
                           (apiLang == "rus" && hlsLang.hasPrefix("ru")) ||
                           (apiLang == "eng" && hlsLang.hasPrefix("en"))
                }
                
                if let matchedOption = matchingOptions.first(where: { option in
                    // Try to match by index within language group
                    let sameLanguageAPITracks = apiTracks.filter { ($0.lang?.lowercased() ?? "") == apiLang }
                    let indexInLanguage = sameLanguageAPITracks.firstIndex(where: { $0.id == apiTrack.id }) ?? 0
                    
                    let sameLanguageHLSOptions = hlsOptions.filter { opt in
                        let hlsLang = getLanguageCode(from: opt)
                        return hlsLang.hasPrefix(apiLang) || apiLang.hasPrefix(hlsLang) ||
                               (apiLang == "rus" && hlsLang.hasPrefix("ru")) ||
                               (apiLang == "eng" && hlsLang.hasPrefix("en"))
                    }
                    
                    if indexInLanguage < sameLanguageHLSOptions.count {
                        return sameLanguageHLSOptions[indexInLanguage] == option
                    }
                    return false
                }) ?? matchingOptions.first {
                    // Avoid duplicates
                    if !matchedTracks.contains(where: { $0.hlsOption == matchedOption }) {
                        matchedTracks.append((apiTrack, matchedOption, apiIndex))
                    }
                }
            }
            
            // If no matches found, fall back to index-based matching
            if matchedTracks.isEmpty {
                for (index, option) in hlsOptions.enumerated() {
                    if index < apiTracks.count {
                        matchedTracks.append((apiTracks[index], option, index))
                    }
                }
            }
            
            guard !matchedTracks.isEmpty else { return }
            
            // Create audio track menu
            var currentSelectedIndex = selectedIndex
            
            // Pre-compute titles to avoid MainActor isolation issues
            let trackTitles = matchedTracks.map { $0.apiTrack.formattedForPlayerMenu }
            
            await MainActor.run {
                func buildAudioMenu() -> UIMenu {
                    let audioActions = matchedTracks.enumerated().map { (idx, match) -> UIAction in
                        let isSelected = match.apiIndex == currentSelectedIndex
                        let title = trackTitles[idx]
                        
                        return UIAction(
                            title: title,
                            image: isSelected ? UIImage(systemName: "checkmark") : nil,
                            state: isSelected ? .on : .off
                        ) { [weak playerVC] _ in
                            guard let playerVC = playerVC,
                                  let currentItem = player.currentItem else { return }
                            
                            // Switch audio track
                            currentItem.select(match.hlsOption, in: audioGroup)
                            currentSelectedIndex = match.apiIndex
                            
                            // Update menu
                            var menus = existingMenus
                            menus.append(buildAudioMenu())
                            playerVC.transportBarCustomMenuItems = menus
                        }
                    }
                    
                    return UIMenu(
                        title: "Аудио",
                        image: UIImage(systemName: "speaker.wave.2"),
                        children: audioActions
                    )
                }
                
                var menus = existingMenus
                menus.append(buildAudioMenu())
                playerVC.transportBarCustomMenuItems = menus
            }
        } catch {
            // Failed to load audio options, leave native picker
        }
    }
}

private var playerPresentationDelegateKey: UInt8 = 0

private func qualityDisplayName(_ quality: String) -> String {
    switch quality {
    case "2160p": return "4K (2160p)"
    case "1080p": return "Full HD (1080p)"
    case "720p": return "HD (720p)"
    case "480p": return "SD (480p)"
    case "360p": return "360p"
    default: return quality.uppercased()
    }
}

private func updateQualityMenu(
    on playerVC: AVPlayerViewController,
    files: [VideoFile],
    currentQuality: String,
    player: AVPlayer,
    currentContext: inout PlaybackContext,
    preferredAudioTrackIndex: inout Int?
) {
    var capturedContext = currentContext
    var capturedAudioIndex = preferredAudioTrackIndex
    
    let qualityActions = files.map { file -> UIAction in
        let isSelected = file.quality == currentQuality
        let title = qualityDisplayName(file.quality)
        return UIAction(
            title: title,
            image: isSelected ? UIImage(systemName: "checkmark") : nil,
            state: isSelected ? .on : .off
        ) { [weak playerVC] _ in
            guard let playerVC = playerVC,
                  let urlString = file.url.preferredURL,
                  let newURL = URL(string: urlString) else { return }
            
            let currentTime = player.currentTime()
            
            let newContext = PlaybackContext(
                url: newURL,
                audioTracks: capturedContext.audioTracks,
                metadata: capturedContext.metadata,
                startTime: currentTime,
                itemID: capturedContext.itemID,
                seasonNumber: capturedContext.seasonNumber,
                videoID: capturedContext.videoID,
                availableFiles: files,
                currentQuality: file.quality
            )
            capturedContext = newContext
            
            let asset = AVURLAsset(url: newURL)
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.externalMetadata = newContext.metadata
            
            player.replaceCurrentItem(with: playerItem)
            player.seek(to: currentTime) { _ in
                player.play()
            }
            
            updateQualityMenu(on: playerVC, files: files, currentQuality: file.quality, player: player, currentContext: &capturedContext, preferredAudioTrackIndex: &capturedAudioIndex)
        }
    }
    
    let qualityMenu = UIMenu(
        title: "Качество",
        image: UIImage(systemName: "slider.horizontal.3"),
        children: qualityActions
    )
    playerVC.transportBarCustomMenuItems = [qualityMenu]
}

private func preferredRussianTrackIndex(in tracks: [AudioTrack]?) -> Int? {
    guard let tracks = tracks else { return nil }
    let prefersRussian = Locale.preferredLanguages.contains { $0.lowercased().hasPrefix("ru") }
    guard prefersRussian else { return nil }
    return tracks.firstIndex { track in
        guard let code = track.lang?.lowercased() else { return false }
        return code == "ru" || code == "rus"
    }
}

private final class PlayerPresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
