//
//  TVWatchingView.swift
//  KinoPubTV
//
//  "Я смотрю" as one TV page instead of segmented tabs: a row of shows with new episodes (every
//  series type — the old screen showed plain serials only), a row of movies you haven't finished
//  (previously unreachable on TV), then a grid of every show you follow. Reloads on each visit so
//  it reflects what you just watched.
//

import SwiftUI
import KinoPubBackend

struct TVWatchingView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var errorHandler: ErrorHandler

  @State private var newEpisodes: [WatchingSerial] = []
  @State private var movies: [WatchingSerial] = []
  @State private var following: [WatchingSerial] = []
  @State private var loaded = false

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        Text("Watching".localized).font(.title2.bold())

        if !loaded {
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if newEpisodes.isEmpty && movies.isEmpty && following.isEmpty {
          StatusView(systemImage: "play.tv", title: "Nothing here yet".localized)
            .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          if !newEpisodes.isEmpty {
            Shelf(title: "New episodes".localized) {
              ForEach(newEpisodes) { WatchingTile(serial: $0).tileWidth(TVMetrics.posterColumns) }
            }
          }
          if !movies.isEmpty {
            Shelf(title: "Unfinished movies".localized) {
              ForEach(movies) { WatchingTile(serial: $0).tileWidth(TVMetrics.posterColumns) }
            }
          }
          if !following.isEmpty {
            VStack(alignment: .leading, spacing: 24) {
              Text("My series".localized).font(.headline).foregroundStyle(.secondary)
              PosterGrid(items: following) { WatchingTile(serial: $0, showsProgress: true) }
            }
            .focusSection()
          }
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
    .task { await load() }
  }

  /// Fetches all three lists in parallel. A failed list just stays as it was; the page only shows
  /// an error if nothing loaded at all on the first visit.
  private func load() async {
    let service = appContext.contentService
    async let newData = try? service.fetchWatchingSerials(subscribed: 0, type: nil)
    async let movieData = try? service.fetchWatchingMovies()
    async let followingData = try? service.fetchWatchingSerials(subscribed: 1, type: nil)
    let (n, m, f) = await (newData, movieData, followingData)

    if let n { newEpisodes = n.items.filter { ($0.new ?? 0) > 0 } }
    if let m { movies = m.items }
    if let f { following = f.items }
    if n == nil && m == nil && f == nil && !loaded {
      errorHandler.setError(URLError(.cannotLoadFromNetwork))
    }
    loaded = true
  }
}

/// Poster for a watching-list entry: "+N" new-episode badge, optionally "12 / 20" watched.
private struct WatchingTile: View {
  let serial: WatchingSerial
  var showsProgress = false

  var body: some View {
    PosterTile(imageURL: serial.posters.medium,
               title: serial.localizedTitle,
               subtitle: subtitle,
               value: Route.detailsByID(serial.id)) {
      if let new = serial.new, new > 0 { CountBadge(text: "+\(new)") }
    }
  }

  private var subtitle: String? {
    if showsProgress, let total = serial.total, total > 0 {
      return "\(serial.watched ?? 0) / \(total)"
    }
    return serial.originalTitle == serial.localizedTitle ? nil : serial.originalTitle
  }
}
