//
//  TVWatchingView.swift
//  KinoPubTV
//
//  "Я смотрю" as one TV page instead of segmented tabs: a row of shows with new episodes (every
//  series type — the old screen showed plain serials only), a row of movies you haven't finished
//  (previously unreachable on TV), then a grid of every show you follow. Reloads after each return
//  so it reflects what you just watched.
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
  @FocusState private var focus: String?
  @State private var lastFocused: String?
  @State private var refreshTask: Task<Void, Never>?

  /// A nil list failed to load and stays as it was.
  private struct Lists {
    var newEpisodes: [WatchingSerial]?
    var movies: [WatchingSerial]?
    var following: [WatchingSerial]?
  }

  private var isEmpty: Bool { newEpisodes.isEmpty && movies.isEmpty && following.isEmpty }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        Text("Watching".localized).font(.title2.bold())

        if !loaded {
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if isEmpty {
          VStack(spacing: 40) {
            StatusView(systemImage: "play.tv", title: "Nothing here yet".localized)
            // Something focusable: with no focus at all, «menu» quits the app.
            Button("Refresh".localized, systemImage: "arrow.clockwise") { startRefresh() }
              .fixedSize()
              .focused($focus, equals: "refresh")
          }
          .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          if !newEpisodes.isEmpty {
            Shelf(title: "New episodes".localized) {
              ForEach(newEpisodes) { tile($0, row: "new").tileWidth(TVMetrics.posterColumns) }
            }
          }
          if !movies.isEmpty {
            Shelf(title: "Unfinished movies".localized) {
              ForEach(movies) { tile($0, row: "movie").tileWidth(TVMetrics.posterColumns) }
            }
          }
          if !following.isEmpty {
            VStack(alignment: .leading, spacing: 24) {
              Text("My series".localized).font(.headline).foregroundStyle(.secondary)
              PosterGrid(items: following) { tile($0, row: "follow", showsProgress: true) }
            }
            .focusSection()
          }
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
    .task {
      if let lists = await fetch() { apply(lists) }
      loaded = true
    }
    .refreshWhenOnTop(true) { startRefresh() }
    .onChange(of: focus) { _, now in
      if let now { lastFocused = now }
    }
    .onChange(of: isEmpty) { _, empty in
      if empty, loaded {
        DispatchQueue.main.async { focus = "refresh" }
      } else if !empty, lastFocused == "refresh",
                let first = focusIds(newEpisodes: newEpisodes, movies: movies, following: following).first {
        DispatchQueue.main.async { focus = first }
      }
    }
  }

  private func tile(_ serial: WatchingSerial, row: String, showsProgress: Bool = false) -> some View {
    WatchingTile(serial: serial, showsProgress: showsProgress)
      .focused($focus, equals: "\(row)-\(serial.id)")
  }

  private func startRefresh() {
    refreshTask?.cancel()
    refreshTask = Task {
      await refreshWithFocus(load: fetch, handoff: handoff, apply: apply)
    }
  }

  /// Fetches all three lists in parallel. The page shows an error only if nothing loaded on the first visit.
  private func fetch() async -> Lists? {
    let service = appContext.contentService
    async let newData = try? service.fetchWatchingSerials(subscribed: 0, type: nil)
    async let movieData = try? service.fetchWatchingMovies()
    async let followingData = try? service.fetchWatchingSerials(subscribed: 1, type: nil)
    let (n, m, f) = await (newData, movieData, followingData)
    if n == nil && m == nil && f == nil {
      if !loaded { errorHandler.setError(URLError(.cannotLoadFromNetwork)) }
      return nil
    }
    return Lists(newEpisodes: n.map { $0.items.filter { ($0.new ?? 0) > 0 } }, movies: m?.items, following: f?.items)
  }

  private func apply(_ lists: Lists) {
    if let list = lists.newEpisodes { newEpisodes = list }
    if let list = lists.movies { movies = list }
    if let list = lists.following { following = list }
  }

  private func focusIds(newEpisodes: [WatchingSerial], movies: [WatchingSerial],
                        following: [WatchingSerial]) -> [String] {
    newEpisodes.map { "new-\($0.id)" } + movies.map { "movie-\($0.id)" } + following.map { "follow-\($0.id)" }
  }

  /// A focused card that leaves hands focus to the nearest card that stays, in page order.
  private func handoff(_ fresh: Lists) -> Bool {
    guard let last = lastFocused, last != "refresh" else { return false }
    let kept = Set(focusIds(newEpisodes: fresh.newEpisodes ?? newEpisodes, movies: fresh.movies ?? movies,
                            following: fresh.following ?? following))
    guard !kept.contains(last) else { return false }
    let shown = focusIds(newEpisodes: newEpisodes, movies: movies, following: following)
    guard let next = FocusNeighbor.neighbor(of: last, in: shown, kept: kept.contains) else { return false }
    focus = next
    return true
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
