//
//  AudioTrackPicker.swift
//  KinoPubTV
//

import SwiftUI
import AVKit
import ObjectiveC

/// Custom audio track picker that shows formatted descriptions before playback
struct AudioTrackPickerView: View {
    let audioTracks: [AudioTrack]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(Array(audioTracks.enumerated()), id: \.offset) { index, track in
                        Button {
                            selectedIndex = index
                        } label: {
                            AudioTrackRow(
                                track: track,
                                index: index,
                                isSelected: selectedIndex == index
                            )
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(50)
            }
            .navigationTitle("Выберите аудиодорожку")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Воспроизвести") {
                        onSelect(selectedIndex)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Individual audio track row
struct AudioTrackRow: View {
    let track: AudioTrack
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 30) {
            // Track number
            Text(String(format: "%02d", index + 1))
                .font(.tvTitle2(weight: .bold))
                .foregroundColor(isSelected ? .green : .secondary)
                .frame(width: 100)
            
            // Track details
            VStack(alignment: .leading, spacing: 12) {
                // Language and author
                Text(track.formattedTitle)
                    .font(.tvHeadline())
                    .foregroundColor(.primary)
                
                // Additional info
                HStack(spacing: 16) {
                    if let type = track.type?.title {
                        Text(type)
                            .font(.tvCallout())
                            .foregroundColor(.secondary)
                    }
                    
                    if let codec = track.codec?.uppercased() {
                        Text(codec)
                            .font(.tvCaption(weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
        }
        .padding(30)
        .background(isSelected ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(16)
    }
}

struct PlaybackContext {
    let url: URL
    let audioTracks: [AudioTrack]?
    let metadata: [AVMetadataItem]
    let startTime: CMTime?
    let itemID: Int?
    let seasonNumber: Int?
    let videoID: Int?
}

/// Helper to present audio track picker and then play
struct AudioTrackPlaybackHelper {
    
    /// Shows audio track picker if multiple tracks, otherwise plays directly
    static func playWithAudioSelection(
        url: URL,
        audioTracks: [AudioTrack]?,
        metadata: [AVMetadataItem],
        startTime: CMTime? = nil,
        itemID: Int? = nil,
        seasonNumber: Int? = nil,
        videoID: Int? = nil,
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
            videoID: videoID
        )
        
        guard let tracks = audioTracks, tracks.count > 1 else {
            // Single or no audio track - play directly
            presentPlayer(context: context, startPreferredAudioTrackIndex: nil, autoPlayNext: autoPlayNext, from: viewController)
            return
        }
        
        // Multiple tracks - show picker first
        let pickerView = AudioTrackPickerView(audioTracks: tracks) { selectedIndex in
            // User selected a track - now play
            presentPlayer(context: context, startPreferredAudioTrackIndex: selectedIndex, autoPlayNext: autoPlayNext, from: viewController)
        }
        
        let hostingController = UIHostingController(rootView: pickerView)
        viewController.present(hostingController, animated: true)
    }
    
    private static func presentPlayer(
        context: PlaybackContext,
        startPreferredAudioTrackIndex: Int?,
        autoPlayNext: (() -> PlaybackContext?)?,
        from viewController: UIViewController
    ) {
        var currentContext = context
        
        func makePlayerItem(for ctx: PlaybackContext, preferredAudioTrackIndex: Int?) -> (asset: AVURLAsset, item: AVPlayerItem) {
            let asset = AVURLAsset(url: ctx.url)
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.externalMetadata = ctx.metadata
            
            if let trackIndex = preferredAudioTrackIndex {
                Task {
                    await asset.loadValues(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"])
                    guard let audioGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
                    let options = audioGroup.options
                    if trackIndex < options.count {
                        playerItem.select(options[trackIndex], in: audioGroup)
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
}

private var playerPresentationDelegateKey: UInt8 = 0

private final class PlayerPresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
