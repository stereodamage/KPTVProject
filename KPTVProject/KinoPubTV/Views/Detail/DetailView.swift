//
//  DetailView.swift
//  KinoPubTV
//

import SwiftUI
import AVKit

struct DetailView: View {
    let itemID: Int
    @State private var viewModel = DetailViewModel()
    @State private var showingBookmarks = false
    @State private var selectedSeason: Season?
    @State private var selectedPerson: String?
    
    var body: some View {
        ScrollView {
            if let item = viewModel.item {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero Section
                    ZStack(alignment: .bottomLeading) {
                        // Background
                        AsyncImage(url: URL.secure(string: item.posters?.wide ?? item.posters?.big)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(height: 700)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        
                        // Content
                        HStack(alignment: .bottom, spacing: 40) {
                            // Poster
                            AsyncImage(url: URL.secure(string: item.posters?.medium)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 250, height: 376)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            // Info
                            VStack(alignment: .leading, spacing: 16) {
                                Text(item.displayTitle)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                if let originalTitle = item.originalTitle {
                                    Text(originalTitle)
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Metadata
                                HStack(spacing: 20) {
                                    if let year = item.year {
                                        Text(String(year))
                                    }
                                    if let country = item.countries?.first?.title {
                                        Text(country)
                                    }
                                    if let genre = item.genres?.first?.title {
                                        Text(genre)
                                    }
                                    if let duration = item.duration?.totalInt {
                                        Text(formatDuration(duration))
                                    }
                                    if let quality = item.quality {
                                        QualityBadge(quality: quality)
                                    }
                                }
                                .font(.callout)
                                .foregroundColor(.secondary)
                                
                                // Ratings
                                HStack(spacing: 30) {
                                    if let rating = item.kinopoiskRating, rating > 0 {
                                        RatingBadge(source: .kinopoisk, rating: rating)
                                    }
                                    if let rating = item.imdbRating, rating > 0 {
                                        RatingBadge(source: .imdb, rating: rating)
                                    }
                                    if let rating = item.ratingPercentage, rating > 0 {
                                        RatingBadge(source: .kinopub, rating: Double(rating) / 10)
                                    }
                                }
                                
                                // Action Buttons
                                HStack(spacing: 20) {
                                    Button {
                                        playContent()
                                    } label: {
                                        Label("Смотреть", systemImage: "play.fill")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(white: 0.85))
                                    .foregroundStyle(.black)
                                    
                                    if let trailer = item.trailer?.url, !trailer.isEmpty {
                                        Button {
                                            playTrailer(url: trailer)
                                        } label: {
                                            Label("Трейлер", systemImage: "film")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Color(white: 0.85))
                                        .foregroundStyle(.black)
                                    }
                                    
                                    Button {
                                        showingBookmarks = true
                                    } label: {
                                        Label("В закладки", systemImage: "plus")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(white: 0.85))
                                    .foregroundStyle(.black)
                                    
                                    if item.isSerial {
                                        Button {
                                            Task {
                                                await viewModel.toggleWatchlist()
                                            }
                                        } label: {
                                            Label(
                                                item.subscribed == true ? "Не буду смотреть" : "Буду смотреть",
                                                systemImage: item.subscribed == true ? "star.fill" : "star"
                                            )
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Color(white: 0.85))
                                        .foregroundStyle(.black)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(50)
                    }
                    
                    // Description
                    if let plot = item.plot, !plot.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Описание")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(plot)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(50)
                    }
                    
                    // Seasons (for serials)
                    if item.isSerial, let seasons = item.seasons, !seasons.isEmpty {
                        SeasonsSection(
                            seasons: seasons,
                            item: item,
                            onToggleWatched: { season in
                                Task {
                                    await viewModel.toggleWatched(season: season)
                                }
                            }
                        )
                    }
                    
                    // Videos (for movies/multi)
                    if !item.isSerial, let videos = item.videos, videos.count > 1 {
                        VideosSection(videos: videos, item: item)
                    }
                    
                    // Similar
                    if !viewModel.similarItems.isEmpty {
                        ContentShelf(title: "Рекомендуемое", items: viewModel.similarItems)
                            .padding(.vertical, 30)
                    }
                    
                    // Cast & Crew
                    if let cast = item.cast, !cast.isEmpty {
                        CastSection(cast: cast, director: item.director) { personName in
                            selectedPerson = personName
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationDestination(for: Item.self) { item in
            DetailView(itemID: item.id)
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedPerson != nil },
            set: { if !$0 { selectedPerson = nil } }
        )) {
            if let person = selectedPerson {
                PersonSearchView(personName: person)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.item == nil {
                ProgressView("Загрузка...")
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadItem(id: itemID)
        }
    }
    
    private func playContent() {
        guard let item = viewModel.item else { return }
        
        var videoURL: String?
        var audios: [AudioTrack]?
        var episodeTitle: String?
        var playbackSeasonNumber: Int?
        var playbackVideoID: Int?
        var startTime: CMTime?
        
        if item.isSerial {
            // Find first unwatched episode
            if let seasons = item.seasons {
                for season in seasons {
                    if let episode = season.episodes.first(where: { ($0.watched ?? 0) < 1 }),
                       let file = episode.files?.first,
                       let url = file.url.hls4 ?? file.url.hls ?? file.url.http {
                        videoURL = url
                        audios = episode.audios
                        episodeTitle = episode.displayTitle
                        playbackSeasonNumber = season.number
                        playbackVideoID = episode.id
                        if let watchTime = episode.watching?.time, watchTime > 0 {
                            startTime = CMTime(seconds: Double(watchTime), preferredTimescale: 1)
                        }
                        break
                    }
                }
                // Fallback to first episode
                if videoURL == nil,
                   let season = seasons.first,
                   let episode = season.episodes.first,
                   let file = episode.files?.first,
                   let url = file.url.hls4 ?? file.url.hls ?? file.url.http {
                    videoURL = url
                    audios = episode.audios
                    episodeTitle = episode.displayTitle
                    playbackSeasonNumber = season.number
                    playbackVideoID = episode.id
                    if let watchTime = episode.watching?.time, watchTime > 0 {
                        startTime = CMTime(seconds: Double(watchTime), preferredTimescale: 1)
                    }
                }
            }
        } else {
            // Movie
            if let video = item.videos?.first,
               let file = video.files?.first,
               let url = file.url.hls4 ?? file.url.hls ?? file.url.http {
                videoURL = url
                audios = video.audios
                playbackVideoID = video.id
                if let watchTime = video.watching?.time, watchTime > 0 {
                    startTime = CMTime(seconds: Double(watchTime), preferredTimescale: 1)
                }
            }
        }
        
        guard let urlString = videoURL, let url = URL(string: urlString) else { return }
        
        // Set metadata for the player info panel
        var metadata: [AVMetadataItem] = []
        
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = item.displayTitle as NSString
        metadata.append(titleItem)
        
        if let epTitle = episodeTitle {
            let subtitleItem = AVMutableMetadataItem()
            subtitleItem.identifier = .iTunesMetadataTrackSubTitle
            subtitleItem.value = epTitle as NSString
            metadata.append(subtitleItem)
        }
        
        var descriptionParts: [String] = []
        if let plot = item.plot, !plot.isEmpty {
            descriptionParts.append(plot)
        }
        if let audioTracks = audios, !audioTracks.isEmpty {
            let audioLines = audioTracks.map { $0.formattedForPlayer }
            let audioSection = "🔊 Аудио: " + audioLines.joined(separator: " | ")
            descriptionParts.append(audioSection)
        }
        if !descriptionParts.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = descriptionParts.joined(separator: "\n\n") as NSString
            metadata.append(descItem)
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            AudioTrackPlaybackHelper.playWithAudioSelection(
                url: url,
                audioTracks: audios,
                metadata: metadata,
                startTime: startTime,
                itemID: item.id,
                seasonNumber: playbackSeasonNumber,
                videoID: playbackVideoID,
                from: rootVC
            )
        }
    }
    
    private func playTrailer(url: String) {
        guard let videoURL = URL(string: url) else { return }
        
        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        
        // Enable Picture-in-Picture for trailers too
        playerVC.allowsPictureInPicturePlayback = true
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(playerVC, animated: true) {
                player.play()
            }
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

// MARK: - Supporting Views

struct QualityBadge: View {
    let quality: Int
    
    var text: String {
        switch quality {
        case 2160: return "4K"
        case 1080: return "FULL HD"
        case 720: return "HD"
        default: return "SD"
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct RatingBadge: View {
    let source: RatingSource
    let rating: Double
    
    enum RatingSource {
        case kinopoisk
        case imdb
        case kinopub
        
        var label: String {
            switch self {
            case .kinopoisk: return "КП"
            case .imdb: return "IMDb"
            case .kinopub: return "KinoPub"
            }
        }
        
        var color: Color {
            switch self {
            case .kinopoisk: return .orange
            case .imdb: return .yellow
            case .kinopub: return .accentColor
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(source.label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(source.color)
            Text(String(format: "%.1f", rating))
                .font(.headline)
                .fontWeight(.bold)
        }
    }
}

struct SeasonsSection: View {
    let seasons: [Season]
    let item: Item
    let onToggleWatched: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Сезоны")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 50)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 30) {
                    ForEach(seasons) { season in
                        VStack(alignment: .leading, spacing: 24) {
                            NavigationLink {
                                EpisodesView(season: season, item: item)
                            } label: {
                                SeasonCard(season: season, posterURL: item.posters?.medium)
                            }
                            .buttonStyle(.card)
                            .contextMenu {
                                Button(role: nil) {
                                    onToggleWatched(season.number)
                                } label: {
                                    Text("Отметить просмотренным")
                                    Image(systemName: "checkmark")
                                }
                            }
                            
                            // Metadata below card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Сезон \(season.number)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    Text(RussianPlural.episodes(season.episodes.count))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    let watchedCount = season.episodes.filter { ($0.watched ?? 0) > 0 }.count
                                    if watchedCount == season.episodes.count {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    } else if watchedCount > 0 {
                                        let newCount = season.episodes.count - watchedCount
                                        Text("\(newCount) новых")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.red.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .frame(width: 250, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 30)
            }
        }
        .padding(.vertical, 30)
    }
}

struct SeasonCard: View {
    let season: Season
    let posterURL: String?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Poster image
            AsyncImage(url: URL.secure(string: posterURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(white: 0.15))
            }
            .frame(width: 250, height: 375)
            .clipped()
        }
        // Let .card buttonStyle handle focus effects
    }
}

struct VideosSection: View {
    let videos: [Video]
    let item: Item
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Видео")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 50)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 30) {
                    ForEach(videos) { video in
                        VStack(alignment: .leading, spacing: 24) {
                            VideoCard(video: video, item: item)
                            
                            // Metadata below card
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.displayTitle)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    let duration = video.durationInt
                                    if duration > 0 {
                                        Text(duration.formattedDuration)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let file = video.files?.first {
                                        Text(qualityText(file.quality))
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                            .frame(width: 400, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 30)
            }
        }
        .padding(.vertical, 30)
    }
    
    private func qualityText(_ quality: String) -> String {
        switch quality {
        case "2160p": return "4K"
        case "1080p": return "FHD"
        case "720p": return "HD"
        default: return "SD"
        }
    }
}

struct VideoCard: View {
    let video: Video
    let item: Item
    
    var body: some View {
        Button {
            playVideo()
        } label: {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                AsyncImage(url: URL.secure(string: video.thumbnail)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(white: 0.15))
                }
                .frame(width: 400, height: 225)
                .clipped()
                
                // Watched badge
                if let status = video.watching?.status, status > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                }
            }
        }
        .buttonStyle(.card)
    }
    
    private func playVideo() {
        guard let file = video.files?.first,
              let urlString = file.url.hls4 ?? file.url.hls ?? file.url.http,
              let url = URL(string: urlString) else { return }
        
        // Set metadata
        var metadata: [AVMetadataItem] = []
        
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = item.displayTitle as NSString
        metadata.append(titleItem)
        
        let subtitleItem = AVMutableMetadataItem()
        subtitleItem.identifier = .iTunesMetadataTrackSubTitle
        subtitleItem.value = video.displayTitle as NSString
        metadata.append(subtitleItem)
        
        // Build description with audio info
        var descriptionParts: [String] = []
        
        if let plot = item.plot, !plot.isEmpty {
            descriptionParts.append(plot)
        }
        
        if let audios = video.audios, !audios.isEmpty {
            let audioLines = audios.map { $0.formattedForPlayer }
            let audioSection = "🔊 Аудио: " + audioLines.joined(separator: " | ")
            descriptionParts.append(audioSection)
        }
        
        if !descriptionParts.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = descriptionParts.joined(separator: "\n\n") as NSString
            metadata.append(descItem)
        }
        
        let startTime: CMTime? = if let watchTime = video.watching?.time, watchTime > 0 {
            CMTime(seconds: Double(watchTime), preferredTimescale: 1)
        } else {
            nil
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            AudioTrackPlaybackHelper.playWithAudioSelection(
                url: url,
                audioTracks: video.audios,
                metadata: metadata,
                startTime: startTime,
                itemID: item.id,
                videoID: video.id,
                from: rootVC
            )
        }
    }
}

struct CastSection: View {
    let cast: String
    let director: String?
    let onPersonTap: (String) -> Void
    
    var castList: [String] {
        cast.components(separatedBy: ", ")
    }
    
    var directorList: [String] {
        director?.components(separatedBy: ", ") ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Актёры и съёмочная группа")
                .font(.title2)
                .fontWeight(.bold)
            
            if !directorList.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Режиссёр")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            ForEach(directorList, id: \.self) { person in
                                VStack(spacing: 12) {
                                    PersonButton(name: person) {
                                        onPersonTap(person)
                                    }
                                    
                                    Text(person)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 120, height: 50, alignment: .top) // Fixed height for alignment
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("В ролях")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 30) {
                        ForEach(castList.prefix(15), id: \.self) { person in
                            VStack(spacing: 12) {
                                PersonButton(name: person) {
                                    onPersonTap(person)
                                }
                                
                                Text(person)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 120, height: 50, alignment: .top) // Fixed height for alignment
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(50)
    }
}

struct PersonButton: View {
    let name: String
    let action: () -> Void
    @State private var imageURL: URL?
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if let url = imageURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(white: 0.2))
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(white: 0.2))
                        .frame(width: 120, height: 120)
                    
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .buttonStyle(.card)
        .task {
            if AppSettings.shared.useTMDBMetadata {
                imageURL = try? await TMDBService.shared.getPersonImage(name: name)
            }
        }
    }
}

struct BookmarksSheet: View {
    @Bindable var viewModel: DetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(viewModel.allFolders) { folder in
                Button {
                    Task {
                        await viewModel.toggleBookmark(folderID: folder.id)
                    }
                } label: {
                    HStack {
                        Text(folder.title)
                        Spacer()
                        if viewModel.itemFolders.contains(where: { $0.id == folder.id }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Закладки")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadBookmarkFolders()
            }
        }
    }
}

// MARK: - Person Search View

struct PersonSearchView: View {
    let personName: String
    
    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Поиск...")
                    .padding(.top, 100)
            } else if items.isEmpty {
                ContentUnavailableView(
                    "Ничего не найдено",
                    systemImage: "person.fill.questionmark",
                    description: Text("Не найдено работ с участием \(personName)")
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5),
                    spacing: 50
                ) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 24) {
                            NavigationLink(value: item) {
                                PosterCard(item: item)
                            }
                            .buttonStyle(.card)
                            
                            ItemMetadata(item: item, width: 250)
                        }
                    }
                }
                .padding(50)
            }
        }
        .navigationTitle(personName)
        .navigationDestination(for: Item.self) { item in
            DetailView(itemID: item.id)
        }
        .task {
            await searchPerson()
        }
    }
    
    private func searchPerson() async {
        isLoading = true
        
        do {
            let token = try await AuthService.shared.getValidToken()
            let response = try await ContentService.shared.search(query: personName, accessToken: token)
            items = response.items
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    DetailView(itemID: 1)
}
