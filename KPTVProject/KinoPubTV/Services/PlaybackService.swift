//
//  PlaybackService.swift
//  KinoPubTV
//
//  Central service for video playback that wraps API calls and transforms
//  responses into tvOS AVPlayer-compatible format with enriched metadata.
//

import Foundation
import AVFoundation
import AVKit

// MARK: - Playback Data Models

/// Enriched audio track with formatted display names for AVPlayer
struct EnrichedAudioTrack: Sendable {
    let originalTrack: AudioTrack
    let displayName: String           // For HLS manifest NAME attribute
    let menuTitle: String             // For transport bar menu
    let languageCode: String          // Normalized language code (ru, en, etc.)
    let index: Int
    
    init(track: AudioTrack, index: Int) {
        self.originalTrack = track
        self.index = index
        self.displayName = track.formattedForHLSManifest
        self.menuTitle = track.formattedForPlayerMenu
        self.languageCode = Self.normalizeLanguageCode(track.lang ?? "und")
    }
    
    private static func normalizeLanguageCode(_ code: String) -> String {
        let lowered = code.lowercased()
        switch lowered {
        case "rus", "ru": return "ru"
        case "eng", "en": return "en"
        case "ukr", "uk": return "uk"
        case "jpn", "ja": return "ja"
        case "ger", "de", "deu": return "de"
        case "fre", "fr", "fra": return "fr"
        case "spa", "es": return "es"
        case "ita", "it": return "it"
        case "por", "pt": return "pt"
        case "kor", "ko": return "ko"
        case "chi", "zh", "zho": return "zh"
        default: return String(lowered.prefix(2))
        }
    }
}

/// Enriched subtitle with formatted display name
struct EnrichedSubtitle: Sendable {
    let originalSubtitle: Subtitle
    let displayName: String
    let languageCode: String
    let isEmbedded: Bool
    
    init(subtitle: Subtitle, index: Int) {
        self.originalSubtitle = subtitle
        self.isEmbedded = subtitle.embed ?? false
        self.languageCode = Self.normalizeLanguageCode(subtitle.lang ?? "und")
        self.displayName = LanguageHelper.localizedName(for: subtitle.lang ?? "und")
    }
    
    private static func normalizeLanguageCode(_ code: String) -> String {
        let lowered = code.lowercased()
        switch lowered {
        case "rus", "ru": return "ru"
        case "eng", "en": return "en"
        case "ukr", "uk": return "uk"
        default: return String(lowered.prefix(2))
        }
    }
}

/// Complete playback data with all enriched metadata
struct PlaybackData: Sendable {
    let streamURL: URL
    let audioTracks: [EnrichedAudioTrack]
    let subtitles: [EnrichedSubtitle]
    let metadata: PlayerMetadata
    let resumeTime: CMTime?
    let itemID: Int
    let videoID: Int
    let seasonNumber: Int?
    let availableQualities: [QualityOption]
    let currentQuality: String
    
    /// Returns the preferred audio track index based on user's locale
    var preferredAudioTrackIndex: Int? {
        let prefersRussian = Locale.preferredLanguages.contains { $0.lowercased().hasPrefix("ru") }
        if prefersRussian {
            return audioTracks.firstIndex { $0.languageCode == "ru" }
        }
        return nil
    }
}

/// Quality option for the player menu
struct QualityOption: Sendable {
    let quality: String
    let displayName: String
    let url: URL
    
    init(file: VideoFile) {
        self.quality = file.quality
        self.displayName = Self.formatQualityName(file.quality)
        // Use preferredURL from settings
        let urlString = file.url.preferredURL ?? file.url.hls ?? file.url.http ?? ""
        self.url = URL(string: urlString) ?? URL(string: "about:blank")!
    }
    
    private static func formatQualityName(_ quality: String) -> String {
        switch quality {
        case "2160p": return "4K (2160p)"
        case "1080p": return "Full HD (1080p)"
        case "720p": return "HD (720p)"
        case "480p": return "SD (480p)"
        case "360p": return "360p"
        default: return quality.uppercased()
        }
    }
}

/// Player metadata (title, description, artwork)
struct PlayerMetadata: Sendable {
    let title: String
    let subtitle: String?
    let description: String?
    let artworkURL: URL?
    
    func toAVMetadata() -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        items.append(titleItem)
        
        if let subtitle = subtitle {
            let subtitleItem = AVMutableMetadataItem()
            subtitleItem.identifier = .iTunesMetadataTrackSubTitle
            subtitleItem.value = subtitle as NSString
            items.append(subtitleItem)
        }
        
