//
//  TVDetailView.swift
//  KinoPubTV
//
//  Apple TV-style product page: full-bleed backdrop, title block and action row on the first screen;
//  seasons/episodes, cast and related shelves further down.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct TVDetailView: View {
  @StateObject private var model: MediaItemModel
  @EnvironmentObject private var library: MediaLibraryStore
  @State private var showVersions = false
  @State private var chosenVersion: FilmVersion?
  @State private var pickedVersion: FilmVersion?
  @State private var creatingFolder = false
  @State private var newFolderName = ""
  @FocusState private var focus: DetailFocus?

  private enum DetailFocus { case play, bookmarks }

  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _model = StateObject(wrappedValue: model())
  }

  private var item: MediaItem { model.mediaItem }

  var body: some View {
    ZStack(alignment: .topLeading) {
      Backdrop(url: model.itemLoaded ? (item.posters.wide ?? item.posters.big) : nil)

      ScrollView {
        VStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
          header
            .frame(minHeight: 860, alignment: .bottomLeading)

          if item.isSeries, let seasons = item.seasons, !seasons.isEmpty {
            TVEpisodesSection(model: model, seasons: seasons)
          }

          castShelf
          relatedShelf("Similar".localized, model.relatedItems)
          if let director = model.primaryDirector {
            relatedShelf("More from %@".localized.replacingOccurrences(of: "%@", with: director), model.moreFromDirector)
          }
          if let actor = model.primaryActor {
            relatedShelf("More with %@".localized.replacingOccurrences(of: "%@", with: actor), model.moreWithActor)
          }
          factsSection
        }
        .padding(.bottom, 80)
      }
      .scrollClipDisabled()
      // Focus that enters from outside (e.g. back from the sidebar) lands on the bookmarks button, not on
      // Play: one stray select there only opens a menu. The first focus is set to Play below.
      .defaultFocus($focus, .bookmarks, priority: .userInitiated)
    }
    .toolbar(.hidden, for: .navigationBar)
    // Push the player only after the sheet is gone: presenting it during the dismissal fails.
    .sheet(isPresented: $showVersions, onDismiss: {
      chosenVersion = pickedVersion
      if pickedVersion == nil { focus = .play }
      pickedVersion = nil
    }) {
      TVVersionPicker(videos: item.videos ?? []) { video in
        pickedVersion = FilmVersion(item: item, video: video)
        showVersions = false
      }
    }
    .navigationDestination(item: $chosenVersion) { TVRouteDestination(route: .player($0)) }
    .task {
      if !model.itemLoaded { model.fetchData() }
    }
    // The store records no progress for titles it has no snapshot of.
    .onChange(of: model.itemLoaded, initial: true) { _, loaded in
      guard loaded else { return }
      AppContext.shared.localProgressStore.cacheItem(model.mediaItem)
      DispatchQueue.main.async { focus = .play }
    }
    .onAppear { model.refreshOnReappear() }
  }

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 26) {
      Text(item.localizedTitle)
        .font(.title.bold())
        .lineLimit(2)
        // Without it the title got one line's height and ended in «…» (sim-measured: 91 pt, x ≤ 1230).
        .fixedSize(horizontal: false, vertical: true)
        .redacted(reason: model.itemLoaded ? [] : .placeholder)
      if item.originalTitle != item.localizedTitle, !item.originalTitle.isEmpty {
        Text(item.originalTitle).font(.headline).foregroundStyle(.secondary)
      }
      metaLine
      ratingsLine
      if !item.plot.isEmpty {
        Text(item.plot)
          .font(.callout)
          .lineLimit(4)
          .foregroundStyle(.secondary)
      }
      actions.padding(.top, 10)
    }
    .frame(maxWidth: 1150, alignment: .leading)
  }

  private var metaLine: some View {
    var parts: [String] = []
    if item.year > 0 { parts.append(String(item.year)) }
    parts.append(contentsOf: item.genres.compactMap(\.title).prefix(3))
    if let country = item.countries.first?.title { parts.append(country) }
    if !item.isSeries {
      // For several versions, `duration.total` is their sum; show the version that Play starts.
      let runtime = item.isMultiVersion
        ? Duration.formatted(TimeInterval(item.primaryVideo(local: model.localFilmResume)?.duration ?? 0))
        : item.duration.totalFormatted
      if !runtime.isEmpty { parts.append(runtime) }
    }
    return HStack(spacing: 16) {
      Text(parts.joined(separator: " · "))
      if item.quality >= 2160 { TagPill(text: "4K") } else if item.quality >= 1080 { TagPill(text: "HD") }
      if (item.ac3 ?? 0) > 0 { TagPill(text: "5.1") }
    }
    .font(.callout)
    .foregroundStyle(.secondary)
  }

  @ViewBuilder
  private var ratingsLine: some View {
    if let rating = item.preferredRating {
      RatingLabel(source: rating.source, value: rating.value)
    }
  }

  // MARK: - Actions

  private var actions: some View {
    // Bottom-aligned: centred, "down" from Bookmarks on a film went right to Like instead of to the cast row.
    HStack(alignment: .bottom, spacing: 30) {
      playButton
        .focused($focus, equals: .play)
      if item.trailer != nil {
        NavigationLink(value: Route.trailerPlayer(item)) {
          Label("Trailer".localized, systemImage: "film")
        }
      }
      Button { model.toggleWatchlist() } label: {
        Label(inWatchlist ? "In Watchlist".localized : "Watchlist".localized,
              systemImage: inWatchlist ? "checkmark" : "plus")
      }
      .labelStyle(.iconOnly)
      if !item.isSeries {
        Button { model.toggleWatched() } label: {
          Label("Watched".localized, systemImage: model.isMovieWatched ? "eye.fill" : "eye")
        }
        .labelStyle(.iconOnly)
      }
      bookmarksMenu
        .focused($focus, equals: .bookmarks)
      Button { model.vote(up: true) } label: {
        Label("Like".localized, systemImage: model.myVote == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
      }
      .labelStyle(.iconOnly)
      Button { model.vote(up: false) } label: {
        Label("Dislike".localized, systemImage: model.myVote == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
      }
      .labelStyle(.iconOnly)
    }
    .buttonBorderShape(.capsule)
    // Without it SwiftUI wraps the Play label one syllable per line in tight Russian rows.
    .fixedSize()
    .disabled(!model.itemLoaded)
    // Only the button row is a focus section: the tall header no longer pulls focus up from lower rows.
    .focusSection()
  }

  private var inWatchlist: Bool {
    library.inWatchlist(itemId: item.id) ?? (item.inWatchlist == true)
  }

  @ViewBuilder
  private var playButton: some View {
    let target = playTarget
    if item.isMultiVersion {
      Button { showVersions = true } label: { playLabel(target) }
    } else {
      NavigationLink(value: target.route) { playLabel(target) }
    }
  }

  private func playLabel(_ target: (route: Route, title: String, subtitle: String?)) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(target.title, systemImage: "play.fill").font(.headline)
      if let subtitle = target.subtitle {
        Text(subtitle).font(.caption2).foregroundStyle(.secondary)
      }
    }
    .lineLimit(1)
    .padding(.horizontal, 12)
  }

  private var bookmarksMenu: some View {
    Menu {
      Button("New folder…".localized, systemImage: "folder.badge.plus") {
        newFolderName = ""
        creatingFolder = true
      }
      ForEach(library.bookmarkFolders, id: \.id) { folder in
        Button {
          model.toggleBookmark(folderId: folder.id, folderTitle: folder.title)
        } label: {
          if library.isBookmarked(itemId: item.id, folderId: folder.id) {
            Label(folder.title, systemImage: "checkmark")
          } else {
            Text(folder.title)
          }
        }
      }
    } label: {
      Label("Bookmarks".localized,
            systemImage: library.isInAnyBookmarkFolder(itemId: item.id) ? "bookmark.fill" : "bookmark")
    }
    .labelStyle(.iconOnly)
    .task { model.loadBookmarkFolders() }
    .onChange(of: creatingFolder) { _, open in
      // An alert hands focus back to the screen's default (Play); return it to the menu that opened it.
      if !open { DispatchQueue.main.async { focus = .bookmarks } }
    }
    .alert("New folder".localized, isPresented: $creatingFolder) {
      TextField("Folder name".localized, text: $newFolderName)
      Button("Create".localized) { model.createFolderAndAdd(named: newFolderName) }
      Button("Cancel".localized, role: .cancel) {}
    }
  }

  /// What the main button plays: the series' continue/first episode, or the movie.
  private var playTarget: (route: Route, title: String, subtitle: String?) {
    if item.isSeries {
      if let target = item.continueEpisode() ?? model.localSeriesContinue() {
        let episode = model.fill(target.episode, in: target.season)
        let time = max(target.episode.watching.time,
                       model.localResumeSeconds(season: target.season.number, episode: target.episode.number))
        var subtitle = "S\(target.season.number) · E\(target.episode.number)"
        if time > 0 { subtitle += " · " + Self.timeString(time) }
        return (.player(episode), "Continue".localized, subtitle)
      }
      if let season = item.seasons?.first, let first = season.episodes.first {
        return (.player(model.fill(first, in: season)), "Play".localized, "S\(season.number) · E\(first.number)")
      }
    }
    guard let primary = item.primaryVideo(local: model.localFilmResume) else {
      return (.player(item), "Play".localized, nil)
    }
    let time = max(primary.watching.time, model.localResumeSeconds(season: nil, episode: primary.number))
    var subtitle = time > 0 ? Self.timeString(time) : nil
    if item.isMultiVersion { subtitle = [FilmVersions.rowTitle(primary), subtitle].compactMap { $0 }.joined(separator: " · ") }
    return (.player(FilmVersion(item: item, video: primary)), (time > 0 ? "Continue" : "Play").localized, subtitle)
  }

  static func timeString(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
  }

  // MARK: - Shelves

  @ViewBuilder
  private var castShelf: some View {
    // Shown only once the extras settled, from one source, so the row never swaps cards under focus.
    if model.extrasLoaded {
      let groups = creditGroups
      if !groups.isEmpty {
        Shelf(title: "Cast & Crew".localized) {
          ForEach(Credits.row(groups, directorRole: "Director".localized)) { PersonLockup(person: $0) }
          PeopleSeeAllLockup(value: .credits(item.localizedTitle, groups))
        }
      }
    }
  }

  private var creditGroups: [CreditGroup] {
    if !model.staff.isEmpty { return Credits.groups(staff: model.staff) }
    return Credits.groups(directors: model.directorNames, cast: model.castNames,
                          photo: ActorImageProvider.photoURLString(for:))
  }

  @ViewBuilder
  private func relatedShelf(_ title: String, _ items: [MediaItem]) -> some View {
    let items = items.filter { $0.id != item.id }
    if !items.isEmpty {
      Shelf(title: title) {
        ForEach(items) { PosterLockup(item: $0).tileWidth(TVMetrics.posterColumns) }
      }
    }
  }

  @ViewBuilder
  private var factsSection: some View {
    let facts = model.facts.filter { !($0.spoiler ?? false) }.prefix(12)
    if !facts.isEmpty {
      Shelf(title: "Did you know?".localized) {
        ForEach(Array(facts)) { fact in
          FactCard(text: fact.text).frame(width: 640)
        }
      }
    }
  }
}

