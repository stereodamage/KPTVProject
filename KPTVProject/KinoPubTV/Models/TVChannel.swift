//
//  TVChannel.swift
//  KinoPubTV
//

import Foundation

// MARK: - TV Channels Response

struct TVChannelsResponse: Codable {
    let channels: [TVChannel]
}

struct TVChannel: Codable, Identifiable {
    let id: Int
    let title: String
    let stream: String?
    let logos: TVLogos?
}

struct TVLogos: Codable {
    let s: String?
    let m: String?
}

// MARK: - References

struct ReferencesResponse: Codable {
    let items: [ReferenceItem]
}

struct ReferenceItem: Codable, Identifiable {
    let id: Int
    let title: String?
    let label: String?
}

// MARK: - Types

struct TypesResponse: Codable {
    let items: [ContentTypeItem]
}

struct ContentTypeItem: Codable, Identifiable {
    let id: String
    let title: String
}

// MARK: - Genres Response

struct GenresResponse: Codable {
    let items: [Genre]
}

// MARK: - Countries Response

struct CountriesResponse: Codable {
    let items: [Country]
}

// MARK: - Comments

struct CommentsResponse: Codable {
    let comments: [Comment]
}

struct Comment: Codable, Identifiable {
    let id: Int
    let user: CommentUser
    let message: String
    let rating: Int?
    let created: Int
    let deleted: Bool?
    let depth: Int?
}

struct CommentUser: Codable {
    let id: Int?
    let name: String
    let avatar: String?
}
