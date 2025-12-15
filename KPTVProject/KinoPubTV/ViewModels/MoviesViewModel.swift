//
//  MoviesViewModel.swift
//  KinoPubTV
//

import Foundation

@MainActor
@Observable
final class MoviesViewModel {
    var featuredItems: [Item] = []
    var hotItems: [Item] = []
    var popularItems: [Item] = []
    var freshItems: [Item] = []
    var unwatchedItems: [Item] = []
    var collections: [Collection] = []
    var fourKItems: [Item] = []
    
    var isLoading = false
    var error: String?
    
    private let contentService = ContentService.shared
    
    func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            async let hotResponse = contentService.getHotItems(type: .movie, accessToken: token)
            async let popularResponse = contentService.getPopularItems(type: .movie, accessToken: token)
            async let freshResponse = contentService.getFreshItems(type: .movie, accessToken: token)
            async let unwatchedResponse = contentService.getWatchingMovies(accessToken: token)
            async let collectionsResponse = contentService.getCollections(accessToken: token)
            async let fourKResponse = contentService.getItems(
                type: .movie,
                sort: .updated,
                quality: "4k",
                accessToken: token
            )
            
            let (hot, popular, fresh, unwatched, cols, fourK) = try await (
                hotResponse,
                popularResponse,
                freshResponse,
                unwatchedResponse,
                collectionsResponse,
                fourKResponse
            )
            
            hotItems = hot.items
            popularItems = popular.items
            freshItems = fresh.items
            unwatchedItems = unwatched.items
            collections = cols.items
            fourKItems = fourK.items
            
            // Featured items: top 5 hot movies with good ratings and wide posters
            featuredItems = hotItems
                .filter { ($0.kinopoiskRating ?? 0) > 5 && $0.posters?.wide != nil }
                .prefix(5)
                .map { $0 }
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
