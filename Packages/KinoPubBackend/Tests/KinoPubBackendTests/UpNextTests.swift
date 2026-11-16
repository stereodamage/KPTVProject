//
//  UpNextTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class UpNextTests: XCTestCase {
  private func episode(_ number: Int) -> Episode {
    Episode(id: 1000 + number, title: "", thumbnail: "", duration: 1324, tracks: 1, number: number, ac3: 0,
            audios: [], watched: 0, watching: EpisodeWatching(status: 0, time: 0), subtitles: [], files: [])
  }

  private func series(_ seasons: [Int: Int]) -> MediaItem {
    var item = MediaItem.mock(id: 7)
    item.seasons = seasons.map { number, count in
      Season(id: number, title: "", number: number, watching: SeasonWatching(status: 0),
             episodes: (1...count).map(episode))
    }
    return item
  }

  func testNextInSameSeason() {
    let next = UpNext.next(after: 3, episode: 1, in: series([3: 3]))
    XCTAssertEqual(next?.season.number, 3)
    XCTAssertEqual(next?.episode.number, 2)
  }

  func testNextCrossesSeason() {
    let next = UpNext.next(after: 1, episode: 2, in: series([2: 2, 1: 2]))
    XCTAssertEqual(next?.season.number, 2)
    XCTAssertEqual(next?.episode.number, 1)
  }

  func testLastAndUnknownHaveNone() {
    XCTAssertNil(UpNext.next(after: 1, episode: 2, in: series([1: 2])))
    XCTAssertNil(UpNext.next(after: 9, episode: 1, in: series([1: 2])))
  }

  func testOfferAtCreditsStart() {
    XCTAssertEqual(UpNext.offerTime(duration: 1336, credits: SkipSegment(kind: .credits, start: 1289, end: 1336)), 1289)
    XCTAssertEqual(UpNext.offerTime(duration: 1336, credits: SkipSegment(kind: .credits, start: 1289, end: nil)), 1289)
  }

  func testOfferFallsBackToEndTolerance() {
    let duration = 1324.0
    XCTAssertEqual(UpNext.offerTime(duration: duration, credits: nil),
                   duration - WatchProgress.endTolerance(forDuration: duration))
  }

  func testCreditsEndingEarlyOrBeyondEndAreIgnored() {
    let fallback = 1324 - WatchProgress.endTolerance(forDuration: 1324)
    XCTAssertEqual(UpNext.offerTime(duration: 1324, credits: SkipSegment(kind: .credits, start: 600, end: 700)), fallback)
    XCTAssertEqual(UpNext.offerTime(duration: 1324, credits: SkipSegment(kind: .credits, start: 1400, end: nil)), fallback)
  }

  func testOfferNeverBeforeHalfAndNeedsDuration() {
    XCTAssertEqual(UpNext.offerTime(duration: 1000, credits: SkipSegment(kind: .credits, start: 100, end: nil)), 500)
    XCTAssertNil(UpNext.offerTime(duration: .nan, credits: nil))
    XCTAssertNil(UpNext.offerTime(duration: 0, credits: nil))
  }

  func testButtonOrder() {
    let intro = SkipSegment(kind: .intro, start: 96.8, end: 126.8)
    let credits = SkipSegment(kind: .credits, start: 1289, end: nil)
    let schedule = SkipSchedule(segments: [intro, credits], isFilm: false, duration: 1336)
    XCTAssertEqual(UpNext.button(at: 100, schedule: schedule, offerTime: 1289, hasNext: true), .skip(intro))
    XCTAssertEqual(UpNext.button(at: 1290, schedule: schedule, offerTime: 1289, hasNext: true), .nextEpisode)
    XCTAssertEqual(UpNext.button(at: 1290, schedule: schedule, offerTime: 1289, hasNext: false), .skip(credits))
    XCTAssertNil(UpNext.button(at: 600, schedule: schedule, offerTime: 1289, hasNext: true))
  }
}
