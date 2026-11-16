//
//  TVBookmarkFolderView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// One bookmark folder as a poster grid, with sort, «Убрать из папки» per title and folder deletion.
struct TVBookmarkFolderView: View {
  let folder: Bookmark

  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVBookmarkFolderContent(model: BookmarkModel(bookmark: folder,
                                                 itemsService: appContext.contentService,
                                                 actionsService: appContext.actionsService,
                                                 errorHandler: errorHandler))
  }
}

private struct TVBookmarkFolderContent: View {
  @StateObject private var model: BookmarkModel
  @Environment(\.dismiss) private var dismiss
  @State private var confirmDelete = false

  init(model: @autoclosure @escaping () -> BookmarkModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    TVBookmarkFolderPage(title: model.title, items: model.sortedItems, sort: $model.sort,
                         needsRefresh: model.needsRefresh,
                         load: { await model.loadFresh() },
                         apply: { model.items = $0 },
                         onRemove: { item in Task { await model.removeFromFolder(item) } },
                         onDelete: { confirmDelete = true })
      .task { await model.fetchItems() }
      .confirmationDialog("Delete folder?".localized, isPresented: $confirmDelete, titleVisibility: .visible) {
        Button("Delete".localized, role: .destructive) {
          Task { if await model.delete() { dismiss() } }
        }
        Button("Cancel".localized, role: .cancel) {}
      } message: {
        Text(model.title)
      }
  }
}

struct TVBookmarkFolderPage: View {
  let title: String
  let items: [MediaItem]
  @Binding var sort: BookmarkSort
  var needsRefresh = false
  var load: () async -> [MediaItem]? = { nil }
  var apply: ([MediaItem]) -> Void = { _ in }
  var onRemove: (MediaItem) -> Void = { _ in }
  var onDelete: () -> Void = {}

  @Namespace private var focusScope
  @FocusState private var focus: String?
  @State private var lastFocused: Int?

  private var isLoading: Bool { items.contains { $0.skeleton ?? false } }

  var body: some View {
    // A change made on a detail screen is applied once this grid is back on top. Focus moves to a
    // remaining title BEFORE the list changes: if the focused poster vanished, tvOS would keep no focus
    // at all, and «menu» would then quit the app.
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
          Text(title).font(.title2.bold()).lineLimit(1)
          if !isLoading {
            Text(verbatim: String(items.count)).font(.title3).foregroundStyle(.secondary)
          }
          Spacer()
          HStack(spacing: 24) {
            FilterMenu(title: "Sort".localized, value: sort.title, systemImage: "arrow.up.arrow.down",
                       active: sort != .added) {
              Picker("Sort".localized, selection: $sort) {
                ForEach(BookmarkSort.allCases) { Text($0.title).tag($0) }
              }
            }
            .prefersDefaultFocus(items.isEmpty, in: focusScope)
            .focused($focus, equals: "sort")
            Button("Delete folder".localized, systemImage: "trash", role: .destructive, action: onDelete)
              .focused($focus, equals: "delete")
          }
          .font(.callout)
          .lineLimit(1)
          .fixedSize()
        }
        .focusSection()

        if isLoading {
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if items.isEmpty {
          StatusView(systemImage: "bookmark", title: "Nothing here yet".localized)
            .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          PosterGrid(items: items) { item in
            PosterLockup(item: item)
              .prefersDefaultFocus(item.id == items.first?.id, in: focusScope)
              .focused($focus, equals: "item-\(item.id)")
              .contextMenu {
                Button("Remove from folder".localized, systemImage: "bookmark.slash", role: .destructive) {
                  onRemove(item)
                }
              }
          }
          .focusSection()
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
    .focusScope(focusScope)
    .refreshWhenOnTop(needsRefresh) { Task { await refresh() } }
    .onChange(of: focus) { _, now in
      guard let now else { return }
      lastFocused = now.hasPrefix("item-") ? Int(now.dropFirst(5)) : nil
    }
    .onChange(of: items.map(\.id)) { _, ids in
      guard let current = focus, current.hasPrefix("item-"),
            !ids.contains(where: { "item-\($0)" == current }) else { return }
      let next = ids.first.map { "item-\($0)" } ?? "sort"
      DispatchQueue.main.async { focus = next }
    }
  }

  private func refresh() async {
    // Let the pop finish, so tvOS has put focus back on the title the user opened.
    try? await Task.sleep(for: .milliseconds(600))
    guard let fresh = await load() else { return }
    let keep = Set(fresh.map(\.id))
    if let last = lastFocused, !keep.contains(last) {
      focus = neighbor(of: last, keeping: keep)
      try? await Task.sleep(for: .milliseconds(200))
    }
    apply(fresh)
  }

  private func neighbor(of id: Int, keeping keep: Set<Int>) -> String {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return "sort" }
    let next = items[(index + 1)...].first { keep.contains($0.id) } ?? items[..<index].last { keep.contains($0.id) }
    return next.map { "item-\($0.id)" } ?? "sort"
  }
}

#Preview {
  NavigationStack {
    TVBookmarkFolderPage(title: "Смотреть позже", items: (1...9).map { MediaItem.mock(id: $0) },
                         sort: .constant(.added))
  }
}
