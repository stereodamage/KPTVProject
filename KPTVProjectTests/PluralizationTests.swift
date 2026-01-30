//
//  PluralizationTests.swift
//  KPTVProjectTests
//
//  Tests for Russian pluralization
//

import XCTest
@testable import KPTVProject

final class PluralizationTests: XCTestCase {
    
    // MARK: - Episodes Pluralization Tests
    
    func testEpisodesPluralOne() {
        XCTAssertEqual(RussianPlural.episodes(1), "1 серия")
        XCTAssertEqual(RussianPlural.episodes(21), "21 серия")
        XCTAssertEqual(RussianPlural.episodes(31), "31 серия")
        XCTAssertEqual(RussianPlural.episodes(101), "101 серия")
    }
    
    func testEpisodesPluralFew() {
        XCTAssertEqual(RussianPlural.episodes(2), "2 серии")
        XCTAssertEqual(RussianPlural.episodes(3), "3 серии")
        XCTAssertEqual(RussianPlural.episodes(4), "4 серии")
        XCTAssertEqual(RussianPlural.episodes(22), "22 серии")
        XCTAssertEqual(RussianPlural.episodes(23), "23 серии")
        XCTAssertEqual(RussianPlural.episodes(24), "24 серии")
    }
    
    func testEpisodesPluralMany() {
        XCTAssertEqual(RussianPlural.episodes(0), "0 серий")
        XCTAssertEqual(RussianPlural.episodes(5), "5 серий")
        XCTAssertEqual(RussianPlural.episodes(10), "10 серий")
        XCTAssertEqual(RussianPlural.episodes(11), "11 серий")
        XCTAssertEqual(RussianPlural.episodes(12), "12 серий")
        XCTAssertEqual(RussianPlural.episodes(13), "13 серий")
        XCTAssertEqual(RussianPlural.episodes(14), "14 серий")
        XCTAssertEqual(RussianPlural.episodes(20), "20 серий")
        XCTAssertEqual(RussianPlural.episodes(100), "100 серий")
    }
    
    // MARK: - Movies Pluralization Tests
    
    func testMoviesPluralOne() {
        XCTAssertEqual(RussianPlural.movies(1), "1 фильм")
        XCTAssertEqual(RussianPlural.movies(21), "21 фильм")
    }
    
    func testMoviesPluralFew() {
        XCTAssertEqual(RussianPlural.movies(2), "2 фильма")
        XCTAssertEqual(RussianPlural.movies(3), "3 фильма")
        XCTAssertEqual(RussianPlural.movies(4), "4 фильма")
    }
    
    func testMoviesPluralMany() {
        XCTAssertEqual(RussianPlural.movies(5), "5 фильмов")
        XCTAssertEqual(RussianPlural.movies(10), "10 фильмов")
        XCTAssertEqual(RussianPlural.movies(11), "11 фильмов")
    }
    
    // MARK: - Series Pluralization Tests
    
    func testSeriesPluralOne() {
        XCTAssertEqual(RussianPlural.series(1), "1 сериал")
    }
    
    func testSeriesPluralFew() {
        XCTAssertEqual(RussianPlural.series(2), "2 сериала")
        XCTAssertEqual(RussianPlural.series(3), "3 сериала")
    }
    
    func testSeriesPluralMany() {
        XCTAssertEqual(RussianPlural.series(5), "5 сериалов")
        XCTAssertEqual(RussianPlural.series(11), "11 сериалов")
    }
    
    // MARK: - Seasons Pluralization Tests
    
    func testSeasonsPluralOne() {
        XCTAssertEqual(RussianPlural.seasons(1), "1 сезон")
    }
    
    func testSeasonsPluralFew() {
        XCTAssertEqual(RussianPlural.seasons(2), "2 сезона")
        XCTAssertEqual(RussianPlural.seasons(3), "3 сезона")
    }
    
    func testSeasonsPluralMany() {
        XCTAssertEqual(RussianPlural.seasons(5), "5 сезонов")
        XCTAssertEqual(RussianPlural.seasons(11), "11 сезонов")
    }
    
    // MARK: - Edge Cases
    
    func testZeroValues() {
        XCTAssertEqual(RussianPlural.episodes(0), "0 серий")
        XCTAssertEqual(RussianPlural.movies(0), "0 фильмов")
        XCTAssertEqual(RussianPlural.series(0), "0 сериалов")
    }
    
    func testLargeNumbers() {
        XCTAssertEqual(RussianPlural.episodes(1001), "1001 серия")
        XCTAssertEqual(RussianPlural.movies(2022), "2022 фильма")
        XCTAssertEqual(RussianPlural.series(3005), "3005 сериалов")
    }
}
