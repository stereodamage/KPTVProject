//
//  TopShelfService.swift
//  KinoPubTV
//

import Foundation
import TVServices
import UIKit

enum TopShelfContentType: String, CaseIterable {
    case continueWatching = "continue_watching"
    case newReleases = "new_releases"
    
    static var allCases: [TopShelfContentType] {
        [.continueWatching, .newReleases]
    }
    
    var displayName: String {
        switch self {
        case .newReleases: return "Новинки"
        case .continueWatching: return "Продолжить просмотр"
        }
    }
}

actor TopShelfService {
    static let shared = TopShelfService()
    
    private let contentService = ContentService.shared
    private let userDefaultsSuiteName = "group.com.kptv.shared"
    
    // Top Shelf image cache directory
    private var topShelfImageURL: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: userDefaultsSuiteName
        ) else { return nil }
        return containerURL.appendingPathComponent("TopShelf")
    }
    
    private init() {
        // Create Top Shelf directory if needed
        Task {
            await createTopShelfDirectory()
        }
    }
    
    private func createTopShelfDirectory() {
        if let url = topShelfImageURL {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Public API
    
    /// Update Top Shelf content with the specified type
    func updateTopShelf(contentType: TopShelfContentType) async {
        guard let token = try? await AuthService.shared.getValidToken() else {
            print("TopShelf: No valid token available")
            return
        }
        
        do {
            let items = try await fetchItems(for: contentType, token: token)
            let topShelfItems = items.prefix(10).map { convertToTopShelfItem($0) }
            
            let section = TopShelfSection(
                title: contentType.displayName,
                contentIdentifier: contentType.rawValue,
                items: topShelfItems
            )
            
            let topShelfData = TopShelfData(sections: [section])
            saveTopShelfData(topShelfData)
            
            // Note: Dynamic Top Shelf updates require a TV Services Extension target
            // See instructions at the bottom of this file
        } catch {
            print("TopShelf: Failed to update - \(error)")
        }
    }
    
    /// Get currently saved Top Shelf data
    func getTopShelfData() -> TopShelfData? {
        guard let defaults = UserDefaults(suiteName: userDefaultsSuiteName),
              let data = defaults.data(forKey: "topShelfData") else {
            return nil
        }
        
        return try? JSONDecoder().decode(TopShelfData.self, from: data)
    }
    
    // MARK: - Private Helpers
    
    private func fetchItems(for contentType: TopShelfContentType, token: String) async throws -> [Item] {
        switch contentType {
        case .newReleases:
            // Fetch both movies and series, then sort by date
            async let moviesResponse = contentService.getFreshItems(type: .movie, page: 1, accessToken: token)
            async let serialsResponse = contentService.getFreshItems(type: .serial, page: 1, accessToken: token)
            
            let (movies, serials) = try await (moviesResponse, serialsResponse)
            
            // Combine and sort by updated date (newest first)
            var allItems = movies.items + serials.items
            allItems.sort(by: { (item1: Item, item2: Item) -> Bool in
                (item1.updatedAt ?? 0) > (item2.updatedAt ?? 0)
            })
            
            return allItems
            
        case .continueWatching:
            // Get items with watching status (movies being watched)
            let moviesResponse = try await contentService.getWatchingMovies(accessToken: token)
            let serialsResponse = try await contentService.getWatchingSerials(subscribed: true, accessToken: token)
            return moviesResponse.items + serialsResponse.items
        }
    }
    
    private func convertToTopShelfItem(_ item: Item) -> TopShelfItem {
        // Use wide poster for Top Shelf
        let imageURL = item.posters?.wide ?? item.posters?.big ?? item.posters?.medium ?? ""
        
        return TopShelfItem(
            slug: "\(item.id)",
            image: imageURL,
            title: item.displayTitle
        )
    }
    
    private func saveTopShelfData(_ data: TopShelfData) {
        guard let defaults = UserDefaults(suiteName: userDefaultsSuiteName),
              let encoded = try? JSONEncoder().encode(data) else {
            return
        }
        
        defaults.set(encoded, forKey: "topShelfData")
        defaults.synchronize()
    }
}

// MARK: - Top Shelf Extension Instructions
//
// To enable dynamic Top Shelf content:
// 1. In Xcode: File > New > Target
// 2. Choose "tvOS" > "TV Services Extension" 
// 3. Name it "TopShelfExtension"
// 4. In the extension's ContentProvider.swift, use:
//
// import TVServices
//
// class ContentProvider: TVTopShelfContentProvider {
//     override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
//         Task {
//             guard let data = await TopShelfService.shared.getTopShelfData(),
//                   let section = data.sections.first else {
//                 completionHandler(nil)
//                 return
//             }
//             
//             var items: [TVTopShelfSectionedItem] = []
//             
//             for item in section.items {
//                 guard let imageURL = URL(string: item.image) else { continue }
//                 
//                 let topShelfItem = TVTopShelfSectionedItem(identifier: item.slug)
//                 topShelfItem.title = item.title
//                 topShelfItem.imageShape = .poster
//                 topShelfItem.setImageURL(imageURL, for: .screenScale1x)
//                 
//                 let url = URL(string: "kptv://item/\(item.slug)")!
//                 topShelfItem.displayAction = TVTopShelfAction(url: url)
//                 
//                 items.append(topShelfItem)
//             }
//             
//             let content = TVTopShelfSectionedContent(sections: [
//                 TVTopShelfItemCollection(items: items)
//             ])
//             content.sections.first?.title = section.title
//             
//             completionHandler(content)
//         }
//     }
// }
