//
//  ContentService.swift
//  KinoPubTV
//

import Foundation

// MARK: - Content Service

actor ContentService {
    static let shared = ContentService()
    
    private let network = NetworkService.shared
    
    private init() {}
    
    // MARK: - Items
    
    func getItems(
        type: ContentType? = nil,
        page: Int = 1,
        perPage: Int = 20,
        sort: SortOption? = nil,
        genre: Int? = nil,
        country: Int? = nil,
        year: Int? = nil,
        quality: String? = nil,
        accessToken: String
    ) async throws -> ItemsResponse {
        var filters: [String: String] = [:]
        
        if let sort = sort {
            filters["sort"] = sort.rawValue
        }
        if let genre = genre {
            filters["genre"] = "\(genre)"
        }
        if let country = country {
            filters["country"] = "\(country)"
        }
        if let year = year {
            filters["year"] = "\(year)"
        }
        if let quality = quality {
            filters["quality"] = quality
        }
        
        let endpoint = APIEndpoint.getItems(
            type: type,
            page: page,
            perPage: perPage,
            sort: sort?.rawValue,
            filters: filters.isEmpty ? nil : filters,
            accessToken: accessToken
        )
        return try await network.request(endpoint)
    }
    
    func getItem(id: Int, accessToken: String) async throws -> ItemResponse {
        let endpoint = APIEndpoint.getItem(id: id, accessToken: accessToken, nolinks: false)
        return try await network.request(endpoint)
    }
    
    func getFreshItems(type: ContentType? = nil, page: Int = 1, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getFreshItems(type: type, page: page, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getHotItems(type: ContentType? = nil, page: Int = 1, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getHotItems(type: type, page: page, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getPopularItems(type: ContentType? = nil, page: Int = 1, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getPopularItems(type: type, page: page, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func search(query: String, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.search(query: query, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getSimilar(itemID: Int, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getSimilar(itemID: itemID, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    // MARK: - Watching
    
    func getWatchingMovies(accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getWatchingMovies(accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getWatchingSerials(subscribed: Bool = true, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getWatchingSerials(subscribed: subscribed, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func markTime(itemID: Int, videoID: Int, time: Int, season: Int? = nil, accessToken: String) async throws {
        let endpoint = APIEndpoint.markTime(
            itemID: itemID,
            videoID: videoID,
            time: time,
            season: season,
            accessToken: accessToken
        )
        try await network.requestVoid(endpoint)
    }
    
    func toggleWatchlist(itemID: Int, accessToken: String) async throws {
        let endpoint = APIEndpoint.toggleWatchlist(itemID: itemID, accessToken: accessToken)
        try await network.requestVoid(endpoint)
    }
    
    func toggleWatched(itemID: Int, season: Int? = nil, video: Int? = nil, accessToken: String) async throws {
        let endpoint = APIEndpoint.toggleWatched(
            itemID: itemID,
            season: season,
            video: video,
            accessToken: accessToken
        )
        try await network.requestVoid(endpoint)
    }
    
    // MARK: - Bookmarks
    
    func getBookmarkFolders(accessToken: String) async throws -> BookmarkFoldersResponse {
        let endpoint = APIEndpoint.getBookmarkFolders(accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getBookmarkItems(folderID: Int, page: Int = 1, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getBookmarkItems(folderID: folderID, page: page, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func createBookmarkFolder(title: String, accessToken: String) async throws -> FolderCreateResponse {
        let endpoint = APIEndpoint.createBookmarkFolder(title: title, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func removeBookmarkFolder(folderID: Int, accessToken: String) async throws {
        let endpoint = APIEndpoint.removeBookmarkFolder(folderID: folderID, accessToken: accessToken)
        try await network.requestVoid(endpoint)
    }
    
    func toggleBookmarkItem(itemID: Int, folderID: Int, accessToken: String) async throws {
        let endpoint = APIEndpoint.toggleBookmarkItem(itemID: itemID, folderID: folderID, accessToken: accessToken)
        try await network.requestVoid(endpoint)
    }
    
    func getItemFolders(itemID: Int, accessToken: String) async throws -> ItemFoldersResponse {
        let endpoint = APIEndpoint.getItemFolders(itemID: itemID, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    // MARK: - History
    
    func getHistory(page: Int = 1, accessToken: String) async throws -> HistoryResponse {
        let endpoint = APIEndpoint.getHistory(page: page, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func clearHistoryForItem(itemID: Int, accessToken: String) async throws {
        let endpoint = APIEndpoint.clearHistoryForItem(itemID: itemID, accessToken: accessToken)
        try await network.requestVoid(endpoint)
    }
    
    // MARK: - Collections
    
    func getCollections(page: Int = 1, accessToken: String) async throws -> CollectionsResponse {
        let endpoint = APIEndpoint.getCollections(page: page, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getCollectionItems(collectionID: Int, page: Int = 1, accessToken: String) async throws -> ItemsResponse {
        let endpoint = APIEndpoint.getCollectionItems(collectionID: collectionID, page: page, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    // MARK: - Comments
    
    func getComments(itemID: Int, accessToken: String) async throws -> CommentsResponse {
        let endpoint = APIEndpoint.getComments(itemID: itemID, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    // MARK: - Vote
    
    func vote(itemID: Int, like: Bool, accessToken: String) async throws {
        let endpoint = APIEndpoint.vote(itemID: itemID, like: like, accessToken: accessToken)
        try await network.requestVoid(endpoint)
    }
    
    // MARK: - References
    
    func getGenres(type: ContentType? = nil, accessToken: String) async throws -> GenresResponse {
        let endpoint = APIEndpoint.getGenres(type: type, accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getCountries(accessToken: String) async throws -> CountriesResponse {
        let endpoint = APIEndpoint.getCountries(accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    // MARK: - TV
    
    func getTVChannels(accessToken: String) async throws -> TVChannelsResponse {
        let endpoint = APIEndpoint.getTVChannels(accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    // MARK: - User
    
    func getUserInfo(accessToken: String) async throws -> UserResponse {
        let endpoint = APIEndpoint.getUserInfo(accessToken: accessToken)
        return try await network.request(endpoint)
    }
    
    func getDeviceInfo(accessToken: String) async throws -> DeviceResponse {
        let endpoint = APIEndpoint.getDeviceInfo(accessToken: accessToken)
        return try await network.request(endpoint)
    }
}
