//
//  Bookmark.swift
//  KinoPubTV
//

import Foundation

// MARK: - Bookmark Folder Response

struct BookmarkFoldersResponse: Codable {
    let items: [BookmarkFolder]
}

struct BookmarkFolder: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let count: Int?
    let views: Int?
    let createdAt: Int?
    let updatedAt: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, count, views
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BookmarkFolder, rhs: BookmarkFolder) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Bookmark Items Response

struct BookmarkItemsResponse: Codable {
    let items: [Item]
    let pagination: Pagination?
}

// MARK: - Folder Create Response

struct FolderCreateResponse: Codable {
    let status: Int
    let folder: BookmarkFolder?
}

// MARK: - Item Folders Response

struct ItemFoldersResponse: Codable {
    let folders: [BookmarkFolder]
}

// MARK: - Toggle Response

struct ToggleResponse: Codable {
    let status: Int?
    let watching: WatchingToggleStatus?
}

struct WatchingToggleStatus: Codable {
    let status: Int?
}
