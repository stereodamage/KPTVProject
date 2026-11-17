//
//  TVHistoryView.swift
//  KinoPubTV
//
//  Watch history, newest first: a day heading over a 4-up grid of 16:9 cards. A show's episodes
//  from one day fold into one card (latest episode + an "N серий" badge), so a binge doesn't flood
//  the page. A type filter sits on top; long-press a card to remove the title from history.
//

import SwiftUI
import KinoPubBackend

struct TVHistoryView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVHistoryContent(model: HistoryModel(itemsService: appContext.contentService,
                                         authState: authState,
                                         errorHandler: errorHandler))
  }
}

private struct TVHistoryContent: View {
  @StateObject private var model: HistoryModel
  @State private var loadingMore = false
  @FocusState private var focus: HistoryFocus?
  @State private var lastFocused: HistoryFocus?
  @State private var refreshTask: Task<Void, Never>?

  init(model: @autoclosure @escaping () -> HistoryModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        Text("History".localized).font(.title2.bold())

        if model.availableTypes.count > 1 {
          Picker("", selection: $model.selectedType) {
            Text("All".localized).tag(MediaType?.none)
            ForEach(model.availableTypes) { Text($0.title.localized).tag(MediaType?.some($0)) }
          }
          .pickerStyle(.segmented)
          .fixedSize()
          .focused($focus, equals: .filter)
          .focusSection()
        }

        if model.isLoadingSkeleton {
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if model.historyItems.isEmpty {
          VStack(spacing: 40) {
            StatusView(systemImage: "clock.arrow.circlepath", title: "Nothing here yet".localized)
            // Something focusable: with no focus at all, «menu» quits the app.
            Button("Refresh".localized, systemImage: "arrow.clockwise") {
              Task { if let data = await model.fetchFirstPage() { model.applyFirstPage(data) } }
            }
            .fixedSize()
            .focused($focus, equals: .refresh)
          }
          .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          ForEach(model.groupedSections) { section in
            HistoryDayGrid(title: Self.dayTitle(section.day), day: section.day, entries: section.items,
                           focus: $focus, onAppear: loadMoreIfLast, onRemove: remove)
          }
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
    .refreshWhenOnTop(true) {
      refreshTask?.cancel()
      refreshTask = Task {
        await refreshWithFocus(load: model.fetchFirstPage, handoff: { fresh in
          handoff(keeping: Self.cardIds(model.historyItems.mergingFreshPage(fresh.history)))
        }, apply: model.applyFirstPage)
      }
    }
    .onChange(of: focus) { _, now in
      if let now { lastFocused = now }
    }
    .onChange(of: model.historyItems.isEmpty) { _, empty in
      if empty, !model.isLoadingSkeleton {
        DispatchQueue.main.async { focus = .refresh }
      } else if !empty, lastFocused == .refresh, let first = shownCards.first {
        DispatchQueue.main.async { focus = first }
      }
    }
  }

  /// The cards that `entries` make: one per title and day.
  private static func cardIds(_ entries: [HistoryItem]) -> Set<HistoryFocus> {
    let calendar = Calendar.current
    return Set(entries.map { entry in
      let day = calendar.startOfDay(for: Date(timeIntervalSince1970: entry.lastSeen ?? entry.time ?? 0))
      return HistoryFocus.card(day: day, item: entry.item.id)
    })
  }

  private var shownCards: [HistoryFocus] {
    model.groupedSections.flatMap { section in
      section.items.groupedByTitle().map { HistoryFocus.card(day: section.day, item: $0.latest.item.id) }
    }
  }

  /// Moves focus off a card that will leave, to the nearest card that stays. Returns true if it moved focus.
  private func handoff(keeping keep: Set<HistoryFocus>) -> Bool {
    guard let last = lastFocused, case .card = last, !keep.contains(last) else { return false }
    focus = FocusNeighbor.neighbor(of: last, in: shownCards, kept: keep.contains)
      ?? (model.availableTypes.count > 1 ? .filter : nil)
    return true
  }

  /// The card leaves at once, so focus moves to a neighbour first.
  private func remove(_ entry: HistoryItem) {
    let moved = handoff(keeping: Self.cardIds(model.historyItems.filter { $0.item.id != entry.item.id }))
    Task {
      if moved { try? await Task.sleep(for: .milliseconds(200)) }
      model.removeFromHistory(entry)
    }
  }

  /// Pages in more history when the card holding the very last loaded entry comes on screen. (Keyed
  /// on entries, not `MediaItem`: a series appears several times, which confuses
  /// `loadMoreContent(after:)`, and the last entry may be folded inside a group.)
  private func loadMoreIfLast(_ group: HistoryGroup) {
    guard !loadingMore, let last = model.historyItems.last?.uniqueID,
          group.entries.contains(where: { $0.uniqueID == last }),
          let page = model.pagination, page.current < page.total else { return }
    loadingMore = true
    Task {
      await model.fetchItems()
      loadingMore = false
    }
  }

  /// "Сегодня", "Вчера", else "среда, 5 ноября" (the year only when it isn't this one).
  static func dayTitle(_ day: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) { return "Today".localized }
    if calendar.isDateInYesterday(day) { return "Yesterday".localized }
    var style = Date.FormatStyle(locale: Locale(identifier: "ru")).weekday(.wide).day().month(.wide)
    if !calendar.isDate(day, equalTo: .now, toGranularity: .year) { style = style.year() }
    return day.formatted(style)
  }
}

enum HistoryFocus: Hashable {
  case filter, refresh
  case card(day: Date, item: Int)
}

/// One day of history: a heading and a grid of wide cards, one per title.
struct HistoryDayGrid: View {
  let title: String
  var day: Date = .now
  let entries: [HistoryItem]
  var focus: FocusState<HistoryFocus?>.Binding
  var onAppear: (HistoryGroup) -> Void = { _ in }
  var onRemove: (HistoryItem) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text(title).font(.headline).foregroundStyle(.secondary)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TVMetrics.itemSpacing, alignment: .top),
                               count: TVMetrics.wideColumns),
                spacing: TVMetrics.shelfSpacing) {
        // Keyed by title: a title watched again keeps its card, so focus stays on it.
        ForEach(entries.groupedByTitle(), id: \.latest.item.id) { group in
          let entry = group.latest
          WideLockup(imageURL: entry.item.posters.wide ?? entry.item.posters.big,
                     title: entry.item.localizedTitle,
                     subtitle: entry.episodeSubtitle ?? entry.item.yearAndRating,
                     badge: group.count > 1 ? RussianPlural.episodes(group.count) : nil,
                     value: Route.details(entry.item))
          .contextMenu {
            // Clears the whole title server-side, so every folded episode goes with it.
            Button("Remove from history".localized, systemImage: "trash", role: .destructive) {
              onRemove(entry)
            }
          }
          .focused(focus, equals: .card(day: day, item: entry.item.id))
          .onAppear { onAppear(group) }
        }
      }
    }
    .focusSection()
  }
}

#Preview {
  // Item 1 three times (a binge), then single entries.
  let ids = [1, 2, 1, 3, 1, 4]
  let entries = ids.enumerated().map { index, id in
    HistoryItem(time: nil, counter: 1, firstSeen: nil, lastSeen: TimeInterval(100 - index),
                item: .mock(id: id), media: HistoryMedia(number: index + 1, seasonNumber: 1))
  }
  return HistoryDayGridPreview(entries: entries)
}

private struct HistoryDayGridPreview: View {
  let entries: [HistoryItem]
  @FocusState private var focus: HistoryFocus?

  var body: some View {
    ScrollView {
      HistoryDayGrid(title: "Сегодня", entries: entries, focus: $focus)
    }
    .scrollClipDisabled()
  }
}
