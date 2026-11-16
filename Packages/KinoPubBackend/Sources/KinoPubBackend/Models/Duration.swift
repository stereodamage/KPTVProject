//
//  Duration.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Duration: Codable, Hashable {
  public let average: Double
  public let total: TimeInterval
}

public extension Duration {
  var totalFormatted: String { Self.formatted(total) }

  static func formatted(_ seconds: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    #if os(iOS) || os(tvOS)
    formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
    #endif
    formatter.unitsStyle = .positional
    return formatter.string(from: seconds) ?? ""
  }
}
