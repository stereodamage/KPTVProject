//
//  TMDBService.swift
//  KinoPubTV
//
//  TMDB API integration for enhanced metadata (episode names, descriptions, posters)
//

import Foundation

// MARK: - TMDB Configuration

enum TMDBConfig {
    static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p"
    static let apiKey = APIConfiguration.tmdbAPIKey
    
    // Image sizes
    static let posterSizes = ["w92", "w154", "w185", "w342", "w500", "w780", "original"]
    static let stillSizes = ["w92", "w185", "w300", "original"]
    static let profileSizes = ["w45", "w185", "h632", "original"]
    static let backdropSizes = ["w300", "w780", "w1280", "original"]
}

// MARK: - TMDB Models

struct TMDBSearchResult: Codable, Sendable {
    let page: Int
    let results: [TMDBShow]
    let totalResults: Int
    let totalPages: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalResults = "total_results"
        case totalPages = "total_pages"
    }
}

struct TMDBPersonSearchResult: Codable, Sendable {
    let page: Int
    let results: [TMDBPerson]
    let totalResults: Int
    let totalPages: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalResults = "total_results"
        case totalPages = "total_pages"
    }
}

struct TMDBPerson: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case profilePath = "profile_path"
    }
    
    var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w185\(path)")
    }
}

struct TMDBShow: Codable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    
    // For movies
    let title: String?
    let originalTitle: String?
    let releaseDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, title
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case originalTitle = "original_title"
        case releaseDate = "release_date"
    }
    
    var displayName: String {
        name ?? title ?? ""
    }
    
    var year: Int? {
        let dateString = firstAirDate ?? releaseDate
        guard let date = dateString, date.count >= 4 else { return nil }
        return Int(date.prefix(4))
    }
    
    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w1280\(path)")
    }
    
    var backdropURLOriginal: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/original\(path)")
    }
}

struct TMDBSeasonDetail: Codable, Sendable {
    let id: Int
    let name: String?
    let overview: String?
    let posterPath: String?
    let seasonNumber: Int
    let episodes: [TMDBEpisode]?
    let airDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, episodes
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
        case airDate = "air_date"
    }
}

struct TMDBEpisode: Codable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let overview: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let stillPath: String?
    let airDate: String?
    let voteAverage: Double?
    let runtime: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }
    
    var stillURL: URL? {
        guard let path = stillPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/w300\(path)")
    }
    
    var stillURLLarge: URL? {
        guard let path = stillPath else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/original\(path)")
    }
}

struct TMDBExternalIds: Codable, Sendable {
    let imdbId: String?
    let tvdbId: Int?
    
    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case tvdbId = "tvdb_id"
    }
}

struct TMDBFindResult: Codable, Sendable {
    let tvResults: [TMDBShow]
    let movieResults: [TMDBShow]
    
    enum CodingKeys: String, CodingKey {
        case tvResults = "tv_results"
        case movieResults = "movie_results"
    }
}

// MARK: - Cached Episode Data

struct CachedTMDBEpisode: Sendable {
    let name: String?
    let overview: String?
    let stillURL: URL?
    let airDate: String?
    let runtime: Int?
}

// MARK: - TMDB Service

