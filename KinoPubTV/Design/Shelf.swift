//
//  Shelf.swift
//  KinoPubTV
//

import SwiftUI

/// A titled horizontal row. Clipping is disabled so focused tiles can lift past the row bounds,
/// and the row is its own focus section so moving down from any tile lands in the next row.
struct Shelf<Content: View>: View {
  var title: String?
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      if let title {
        Text(title)
          .font(.headline)
          .foregroundStyle(.secondary)
      }
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: TVMetrics.itemSpacing) {
          content()
        }
        .padding(.vertical, 20)
      }
      .scrollClipDisabled()
      .scrollIndicators(.hidden)
    }
    .focusSection()
  }
}

/// A vertically scrolling grid of poster lockups.
struct PosterGrid<Item: Identifiable, Cell: View>: View {
  let items: [Item]
  var columns = TVMetrics.posterColumns
  var onAppearLast: (() -> Void)?
  @ViewBuilder var cell: (Item) -> Cell

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TVMetrics.itemSpacing, alignment: .top),
                             count: columns),
              spacing: TVMetrics.shelfSpacing) {
      ForEach(items) { item in
        cell(item)
          .onAppear {
            if item.id == items.last?.id { onAppearLast?() }
          }
      }
    }
  }
}

/// Centered loading / empty / error states.
struct StatusView: View {
  let systemImage: String
  let title: String
  var message: String?

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
    } description: {
      if let message { Text(message) }
    }
  }
}
