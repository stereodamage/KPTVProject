//
//  LogRedactionTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class LogRedactionTests: XCTestCase {
  func testHeadersAreRedacted() {
    let curl = "curl --header 'Authorization: Bearer abc.def' \\\n--header 'Accept: application/json' \\\n"
    let out = LogRedaction.redact(curl)
    XCTAssertFalse(out.contains("abc.def"))
    XCTAssertTrue(out.contains("Authorization: <redacted>"))
    XCTAssertTrue(out.contains("Accept: application/json"))
  }

  func testQueryAndFormValuesAreRedacted() {
    let out = LogRedaction.redact("https://x/oauth2/token?grant_type=refresh_token&refresh_token=R1&client_secret=S1&id=5")
    XCTAssertFalse(out.contains("R1"))
    XCTAssertFalse(out.contains("S1"))
    XCTAssertTrue(out.contains("grant_type=refresh_token"))
    XCTAssertTrue(out.contains("id=5"))
  }

  func testJSONTokensAreRedacted() {
    let out = LogRedaction.redact(#"{"access_token":"A1","refresh_token":"R1","expires_in":3600}"#)
    XCTAssertEqual(out, #"{"access_token":"<redacted>","refresh_token":"<redacted>","expires_in":3600}"#)
  }

  func testPlainBodiesUntouched() {
    let body = #"{"item":{"id":96,"title":"Гарри Поттер"}}"#
    XCTAssertEqual(LogRedaction.redact(body), body)
  }
}
