//
//  MyContentViewModel.swift
//  KinoPubTV
//

import Foundation

@MainActor
@Observable
final class MyContentViewModel {
    var unwatchedSerials: [Item] = []
    var unwatchedMovies: [Item] = []
    var bookmarkFolders: [BookmarkFolder] = []
    var bookmarkItems: [Int: [Item]] = [:]
    var history: [HistoryItem] = []
    
    var isLoading = false
    var error: String?
    
    private let contentService = ContentService.shared
    
    // MARK: - Load All Content (legacy)
    
    func loadContent() async {
        await loadWatching()
        await loadBookmarks()
        await loadHistory()
    }
    
    // MARK: - Load Watching
    
    func loadWatching() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            async let serialsResponse = contentService.getWatchingSerials(subscribed: true, accessToken: token)
            async let moviesResponse = contentService.getWatchingMovies(accessToken: token)
            
            let (serials, movies) = try await (serialsResponse, moviesResponse)
            
            unwatchedSerials = serials.items
            unwatchedMovies = movies.items
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Load Bookmarks
    
    func loadBookmarks() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            let foldersResponse = try await contentService.getBookmarkFolders(accessToken: token)
            bookmarkFolders = foldersResponse.items
            
            // Load items for each bookmark folder
            for folder in foldersResponse.items {
                let items = try await contentService.getBookmarkItems(
                    folderID: folder.id,
                    accessToken: token
                )
                bookmarkItems[folder.id] = items.items
            }
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Load History
    
    func loadHistory() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            let historyResponse = try await contentService.getHistory(accessToken: token)
            history = historyResponse.history
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Actions
    
    func createFolder(title: String) async {
        do {
            let token = try await AuthService.shared.getValidToken()
            _ = try await contentService.createBookmarkFolder(title: title, accessToken: token)
            await loadBookmarks()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteFolder(id: Int) async {
        do {
            let token = try await AuthService.shared.getValidToken()
            try await contentService.removeBookmarkFolder(folderID: id, accessToken: token)
            await loadBookmarks()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func clearHistory(itemID: Int) async {
        do {
            let token = try await AuthService.shared.getValidToken()
            try await contentService.clearHistoryForItem(itemID: itemID, accessToken: token)
            await loadHistory()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
