//
//  HTMLText.swift
//  KinoPubBackend
//
//  Third-party text (Kinopoisk facts/reviews via the kpapi proxy) arrives with HTML entities and
//  the odd tag, e.g. `&#171;Гарри Поттер&#187;` or `<a href="…">Имя</a>`. This turns it into plain
//  display text without NSAttributedString's HTML importer (main-thread only, slow, UIKit-bound).
//

import Foundation

public extension String {
  /// Plain text: tags removed (`<br>`/`<p>` become line breaks), entities decoded, spacing tidied.
  var htmlToPlainText: String {
    guard contains("<") || contains("&") else { return self }
    var text = replacingOccurrences(of: #"<\s*(br|/p)\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
    text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    text = text.decodingHTMLEntities
    text = text.replacingOccurrences(of: #"[ \t\u{00A0}]{2,}"#, with: " ", options: .regularExpression)
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Decodes numeric (`&#171;`, `&#xAB;`) and common named (`&laquo;`, `&amp;`) entities.
  /// Unknown entities are left as-is.
  var decodingHTMLEntities: String {
    guard contains("&") else { return self }
    var result = ""
    result.reserveCapacity(count)
    var rest = self[...]
    while let amp = rest.firstIndex(of: "&") {
      result += rest[..<amp]
      let afterAmp = rest.index(after: amp)
      // Entities are short; don't scan arbitrarily far for a ';'.
      guard let semi = rest[afterAmp...].prefix(12).firstIndex(of: ";"),
            let decoded = Self.decodeEntity(rest[afterAmp..<semi]) else {
        result.append("&")
        rest = rest[afterAmp...]
        continue
      }
      result += decoded
      rest = rest[rest.index(after: semi)...]
    }
    result += rest
    return result
  }

  private static func decodeEntity(_ body: Substring) -> String? {
    if body.hasPrefix("#") {
      let digits = body.dropFirst()
      let value: UInt32?
      if digits.hasPrefix("x") || digits.hasPrefix("X") {
        value = UInt32(digits.dropFirst(), radix: 16)
      } else {
        value = UInt32(digits)
      }
      return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }
    return namedEntities[String(body)]
  }

  private static let namedEntities: [String: String] = [
    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
    "laquo": "«", "raquo": "»", "bdquo": "„", "ldquo": "“", "rdquo": "”", "lsquo": "‘", "rsquo": "’",
    "mdash": "—", "ndash": "–", "hellip": "…", "middot": "·", "bull": "•", "deg": "°",
    "copy": "©", "reg": "®", "trade": "™", "times": "×", "shy": "",
  ]
}
