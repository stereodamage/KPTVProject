//
//  UpNext.swift
//  KinoPubBackend
//

import Foundation

public enum PlayerButton: Equatable {
  case skip(SkipSegment)
  case nextEpisode
}

public enum UpNext {
  public static func next(after season: Int, episode: Int, in item: MediaItem) -> (season: Season, episode: Episode)? {
    let ordered = item.orderedEpisodes
    guard let index = ordered.firstIndex(where: { $0.season.number == season && $0.episode.number == episode }),
          index + 1 < ordered.count else { return nil }
    return ordered[index + 1]
  }

  /// The credits start when the credits run to the end; else the usual end-of-credits tolerance.
  public static func offerTime(duration: Double, credits: SkipSegment?) -> Double? {
    guard duration.isFinite, duration > 0 else { return nil }
    let fallback = duration - WatchProgress.endTolerance(forDuration: duration)
    var time = fallback
    if let credits, credits.start.isFinite, credits.start < duration, (credits.end ?? duration) >= duration - 5 {
      time = credits.start
    }
    return max(time, duration / 2)
  }

  public static func button(at time: Double, schedule: SkipSchedule, offerTime: Double?, hasNext: Bool) -> PlayerButton? {
    if hasNext, let offerTime, time >= offerTime { return .nextEpisode }
    return schedule.active(at: time).map(PlayerButton.skip)
  }
}
