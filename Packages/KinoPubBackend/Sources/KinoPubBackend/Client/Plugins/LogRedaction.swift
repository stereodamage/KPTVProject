//
//  LogRedaction.swift
//  KinoPubBackend
//

import Foundation

enum LogRedaction {
  private static let names = "authorization|cookie|set-cookie|x-user|access_token|refresh_token|client_secret|code|token"

  private static let patterns: [NSRegularExpression] = [
    // Header lines: "Authorization: Bearer abc"
    "(?i)((?:\(names))\\s*:\\s*)[^'\\n\\\\]+",
    // Query / form values: "access_token=abc&"
    "(?i)(\\b(?:\(names))=)[^&\\s'\"]+",
    // JSON values: "access_token":"abc"
    "(?i)(\"(?:\(names))\"\\s*:\\s*\")[^\"]*",
  ].map { try! NSRegularExpression(pattern: $0) }

  static func redact(_ text: String) -> String {
    patterns.reduce(text) { result, regex in
      regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result),
                                     withTemplate: "$1<redacted>")
    }
  }
}
