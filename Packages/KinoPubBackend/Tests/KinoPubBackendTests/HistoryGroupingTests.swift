//
//  HistoryGroupingTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class HistoryGroupingTests: XCTestCase {
  private func entry(_ itemId: Int, episode: Int? = nil, seen: TimeInterval) -> HistoryItem {
    HistoryItem(time: nil, counter: 1, firstSeen: nil, lastSeen: seen, item: .mock(id: itemId),
                media: episode.map { HistoryMedia(number: $0, seasonNumber: 1) })
  }

  func testEpisodesOfOneShowFoldIntoOneGroupAtItsLatestPosition() {
    // Newest first: show 1 ep3, movie 2, show 1 ep2, show 1 ep1, movie 3
    let groups = [entry(1, episode: 3, seen: 50), entry(2, seen: 40), entry(1, episode: 2, seen: 30),
                  entry(1, episode: 1, seen: 20), entry(3, seen: 10)].groupedByTitle()

    XCTAssertEqual(groups.map(\.latest.item.id), [1, 2, 3])
    XCTAssertEqual(groups.map(\.count), [3, 1, 1])
    XCTAssertEqual(groups[0].latest.media?.number, 3)
    XCTAssertEqual(groups[0].entries.map { $0.media?.number }, [3, 2, 1])
  }

  func testEmptyAndSingle() {
    XCTAssertTrue([HistoryItem]().groupedByTitle().isEmpty)
    XCTAssertEqual([entry(7, seen: 1)].groupedByTitle().first?.count, 1)
  }

  func testFreshPageReplacesARewatchedVideoAndKeepsOlderPages() {
    let loaded = [entry(1, episode: 2, seen: 30), entry(2, seen: 20), entry(3, seen: 10)]
    let fresh = [entry(2, seen: 50), entry(4, seen: 40), entry(1, episode: 2, seen: 30)]
    let merged = loaded.mergingFreshPage(fresh)
    XCTAssertEqual(merged.map(\.item.id), [2, 4, 1, 3])
    XCTAssertEqual(merged.first?.lastSeen, 50)
  }

  func testOtherEpisodesOfAShowStaySeparate() {
    let merged = [entry(1, episode: 1, seen: 10)].mergingFreshPage([entry(1, episode: 2, seen: 20)])
    XCTAssertEqual(merged.map { $0.media?.number }, [2, 1])
  }
}
