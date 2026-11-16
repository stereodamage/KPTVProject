//
//  BookmarksCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

@MainActor
class BookmarksCatalog: ObservableObject {

  private var authState: AuthState
  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var bag = Set<AnyCancellable>()

  @Published public var items: [Bookmark] = Bookmark.skeletonMock()
  /// Items per bookmark folder (by folder id), powering the Home-style shelves.
  @Published public var folderItems: [Int: [MediaItem]] = [:]

  private var actionsService: UserActionsService

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.actionsService = actionsService
    observeFolderCache()
    // Load on creation, not via the view's `.task` (unreliable in a compact split view / nested stack).
    Task { await fetchItems() }
  }

  /// Refetch folders and their items in place (no skeleton flash), e.g. on a return to the tab.
  func reload() async {
    guard authState.userState == .authorized else { return }
    staleFolders = []
    await AppContext.shared.libraryState.reloadBookmarkFolders()
    await fetchItems()
  }

  /// Creates an empty folder; returns false when the name is blank or the call fails.
  func createFolder(named name: String) async -> Bool {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return false }
    do {
      _ = try await actionsService.createBookmarkFolder(title: title)
    } catch {
      errorHandler.setError(error)
      return false
    }
    await reload()
    return true
  }

  /// Keep the folder list in sync with the shared cache so a folder deleted on its detail screen
  /// disappears here too (without a manual refresh).
  private func observeFolderCache() {
    AppContext.shared.libraryState.$bookmarkFolders
      .dropFirst()
      .receive(on: RunLoop.main)
      .sink { [weak self] folders in
        guard let self else { return }
        self.items = folders
        let ids = Set(folders.map { $0.id })
        self.folderItems = self.folderItems.filter { ids.contains($0.key) }
      }
      .store(in: &bag)
    AppContext.shared.libraryState.bookmarkFolderChanged
      .receive(on: RunLoop.main)
      .sink { [weak self] id in self?.staleFolders.insert(id) }
      .store(in: &bag)
  }

  /// Folders changed elsewhere; the view loads them with `loadStaleFolders()` and applies them itself
  /// (see `BookmarkModel.loadFresh()` for why).
  @Published public var staleFolders = Set<Int>()

  func loadStaleFolders() async -> [Int: [MediaItem]] {
    let ids = staleFolders
    staleFolders = []
    var result = [Int: [MediaItem]]()
    for id in ids {
      if let items = try? await contentService.fetchBookmarkItems(id: "\(id)").items { result[id] = items }
    }
    return result
  }

  func apply(_ shelves: [Int: [MediaItem]]) {
    for (id, items) in shelves { folderItems[id] = items }
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    // Folder list comes from the shared session cache (single source of truth across the app);
    // only each folder's contents are fetched here.
    await AppContext.shared.libraryState.loadBookmarkFoldersIfNeeded()
    let bookmarks = AppContext.shared.libraryState.bookmarkFolders
    items = bookmarks
    await loadFolderItems(bookmarks)
  }

  /// Loads each folder's contents concurrently so every shelf can show its posters.
  private func loadFolderItems(_ bookmarks: [Bookmark]) async {
    let service = contentService
    await withTaskGroup(of: (Int, [MediaItem]).self) { group in
      for bookmark in bookmarks {
        group.addTask {
          let items = (try? await service.fetchBookmarkItems(id: "\(bookmark.id)").items) ?? []
          return (bookmark.id, items)
        }
      }
      for await (id, items) in group {
        folderItems[id] = items
      }
    }
  }

  

  @Sendable @MainActor
  func refresh() async {
    items = Bookmark.skeletonMock()
    folderItems = [:]
    Logger.app.debug("refetch bookmarks")
    // Pull-to-refresh forces a fresh folder list (e.g. after creating/renaming a folder).
    await AppContext.shared.libraryState.reloadBookmarkFolders()
    await fetchItems()
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
