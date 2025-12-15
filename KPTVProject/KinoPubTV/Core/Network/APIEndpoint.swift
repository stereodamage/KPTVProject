//
//  APIEndpoint.swift
//  KinoPubTV
//
//  API Documentation: https://kinoapi.com/

import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

// MARK: - Content Type

enum ContentType: String, CaseIterable {
    case movie
    case serial
    case docuserial
    case tvshow
    case concert
    case documovie
    case threeD = "3d"
    
    var displayName: String {
        switch self {
        case .movie: return "Фильмы"
        case .serial: return "Сериалы"
        case .docuserial: return "Докусериалы"
        case .tvshow: return "ТВ-шоу"
        case .concert: return "Концерты"
        case .documovie: return "Документальные"
        case .threeD: return "3D"
        }
    }
}

// MARK: - Sort Options

enum SortOption: String, CaseIterable {
    case created = "-created"
    case updated = "-updated"
    case views = "-views"
    case title = "title"
    case year = "-year"
    case rating = "-rating"
    case kinopoiskRating = "-kinopoisk_rating"
    case imdbRating = "-imdb_rating"
    case watchers = "-watchers"
    
    var displayName: String {
        switch self {
        case .created: return "Последние добавленные"
        case .updated: return "Последние обновленные"
        case .views: return "По просмотрам"
        case .title: return "По названию"
        case .year: return "По году"
        case .rating: return "По рейтингу Кинопаба"
        case .kinopoiskRating: return "По рейтингу Кинопоиска"
        case .imdbRating: return "По рейтингу IMDB"
        case .watchers: return "По подписчикам"
        }
    }
}

// MARK: - API Endpoint

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]?
    let body: Data?
    let useAuthURL: Bool

    var url: URL? {
        let baseURL = useAuthURL ? APIConfig.authBaseURL : APIConfig.baseURL
        var components = URLComponents(string: baseURL + path)
        components?.queryItems = queryItems
        return components?.url
    }

    var cacheKey: String {
        var key = "\(method.rawValue):\(path)"
        if let query = queryItems {
            key += "?" + query.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        }
        return key
    }
}

struct APIConfig {
    // ✅ FIXED: Correct base URLs from official documentation
    static var baseURL = "https://api.service-kp.com/v1"
    static var authBaseURL = "https://api.service-kp.com"

    // Credentials
    static var clientID = APIConfiguration.kinoPubClientID
    static var clientSecret = APIConfiguration.kinoPubClientSecret
}

// MARK: - Endpoint Factory

extension APIEndpoint {
    // MARK: - Authentication

    static func getDeviceCode() -> APIEndpoint {
        let body = [
            "grant_type": "device_code",
            "client_id": APIConfig.clientID,
            "client_secret": APIConfig.clientSecret
        ]

        return APIEndpoint(
            path: "/oauth2/device",
            method: .POST,
            headers: ["Content-Type": "application/json"],
            queryItems: nil,
            body: try? JSONSerialization.data(withJSONObject: body),
            useAuthURL: true
        )
    }

    static func checkDeviceToken(code: String) -> APIEndpoint {
        let body = [
            "grant_type": "device_token",
            "code": code,
            "client_id": APIConfig.clientID,
            "client_secret": APIConfig.clientSecret
        ]

        return APIEndpoint(
            path: "/oauth2/device",
            method: .POST,
            headers: ["Content-Type": "application/json"],
            queryItems: nil,
            body: try? JSONSerialization.data(withJSONObject: body),
            useAuthURL: true
        )
    }

    // ✅ FIXED: Changed from /oauth2/device to /oauth2/token
    static func refreshToken(_ token: String) -> APIEndpoint {
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": token,
            "client_id": APIConfig.clientID,
            "client_secret": APIConfig.clientSecret
        ]