        if let description = description {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = description as NSString
            items.append(descItem)
        }
        
        return items
    }
}

// MARK: - Playback Service

/// Central service that fetches video data from API and transforms it for AVPlayer
actor PlaybackService {
    static let shared = PlaybackService()
    
    private let contentService = ContentService.shared
    
    private init() {}
    
    // MARK: - Public API
    
    /// Prepares playback data for a movie or standalone video
    func preparePlayback(
        for item: Item,
        video: Video,
        preferredQuality: String? = nil
    ) async throws -> PlaybackData {
        let accessToken = try await AuthService.shared.getValidToken()
        
        // Get fresh item data to ensure we have latest video URLs
        let freshItem = try await contentService.getItem(id: item.id, accessToken: accessToken)
        
        // Find the video in fresh data
        guard let freshVideo = freshItem.item.videos?.first(where: { $0.id == video.id }) else {
            throw PlaybackError.videoNotFound
        }
        
        return buildPlaybackData(
            item: freshItem.item,
            video: freshVideo,
            seasonNumber: nil,
            preferredQuality: preferredQuality
        )
    }
    
    /// Prepares playback data for a TV series episode
    func preparePlayback(
        for item: Item,
        season: Season,
        episode: Episode,
        preferredQuality: String? = nil
    ) async throws -> PlaybackData {
        let accessToken = try await AuthService.shared.getValidToken()
        
        // Get fresh item data
        let freshItem = try await contentService.getItem(id: item.id, accessToken: accessToken)
        
        // Find the season and episode
        guard let freshSeason = freshItem.item.seasons?.first(where: { $0.number == season.number }),
              let freshEpisode = freshSeason.episodes.first(where: { $0.id == episode.id }) else {
            throw PlaybackError.episodeNotFound
        }
        
        return buildPlaybackData(
            item: freshItem.item,
            episode: freshEpisode,
            seasonNumber: freshSeason.number,
            preferredQuality: preferredQuality
        )
    }
    
    /// Prepares playback directly from an Episode (used by EpisodesView)
    func preparePlayback(
        itemID: Int,
        episode: Episode,
        seasonNumber: Int,
        preferredQuality: String? = nil
    ) async throws -> PlaybackData {
        let accessToken = try await AuthService.shared.getValidToken()
        let freshItem = try await contentService.getItem(id: itemID, accessToken: accessToken)
        
        // Find fresh episode data
        guard let freshSeason = freshItem.item.seasons?.first(where: { $0.number == seasonNumber }),
              let freshEpisode = freshSeason.episodes.first(where: { $0.id == episode.id }) else {
            throw PlaybackError.episodeNotFound
        }
        
        return buildPlaybackData(
            item: freshItem.item,
            episode: freshEpisode,
            seasonNumber: seasonNumber,
            preferredQuality: preferredQuality
        )
    }
    
    /// Prepares playback data for a specific episode by ID (used for auto-play next)
    func prepareNextEpisode(
        itemID: Int,
        seasonNumber: Int,
        episodeID: Int,
        preferredQuality: String? = nil
    ) async throws -> PlaybackData {
        let accessToken = try await AuthService.shared.getValidToken()
        let freshItem = try await contentService.getItem(id: itemID, accessToken: accessToken)
        
        guard let freshSeason = freshItem.item.seasons?.first(where: { $0.number == seasonNumber }),
              let freshEpisode = freshSeason.episodes.first(where: { $0.id == episodeID }) else {
            throw PlaybackError.episodeNotFound
        }
        
        return buildPlaybackData(
            item: freshItem.item,
            episode: freshEpisode,
            seasonNumber: seasonNumber,
            preferredQuality: preferredQuality
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildPlaybackData(
        item: Item,
        video: Video,
        seasonNumber: Int?,
        preferredQuality: String?
    ) -> PlaybackData {
        let files = video.files ?? []
        let selectedFile = selectFile(from: files, preferredQuality: preferredQuality)
        
        guard let urlString = selectedFile?.url.preferredURL,
              let streamURL = URL(string: urlString) else {
            // Return a placeholder - caller should handle this
            return PlaybackData(
                streamURL: URL(string: "about:blank")!,
                audioTracks: [],
                subtitles: [],
                metadata: PlayerMetadata(title: item.displayTitle, subtitle: nil, description: nil, artworkURL: nil),
                resumeTime: nil,
                itemID: item.id,
                videoID: video.id,
                seasonNumber: seasonNumber,
                availableQualities: [],
                currentQuality: ""
            )
        }
        
        // Enrich audio tracks
        let enrichedAudio = (video.audios ?? []).enumerated().map { idx, track in
            EnrichedAudioTrack(track: track, index: idx)
        }
        
        // Enrich subtitles
        let enrichedSubs = (video.subtitles ?? []).enumerated().map { idx, sub in
            EnrichedSubtitle(subtitle: sub, index: idx)
        }
        
        // Build metadata
        let metadata = PlayerMetadata(
            title: item.displayTitle,
            subtitle: video.displayTitle,
            description: item.plot,
            artworkURL: URL.secure(string: item.posters?.big)
        )
        
        // Resume time
        let resumeTime: CMTime? = if let watchTime = video.watching?.time, watchTime > 0 {
            CMTime(seconds: Double(watchTime), preferredTimescale: 1)
        } else {
            nil
        }
        
        // Available qualities
        let qualities = files.map { QualityOption(file: $0) }
        
        return PlaybackData(
            streamURL: streamURL,
            audioTracks: enrichedAudio,
            subtitles: enrichedSubs,
            metadata: metadata,
            resumeTime: resumeTime,
            itemID: item.id,
            videoID: video.id,
            seasonNumber: seasonNumber,
            availableQualities: qualities,
            currentQuality: selectedFile?.quality ?? ""
        )
    }
    
    private func buildPlaybackData(
        item: Item,
        episode: Episode,
        seasonNumber: Int,
        preferredQuality: String?
    ) -> PlaybackData {
        let files = episode.files ?? []
        let selectedFile = selectFile(from: files, preferredQuality: preferredQuality)
        
        guard let urlString = selectedFile?.url.preferredURL,
              let streamURL = URL(string: urlString) else {
            return PlaybackData(
                streamURL: URL(string: "about:blank")!,
                audioTracks: [],
                subtitles: [],
                metadata: PlayerMetadata(title: item.displayTitle, subtitle: nil, description: nil, artworkURL: nil),
                resumeTime: nil,
                itemID: item.id,
                videoID: episode.id,
                seasonNumber: seasonNumber,
                availableQualities: [],
                currentQuality: ""
            )
        }
        
        // Enrich audio tracks
        let enrichedAudio = (episode.audios ?? []).enumerated().map { idx, track in
            EnrichedAudioTrack(track: track, index: idx)
        }
        
        // Enrich subtitles
        let enrichedSubs = (episode.subtitles ?? []).enumerated().map { idx, sub in
            EnrichedSubtitle(subtitle: sub, index: idx)
        }
        
        // Build metadata with episode info
        let episodeTitle = "S\(seasonNumber)E\(episode.number): \(episode.displayTitle)"
        let metadata = PlayerMetadata(
            title: item.displayTitle,
            subtitle: episodeTitle,
            description: item.plot,
            artworkURL: URL.secure(string: episode.thumbnail ?? item.posters?.big)
        )
        
        // Resume time
        let resumeTime: CMTime? = if let watchTime = episode.watching?.time, watchTime > 0 {
            CMTime(seconds: Double(watchTime), preferredTimescale: 1)
        } else {
            nil
        }
        
        // Available qualities
        let qualities = files.map { QualityOption(file: $0) }
        
        return PlaybackData(
            streamURL: streamURL,
            audioTracks: enrichedAudio,
            subtitles: enrichedSubs,
            metadata: metadata,
            resumeTime: resumeTime,
            itemID: item.id,
            videoID: episode.id,
            seasonNumber: seasonNumber,
            availableQualities: qualities,
            currentQuality: selectedFile?.quality ?? ""
        )
    }
    
    private func selectFile(from files: [VideoFile], preferredQuality: String?) -> VideoFile? {
        if let preferred = preferredQuality,
           let match = files.first(where: { $0.quality == preferred }) {
            return match
        }
        return files.preferredFile
    }
}

// MARK: - Errors

enum PlaybackError: LocalizedError {
    case videoNotFound
    case episodeNotFound
    case noStreamURL
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .videoNotFound:
            return "Видео не найдено"
        case .episodeNotFound:
            return "Эпизод не найден"
        case .noStreamURL:
            return "Ссылка на видео недоступна"
        case .authenticationRequired:
            return "Требуется авторизация"
        }
    }
}
