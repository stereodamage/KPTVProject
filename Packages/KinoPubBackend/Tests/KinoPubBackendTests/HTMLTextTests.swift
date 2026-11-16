//
//  HTMLTextTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class HTMLTextTests: XCTestCase {
  func testNumericEntities() {
    XCTAssertEqual("романа &#171;Гарри Поттер&#187; (1997)".htmlToPlainText, "романа «Гарри Поттер» (1997)")
    XCTAssertEqual("&#xAB;x&#XBB;".decodingHTMLEntities, "«x»")
  }

  func testNamedEntities() {
    XCTAssertEqual("Tom &amp; Jerry &mdash; &laquo;OK&raquo;".decodingHTMLEntities, "Tom & Jerry — «OK»")
  }

  func testUnknownOrBrokenEntitiesAreKept() {
    XCTAssertEqual("A & B".decodingHTMLEntities, "A & B")
    XCTAssertEqual("&bogus; &#; &#99999999;".decodingHTMLEntities, "&bogus; &#; &#99999999;")
    XCTAssertEqual("trailing &".decodingHTMLEntities, "trailing &")
  }

  func testTagsStrippedAndBreaksKept() {
    XCTAssertEqual(#"Играет <a href="/name/1/">Дэниел Рэдклифф</a>.<br>Ещё"#.htmlToPlainText,
                   "Играет Дэниел Рэдклифф.\nЕщё")
  }

  func testDecodingFactFromJSON() throws {
    let json = Data(#"{"text":"&#171;Камень&#187;","type":"FACT","spoiler":false}"#.utf8)
    let fact = try JSONDecoder().decode(KpFact.self, from: json)
    XCTAssertEqual(fact.text, "«Камень»")
    XCTAssertFalse(fact.isBlooper)
  }

  func testPlainTextUntouched() {
    XCTAssertEqual("Обычный текст".htmlToPlainText, "Обычный текст")
  }
}
