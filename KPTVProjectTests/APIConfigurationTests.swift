//
//  APIConfigurationTests.swift
//  KPTVProjectTests
//
//  Tests for API configuration
//

import XCTest
@testable import KPTVProject

final class APIConfigurationTests: XCTestCase {
    
    func testAPIKeysAreNotEmpty() {
        // API keys should be set (either from config or environment)
        XCTAssertFalse(APIConfiguration.kinoPubClientID.isEmpty, "KinoPub Client ID should not be empty")
        XCTAssertFalse(APIConfiguration.kinoPubClientSecret.isEmpty, "KinoPub Client Secret should not be empty")
        XCTAssertFalse(APIConfiguration.tmdbAPIKey.isEmpty, "TMDB API Key should not be empty")
    }
    
    func testAPIKeysDoNotContainPlaceholders() {
        // Ensure keys don't contain "YOUR_" placeholders
        XCTAssertFalse(APIConfiguration.kinoPubClientSecret.contains("YOUR_"), 
                      "KinoPub Client Secret should not contain placeholder text")
        XCTAssertFalse(APIConfiguration.tmdbAPIKey.contains("YOUR_"), 
                      "TMDB API Key should not contain placeholder text")
    }
    
    func testConfigurationStatus() {
        // Test configuration validation
        let isConfigured = APIConfiguration.isConfigured
        XCTAssertTrue(isConfigured, "API Configuration should be properly set up")
    }
}
