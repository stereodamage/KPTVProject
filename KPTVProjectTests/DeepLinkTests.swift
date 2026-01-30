//
//  DeepLinkTests.swift
//  KPTVProjectTests
//
//  Tests for deep link URL handling (kptv://item/{id})
//

import XCTest
@testable import KPTVProject

final class DeepLinkTests: XCTestCase {
    
    // MARK: - URL Parsing Tests
    
    func testValidItemDeepLink() {
        // Given a valid deep link URL
        let url = URL(string: "kptv://item/12345")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should extract the item ID correctly
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "item")
        XCTAssertEqual(result?.itemID, 12345)
    }
    
    func testDeepLinkWithLeadingZeros() {
        // Given a deep link with leading zeros in ID
        let url = URL(string: "kptv://item/00789")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should parse correctly
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.itemID, 789)
    }
    
    func testInvalidScheme() {
        // Given a URL with wrong scheme
        let url = URL(string: "https://item/12345")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should return nil
        XCTAssertNil(result)
    }
    
    func testInvalidHost() {
        // Given a URL with wrong host
        let url = URL(string: "kptv://unknown/12345")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should return nil
        XCTAssertNil(result)
    }
    
    func testMissingItemID() {
        // Given a URL without item ID
        let url = URL(string: "kptv://item/")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should return nil
        XCTAssertNil(result)
    }
    
    func testNonNumericItemID() {
        // Given a URL with non-numeric item ID
        let url = URL(string: "kptv://item/abc")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should return nil
        XCTAssertNil(result)
    }
    
    func testItemIDWithTrailingSlash() {
        // Given a URL with trailing slash
        let url = URL(string: "kptv://item/12345/")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should still parse correctly
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.itemID, 12345)
    }
    
    func testLargeItemID() {
        // Given a URL with a large item ID
        let url = URL(string: "kptv://item/999999999")!
        
        // When parsing the URL
        let result = parseDeepLink(url)
        
        // Then it should parse correctly
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.itemID, 999999999)
    }
    
    // MARK: - Helper
    
    /// Parsed deep link result
    struct DeepLinkResult {
        let host: String
        let itemID: Int
    }
    
    /// Parses a deep link URL and extracts the item ID
    /// This mirrors the logic in KPTVProjectApp.swift handleDeepLink()
    private func parseDeepLink(_ url: URL) -> DeepLinkResult? {
        // Check scheme
        guard url.scheme == "kptv" else {
            return nil
        }
        
        // Check host
        guard url.host == "item" else {
            return nil
        }
        
        // Extract item ID from path
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let itemIDString = pathComponents.first,
              let itemID = Int(itemIDString) else {
            return nil
        }
        
        return DeepLinkResult(host: url.host!, itemID: itemID)
    }
}
