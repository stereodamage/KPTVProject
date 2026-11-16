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
          .focusSection()
        }

        if model.isLoadingSkeleton {
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if model.historyItems.isEmpty {
          StatusView(systemImage: "clock.arrow.circlepath", title: "Nothing here yet".localized)
            .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          ForEach(model.groupedSections) { section in
            HistoryDayGrid(title: Self.dayTitle(section.day), entries: section.items,
                           onAppear: loadMoreIfLast, onRemove: model.removeFromHistory)
          }
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
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

/// One day of history: a heading and a grid of wide cards, one per title.
struct HistoryDayGrid: View {
  let title: String
  let entries: [HistoryItem]
  var onAppear: (HistoryGroup) -> Void = { _ in }
  var onRemove: (HistoryItem) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text(title).font(.headline).foregroundStyle(.secondary)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TVMetrics.itemSpacing, alignment: .top),
                               count: TVMetrics.wideColumns),
                spacing: TVMetrics.shelfSpacing) {
        ForEach(entries.groupedByTitle()) { group in
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
  return ScrollView {
    HistoryDayGrid(title: "Сегодня", entries: entries)
  }
  .scrollClipDisabled()
}