// MARK: - Episodes

/// Season chips (moving focus onto a chip switches the season, like the Apple TV app) and the
/// season's episodes as 16:9 cards with progress / watched state.
private struct TVEpisodesSection: View {
  @ObservedObject var model: MediaItemModel
  let seasons: [Season]
  @State private var selected = 0
  @FocusState private var focusedSeason: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 30) {
      if seasons.count > 1 {
        ScrollView(.horizontal) {
          HStack(spacing: 20) {
            ForEach(seasons.indices, id: \.self) { index in
              Button { selected = index } label: {
                Text(seasons[index].fixedTitle)
                  .fontWeight(index == selected ? .bold : .regular)
                  .foregroundStyle(index == selected ? .primary : .secondary)
              }
                .buttonStyle(.bordered)
                .focused($focusedSeason, equals: index)
            }
          }
          .padding(.vertical, 16)
        }
        .scrollClipDisabled()
        .focusSection()
        .onChange(of: focusedSeason) { _, value in
          if let value { selected = value }
        }
      }

      let season = seasons[min(selected, seasons.count - 1)]
      Shelf(title: seasons.count > 1 ? nil : "Episodes".localized) {
        ForEach(season.episodes, id: \.id) { episode in
          WideLockup(imageURL: episode.thumbnail,
                     title: "\(episode.number). \(episode.fixedTitle)",
                     subtitle: "\(max(episode.duration / 60, 1)) " + "min".localized,
                     progress: progress(episode, in: season),
                     watched: model.isEpisodeWatched(episode),
                     value: Route.player(model.fill(episode, in: season)))
          .tileWidth(TVMetrics.wideColumns)
        }
      }
      .id(season.id)
    }
    .onAppear {
      if let target = model.mediaItem.continueEpisode(),
         let index = seasons.firstIndex(where: { $0.number == target.season.number }) {
        selected = index
      }
    }
  }

  private func progress(_ episode: Episode, in season: Season) -> Double? {
    let server = episode.watching.time > 0 ? episode.watchProgress.fraction : nil
    let local = model.localProgressFraction(season: season.number, episode: episode.number)
    return [server, local].compactMap { $0 }.max()
  }
}

