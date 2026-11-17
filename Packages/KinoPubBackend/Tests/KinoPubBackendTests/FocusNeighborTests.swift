import XCTest
@testable import KinoPubBackend

final class FocusNeighborTests: XCTestCase {
  func testPrefersTheNextKeptId() {
    XCTAssertEqual(FocusNeighbor.neighbor(of: 2, in: [1, 2, 3, 4], kept: { $0 != 2 && $0 != 3 }), 4)
  }

  func testFallsBackToThePreviousKeptId() {
    XCTAssertEqual(FocusNeighbor.neighbor(of: 4, in: [1, 2, 3, 4], kept: { $0 == 1 }), 1)
  }

  func testCrossesRowsInDisplayOrder() {
    let order = ["new-1", "movie-7", "follow-3"]
    XCTAssertEqual(FocusNeighbor.neighbor(of: "movie-7", in: order, kept: { $0 != "movie-7" }), "follow-3")
  }

  func testNilWhenNothingIsKeptOrIdIsUnknown() {
    XCTAssertNil(FocusNeighbor.neighbor(of: 1, in: [1, 2], kept: { _ in false }))
    XCTAssertNil(FocusNeighbor.neighbor(of: 9, in: [1, 2], kept: { _ in true }))
  }
}
