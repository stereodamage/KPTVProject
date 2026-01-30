//
//  ModelTests.swift
//  KPTVProjectTests
//
//  Tests for data models
//

import XCTest
@testable import KPTVProject

final class ModelTests: XCTestCase {
    
    // MARK: - Item Tests
    
    func testItemDisplayTitle() {
        // Test that display title extracts properly from "Russian / English" format
        let item = Item(
            id: 1,
            title: "Тестовый фильм / Test Movie",
            type: "movie",
            subtype: nil,
            year: 2024,
            cast: nil,
            director: nil,
            voice: nil,
            duration: nil,
            langs: nil,
            ac3: nil,
            subtitles: nil,
            quality: nil,
            genres: nil,
            countries: nil,
            plot: "Test plot",
            imdb: nil,
            imdbRating: nil,
            imdbVotes: nil,
            kinopoisk: nil,
            kinopoiskRating: nil,
            kinopoiskVotes: nil,
            rating: nil,
            ratingPercentage: nil,
            ratingVotes: nil,
            views: nil,
            comments: nil,
            finished: nil,
            advert: nil,
            inWatchlist: nil,
            subscribed: nil,
            posters: nil,
            trailer: nil,
            seasons: nil,
            videos: nil,
            createdAt: nil,
            updatedAt: nil,
            poorQuality: nil,
            new: nil
        )
        
        XCTAssertEqual(item.displayTitle, "Тестовый фильм")
    }
    
    func testItemDisplayTitleFallback() {
        // Test fallback when there's no Russian title
        let item = Item(
            id: 1,
            title: "English Only Title",
            type: "movie",
            subtype: nil,
            year: 2024,
            cast: nil,
            director: nil,
            voice: nil,
            duration: nil,
            langs: nil,
            ac3: nil,
            subtitles: nil,
            quality: nil,
            genres: nil,
            countries: nil,
            plot: nil,
            imdb: nil,
            imdbRating: nil,
            imdbVotes: nil,
            kinopoisk: nil,
            kinopoiskRating: nil,
            kinopoiskVotes: nil,
            rating: nil,
            ratingPercentage: nil,
            ratingVotes: nil,
            views: nil,
            comments: nil,
            finished: nil,
            advert: nil,
            inWatchlist: nil,
            subscribed: nil,
            posters: nil,
            trailer: nil,
            seasons: nil,
            videos: nil,
            createdAt: nil,
            updatedAt: nil,
            poorQuality: nil,
            new: nil
        )
        
        XCTAssertEqual(item.displayTitle, "English Only Title")
    }
    
    // MARK: - Season Tests
    
    func testSeasonDisplayTitle() {
        let season = Season(
            id: 1,
            number: 1,
            title: "Season 1",
            episodes: [],
            watching: nil
        )
        
        XCTAssertEqual(season.displayTitle, "Season 1")
    }
    
    func testSeasonDisplayTitleFallback() {
        let season = Season(
            id: 2,
            number: 2,
            title: nil,
            episodes: [],
            watching: nil
        )
        
        XCTAssertEqual(season.displayTitle, "Сезон 2")
    }
    
    // MARK: - Episode Tests
    
    func testEpisodeDisplayTitle() {
        let episode = Episode(
            id: 1,
            number: 1,
            title: "Пилот / Pilot",
            thumbnail: nil,
            duration: 3600,
            watched: nil,
            watching: nil,
            files: nil,
            audios: nil,
            subtitles: nil,
            seasonNumber: 1
        )
        
        XCTAssertEqual(episode.displayTitle, "Пилот")
    }
    
    func testEpisodeDisplayTitleFallback() {
        let episode = Episode(
            id: 2,
            number: 2,
            title: nil,
            thumbnail: nil,
            duration: 3600,
            watched: nil,
            watching: nil,
            files: nil,
            audios: nil,
            subtitles: nil,
            seasonNumber: 1
        )
        
        XCTAssertEqual(episode.displayTitle, "Серия 2")
    }
    
    // MARK: - URL Tests
    
    func testSecureURLConversion() {
        // Test that http URLs are converted to https
        let httpURL = URL.secure(string: "http://example.com/image.jpg")
        XCTAssertEqual(httpURL?.scheme, "https")
        
        let httpsURL = URL.secure(string: "https://example.com/image.jpg")
        XCTAssertEqual(httpsURL?.scheme, "https")
        
        let invalidURL = URL.secure(string: "")
        XCTAssertNil(invalidURL)
    }
}