// MARK: - Pieces

private struct FactCard: View {
  let text: String
  @State private var showFull = false
  @FocusState private var focused: Bool

  var body: some View {
    Button { showFull = true } label: {
      Text(text)
        .font(.callout)
        .lineLimit(5)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .padding(30)
    }
    .buttonStyle(.card)
    .focused($focused)
    .sheet(isPresented: $showFull, onDismiss: { focused = true }) {
      ScrollView {
        Text(text)
          .font(.body)
          .frame(maxWidth: 1100, alignment: .leading)
          .padding(60)
      }
    }
  }
}

struct TagPill: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2.bold())
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary, lineWidth: 2))
  }
}

struct RatingLabel: View {
  let source: String
  let value: Double

  var body: some View {
    HStack(spacing: 10) {
      Text(source).foregroundStyle(.secondary)
      Text(String(format: "%.1f", value)).bold()
    }
    .font(.callout)
  }
}

/// Full-screen backdrop that dims toward the bottom-left, where the text sits.
private struct Backdrop: View {
  let url: String?

  var body: some View {
    GeometryReader { geo in
      CachedAsyncImage(url: url.flatMap(URL.init(string:))) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Color.clear
      }
      .frame(width: geo.size.width, height: geo.size.height)
      .clipped()
      .overlay {
        LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.4), .clear],
                       startPoint: .leading, endPoint: .trailing)
      }
      .overlay {
        LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .center, endPoint: .bottom)
      }
    }
    .background(Color.KinoPub.background)
    .ignoresSafeArea()
  }
}

extension MediaItemModel {
  /// Episode with its series context filled in (needed for marktime + the player title).
  func fill(_ episode: Episode, in season: Season) -> Episode {
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId ?? mediaItem.id
    episode.mediaTitle = mediaItem.localizedTitle
    return episode
  }
}
