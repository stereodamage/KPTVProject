//
//  LocalResumeMatchTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class LocalResumeMatchTests: XCTestCase {
  func testSeriesNeedsSameSeasonAndEpisode() {
    XCTAssertTrue(LocalResumeMatch.matches(entrySeason: 2, entryEpisode: 5, season: 2, episode: 5))
    XCTAssertFalse(LocalResumeMatch.matches(entrySeason: 2, entryEpisode: 4, season: 2, episode: 5))
    XCTAssertFalse(LocalResumeMatch.matches(entrySeason: 1, entryEpisode: 5, season: 2, episode: 5))
  }

  func testFilmVersionMismatchIsRejected() {
    XCTAssertFalse(LocalResumeMatch.matches(entrySeason: nil, entryEpisode: 1, season: nil, episode: 2))
  }

  func testFilmSameVersionMatches() {
    XCTAssertTrue(LocalResumeMatch.matches(entrySeason: nil, entryEpisode: 1, season: nil, episode: 1))
  }

  func testFilmWithoutNumberMatches() {
    XCTAssertTrue(LocalResumeMatch.matches(entrySeason: nil, entryEpisode: nil, season: nil, episode: 2))
    XCTAssertTrue(LocalResumeMatch.matches(entrySeason: nil, entryEpisode: 3, season: nil, episode: nil))
  }

  func testFilmEntryNeverMatchesSeriesRequestAndBack() {
    XCTAssertFalse(LocalResumeMatch.matches(entrySeason: nil, entryEpisode: 1, season: 1, episode: 1))
    XCTAssertFalse(LocalResumeMatch.matches(entrySeason: 1, entryEpisode: 1, season: nil, episode: 1))
  }
}
