import Foundation
import XCTest
@testable import KinoPubBackend

final class BookmarksCollectionsTests: XCTestCase {

  private let builder = RequestBuilder(baseURL: URL(string: "https://api.example.com")!)

  private func body(_ endpoint: Endpoint) -> [String: String] {
    guard let data = builder.build(with: endpoint)?.httpBody,
          let string = String(data: data, encoding: .utf8) else { return [:] }
    var dict = [String: String]()
    for pair in string.split(separator: "&") {
      let kv = pair.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding ?? String($0) }
      if kv.count == 2 { dict[kv[0]] = kv[1] }
    }
    return dict
  }

  private func query(_ endpoint: Endpoint) -> [String: String] {
    guard let url = builder.build(with: endpoint)?.url,
          let items = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems else { return [:] }
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })
  }

  // MARK: - Preferred rating

  func testPreferredRating_IMDbFirst() {
    let rating = PreferredRating.pick(imdb: 7.9, kinopoisk: 8.4, votes: 10, percentage: 90)
    XCTAssertEqual(rating?.source, "IMDb")
    XCTAssertEqual(rating?.value, 7.9)
  }

  func testPreferredRating_KinopoiskWhenNoIMDb() {
    XCTAssertEqual(PreferredRating.pick(imdb: nil, kinopoisk: 8.4, votes: 10, percentage: 90)?.source, "КиноПоиск")
    XCTAssertEqual(PreferredRating.pick(imdb: 0, kinopoisk: 8.4, votes: 10, percentage: 90)?.value, 8.4)
  }

  func testPreferredRating_KinoPubNeedsVotes() {
    let rating = PreferredRating.pick(imdb: 0, kinopoisk: nil, votes: 3, percentage: 85)
    XCTAssertEqual(rating?.source, "kino.pub")
    XCTAssertEqual(rating?.value ?? 0, 8.5, accuracy: 0.0001)
    XCTAssertNil(PreferredRating.pick(imdb: nil, kinopoisk: 0, votes: 0, percentage: 85))
    XCTAssertNil(PreferredRating.pick(imdb: nil, kinopoisk: nil, votes: 5, percentage: 0))
  }

  // MARK: - RemoveBookmarkItemRequest

  func testRemoveBookmarkItem_PathAndMethod() {
    let request = builder.build(with: RemoveBookmarkItemRequest(item: 42, folder: 7))
    XCTAssertEqual(request?.url?.path, "/v1/bookmarks/remove-item")
    XCTAssertEqual(request?.httpMethod, "POST")
  }

  func testRemoveBookmarkItem_SendsItemAndFolderInBody() {
    let endpoint = RemoveBookmarkItemRequest(item: 42, folder: 7)
    XCTAssertFalse(endpoint.forceSendAsGetParams)
    XCTAssertEqual(body(endpoint), ["item": "42", "folder": "7"])
    XCTAssertTrue(query(endpoint).isEmpty)
  }

  // MARK: - BookmarkItemsRequest paging

  func testBookmarkItems_NoPageByDefault() {
    let endpoint = BookmarkItemsRequest(id: "777")
    XCTAssertEqual(builder.build(with: endpoint)?.url?.path, "/v1/bookmarks/777")
    XCTAssertNil(query(endpoint)["page"])
  }

  func testBookmarkItems_SendsPage() {
    let endpoint = BookmarkItemsRequest(id: "777", page: 3)
    XCTAssertEqual(builder.build(with: endpoint)?.httpMethod, "GET")
    XCTAssertEqual(query(endpoint)["page"], "3")
  }

  // MARK: - PagedItemsData

  private struct Row: Codable, Equatable { let id: Int }

  func testPagedItems_DecodesWithPagination() throws {
    let json = #"{"status":200,"items":[{"id":1},{"id":2}],"pagination":{"total":3,"current":1,"perpage":2}}"#
    let data = try JSONDecoder().decode(PagedItemsData<Row>.self, from: Data(json.utf8))
    XCTAssertEqual(data.items, [Row(id: 1), Row(id: 2)])
    XCTAssertEqual(data.pagination?.total, 3)
    XCTAssertTrue(data.hasNextPage)
  }

  func testPagedItems_DecodesWithoutPagination() throws {
    let json = #"{"status":200,"folder":{"id":5},"items":[{"id":1}]}"#
    let data = try JSONDecoder().decode(PagedItemsData<Row>.self, from: Data(json.utf8))
    XCTAssertEqual(data.items, [Row(id: 1)])
    XCTAssertNil(data.pagination)
    XCTAssertFalse(data.hasNextPage)
  }

  func testPagedItems_LastPageHasNoNext() throws {
    let json = #"{"items":[],"pagination":{"total":3,"current":3,"perpage":2}}"#
    XCTAssertFalse(try JSONDecoder().decode(PagedItemsData<Row>.self, from: Data(json.utf8)).hasNextPage)
  }

  // MARK: - Bookmark.itemCount

  func testBookmarkItemCount() {
    func folder(_ count: String) -> Bookmark {
      Bookmark(id: 1, title: "", views: 0, count: count, created: 0, updated: 0)
    }
    XCTAssertEqual(folder("12").itemCount, 12)
    XCTAssertEqual(folder(" 3 ").itemCount, 3)
    XCTAssertNil(folder("").itemCount)
    XCTAssertNil(folder("abc").itemCount)
  }
}
