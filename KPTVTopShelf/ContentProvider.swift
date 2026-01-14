//
//  ContentProvider.swift
//  TopShelfExtension
//
//  Provides dynamic content for the Apple TV Top Shelf.
//

import TVServices
import Foundation

class ContentProvider: TVTopShelfContentProvider {
    
    private let userDefaultsSuiteName = "group.com.kptv.shared"
    
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        guard let topShelfData = getTopShelfData(),
              !topShelfData.sections.isEmpty else {
            return nil
        }
        
        var allSections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        
        for section in topShelfData.sections {
            var items: [TVTopShelfSectionedItem] = []
            
            for item in section.items {
                guard let imageURL = URL(string: item.image) else { continue }
                
                let topShelfItem = TVTopShelfSectionedItem(identifier: item.slug)
                topShelfItem.title = item.title
                topShelfItem.imageShape = .poster
                topShelfItem.setImageURL(imageURL, for: .screenScale1x)
                topShelfItem.setImageURL(imageURL, for: .screenScale2x)
                
                // Deep link to open the item in the app
                if let deepLinkURL = URL(string: "kptv://item/\(item.slug)") {
                    topShelfItem.displayAction = TVTopShelfAction(url: deepLinkURL)
                    topShelfItem.playAction = TVTopShelfAction(url: deepLinkURL)
                }
                
                items.append(topShelfItem)
            }
            
            if !items.isEmpty {
                let itemCollection = TVTopShelfItemCollection(items: items)
                itemCollection.title = section.title
                allSections.append(itemCollection)
            }
        }
        
        guard !allSections.isEmpty else { return nil }
        
        return TVTopShelfSectionedContent(sections: allSections)
    }
    
    // MARK: - Shared Data Access
    
    private func getTopShelfData() -> TopShelfData? {
        guard let defaults = UserDefaults(suiteName: userDefaultsSuiteName),
              let data = defaults.data(forKey: "topShelfData") else {
            return nil
        }
        
        return try? JSONDecoder().decode(TopShelfData.self, from: data)
    }
}

// MARK: - Shared Models (Must match app models)

struct TopShelfData: Codable {
    var sections: [TopShelfSection]
}

struct TopShelfSection: Codable {
    let title: String
    let contentIdentifier: String
    var items: [TopShelfItem]
}

struct TopShelfItem: Codable {
    let slug: String
    let image: String
    let title: String
}
