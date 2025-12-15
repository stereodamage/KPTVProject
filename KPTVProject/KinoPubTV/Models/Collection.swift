//
//  Collection.swift
//  KinoPubTV
//

import Foundation

// MARK: - Collections Response

struct CollectionsResponse: Codable {
    let items: [Collection]
    let pagination: Pagination?
}

struct Collection: Codable, Identifiable {
    let id: Int
    let title: String
    let posters: Posters?
    let watchers: Int?
    let views: Int?
    let createdAt: Int?
    let updatedAt: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, posters, watchers, views
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Collection Items Response

struct CollectionItemsResponse: Codable {
    let items: [Item]
    let pagination: Pagination?
}
