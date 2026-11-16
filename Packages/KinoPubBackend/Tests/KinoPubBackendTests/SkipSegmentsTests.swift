//
//  SkipSegmentsTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class SkipSegmentsTests: XCTestCase {
  // Live replies, 2026-11-16.
  private let skipDBBreakingBad = """
  {"imdb_id":"tt0903747","season":1,"episode":1,"segments":{"intro":{"start_ms":229500,"end_ms":246500,"adjusted":false,"offset_ms":0,"match":"agnostic","confidence":0.75},"recap":null,"outro":{"start_ms":3434000,"end_ms":3500000,"adjusted":false,"offset_ms":0,"match":"agnostic","confidence":0.75},"preview":null},"intro_length_estimate_ms":17000}
  """
  private let skipDBUnknown = """
  {"imdb_id":"tt9999999","season":1,"episode":1,"segments":{"intro":null,"recap":null,"outro":null,"preview":null},"intro_length_estimate_ms":null}
  """
  private let introDBBreakingBad = """
  {"tvdb_id":81189,"type":"tv","season":1,"episode":1,"intro":[{"start_ms":228665,"end_ms":246498}],"credits":[{"start_ms":3432884,"end_ms":null}]}
  """
  private let introDBInception = """
  {"tvdb_id":113,"type":"movie","intro":[{"start_ms":null,"end_ms":38000}]}
  """

  private func skipDB(match: String, offset: Int) -> String {
    """
    {"segments":{"intro":{"start_ms":229500,"end_ms":246500,"adjusted":false,"offset_ms":\(offset),"match":"\(match)"},"recap":null,"outro":null,"preview":null}}
    """
  }

  func testSkipDBEpisode() {
    XCTAssertEqual(SkipDB.segments(from: Data(skipDBBreakingBad.utf8)), [
      SkipSegment(kind: .intro, start: 229.5, end: 246.5),
      SkipSegment(kind: .credits, start: 3434, end: 3500),
    ])
  }

  func testSkipDBNullsGiveNothing() {
    XCTAssertEqual(SkipDB.segments(from: Data(skipDBUnknown.utf8)), [])
  }

  func testSkipDBOutOfRangeIsIgnored() {
    XCTAssertEqual(SkipDB.segments(from: Data(skipDB(match: "out-of-range", offset: -20000).utf8)), [])
  }

  func testSkipDBShiftedUsesTimesAsGiven() {
    XCTAssertEqual(SkipDB.segments(from: Data(skipDB(match: "shifted", offset: 10000).utf8)),
                   [SkipSegment(kind: .intro, start: 229.5, end: 246.5)])
  }

  func testTheIntroDBNullEndAndStart() {
    XCTAssertEqual(TheIntroDB.segments(from: Data(introDBBreakingBad.utf8)), [
      SkipSegment(kind: .intro, start: 228.665, end: 246.498),
      SkipSegment(kind: .credits, start: 3432.884, end: nil),
    ])
    XCTAssertEqual(TheIntroDB.segments(from: Data(introDBInception.utf8)),
                   [SkipSegment(kind: .intro, start: 0, end: 38)])
  }

  func testTheIntroDBMissingKeysAndErrors() {
    XCTAssertEqual(TheIntroDB.segments(from: Data(#"{"tvdb_id":1,"type":"tv"}"#.utf8)), [])
    XCTAssertEqual(TheIntroDB.segments(from: Data(#"{"error":"media not found","code":"media_not_found"}"#.utf8)), [])
  }

  func testMergePrefersSkipDBAndFillsGaps() {
    let merged = SkipSegments.merge(primary: [SkipSegment(kind: .intro, start: 229.5, end: 246.5)],
                                    fallback: [SkipSegment(kind: .intro, start: 228.6, end: 246.4),
                                               SkipSegment(kind: .credits, start: 3432.9, end: nil)])
    XCTAssertEqual(merged, [SkipSegment(kind: .intro, start: 229.5, end: 246.5),
                            SkipSegment(kind: .credits, start: 3432.9, end: nil)])
  }

  func testMergeDropsShortSegments() {
    XCTAssertEqual(SkipSegments.merge(primary: [SkipSegment(kind: .recap, start: 10, end: 10.5)], fallback: []), [])
  }

  func testURLs() {
    XCTAssertEqual(SkipSegments.imdbID(903747), "tt0903747")
    XCTAssertEqual(SkipDB.url(imdb: "tt1375666", season: nil, episode: nil).absoluteString,
                   "https://api.skipdb.tv/api/segments?imdb_id=tt1375666")
    XCTAssertEqual(TheIntroDB.url(imdb: "tt0903747", season: 1, episode: 1).absoluteString,
                   "https://api.theintrodb.org/v4/media?imdb_id=tt0903747&season=1&episode=1")
  }

  // MARK: - Service

  func testCacheKeyIncludesDuration() async {
    StubProtocol.reset(reply: skipDBBreakingBad)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubProtocol.self]
    let service = SkipSegmentsService(session: URLSession(configuration: configuration))

    let first = await service.segments(imdb: 903747, season: 1, episode: 1, duration: 3480)
    _ = await service.segments(imdb: 903747, season: 1, episode: 1, duration: 3480)
    XCTAssertEqual(StubProtocol.requestCount, 2, "both sources once; the second call is cached")
    _ = await service.segments(imdb: 903747, season: 1, episode: 1, duration: 3500)
    XCTAssertEqual(StubProtocol.requestCount, 4, "another duration is another cache entry")
    XCTAssertEqual(first.map(\.kind), [.intro, .credits])
  }

  // MARK: - Schedule

  private let episode = [SkipSegment(kind: .intro, start: 229.5, end: 246.5),
                         SkipSegment(kind: .credits, start: 3434, end: nil)]

  func testActiveInsideSegment() {
    let schedule = SkipSchedule(segments: episode, isFilm: false, duration: 3480)
    XCTAssertNil(schedule.active(at: 229))
    XCTAssertEqual(schedule.active(at: 230)?.kind, .intro)
    XCTAssertEqual(schedule.active(at: 3440)?.kind, .credits)
  }

  func testHiddenInLastTwoSeconds() {
    let schedule = SkipSchedule(segments: episode, isFilm: false, duration: 3480)
    XCTAssertEqual(schedule.active(at: 244.4)?.kind, .intro)
    XCTAssertNil(schedule.active(at: 244.6))
  }

  func testFilmIgnoresCredits() {
    let schedule = SkipSchedule(segments: episode, isFilm: true, duration: 3480)
    XCTAssertNil(schedule.active(at: 3440))
    XCTAssertEqual(schedule.active(at: 230)?.kind, .intro)
  }

  func testCreditsToStreamEndTargetsJustBeforeEnd() {
    let schedule = SkipSchedule(segments: episode, isFilm: false, duration: 3480)
    XCTAssertEqual(schedule.skipTarget(for: episode[1]), 3479.5)
    XCTAssertEqual(schedule.skipTarget(for: SkipSegment(kind: .credits, start: 3434, end: 3500)), 3479.5)
    XCTAssertEqual(schedule.skipTarget(for: episode[0]), 246.5)
  }

  private func auto(_ state: inout AutoSkipState, _ segment: SkipSegment, at time: Double, previous: Double?,
                    playing: Bool = true, enabled: Bool = true) -> Bool {
    state.shouldAutoSkip(segment, at: time, previous: previous, isPlaying: playing, enabled: enabled)
  }

  func testAutoSkipOncePerSegment() {
    var state = AutoSkipState()
    XCTAssertTrue(auto(&state, episode[0], at: 229.6, previous: 229.35))
    XCTAssertFalse(auto(&state, episode[0], at: 229.6, previous: 229.35))
  }

  func testAutoSkipNeverForCredits() {
    var state = AutoSkipState()
    XCTAssertFalse(auto(&state, episode[1], at: 3434.1, previous: 3433.9))
  }

  func testAutoSkipOffWhenDisabled() {
    var state = AutoSkipState()
    XCTAssertFalse(auto(&state, episode[0], at: 229.6, previous: 229.35, enabled: false))
    XCTAssertTrue(auto(&state, episode[0], at: 229.6, previous: 229.35))
  }

  func testScrubIntoSegmentDoesNotAutoSkipOrUseItUp() {
    var state = AutoSkipState()
    XCTAssertFalse(auto(&state, episode[0], at: 238, previous: 228), "a 10 s jump into the middle")
    XCTAssertFalse(auto(&state, episode[0], at: 230, previous: 240), "scrubbing backwards")
    XCTAssertFalse(auto(&state, episode[0], at: 229.6, previous: 229.6, playing: false), "paused")
    XCTAssertTrue(auto(&state, episode[0], at: 229.6, previous: 229.35), "later normal playback still skips")
  }

  func testIntroAtZeroSkipsOnStart() {
    var state = AutoSkipState()
    XCTAssertTrue(auto(&state, SkipSegment(kind: .intro, start: 0, end: 34), at: 0.3, previous: nil))
  }
}

private final class StubProtocol: URLProtocol {
  nonisolated(unsafe) static var requestCount = 0
  nonisolated(unsafe) static var reply = Data()

  static func reset(reply: String) {
    requestCount = 0
    self.reply = Data(reply.utf8)
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.requestCount += 1
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.reply)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
