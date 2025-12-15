//
//  EpisodesView.swift
//  KinoPubTV
//

import SwiftUI
import AVKit

struct EpisodesView: View {
    let season: Season
    let item: Item
    
    @State private var tmdbShowId: Int?
    @State private var tmdbEpisodes: [Int: TMDBEpisode] = [:]
    @State private var isLoadingTMDB = false
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .bottom, spacing: 30) {
                    AsyncImage(url: URL.secure(string: item.posters?.medium)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 200, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.displayTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Сезон \(season.number)")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text(RussianPlural.episodes(season.episodes.count))
                            .font(.callout)
                            .foregroundColor(.secondary)
                        
                        if isLoadingTMDB {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Загрузка данных TMDB...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(50)
                
                Divider()
                    .padding(.horizontal, 50)
                
                // Episodes List
                ForEach(Array(season.episodes.enumerated()), id: \.element.id) { index, episode in
                    let nextEpisode = index + 1 < season.episodes.count ? season.episodes[index + 1] : nil
                    EpisodeRow(
                        episode: episode,
                        nextEpisode: nextEpisode,
                        seasonNumber: season.number,
                        item: item,
                        tmdbEpisode: tmdbEpisodes[episode.number],
                        isFirst: index == 0,
                        isLast: index == season.episodes.count - 1
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadTMDBData()
        }
    }
    
    private func loadTMDBData() async {
        // Check if TMDB integration is enabled
        let settings = await MainActor.run { AppSettings.shared }
        guard await MainActor.run(body: { settings.useTMDBMetadata }) else {
            return
        }
        
        // Skip if no IMDb ID
        guard let imdbId = item.imdb, imdbId > 0 else { return }
        
        isLoadingTMDB = true
        defer { isLoadingTMDB = false }
        
        do {
            // Find TMDB show by IMDb ID
            let imdbString = String(imdbId)
            if let showId = try await TMDBService.shared.findByIMDbId(imdbString) {
                tmdbShowId = showId
                
                // Load season details
                if let seasonDetail = try await TMDBService.shared.getSeasonDetail(
                    showId: showId,
                    seasonNumber: season.number
                ) {
                    // Map episodes by number
                    if let episodes = seasonDetail.episodes {
                        var episodeMap: [Int: TMDBEpisode] = [:]
                        for episode in episodes {
                            episodeMap[episode.episodeNumber] = episode
                        }
                        tmdbEpisodes = episodeMap
                    }
                }
            }
        } catch {
            print("TMDB load error: \(error)")
        }
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let nextEpisode: Episode?
    let seasonNumber: Int
    let item: Item
    let tmdbEpisode: TMDBEpisode?
    let isFirst: Bool
    let isLast: Bool
    
    @FocusState private var isFocused: Bool
    
    var isWatched: Bool {
        (episode.watched ?? 0) > 0
    }
    
    var isInProgress: Bool {
        (episode.watched ?? 0) == -1 || ((episode.watching?.time ?? 0) > 0 && !isWatched)
    }
    
    // Use TMDB episode name if available, otherwise fall back to KinoPub
    var episodeTitle: String {
        if let tmdbName = tmdbEpisode?.name, !tmdbName.isEmpty {
            return tmdbName
        }
        return episode.displayTitle
    }
    
    // Use TMDB still if available, otherwise KinoPub thumbnail
    var thumbnailURL: URL? {
        if let tmdbURL = tmdbEpisode?.stillURL {
            return tmdbURL
        }
        return URL.secure(string: episode.thumbnail)
    }
    
    // Episode overview from TMDB
    var episodeOverview: String? {
        tmdbEpisode?.overview
    }
    
    var body: some View {
        Button {
            playEpisode()
        } label: {
            HStack(spacing: 30) {
                // Episode Number
                Text("\(episode.number)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 300, height: 169)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Quality Badge
                    if let file = episode.files?.first {
                        Text(qualityText(file.quality))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(episodeTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    // Episode description from TMDB
                    if let overview = episodeOverview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(isFocused ? 4 : 2)
                    }
                    
                    HStack(spacing: 20) {
                        if let duration = episode.duration {
                            Label(formatDuration(Int(duration)), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let runtime = tmdbEpisode?.runtime {
                            Label("\(runtime)м", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let audios = episode.audios, !audios.isEmpty {
                            // Show audio tracks count and first track info
                            let firstAudio = audios[0]
                            let audioInfo = firstAudio.formattedDescription
                            let displayText = audios.count > 1 
                                ? "\(audioInfo) +\(audios.count - 1)"
                                : audioInfo
                            Label(displayText.isEmpty ? "\(audios.count) дорожек" : displayText, systemImage: "speaker.wave.2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let subs = episode.subtitles, !subs.isEmpty {
                            Label("\(subs.count) субтитров", systemImage: "captions.bubble")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Air date from TMDB
                        if let airDate = tmdbEpisode?.airDate {
                            Label(airDate, systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Status
                if isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else if isInProgress {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.title2)
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 20)
            .background(isFocused ? Color.gray.opacity(0.2) : Color.clear)
            .focused($isFocused)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: nil) {
                toggleWatched()
            } label: {
                if isWatched {
                    Text("Отметить непросмотренным")
                    Image(systemName: "xmark.circle")
                } else {
                    Text("Отметить просмотренным")
                    Image(systemName: "checkmark.circle")
                }
            }
        }
        
        if !isLast {
            Divider()
                .padding(.leading, 80)
                .padding(.trailing, 50)
        }
    }
    
    private func playEpisode() {
        guard let file = episode.files?.first,
              let urlString = file.url.hls4 ?? file.url.hls ?? file.url.http,
              let url = URL(string: urlString) else { return }
        
        // Set metadata for the player info panel
        var metadata: [AVMetadataItem] = []
        
        // Title
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = item.displayTitle as NSString
        metadata.append(titleItem)
        
        // Episode subtitle
        let subtitleItem = AVMutableMetadataItem()
        subtitleItem.identifier = .iTunesMetadataTrackSubTitle
        subtitleItem.value = "S\(seasonNumber)E\(episode.number) - \(episodeTitle)" as NSString
        metadata.append(subtitleItem)
        
        // Build description with audio info
        var descriptionParts: [String] = []
        
        // Episode overview from TMDB
        if let overview = episodeOverview, !overview.isEmpty {
            descriptionParts.append(overview)
        }
        
        // Audio tracks formatted for player: "Русский - AniLibria - AC3"
        if let audios = episode.audios, !audios.isEmpty {
            let audioLines = audios.map { $0.formattedForPlayer }
            let audioSection = "🔊 Доступные аудиодорожки:\n" + audioLines.enumerated().map { idx, line in
                "\(idx + 1). \(line)"
            }.joined(separator: "\n")
            descriptionParts.append(audioSection)
        }
        
        // Set combined description
        if !descriptionParts.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = descriptionParts.joined(separator: "\n\n") as NSString
            metadata.append(descItem)
        }
        
        // Calculate start time for resume
        let startTime: CMTime? = if let watchTime = episode.watching?.time, watchTime > 0 {
            CMTime(seconds: Double(watchTime), preferredTimescale: 1)
        } else {
            nil
        }
        
        // Present with audio track selection if multiple tracks available
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            AudioTrackPlaybackHelper.playWithAudioSelection(
                url: url,
                audioTracks: episode.audios,
                metadata: metadata,
                startTime: startTime,
                itemID: item.id,
                seasonNumber: seasonNumber,
                videoID: episode.id,
                autoPlayNext: {
                    guard AppSettings.shared.autoPlayNextEpisode,
                          let next = nextEpisode,
                          let nextFile = next.files?.first,
                          let nextURLString = nextFile.url.hls4 ?? nextFile.url.hls ?? nextFile.url.http,
                          let nextURL = URL(string: nextURLString) else { return nil }
                    
                    var nextMetadata: [AVMetadataItem] = []
                    let titleItem = AVMutableMetadataItem()
                    titleItem.identifier = .commonIdentifierTitle
                    titleItem.value = item.displayTitle as NSString
                    nextMetadata.append(titleItem)
                    
                    let subtitleItem = AVMutableMetadataItem()
                    subtitleItem.identifier = .iTunesMetadataTrackSubTitle
                    subtitleItem.value = "S\(seasonNumber)E\(next.number) - \(next.displayTitle)" as NSString
                    nextMetadata.append(subtitleItem)
                    
                    let nextStart: CMTime? = if let watchTime = next.watching?.time, watchTime > 0 {
                        CMTime(seconds: Double(watchTime), preferredTimescale: 1)
                    } else {
                        nil
                    }
                    
                    return PlaybackContext(
                        url: nextURL,
                        audioTracks: next.audios,
                        metadata: nextMetadata,
                        startTime: nextStart,
                        itemID: item.id,
                        seasonNumber: seasonNumber,
                        videoID: next.id
                    )
                },
                from: rootVC
            )
        }
    }
    
    private func toggleWatched() {
        Task {
            do {
                let token = try await AuthService.shared.getValidToken()
                try await ContentService.shared.toggleWatched(
                    itemID: item.id,
                    season: seasonNumber,
                    video: episode.id,
                    accessToken: token
                )
            } catch {
                print("Error toggling watched: \(error)")
            }
        }
    }
    
    private func qualityText(_ quality: String) -> String {
        switch quality {
        case "2160p": return "4K"
        case "1080p": return "FHD"
        case "720p": return "HD"
        default: return "SD"
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return String(format: "%d:%02d", 0, minutes)
        }
    }
}

#Preview {
    NavigationStack {
        EpisodesView(
            season: Season(
                id: 1,
                number: 1,
                title: "Сезон 1",
                episodes: [],
                watching: nil
            ),
            item: Item(
                id: 1,
                title: "Test",
                type: "serial",
                subtype: nil,
                year: 2024,
                cast: nil,
                director: nil,
                voice: nil,
                duration: nil,
                langs: nil,
                ac3: nil,
                subtitles: nil,
                quality: nil,
                genres: nil,
                countries: nil,
                plot: nil,
                imdb: nil,
                imdbRating: nil,
                imdbVotes: nil,
                kinopoisk: nil,
                kinopoiskRating: nil,
                kinopoiskVotes: nil,
                rating: nil,
                ratingPercentage: nil,
                ratingVotes: nil,
                views: nil,
                comments: nil,
                finished: nil,
                advert: nil,
                inWatchlist: nil,
                subscribed: nil,
                posters: nil,
                trailer: nil,
                seasons: nil,
                videos: nil,
                createdAt: nil,
                updatedAt: nil,
                poorQuality: nil,
                new: nil
            )
        )
    }
}
