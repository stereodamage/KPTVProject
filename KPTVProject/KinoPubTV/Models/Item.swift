//
//  Item.swift
//  KinoPubTV
//

import Foundation

// MARK: - Item Response

struct ItemResponse: Codable {
    let item: Item
}

struct ItemsResponse: Codable {
    let items: [Item]
    let pagination: Pagination?
}

struct Pagination: Codable {
    let total: Int
    let current: Int
    let perpage: Int
}

// MARK: - Item

struct Item: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let type: String
    let subtype: String?
    let year: Int?
    let cast: String?
    let director: String?
    let voice: String?
    let duration: Duration?
    let langs: Int?
    let ac3: Int?
    let subtitles: Int?
    let quality: Int?
    let genres: [Genre]?
    let countries: [Country]?
    let plot: String?
    let imdb: Int?
    let imdbRating: Double?
    let imdbVotes: Int?
    let kinopoisk: Int?
    let kinopoiskRating: Double?
    let kinopoiskVotes: Int?
    let rating: Int?
    let ratingPercentage: Int?
    let ratingVotes: Int?
    let views: Int?
    let comments: Int?
    let finished: Bool?
    let advert: Bool?
    let inWatchlist: Bool?
    let subscribed: Bool?
    let posters: Posters?
    let trailer: Trailer?
    let seasons: [Season]?
    let videos: [Video]?
    let createdAt: Int?
    let updatedAt: Int?
    let poorQuality: Bool?
    let new: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, type, subtype, year, cast, director, voice, duration
        case langs, ac3, subtitles, quality, genres, countries, plot
        case imdb, rating, views, comments, finished, advert
        case posters, trailer, seasons, videos
        case imdbRating = "imdb_rating"
        case imdbVotes = "imdb_votes"
        case kinopoisk
        case kinopoiskRating = "kinopoisk_rating"
        case kinopoiskVotes = "kinopoisk_votes"
        case ratingPercentage = "rating_percentage"
        case ratingVotes = "rating_votes"
        case inWatchlist = "in_watchlist"
        case subscribed
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case poorQuality = "poor_quality"
        case new
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id
    }
    
    var isSerial: Bool {
        type == "serial" || type == "docuserial" || type == "tvshow"
    }
    
    var displayTitle: String {
        title.components(separatedBy: " / ").first ?? title
    }
    
    var originalTitle: String? {
        let parts = title.components(separatedBy: " / ")
        return parts.count > 1 ? parts[1] : nil
    }
}

// MARK: - Duration

struct Duration: Codable {
    let average: Double?
    let total: Double?
    
    var averageInt: Int {
        Int(average ?? 0)
    }
    
    var totalInt: Int {
        Int(total ?? 0)
    }
}

// MARK: - Genre & Country

struct Genre: Codable, Identifiable {
    let id: Int
    let title: String
}

struct Country: Codable, Identifiable {
    let id: Int
    let title: String
}

// MARK: - Posters

struct Posters: Codable {
    let small: String?
    let medium: String?
    let big: String?
    let wide: String?
}

// MARK: - Trailer

struct Trailer: Codable {
    let id: Int?
    let url: String?
}

// MARK: - Season

struct Season: Codable, Identifiable {
    let id: Int?
    let number: Int
    let title: String?
    let episodes: [Episode]
    let watching: WatchingStatus?
    
    var displayTitle: String {
        title ?? "Сезон \(number)"
    }
}

// MARK: - Episode

struct Episode: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String?
    let thumbnail: String?
    let duration: Double?
    let watched: Int?
    let watching: WatchingStatus?
    let files: [VideoFile]?
    let audios: [AudioTrack]?
    let subtitles: [Subtitle]?
    let seasonNumber: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, thumbnail, duration, watched, watching
        case files, audios, subtitles
        case seasonNumber = "snumber"
    }
    
    var displayTitle: String {
        title?.components(separatedBy: " / ").first ?? "Серия \(number)"
    }
    
    var durationInt: Int {
        Int(duration ?? 0)
    }
}

// MARK: - Video (for movies/multi)

struct Video: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String?
    let thumbnail: String?
    let duration: Double?
    let watching: WatchingStatus?
    let files: [VideoFile]?
    let audios: [AudioTrack]?
    let subtitles: [Subtitle]?
    
    var displayTitle: String {
        title?.components(separatedBy: " / ").first ?? "Видео \(number)"
    }
    
    var durationInt: Int {
        Int(duration ?? 0)
    }
}

// MARK: - Video File

struct VideoFile: Codable {
    let quality: String
    let codec: String?
    let url: VideoURL
}

struct VideoURL: Codable {
    let http: String?
    let hls: String?
    let hls2: String?
    let hls4: String?
}

// MARK: - Audio Track

struct AudioTrack: Codable {
    let id: Int?
    let index: Int?
    let codec: String?
    let lang: String?
    let type: AudioType?
    let author: AudioAuthor?
}

struct AudioType: Codable {
    let id: Int?
    let title: String?
}

struct AudioAuthor: Codable {
    let id: Int?
    let title: String?
}

// MARK: - Subtitle

struct Subtitle: Codable {
    let lang: String?
    let shift: Int?
    let embed: Bool?
    let url: String?
}

// MARK: - Watching Status

struct WatchingStatus: Codable {
    let status: Int?
    let time: Int?
}

// MARK: - Watching Response

struct WatchingResponse: Codable {
    let items: [WatchingItem]?
}

struct WatchingItem: Codable, Identifiable {
    let id: Int
    let title: String?
    let type: String?
    let subtype: String?
    let posters: Posters?
    let new: Int?
    let subscribed: Bool?
}

// MARK: - History

struct HistoryResponse: Codable {
    let history: [HistoryItem]
}

struct HistoryItem: Codable, Identifiable {
    var id: Int { item.id }
    let item: Item
    let media: HistoryMedia
    let lastSeen: Int
    
    enum CodingKeys: String, CodingKey {
        case item, media
        case lastSeen = "last_seen"
    }
}

struct HistoryMedia: Codable {
    let id: Int
    let number: Int?
    let snumber: Int?
}
