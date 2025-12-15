//
//  SerialsViewModel.swift
//  KinoPubTV
//

import Foundation

@MainActor
@Observable
final class SerialsViewModel {
    var featuredItems: [Item] = []
    var popularItems: [Item] = []
    var hotItems: [Item] = []
    var freshItems: [Item] = []
    var unwatchedItems: [Item] = []
    var fourKItems: [Item] = []
    var mostSubscribed: [Item] = []
    
    var isLoading = false
    var error: String?
    
    private let contentService = ContentService.shared
    
    func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            async let popularResponse = contentService.getPopularItems(type: .serial, accessToken: token)
            async let hotResponse = contentService.getHotItems(type: .serial, accessToken: token)
            async let freshResponse = contentService.getFreshItems(type: .serial, accessToken: token)
            async let unwatchedResponse = contentService.getWatchingSerials(subscribed: true, accessToken: token)
            async let fourKResponse = contentService.getItems(
                type: .serial,
                sort: .updated,
                quality: "4k",
                accessToken: token
            )
            async let subscribedResponse = contentService.getItems(
                type: .serial,
                sort: .watchers,
                accessToken: token
            )
            
            let (popular, hot, fresh, unwatched, fourK, subscribed) = try await (
                popularResponse,
                hotResponse,
                freshResponse,
                unwatchedResponse,
                fourKResponse,
                subscribedResponse
            )
            
            popularItems = popular.items
            hotItems = hot.items
            freshItems = fresh.items
            unwatchedItems = unwatched.items
            fourKItems = fourK.items
            mostSubscribed = subscribed.items
            
            // Featured items: top 5 hot serials with good ratings and wide posters
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
