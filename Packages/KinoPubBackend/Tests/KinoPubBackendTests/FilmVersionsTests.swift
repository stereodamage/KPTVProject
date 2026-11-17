//
//  FilmVersionsTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class FilmVersionsTests: XCTestCase {
  private func makeVideo(number: Int, title: String = "", duration: Int = 7200, time: Int = 0,
                         heights: [Int] = [1080], audio: [String] = ["rus"], subs: [String] = []) -> Video {
    Video(id: 100 + number, title: title, thumbnail: "", duration: duration, tracks: 1, number: number, ac3: 0,
          audios: audio.enumerated().map {
            VideoAudio(id: $0.offset, index: $0.offset, codec: "aac", channels: 2, lang: $0.element,
                       type: nil, author: nil)
          },
          watched: 0, watching: EpisodeWatching(status: 0, time: time),
          subtitles: subs.map { Subtitle(lang: $0, shift: 0, embed: false, url: "", forced: nil, file: nil) },
          files: heights.map {
            FileInfo(codec: "h264", w: $0 * 16 / 9, h: $0, quality: "\($0)p", qualityID: 0,
                     url: URLInfo(http: "", hls: "", hls4: "", hls2: ""))
          })
  }

  func testMultiNeedsSubtypeAndTwoVideos() {
    XCTAssertTrue(FilmVersions.isMultiVersion(subtype: "multi", isSeries: false, videoCount: 2))
    XCTAssertTrue(FilmVersions.isMultiVersion(subtype: "MULTI", isSeries: false, videoCount: 2))
    XCTAssertFalse(FilmVersions.isMultiVersion(subtype: "multi", isSeries: false, videoCount: 1))
    XCTAssertFalse(FilmVersions.isMultiVersion(subtype: "movie", isSeries: false, videoCount: 3))
    XCTAssertFalse(FilmVersions.isMultiVersion(subtype: "multi", isSeries: true, videoCount: 2))
  }

  func testPrimaryPrefersInProgressVersion() {
    let videos = [makeVideo(number: 1), makeVideo(number: 2, time: 1200)]
    XCTAssertEqual(FilmVersions.primary(in: videos)?.number, 2)
  }

  func testPrimaryIgnoresFinishedVersion() {
    let videos = [makeVideo(number: 1), makeVideo(number: 2, time: 7190)]
    XCTAssertEqual(FilmVersions.primary(in: videos)?.number, 1)
  }

  func testPrimaryUsesLocalProgress() {
    let videos = [makeVideo(number: 1), makeVideo(number: 2)]
    XCTAssertEqual(FilmVersions.primary(in: videos, local: (video: 2, position: 900))?.number, 2)
  }

  func testRowTitleFallsBack() {
    XCTAssertEqual(FilmVersions.rowTitle(makeVideo(number: 3, title: "  ")), "Версия 3")
    XCTAssertEqual(FilmVersions.rowTitle(makeVideo(number: 1, title: "Режиссёрская")), "Режиссёрская")
  }

  func testFactsShowOnlyDifferences() {
    let videos = [makeVideo(number: 1, duration: 8040, heights: [1080, 2160], audio: ["rus", "eng"]),
                  makeVideo(number: 2, duration: 8040, heights: [1080], audio: ["rus", "eng"])]
    XCTAssertEqual(FilmVersions.differingFacts(videos), [["4K"], ["1080p"]])
  }

  func testFactsEmptyWhenOnlyTitlesDiffer() {
    let videos = [makeVideo(number: 1, title: "A"), makeVideo(number: 2, title: "B")]
    XCTAssertEqual(FilmVersions.differingFacts(videos), [[], []])
  }

  func testRuntimeAndSubtitleFacts() {
    let videos = [makeVideo(number: 1, duration: 8040, subs: ["eng"]), makeVideo(number: 2, duration: 3240)]
    XCTAssertEqual(FilmVersions.differingFacts(videos), [["2 ч 14 мин", "Субтитры: ENG"], ["54 мин"]])
  }

  func testManyLanguagesShowACount() {
    let videos = [makeVideo(number: 1, subs: ["eng", "ukr", "fre", "ger", "ita"]),
                  makeVideo(number: 2, audio: ["rus", "eng"])]
    XCTAssertEqual(FilmVersions.differingFacts(videos), [["Аудио: RUS", "Субтитры: 5 языков"], ["Аудио: RUS, ENG"]])
  }

  func testLanguageCountPlural() {
    XCTAssertEqual(FilmVersions.languageCount(4), "4 языка")
    XCTAssertEqual(FilmVersions.languageCount(21), "21 язык")
    XCTAssertEqual(FilmVersions.languageCount(46), "46 языков")
    XCTAssertEqual(FilmVersions.languageCount(12), "12 языков")
  }

  func testFilmVersionReportsItsOwnVideoNumber() {
    let video = makeVideo(number: 2)
    let version = FilmVersion(item: .mock(id: 5), video: video)
    XCTAssertEqual(version.metadata, WatchingMetadata(id: 5, video: 2, season: nil))
    XCTAssertEqual(version.files, video.files)
    XCTAssertEqual(version.id, video.id)
  }

  // MARK: - Quality label from the quality class, not the pixel height

  private func file(_ w: Int, _ h: Int, _ quality: String) -> FileInfo {
    FileInfo(codec: "h264", w: w, h: h, quality: quality, qualityID: 0,
             url: URLInfo(http: "", hls: "", hls4: "", hls2: ""))
  }

  func testBestQuality_LetterboxedFilmsUseTheQualityClass() {
    XCTAssertEqual(FilmVersions.bestQuality([file(1920, 800, "1080p"), file(1280, 534, "720p")]), "1080p")
    XCTAssertEqual(FilmVersions.bestQuality([file(3840, 1606, "2160p"), file(1920, 800, "1080p")]), "4K")
  }

  func testBestQuality_FallsBackToWidthWhenQualityIsUnreadable() {
    XCTAssertEqual(FilmVersions.bestQuality([file(1920, 800, "")]), "1080p")
    XCTAssertEqual(FilmVersions.bestQuality([file(3840, 1600, "uhd")]), "4K")
    XCTAssertNil(FilmVersions.bestQuality([]))
  }
}