actor TMDBService {
    static let shared = TMDBService()
    
    private let session: URLSession
    private var showCache: [String: Int] = [:] // IMDb ID -> TMDB ID
    private var titleCache: [String: Int] = [:] // "title-year" -> TMDB ID
    private var showDetailCache: [Int: TMDBShow] = [:] // TMDB ID -> Show details
    private var episodeCache: [String: CachedTMDBEpisode] = [:] // "tmdbId-season-episode" -> episode data
    private var seasonCache: [String: TMDBSeasonDetail] = [:] // "tmdbId-season" -> season detail
    private var personCache: [String: URL] = [:] // Name -> Profile URL
    private var backdropCache: [Int: URL] = [:] // Item ID -> Backdrop URL
    
    // In-flight request deduplication
    private var pendingShowLookups: [String: Task<Int?, Error>] = [:]
    private var pendingSeasonLookups: [String: Task<TMDBSeasonDetail?, Error>] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Find TMDB ID for an item, using all available methods
    func findShowId(for item: Item) async throws -> Int? {
        // Try IMDb ID first (fastest)
        if let imdbId = item.imdb, imdbId > 0 {
            if let showId = try await findByIMDbId(String(imdbId)) {
                return showId
            }
        }
        
        // Try original title search
        if let originalTitle = item.originalTitle {
            if let showId = try await searchShowId(name: originalTitle, year: item.year, isSerial: item.isSerial) {
                return showId
            }
        }
        
        // Try localized title
        if let showId = try await searchShowId(name: item.displayTitle, year: item.year, isSerial: item.isSerial) {
            return showId
        }
        
        return nil
    }
    
    /// Search for TMDB ID by name (with caching)
    func searchShowId(name: String, year: Int?, isSerial: Bool) async throws -> Int? {
        let cacheKey = "\(name.lowercased())-\(year ?? 0)-\(isSerial ? "tv" : "movie")"
        
        // Check cache
        if let cached = titleCache[cacheKey] {
            return cached
        }
        
        // Check for in-flight request
        if let pending = pendingShowLookups[cacheKey] {
            return try await pending.value
        }
        
        // Create new lookup task
        let task = Task<Int?, Error> {
            let show = isSerial
                ? try await searchTVShow(name: name, year: year)
                : try await searchMovie(name: name, year: year)
            
            if let showId = show?.id {
                titleCache[cacheKey] = showId
                showDetailCache[showId] = show
                return showId
            }
            return nil
        }
        
        pendingShowLookups[cacheKey] = task
        defer { pendingShowLookups.removeValue(forKey: cacheKey) }
        
        return try await task.value
    }
    
    /// Find TMDB show/movie by IMDb ID
    func findByIMDbId(_ imdbId: String) async throws -> Int? {
        // Check cache first
        if let cachedId = showCache[imdbId] {
            return cachedId
        }
        
        // Check for in-flight request
        let cacheKey = "imdb-\(imdbId)"
        if let pending = pendingShowLookups[cacheKey] {
            return try await pending.value
        }
        
        // Create new lookup task
        let task = Task<Int?, Error> {
            // Format IMDb ID properly (tt + 7 digits)
            let formattedId = formatIMDbId(imdbId)
            
            let urlString = "\(TMDBConfig.baseURL)/find/\(formattedId)?api_key=\(TMDBConfig.apiKey)&external_source=imdb_id"
            
            guard let url = URL(string: urlString) else {
                return nil
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let result = try JSONDecoder().decode(TMDBFindResult.self, from: data)
            
            // Check TV results first, then movies
            if let show = result.tvResults.first {
                showCache[imdbId] = show.id
                showDetailCache[show.id] = show
                return show.id
            }
            
            if let movie = result.movieResults.first {
                showCache[imdbId] = movie.id
                showDetailCache[movie.id] = movie
                return movie.id
            }
            
            return nil
        }
        
        pendingShowLookups[cacheKey] = task
        defer { pendingShowLookups.removeValue(forKey: cacheKey) }
        
        return try await task.value
    }
    
    /// Search for TV show by name and year
    func searchTVShow(name: String, year: Int? = nil) async throws -> TMDBShow? {
        var urlString = "\(TMDBConfig.baseURL)/search/tv?api_key=\(TMDBConfig.apiKey)&query=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)&language=ru-RU"
        
        if let year = year {
            urlString += "&first_air_date_year=\(year)"
        }
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        let result = try JSONDecoder().decode(TMDBSearchResult.self, from: data)
        return result.results.first
    }
    
    /// Search for movie by name and year
    func searchMovie(name: String, year: Int? = nil) async throws -> TMDBShow? {
        var urlString = "\(TMDBConfig.baseURL)/search/movie?api_key=\(TMDBConfig.apiKey)&query=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)&language=ru-RU"
        
        if let year = year {
            urlString += "&year=\(year)"
        }
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        let result = try JSONDecoder().decode(TMDBSearchResult.self, from: data)
        return result.results.first
    }
    
    /// Get backdrop URL for an item by searching TMDB
    /// Get backdrop URL for an item by searching TMDB
    func getBackdropURL(for item: Item) async -> URL? {
        // Check cache first
        if let cachedURL = backdropCache[item.id] {
            return cachedURL
        }
        
        // Try TMDB search if enabled
        let useTMDB = await MainActor.run { AppSettings.shared.useTMDBMetadata }
        guard useTMDB else {
            // Fallback to wide poster from KinoPub
            return URL.secure(string: item.posters?.wide)
        }
        
        var backdropURL: URL?
        
        // Try IMDb ID first
        if let imdbId = item.imdb,
           let tmdbId = try? await findByIMDbId(String(imdbId)) {
            // If we found it via ID, we might have cached the details which contain the backdrop
            if let show = showDetailCache[tmdbId] {
                backdropURL = show.backdropURL
            } else {
                let show = item.isSerial 
                    ? try? await searchTVShow(name: item.displayTitle, year: item.year)
                    : try? await searchMovie(name: item.displayTitle, year: item.year)
                backdropURL = show?.backdropURL
            }
        } else {
            // Fallback to name search
            let show = item.isSerial 
                ? try? await searchTVShow(name: item.displayTitle, year: item.year)
                : try? await searchMovie(name: item.displayTitle, year: item.year)
            backdropURL = show?.backdropURL
        }
        
        // Cache and return (fallback to wide poster if nil)
        let finalURL = backdropURL ?? URL.secure(string: item.posters?.wide)
        if let url = finalURL {
            backdropCache[item.id] = url
        }
        return finalURL
    }
    
    /// Search for person by name and return profile image URL
    func getPersonImage(name: String) async throws -> URL? {
        // Check cache
        if let cachedURL = personCache[name] {
            return cachedURL
        }
        
        let urlString = "\(TMDBConfig.baseURL)/search/person?api_key=\(TMDBConfig.apiKey)&query=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)&language=ru-RU"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        let result = try JSONDecoder().decode(TMDBPersonSearchResult.self, from: data)
        
        if let person = result.results.first, let profileURL = person.profileURL {
            personCache[name] = profileURL
            return profileURL
        }
        
        return nil
    }
    
    /// Get season details with all episodes
    func getSeasonDetail(showId: Int, seasonNumber: Int) async throws -> TMDBSeasonDetail? {
        let cacheKey = "\(showId)-\(seasonNumber)"
        
        // Check cache
        if let cached = seasonCache[cacheKey] {
            return cached
        }
        
        // Check for in-flight request
        if let pending = pendingSeasonLookups[cacheKey] {
            return try await pending.value
        }
        
        // Create new lookup task
        let task = Task<TMDBSeasonDetail?, Error> {
            let urlString = "\(TMDBConfig.baseURL)/tv/\(showId)/season/\(seasonNumber)?api_key=\(TMDBConfig.apiKey)&language=ru-RU"
            
            guard let url = URL(string: urlString) else {
                return nil
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let season = try JSONDecoder().decode(TMDBSeasonDetail.self, from: data)
            seasonCache[cacheKey] = season
            
            // Cache individual episodes
            if let episodes = season.episodes {
                for episode in episodes {
                    let episodeKey = "\(showId)-\(seasonNumber)-\(episode.episodeNumber)"
                    episodeCache[episodeKey] = CachedTMDBEpisode(
                        name: episode.name,
                        overview: episode.overview,
                        stillURL: episode.stillURL,
                        airDate: episode.airDate,
                        runtime: episode.runtime
                    )
                }
            }
            
            return season
        }
        
        pendingSeasonLookups[cacheKey] = task
        defer { pendingSeasonLookups.removeValue(forKey: cacheKey) }
        
        return try await task.value
    }
    
    /// Get episode info
    func getEpisode(showId: Int, seasonNumber: Int, episodeNumber: Int) async throws -> TMDBEpisode? {
        // Try to get from season cache first
        let seasonCacheKey = "\(showId)-\(seasonNumber)"
        if let season = seasonCache[seasonCacheKey],
           let episodes = season.episodes,
           let episode = episodes.first(where: { $0.episodeNumber == episodeNumber }) {
            return episode
        }
        
        // Fetch the whole season (more efficient than individual episode calls)
        if let season = try await getSeasonDetail(showId: showId, seasonNumber: seasonNumber),
           let episodes = season.episodes {
            return episodes.first(where: { $0.episodeNumber == episodeNumber })
        }
        
        return nil
    }
    
    /// Get cached episode data
    func getCachedEpisode(showId: Int, seasonNumber: Int, episodeNumber: Int) -> CachedTMDBEpisode? {
        let key = "\(showId)-\(seasonNumber)-\(episodeNumber)"
        return episodeCache[key]
    }
    
    /// Preload all episodes for a season
    func preloadSeason(showId: Int, seasonNumber: Int) async {
        do {
            _ = try await getSeasonDetail(showId: showId, seasonNumber: seasonNumber)
        } catch {
            print("Failed to preload season \(seasonNumber): \(error)")
        }
    }
    
    /// Get image URL for a poster or still
    func imageURL(path: String?, size: String = "w300") -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(TMDBConfig.imageBaseURL)/\(size)\(path)")
    }
    
    // MARK: - Private Helpers
    
    private func formatIMDbId(_ id: String) -> String {
        // If already formatted, return as is
        if id.hasPrefix("tt") {
            return id
        }
        // Convert numeric ID to tt format
        if let numericId = Int(id) {
            return String(format: "tt%07d", numericId)
        }
        return "tt\(id)"
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        showCache.removeAll()
        titleCache.removeAll()
        showDetailCache.removeAll()
        episodeCache.removeAll()
        seasonCache.removeAll()
        personCache.removeAll()
        backdropCache.removeAll()
    }
}

// MARK: - Episode Enhancement Extension

extension Episode {
    /// Enhanced title using TMDB data if available
    func enhancedTitle(tmdbEpisode: TMDBEpisode?) -> String {
        if let tmdbName = tmdbEpisode?.name, !tmdbName.isEmpty {
            return tmdbName
        }
        return displayTitle
    }
    
    /// Enhanced thumbnail using TMDB still if available
    func enhancedThumbnailURL(tmdbEpisode: TMDBEpisode?) -> URL? {
        if let tmdbURL = tmdbEpisode?.stillURL {
            return tmdbURL
        }
        return URL.secure(string: thumbnail)
    }
}
