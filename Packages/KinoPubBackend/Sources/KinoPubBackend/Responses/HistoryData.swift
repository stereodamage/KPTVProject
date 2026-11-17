//
//  HistoryData.swift
//
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation

/// The specific media (episode/video) a history entry refers to. Schema is undocumented, so
/// fields are decoded defensively under several likely names.
public struct HistoryMedia: Codable, Hashable {
  public let title: String?
  public let number: Int?
  public let seasonNumber: Int?

  private enum CodingKeys: String, CodingKey {
    case title, number, season, snumber
  }

  public init(title: String? = nil, number: Int? = nil, seasonNumber: Int? = nil) {
    self.title = title
    self.number = number
    self.seasonNumber = seasonNumber
  }

  public init(from decoder: Decoder) throws {
    let container = try? decoder.container(keyedBy: CodingKeys.self)
    title = (try? container?.decodeIfPresent(String.self, forKey: .title)) ?? nil
    number = (try? container?.decodeIfPresent(Int.self, forKey: .number)) ?? nil
    seasonNumber = ((try? container?.decodeIfPresent(Int.self, forKey: .season)) ?? nil)
      ?? ((try? container?.decodeIfPresent(Int.self, forKey: .snumber)) ?? nil)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(title, forKey: .title)
    try container.encodeIfPresent(number, forKey: .number)
    try container.encodeIfPresent(seasonNumber, forKey: .season)
  }
}

public struct HistoryItem: Codable, Hashable, Identifiable {

  public let time: TimeInterval?
  public let counter: Int?
  public let firstSeen: TimeInterval?
  public let lastSeen: TimeInterval?
  public let item: MediaItem
  public let media: HistoryMedia?

  public var id: Int { item.id }

  /// Stable, collision-free id for `ForEach` (a series can appear in several entries with the
  /// same `item.id`, which broke grid rendering — gaps/recycling — when keyed by `id` alone).
  public var uniqueID: String {
    "\(item.id)-\(Int(lastSeen ?? firstSeen ?? time ?? 0))-\(media?.number ?? 0)"
  }

  /// One per watched video: the same episode watched again keeps it, unlike `uniqueID`.
  public var mediaKey: String {
    "\(item.id)-\(media?.seasonNumber ?? 0)-\(media?.number ?? 0)"
  }

  private static let seriesTypes: Set<String> = ["serial", "docuserial", "tvshow"]

  /// "S{n} · E{n}" (or episode number / title) for series entries; nil for movies.
  public var episodeSubtitle: String? {
    guard HistoryItem.seriesTypes.contains(item.type), let media else { return nil }
    if let season = media.seasonNumber, let episode = media.number {
      return "S\(season) · E\(episode)"
    }
    if let episode = media.number {
      if let title = media.title, !title.isEmpty { return "E\(episode) · \(title)" }
      return "E\(episode)"
    }
    if let title = media.title, !title.isEmpty { return title }
    return nil
  }

  private enum CodingKeys: String, CodingKey {
    case time = "time"
    case counter = "counter"
    case firstSeen = "first_seen"
    case lastSeen = "last_seen"
    case item = "item"
    case media = "media"
  }

  public init(time: TimeInterval?,
              counter: Int?,
              firstSeen: TimeInterval?,
              lastSeen: TimeInterval?,
              item: MediaItem,
              media: HistoryMedia? = nil) {
    self.time = time
    self.counter = counter
    self.firstSeen = firstSeen
    self.lastSeen = lastSeen
    self.item = item
    self.media = media
  }
}

public struct HistoryData: Codable {

  public let history: [HistoryItem]
  public let pagination: Pagination

  public init(history: [HistoryItem], pagination: Pagination) {
    self.history = history
    self.pagination = pagination
  }

  public static func mock(data: [HistoryItem] = []) -> HistoryData {
    return HistoryData(history: data, pagination: Pagination(total: 0, current: 0, perpage: 0))
  }

}

// MARK: - Collapsing repeat entries

/// One title's entries within a stretch of history (e.g. a day): the most recent entry plus the rest.
public struct HistoryGroup: Identifiable, Hashable {
  /// All entries for this title, most recent first (input order is preserved).
  public let entries: [HistoryItem]

  public var latest: HistoryItem { entries[0] }
  public var count: Int { entries.count }
  public var id: String { latest.uniqueID }
}

public extension Array where Element == HistoryItem {
  /// A fresh first page on top of the entries already loaded: each video keeps only its newest entry.
  func mergingFreshPage(_ fresh: [HistoryItem]) -> [HistoryItem] {
    var seen = Set<String>()
    return (fresh + self).filter { seen.insert($0.mediaKey).inserted }
  }

  /// Folds repeat entries of the same title (a series' episodes) into one group each, placed where
  /// the title's most recent entry was. Assumes the array is newest-first, as the API returns it.
  func groupedByTitle() -> [HistoryGroup] {
    var order: [Int] = []
    var buckets: [Int: [HistoryItem]] = [:]
    for entry in self {
      if buckets[entry.item.id] == nil { order.append(entry.item.id) }
      buckets[entry.item.id, default: []].append(entry)
    }
    return order.map { HistoryGroup(entries: buckets[$0]!) }
  }
}
