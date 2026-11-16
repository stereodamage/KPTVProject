//
//  TVMetrics.swift
//  KinoPubTV
//
//  Layout constants for the 10-foot UI. Item widths come from `containerRelativeFrame(count:)` so a
//  row always shows a whole number of tiles across the 1920pt screen (Apple TV app proportions).
//

import SwiftUI

enum TVMetrics {
  /// Gap between tiles in a row/grid — wide enough for the focused tile's lift and shadow.
  static let itemSpacing: CGFloat = 40
  /// Vertical gap between shelves on a scrolling page.
  static let shelfSpacing: CGFloat = 60
  /// Portrait posters visible per row.
  static let posterColumns = 6
  /// 16:9 cards visible per row (Continue Watching, episodes).
  static let wideColumns = 4
  /// Big featured banners visible per row.
  static let featuredColumns = 2
  static let cornerRadius: CGFloat = 12
}

extension View {
  /// Sizes a tile to `count` per row of its enclosing scroll view / container.
  func tileWidth(_ count: Int) -> some View {
    containerRelativeFrame(.horizontal, count: count, spacing: TVMetrics.itemSpacing)
  }
}
