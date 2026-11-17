import Foundation
import XCTest
@testable import KinoPubBackend

final class ContinueWatchingMergeTests: XCTestCase {

  private struct Entry: Equatable {
    let id: Int
    let progress: Double
    let at: TimeInterval
  }

  private func merge(fresh: [Entry]?, cached: [Entry], local: [Entry]) -> [Entry] {
    ContinueWatchingMerge.merge(fresh: fresh, cached: cached, local: local, id: \.id, watchedAt: \.at)
      .sorted { $0.id < $1.id }
  }

  // MARK: - Failed history (fresh == nil)

  func testFailed_NewerLocalProgressReplacesCached() {
    let result = merge(fresh: nil, cached: [Entry(id: 1, progress: 0.2, at: 100)],
                       local: [Entry(id: 1, progress: 0.6, at: 200)])
    XCTAssertEqual(result, [Entry(id: 1, progress: 0.6, at: 200)])
  }

  func testFailed_LocalFinishReplacesCached() {
    let result = merge(fresh: nil, cached: [Entry(id: 1, progress: 0.2, at: 100)],
                       local: [Entry(id: 1, progress: 0.99, at: 300)])
    XCTAssertEqual(result.first?.progress, 0.99, "the caller's finished filter then drops it")
  }

  func testFailed_OlderLocalIsIgnored() {
    let result = merge(fresh: nil, cached: [Entry(id: 1, progress: 0.5, at: 200)],
                       local: [Entry(id: 1, progress: 0.3, at: 100)])
    XCTAssertEqual(result, [Entry(id: 1, progress: 0.5, at: 200)])
  }

  func testFailed_NewLocalTitleIsAdded() {
    let result = merge(fresh: nil, cached: [Entry(id: 1, progress: 0.2, at: 100)],
                       local: [Entry(id: 2, progress: 0.1, at: 50)])
    XCTAssertEqual(result.map(\.id), [1, 2])
  }

  func testFailed_NoCacheUsesLocalOnly() {
    let result = merge(fresh: nil, cached: [], local: [Entry(id: 3, progress: 0.4, at: 10)])
    XCTAssertEqual(result.map(\.id), [3])
  }

  // MARK: - Fresh history

  func testFresh_WinsForListedTitles_LocalAddsUnlisted() {
    let result = merge(fresh: [Entry(id: 1, progress: 0.3, at: 100)],
                       cached: [Entry(id: 9, progress: 0.9, at: 999)],
                       local: [Entry(id: 1, progress: 0.8, at: 500), Entry(id: 2, progress: 0.1, at: 50)])
    XCTAssertEqual(result, [Entry(id: 1, progress: 0.3, at: 100), Entry(id: 2, progress: 0.1, at: 50)],
                   "fresh entry wins for id 1 even if local is newer; the cache is not used")
  }

  func testFresh_EmptyHistoryDropsCache() {
    let result = merge(fresh: [], cached: [Entry(id: 9, progress: 0.9, at: 999)], local: [])
    XCTAssertTrue(result.isEmpty)
  }
}
