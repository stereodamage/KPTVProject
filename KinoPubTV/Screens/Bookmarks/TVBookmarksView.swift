//
//  TVBookmarksView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// The Bookmarks tab: one shelf per folder, each ending in «Все» for the full folder grid.
struct TVBookmarksView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVBookmarksContent(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                                 authState: authState,
                                                 errorHandler: errorHandler,
                                                 actionsService: appContext.actionsService))
  }
}

private struct TVBookmarksContent: View {
  @StateObject private var catalog: BookmarksCatalog
  @State private var appeared = false
  @State private var creating = false
  @State private var newName = ""

  init(catalog: @autoclosure @escaping () -> BookmarksCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    TVBookmarksPage(folders: catalog.items, folderItems: catalog.folderItems,
                    needsRefresh: !catalog.staleFolders.isEmpty,
                    load: { await catalog.loadStaleFolders() },
                    apply: { catalog.apply($0) }) {
      newName = ""
      creating = true
    }
    // The first load comes from the catalog's init; later visits pick up changes made elsewhere.
    .onAppear {
      if appeared { Task { await catalog.reload() } }
      appeared = true
    }
    .alert("New folder".localized, isPresented: $creating) {
      TextField("Folder name".localized, text: $newName)
      Button("Create".localized) {
        let name = newName
        Task { _ = await catalog.createFolder(named: name) }
      }
      Button("Cancel".localized, role: .cancel) {}
    }
  }
}

struct TVBookmarksPage: View {
  let folders: [Bookmark]
  let folderItems: [Int: [MediaItem]]
  var needsRefresh = false
  var load: () async -> [Int: [MediaItem]] = { [:] }
  var apply: ([Int: [MediaItem]]) -> Void = { _ in }
  var onCreate: () -> Void = {}

  @FocusState private var focus: String?
  @State private var lastFocused: (folder: Int, item: Int)?

  var body: some View {
    // Same rule as the folder grid: apply changes from a detail screen once back on top, and move focus
    // to the shelf's «Все» before a focused poster leaves.
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        HStack(spacing: 40) {
          Text("Bookmarks".localized).font(.title2.bold())
          Spacer()
          Button("New folder".localized, systemImage: "folder.badge.plus", action: onCreate)
            .lineLimit(1)
            .fixedSize()
            .focused($focus, equals: "new")
        }
        .focusSection()

        if folders.contains(where: { $0.skeleton ?? false }) {
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if folders.isEmpty {
          StatusView(systemImage: "bookmark", title: "No bookmark folders".localized)
            .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          ForEach(folders) { folder in
            BookmarkFolderShelf(folder: folder, items: folderItems[folder.id], focus: $focus)
          }
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
    .refreshWhenOnTop(needsRefresh) { Task { await refresh() } }
    .onChange(of: focus) { _, now in
      guard let now else { return }
      let parts = now.split(separator: "-")
      if parts.count == 2, let folder = Int(parts[0]), let item = Int(parts[1]) {
        lastFocused = (folder, item)
      } else {
        lastFocused = nil
      }
    }
    .onChange(of: folderItems) { _, shelves in
      // A focused poster that left its shelf hands focus to that shelf's «Все».
      let parts = (focus ?? "").split(separator: "-")
      guard parts.count == 2, let folderId = Int(parts[0]), let itemId = Int(parts[1]) else { return }
      let shown = (shelves[folderId] ?? []).prefix(BookmarkFolderShelf.previewLimit)
      guard !shown.contains(where: { $0.id == itemId }) else { return }
      DispatchQueue.main.async { focus = "all-\(folderId)" }
    }
  }

  private func refresh() async {
    try? await Task.sleep(for: .milliseconds(600))
    let shelves = await load()
    if let last = lastFocused, let fresh = shelves[last.folder],
       !fresh.prefix(BookmarkFolderShelf.previewLimit).contains(where: { $0.id == last.item }) {
      focus = "all-\(last.folder)"
      try? await Task.sleep(for: .milliseconds(200))
    }
    apply(shelves)
  }
}

private struct BookmarkFolderShelf: View {
  let folder: Bookmark
  let items: [MediaItem]?
  var focus: FocusState<String?>.Binding

  static let previewLimit = 12

  var body: some View {
    Shelf(title: "\(folder.title) · \(count)") {
      if let items {
        ForEach(items.prefix(Self.previewLimit)) { item in
          PosterLockup(item: item)
            .focused(focus, equals: "\(folder.id)-\(item.id)")
            .tileWidth(TVMetrics.posterColumns)
        }
      } else {
        ForEach(0..<3, id: \.self) { _ in PlaceholderTile().tileWidth(TVMetrics.posterColumns) }
      }
      SeeAllLockup(value: .bookmark(folder))
        .focused(focus, equals: "all-\(folder.id)")
        .tileWidth(TVMetrics.posterColumns)
    }
  }

  private var count: String {
    if let items { return String(items.count) }
    return folder.itemCount.map(String.init) ?? "…"
  }
}

#Preview {
  let folders = [
    Bookmark(id: 1, title: "Смотреть позже", views: 0, count: "14", created: 0, updated: 0),
    Bookmark(id: 2, title: "Для детей", views: 0, count: "3", created: 0, updated: 0),
    Bookmark(id: 3, title: "Пустая папка", views: 0, count: "0", created: 0, updated: 0)
  ]
  let items: [Int: [MediaItem]] = [
    1: (1...8).map { MediaItem.mock(id: $0) },
    2: (11...13).map { MediaItem.mock(id: $0) },
    3: []
  ]
  return NavigationStack {
    TVBookmarksPage(folders: folders, folderItems: items)
  }
}
