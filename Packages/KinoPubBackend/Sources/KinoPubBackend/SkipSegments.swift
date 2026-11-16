//
//  SkipSegments.swift
//  KinoPubBackend
//

import Foundation

public struct SkipSegment: Hashable, Sendable {
  public enum Kind: String, Sendable { case recap, intro, credits }

  public let kind: Kind
  public let start: Double
  /// nil = until the end of the stream.
  public let end: Double?

  public init(kind: Kind, start: Double, end: Double?) {
    self.kind = kind
    self.start = start
    self.end = end
  }
}

enum SkipDB {
  private struct Reply: Decodable {
    struct Part: Decodable {
      let start_ms: Double?
      let end_ms: Double?
      let match: String?
    }
    let segments: [String: Part?]?
  }

  /// No `duration`: with it SkipDB shifts every time to match, assuming the difference is at the start.
  /// kino.pub files differ at the end, so the shifted times were ~12 s early (The Office S3E1).
  static func url(imdb: String, season: Int?, episode: Int?) -> URL {
    var components = URLComponents(string: "https://api.skipdb.tv/api/segments")!
    var items = [URLQueryItem(name: "imdb_id", value: imdb)]
    if let season, let episode {
      items += [URLQueryItem(name: "season", value: "\(season)"), URLQueryItem(name: "episode", value: "\(episode)")]
    }
    components.queryItems = items
    return components.url!
  }

  static func segments(from data: Data) -> [SkipSegment] {
    guard let parts = (try? JSONDecoder().decode(Reply.self, from: data))?.segments else { return [] }
    let present = parts.compactMapValues { $0 }
    // A different cut (runtime too far from ours): none of its times can be trusted.
    if present.values.contains(where: { $0.match == "out-of-range" }) { return [] }
    let kinds: [(String, SkipSegment.Kind)] = [("recap", .recap), ("intro", .intro), ("outro", .credits)]
    return kinds.compactMap { key, kind in
      guard let part = present[key], let end = part.end_ms else { return nil }
      return SkipSegment(kind: kind, start: (part.start_ms ?? 0) / 1000, end: end / 1000)
    }
  }
}

enum TheIntroDB {
  private struct Reply: Decodable {
    struct Part: Decodable {
      let start_ms: Double?
      let end_ms: Double?
    }
    let recap: [Part]?
    let intro: [Part]?
    let credits: [Part]?
  }

  static func url(imdb: String, season: Int?, episode: Int?) -> URL {
    var components = URLComponents(string: "https://api.theintrodb.org/v4/media")!
    var items = [URLQueryItem(name: "imdb_id", value: imdb)]
    if let season, let episode {
      items += [URLQueryItem(name: "season", value: "\(season)"), URLQueryItem(name: "episode", value: "\(episode)")]
    }
    components.queryItems = items
    return components.url!
  }

  static func segments(from data: Data) -> [SkipSegment] {
    guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
    let kinds: [([Reply.Part]?, SkipSegment.Kind)] = [(reply.recap, .recap), (reply.intro, .intro), (reply.credits, .credits)]
    return kinds.compactMap { parts, kind in
      guard let part = parts?.first else { return nil }
      return SkipSegment(kind: kind, start: (part.start_ms ?? 0) / 1000, end: part.end_ms.map { $0 / 1000 })
    }
  }
}

public enum SkipSegments {
  /// SkipDB wins per kind; TheIntroDB fills the gaps. Segments under 1 s are dropped.
  public static func merge(primary: [SkipSegment], fallback: [SkipSegment]) -> [SkipSegment] {
    let kinds = Set(primary.map(\.kind))
    return (primary + fallback.filter { !kinds.contains($0.kind) })
      .filter { segment in segment.end.map { $0 - segment.start >= 1 } ?? true }
      .sorted { $0.start < $1.start }
  }

  public static func imdbID(_ number: Int) -> String {
    String(format: "tt%07d", number)
  }
}

/// Keyless lookups against SkipDB and TheIntroDB. Never throws: any failure means "no segments".
public actor SkipSegmentsService {
  private struct Key: Hashable {
    let imdb: Int
    let season: Int?
    let episode: Int?
    let duration: Int
  }

  private let session: URLSession
  private var cache: [Key: (date: Date, segments: [SkipSegment])] = [:]
  private static let lifetime: TimeInterval = 24 * 3600

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func segments(imdb: Int, season: Int?, episode: Int?, duration: Int) async -> [SkipSegment] {
    let key = Key(imdb: imdb, season: season, episode: episode, duration: duration)
    if let hit = cache[key], Date().timeIntervalSince(hit.date) < Self.lifetime { return hit.segments }

    let id = SkipSegments.imdbID(imdb)
    async let skipDB = fetch(SkipDB.url(imdb: id, season: season, episode: episode))
    async let introDB = fetch(TheIntroDB.url(imdb: id, season: season, episode: episode))
    let (primaryData, fallbackData) = await (skipDB, introDB)
    let result = SkipSegments.merge(primary: primaryData.map(SkipDB.segments(from:)) ?? [],
                                    fallback: fallbackData.map(TheIntroDB.segments(from:)) ?? [])
    cache[key] = (Date(), result)
    return result
  }

  private func fetch(_ url: URL) async -> Data? {
    var request = URLRequest(url: url, timeoutInterval: 8)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    guard let (data, response) = try? await session.data(for: request),
          (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return data
  }
}

/// What to offer at a playback time.
public struct SkipSchedule {
  public let segments: [SkipSegment]
  public let duration: Double

  public init(segments: [SkipSegment], isFilm: Bool, duration: Double) {
    self.segments = isFilm ? segments.filter { $0.kind != .credits } : segments
    self.duration = duration
  }

  public func active(at time: Double) -> SkipSegment? {
    segments.first { segment in
      time >= segment.start && time < resolvedEnd(segment) - 2
    }
  }

  /// Credits that run to the end stop just short of it, so playback ends by itself and the normal
  /// end-of-item handling runs (a seek to the very end does not always post it).
  public func skipTarget(for segment: SkipSegment) -> Double {
    let end = resolvedEnd(segment)
    return end >= duration - 0.5 ? max(duration - 0.5, segment.start) : end
  }

  private func resolvedEnd(_ segment: SkipSegment) -> Double {
    segment.end.map { min($0, duration) } ?? duration
  }
}

public struct AutoSkipState {
  private var skipped: Set<SkipSegment> = []

  public init() {}

  /// Recaps and intros, once each, and only when normal playback has just reached the segment start.
  /// A scrub or jump into a segment (or a paused player) gets the button instead.
  public mutating func shouldAutoSkip(_ segment: SkipSegment, at time: Double, previous: Double?,
                                      isPlaying: Bool, enabled: Bool) -> Bool {
    let justEntered = time >= segment.start && time - segment.start < 2
    let smooth = previous.map { time - $0 >= 0 && time - $0 < 2 } ?? true
    guard enabled, isPlaying, justEntered, smooth, segment.kind != .credits, !skipped.contains(segment) else {
      return false
    }
    skipped.insert(segment)
    return true
  }
}
