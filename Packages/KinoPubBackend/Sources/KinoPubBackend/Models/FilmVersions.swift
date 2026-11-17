//
//  FilmVersions.swift
//  KinoPubBackend
//

import Foundation

public enum FilmVersions {
  public static func isMultiVersion(subtype: String, isSeries: Bool, videoCount: Int) -> Bool {
    subtype.lowercased() == "multi" && !isSeries && videoCount > 1
  }

  /// The version to resume: the unfinished one with the most watched time, else the first.
  public static func primary(in videos: [Video], local: (video: Int, position: Double)? = nil) -> Video? {
    func time(_ video: Video) -> Double {
      let localTime = local?.video == video.number ? local?.position ?? 0 : 0
      return max(Double(video.watching.time), localTime)
    }
    let candidates = videos.filter { !$0.isWatchedToEnd && time($0) > 0 }
    return candidates.max { time($0) < time($1) } ?? videos.first
  }

  public static func rowTitle(_ video: Video) -> String {
    let title = video.title.trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? "Версия \(video.number)" : title
  }

  /// Per video, the facts that are not the same for all videos: runtime, best quality, audio, subtitles.
  public static func differingFacts(_ videos: [Video]) -> [[String]] {
    let columns: [[String?]] = [
      videos.map { runtime($0.duration) },
      videos.map { bestQuality($0.files) },
      videos.map { languages($0.audios.map(\.lang), label: "Аудио") },
      videos.map { languages($0.subtitles.map(\.lang), label: "Субтитры") },
    ]
    let differing = columns.filter { Set($0.map { $0 ?? "" }).count > 1 }
    return videos.indices.map { index in differing.compactMap { $0[index] } }
  }

  static func runtime(_ seconds: Int) -> String? {
    guard seconds > 0 else { return nil }
    let hours = seconds / 3600, minutes = (seconds % 3600) / 60
    return hours > 0 ? "\(hours) ч \(minutes) мин" : "\(minutes) мин"
  }

  /// From the quality class ("1080p"), not the pixel height: a letterboxed 1080p file is 1920×800.
  static func bestQuality(_ files: [FileInfo]) -> String? {
    guard let lines = files.map(qualityLines).max(), lines > 0 else { return nil }
    return lines >= 2160 ? "4K" : "\(lines)p"
  }

  private static func qualityLines(_ file: FileInfo) -> Int {
    if file.resolution > 0 { return file.resolution }
    switch file.w {
    case 3840...: return 2160
    case 2560...: return 1440
    case 1920...: return 1080
    case 1280...: return 720
    default: return file.h
    }
  }

  /// Up to 3 language codes, else only their number (one version can carry 40+ subtitle tracks).
  static func languages(_ codes: [String], label: String) -> String? {
    var seen = Set<String>()
    let unique = codes.map { $0.uppercased() }.filter { !$0.isEmpty && seen.insert($0).inserted }
    if unique.isEmpty { return nil }
    return "\(label): " + (unique.count > 3 ? languageCount(unique.count) : unique.joined(separator: ", "))
  }

  static func languageCount(_ count: Int) -> String {
    let mod10 = count % 10, mod100 = count % 100
    if mod10 == 1 && mod100 != 11 { return "\(count) язык" }
    if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(count) языка" }
    return "\(count) языков"
  }
}

public extension MediaItem {
  var isMultiVersion: Bool {
    FilmVersions.isMultiVersion(subtype: subtype, isSeries: isSeries, videoCount: videos?.count ?? 0)
  }

  func primaryVideo(local: (video: Int, position: Double)? = nil) -> Video? {
    FilmVersions.primary(in: videos ?? [], local: local)
  }
}

/// One version of a film, playable on its own.
public struct FilmVersion: PlayableItem {
  public let item: MediaItem
  public let video: Video

  public init(item: MediaItem, video: Video) {
    self.item = item
    self.video = video
  }

  public var id: Int { video.id }
  public var files: [FileInfo] { video.files }
  public var trailer: Trailer? { nil }
  public var metadata: WatchingMetadata { WatchingMetadata(id: item.id, video: video.number, season: nil) }
  public var playerTitle: String { item.localizedTitle }
  public var playerSubtitle: String? { item.isMultiVersion ? FilmVersions.rowTitle(video) : nil }
}