        return APIEndpoint(
            path: "/oauth2/token",  // ✅ FIXED: Was /oauth2/device
            method: .POST,
            headers: ["Content-Type": "application/json"],
            queryItems: nil,
            body: try? JSONSerialization.data(withJSONObject: body),
            useAuthURL: true
        )
    }

    // MARK: - Content

    static func getItems(
        type: ContentType? = nil,
        page: Int = 1,
        perPage: Int = 20,
        sort: String? = nil,
        filters: [String: String]? = nil,
        accessToken: String
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perpage", value: "\(perPage)")
        ]

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }

        if let sort = sort {
            queryItems.append(URLQueryItem(name: "sort", value: sort))
        }

        if let filters = filters {
            for (key, value) in filters {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
        }

        return APIEndpoint(
            path: "/items",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }

    // ✅ ADDED: nolinks parameter for better performance
    static func getItem(id: Int, accessToken: String, nolinks: Bool = true) -> APIEndpoint {
        var queryItems: [URLQueryItem]? = nil
        if nolinks {
            queryItems = [URLQueryItem(name: "nolinks", value: "1")]
        }

        return APIEndpoint(
            path: "/items/\(id)",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }

    static func search(query: String, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/items/search",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "q", value: query)],
            body: nil,
            useAuthURL: false
        )
    }

    // ✅ NEW: Fresh videos endpoint
    static func getFreshItems(type: ContentType? = nil, page: Int = 1, perPage: Int = 25, accessToken: String) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perpage", value: "\(perPage)")
        ]

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }

        return APIEndpoint(
            path: "/items/fresh",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }

    // ✅ NEW: Hot videos endpoint
    static func getHotItems(type: ContentType? = nil, page: Int = 1, perPage: Int = 25, accessToken: String) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perpage", value: "\(perPage)")
        ]

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }

        return APIEndpoint(
            path: "/items/hot",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }

    // ✅ NEW: Popular videos endpoint
    static func getPopularItems(type: ContentType? = nil, page: Int = 1, perPage: Int = 25, accessToken: String) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perpage", value: "\(perPage)")
        ]

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }

        return APIEndpoint(
            path: "/items/popular",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }

    // MARK: - Watching

    // ✅ FIXED: Changed from POST to GET with query parameters
    static func markTime(
        itemID: Int,
        videoID: Int,
        time: Int,
        season: Int? = nil,
        accessToken: String
    ) -> APIEndpoint {
        var queryItems = [
            URLQueryItem(name: "id", value: "\(itemID)"),
            URLQueryItem(name: "video", value: "\(videoID)"),
            URLQueryItem(name: "time", value: "\(time)")
        ]

        if let season = season {
            queryItems.append(URLQueryItem(name: "season", value: "\(season)"))
        }

        return APIEndpoint(
            path: "/watching/marktime",
            method: .GET,  // ✅ FIXED: Was POST
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,  // ✅ FIXED: No body needed
            useAuthURL: false
        )
    }

    static func getWatching(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/watching",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }

    // ✅ NEW: Get unwatched movies
    static func getWatchingMovies(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/watching/movies",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }

    // ✅ NEW: Get serials with new episodes
    static func getWatchingSerials(subscribed: Bool? = nil, accessToken: String) -> APIEndpoint {
        var queryItems: [URLQueryItem]? = nil
        if let subscribed = subscribed {
            queryItems = [URLQueryItem(name: "subscribed", value: subscribed ? "1" : "0")]
        }

        return APIEndpoint(
            path: "/watching/serials",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }

    // MARK: - Bookmarks

    // ✅ FIXED: Changed endpoint path and method
    static func toggleWatchlist(itemID: Int, accessToken: String) -> APIEndpoint {
        return APIEndpoint(
            path: "/watching/togglewatchlist",  // ✅ FIXED: Was "toggle"
            method: .GET,  // ✅ FIXED: Was POST
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "id", value: "\(itemID)")],
            body: nil,  // ✅ FIXED: No body needed
            useAuthURL: false
        )
    }

    // ✅ NEW: Toggle watched status
    static func toggleWatched(
        itemID: Int,
        season: Int? = nil,
        video: Int? = nil,
        accessToken: String
    ) -> APIEndpoint {
        var queryItems = [URLQueryItem(name: "id", value: "\(itemID)")]

        if let season = season {
            queryItems.append(URLQueryItem(name: "season", value: "\(season)"))
        }

        if let video = video {
            queryItems.append(URLQueryItem(name: "video", value: "\(video)"))
        }

        return APIEndpoint(
            path: "/watching/toggle",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - User
    
    static func getUserInfo(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/user",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - Device
    
    static func getDeviceInfo(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/device/info",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    static func deviceNotify(title: String, software: String, hardware: String, accessToken: String) -> APIEndpoint {
        let body: [String: Any] = [
            "title": title,
            "software": software,
            "hardware": hardware
        ]
        
        return APIEndpoint(
            path: "/device/notify",
            method: .POST,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json"
            ],
            queryItems: nil,
            body: try? JSONSerialization.data(withJSONObject: body),
            useAuthURL: false
        )
    }
    
    static func unlinkDevice(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/device/unlink",
            method: .POST,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - Bookmarks
    
    static func getBookmarkFolders(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/bookmarks",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getBookmarkItems(folderID: Int, page: Int = 1, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/bookmarks/\(folderID)",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "page", value: "\(page)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    static func createBookmarkFolder(title: String, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/bookmarks/create",
            method: .POST,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "title", value: title)],
            body: nil,
            useAuthURL: false
        )
    }
    
    static func removeBookmarkFolder(folderID: Int, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/bookmarks/remove-folder",
            method: .POST,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "folder", value: "\(folderID)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    static func toggleBookmarkItem(itemID: Int, folderID: Int, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/bookmarks/toggle-item",
            method: .POST,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [
                URLQueryItem(name: "item", value: "\(itemID)"),
                URLQueryItem(name: "folder", value: "\(folderID)")
            ],
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getItemFolders(itemID: Int, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/bookmarks/get-item-folders",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "item", value: "\(itemID)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - History
    
    static func getHistory(page: Int = 1, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/history",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "page", value: "\(page)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    static func clearHistoryForItem(itemID: Int, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/history/clear-for-item",
            method: .POST,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "id", value: "\(itemID)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - Collections
    
    static func getCollections(page: Int = 1, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/collections",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "page", value: "\(page)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getCollectionItems(collectionID: Int, page: Int = 1, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/collections/view",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [
                URLQueryItem(name: "id", value: "\(collectionID)"),
                URLQueryItem(name: "page", value: "\(page)")
            ],
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - Similar
    
    static func getSimilar(itemID: Int, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/items/similar",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "id", value: "\(itemID)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - Comments
    
    static func getComments(itemID: Int, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/items/comments",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "id", value: "\(itemID)")],
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - Vote
    
    static func vote(itemID: Int, like: Bool, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/items/vote",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [
                URLQueryItem(name: "id", value: "\(itemID)"),
                URLQueryItem(name: "like", value: like ? "1" : "0")
            ],
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - References
    
    static func getTypes(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/types",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getGenres(type: ContentType? = nil, accessToken: String) -> APIEndpoint {
        var queryItems: [URLQueryItem]? = nil
        if let type = type {
            queryItems = [URLQueryItem(name: "type", value: type.rawValue)]
        }
        
        return APIEndpoint(
            path: "/genres",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: queryItems,
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getCountries(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/countries",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getServerLocations(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/references/server-location",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getStreamingTypes(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/references/streaming-type",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    static func getVideoQualities(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/references/video-quality",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - TV
    
    static func getTVChannels(accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/tv",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: nil,
            body: nil,
            useAuthURL: false
        )
    }
    
    // MARK: - Media Links
    
    static func getMediaLinks(mediaID: Int, accessToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/items/media-links",
            method: .GET,
            headers: ["Authorization": "Bearer \(accessToken)"],
            queryItems: [URLQueryItem(name: "mid", value: "\(mediaID)")],
            body: nil,
            useAuthURL: false
        )
    }
}
