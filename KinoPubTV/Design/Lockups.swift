//
//  Lockups.swift
//  KinoPubTV
//
//  Focusable content tiles. All use the system `.borderless` button style with a `.highlight`
//  hover effect on the artwork: that is the native Apple TV lift — scale, shadow, specular shine and
//  remote-driven parallax — and the caption underneath stays readable.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

/// Portrait poster tile: artwork (with optional corner badge) and a title + secondary line.
struct PosterTile<Value: Hashable, Badge: View>: View {
  let imageURL: String?
  let title: String
  var subtitle: String?
  let value: Value
  @ViewBuilder var badge: () -> Badge

  var body: some View {
    NavigationLink(value: value) {
      VStack(alignment: .leading, spacing: 14) {
        Artwork(url: imageURL)
          .overlay(alignment: .topTrailing) { badge() }
          .hoverEffect(.highlight)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.caption)
            .lineLimit(1)
          if let subtitle {
            Text(subtitle)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
    }
    .buttonStyle(.borderless)
  }
}

/// A kino.pub title as a poster tile (opens its detail page by default).
struct PosterLockup: View {
  let item: MediaItem
  var value: Route

  init(item: MediaItem, value: Route? = nil) {
    self.item = item
    self.value = value ?? .details(item)
  }

  var body: some View {
    if item.skeleton ?? false {
      PlaceholderTile()
    } else {
      PosterTile(imageURL: item.posters.medium, title: item.localizedTitle, subtitle: item.yearAndRating,
                 value: value) {
        WatchStateBadge(itemId: item.id)
      }
    }
  }
}

/// Non-focusable stand-in while a row loads.
struct PlaceholderTile: View {
  var aspectRatio: CGFloat = 2.0 / 3.0

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      RoundedRectangle(cornerRadius: TVMetrics.cornerRadius, style: .continuous)
        .fill(Color.white.opacity(0.06))
        .aspectRatio(aspectRatio, contentMode: .fit)
      RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).frame(width: 160, height: 24)
    }
  }
}

/// Small count pill, e.g. "+3" new episodes.
struct CountBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2.bold())
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .background(Color.KinoPub.accent, in: Capsule())
      .foregroundStyle(.black)
      .padding(12)
  }
}

/// 16:9 card: artwork with an optional progress bar, then title and subtitle.
struct WideLockup<Value: Hashable>: View {
  let imageURL: String?
  let title: String
  var subtitle: String?
  var progress: Double?
  var watched = false
  /// Corner pill on the artwork, e.g. "4 серии" for a collapsed history entry.
  var badge: String?
  let value: Value

  var body: some View {
    NavigationLink(value: value) {
      VStack(alignment: .leading, spacing: 14) {
        Artwork(url: imageURL, aspectRatio: 16.0 / 9.0, placeholderSymbol: "play.rectangle")
          .overlay(alignment: .bottom) {
            if let progress, progress > 0, !watched {
              ProgressBar(value: progress).padding(16)
            }
          }
          .overlay(alignment: .topTrailing) {
            if watched {
              CheckBadge().padding(12)
            } else if let badge {
              CountBadge(text: badge)
            }
          }
          .hoverEffect(.highlight)
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.caption).lineLimit(1)
          if let subtitle {
            Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
          }
        }
      }
    }
    .buttonStyle(.borderless)
  }
}

/// Large featured banner with the title over a bottom scrim.
struct FeaturedLockup: View {
  let item: MediaItem

  var body: some View {
    NavigationLink(value: Route.details(item)) {
      Artwork(url: item.posters.wide ?? item.posters.big, aspectRatio: 16.0 / 9.0)
        .overlay(alignment: .bottomLeading) {
          VStack(alignment: .leading, spacing: 6) {
            Text(item.localizedTitle).font(.headline).lineLimit(1)
            Text(item.genreLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          }
          .padding(30)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: TVMetrics.cornerRadius, style: .continuous))
        .hoverEffect(.highlight)
    }
    .buttonStyle(.borderless)
  }
}

/// Trailing "See All" tile for a shelf, same footprint as the shelf's posters.
struct SeeAllLockup: View {
  let value: Route
  var aspectRatio: CGFloat = 2.0 / 3.0

  var body: some View {
    NavigationLink(value: value) {
      RoundedRectangle(cornerRadius: TVMetrics.cornerRadius, style: .continuous)
        .fill(Color.white.opacity(0.1))
        .aspectRatio(aspectRatio, contentMode: .fit)
        .overlay {
          VStack(spacing: 16) {
            Image(systemName: "chevron.right.circle").font(.system(size: 64))
            Text("See All".localized).font(.callout)
          }
          .foregroundStyle(.secondary)
        }
        .hoverEffect(.highlight)
    }
    .buttonStyle(.borderless)
  }
}

struct ProgressBar: View {
  let value: Double

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.3))
        Capsule().fill(.white).frame(width: geo.size.width * min(max(value, 0), 1))
      }
    }
    .frame(height: 8)
  }
}

struct CheckBadge: View {
  var body: some View {
    Image(systemName: "checkmark.circle.fill")
      .font(.system(size: 40))
      .symbolRenderingMode(.palette)
      .foregroundStyle(.black, .white)
  }
}

/// Watched check on a poster, from the shared library store (server flag + optimistic overrides).
struct WatchStateBadge: View {
  let itemId: Int
  @EnvironmentObject private var library: MediaLibraryStore

  var body: some View {
    if library.movieWatched(itemId: itemId, serverWatched: false) {
      CheckBadge().padding(12)
    }
  }
}

extension MediaItem {
  /// "2024 · IMDb 7.9" — the secondary line under a poster.
  var yearAndRating: String {
    var parts = [String(year)]
    if let rating = preferredRating {
      parts.append("\(rating.source) " + String(format: "%.1f", rating.value))
    }
    return parts.joined(separator: " · ")
  }

  var genreLine: String {
    genres.compactMap(\.title).prefix(3).joined(separator: " · ")
  }
}
