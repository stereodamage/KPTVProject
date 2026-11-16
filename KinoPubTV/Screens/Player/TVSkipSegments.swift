//
//  TVSkipSegments.swift
//  KinoPubTV
//

import Foundation
import KinoPubBackend

struct TVSkipSetup: Equatable {
  let segments: [SkipSegment]
  let isFilm: Bool
  /// Runtime from kino.pub, used until the player knows the real stream length.
  let apiDuration: Double
}

/// What the player needs beyond the stream: skip segments and, for an episode, the next one.
struct TVPlaybackContext {
  let skip: TVSkipSetup?
  let next: Episode?

  static func load(item: any PlayableItem, mode: WatchMode, contentService: VideoContentService) async -> TVPlaybackContext {
    guard mode == .media else { return TVPlaybackContext(skip: nil, next: nil) }
    let imdb: Int?, season: Int?, episode: Int?, duration: Int, isFilm: Bool
    var next: Episode?
    switch item {
    case let version as FilmVersion:
      (imdb, season, episode, duration, isFilm) = (version.item.imdb, nil, nil, version.video.duration, true)
    case let film as MediaItem where !film.isSeries:
      (imdb, season, episode, duration, isFilm) = (film.imdb, nil, nil, film.videos?.first?.duration ?? 0, true)
    case let item as Episode:
      guard let seasonNumber = item.seasonNumber else { return TVPlaybackContext(skip: nil, next: nil) }
      let series = try? await contentService.fetchDetails(for: String(item.metadata.id)).item
      if let series, let entry = UpNext.next(after: seasonNumber, episode: item.number, in: series) {
        // A fresh instance from this fetch, so filling it in place is not seen by the detail screen.
        entry.episode.seasonNumber = entry.season.number
        entry.episode.mediaId = entry.season.mediaId ?? series.id
        entry.episode.mediaTitle = series.localizedTitle
        next = entry.episode
      }
      (imdb, season, episode, duration, isFilm) = (series?.imdb, seasonNumber, item.number, item.duration, false)
    default:
      return TVPlaybackContext(skip: nil, next: nil)
    }
    var skip: TVSkipSetup?
    if let imdb, imdb > 0 {
      let segments = await TVSkipSegments.service.segments(imdb: imdb, season: season, episode: episode, duration: duration)
      if !segments.isEmpty { skip = TVSkipSetup(segments: segments, isFilm: isFilm, apiDuration: Double(duration)) }
    }
    return TVPlaybackContext(skip: skip, next: next)
  }
}

enum TVSkipSegments {
  static let autoSkipKey = "autoSkipIntro"
  static let service = SkipSegmentsService()

  /// One short label: AVKit's button has a fixed width and scrolls «Пропустить заставку».
  static func title(for kind: SkipSegment.Kind) -> String {
    "Skip".localized
  }
}
