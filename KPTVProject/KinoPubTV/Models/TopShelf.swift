//
//  TopShelf.swift
//  KinoPubTV
//

import Foundation

// MARK: - TopShelf Data

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
