//
//  TVView.swift
//  KinoPubTV
//

import SwiftUI
import AVKit

struct TVView: View {
    @State private var channels: [TVChannel] = []
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 6),
                    spacing: 40
                ) {
                    ForEach(channels) { channel in
                        VStack(spacing: 12) {
                            TVChannelCard(channel: channel)
                            
                            Text(channel.title)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 200)
                        }
                    }
                }
                .padding(50)
            }
            .overlay {
                if isLoading && channels.isEmpty {
                    ProgressView("Загрузка каналов...")
                }
            }
            .alert("Ошибка", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .task {
                await loadChannels()
            }
        }
    }
    
    private func loadChannels() async {
        isLoading = true
        
        do {
            let token = try await AuthService.shared.getValidToken()
            let response = try await ContentService.shared.getTVChannels(accessToken: token)
            channels = response.channels
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct TVChannelCard: View {
    let channel: TVChannel
    
    var body: some View {
        Button {
            playChannel()
        } label: {
            ZStack(alignment: .center) {
                // Logo/image
                AsyncImage(url: URL.secure(string: channel.logos?.m ?? channel.logos?.s)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .overlay {
                            Image(systemName: "tv")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                }
                .frame(width: 200, height: 200)
                .background(Color(white: 0.1))
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.card)
        .accessibilityLabel("ТВ канал \(channel.title)")
        .accessibilityHint("Двойное нажатие для просмотра")
    }
    
    private func playChannel() {
        guard let urlString = channel.stream,
              let url = URL(string: urlString) else { return }
        
        // Create AVPlayer with live stream support
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Configure for live streaming
        playerItem.automaticallyPreservesTimeOffsetFromLive = true
        playerItem.configuredTimeOffsetFromLive = .zero
        
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        
        // Enable Picture-in-Picture for live TV
        playerVC.allowsPictureInPicturePlayback = true
        
        // For live content, hide time progress as it's not relevant
        if #available(tvOS 14.0, *) {
            playerVC.requiresLinearPlayback = false
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(playerVC, animated: true) {
                player.play()
            }
        }
    }
}

#Preview {
    TVView()
}
