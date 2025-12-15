//
//  DetailViewModel.swift
//  KinoPubTV
//

import Foundation

@MainActor
@Observable
final class DetailViewModel {
    var item: Item?
    var similarItems: [Item] = []
    var comments: [Comment] = []
    var itemFolders: [BookmarkFolder] = []
    var allFolders: [BookmarkFolder] = []
    
    var isLoading = false
    var error: String?
    
    private let contentService = ContentService.shared
    
    func loadItem(id: Int) async {
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            let response = try await contentService.getItem(id: id, accessToken: token)
            item = response.item
            
            // Load additional data
            async let similarResponse = contentService.getSimilar(itemID: id, accessToken: token)
            async let commentsResponse = contentService.getComments(itemID: id, accessToken: token)
            
            let (similar, commentsData) = try await (similarResponse, commentsResponse)
            
            similarItems = similar.items
            comments = commentsData.comments
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func toggleWatchlist() async {
        guard let item = item else { return }
        
        do {
            let token = try await AuthService.shared.getValidToken()
            try await contentService.toggleWatchlist(itemID: item.id, accessToken: token)
            
            // Refresh item
            await loadItem(id: item.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func toggleWatched(season: Int? = nil, video: Int? = nil) async {
        guard let item = item else { return }
        
        do {
            let token = try await AuthService.shared.getValidToken()
            try await contentService.toggleWatched(
                itemID: item.id,
                season: season,
                video: video,
                accessToken: token
            )
            
            // Refresh item
            await loadItem(id: item.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func loadBookmarkFolders() async {
        guard let item = item else { return }
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            async let itemFoldersResponse = contentService.getItemFolders(itemID: item.id, accessToken: token)
            async let allFoldersResponse = contentService.getBookmarkFolders(accessToken: token)
            
            let (itemF, allF) = try await (itemFoldersResponse, allFoldersResponse)
            
            itemFolders = itemF.folders
            allFolders = allF.items
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func toggleBookmark(folderID: Int) async {
        guard let item = item else { return }
        
        do {
            let token = try await AuthService.shared.getValidToken()
            try await contentService.toggleBookmarkItem(
                itemID: item.id,
                folderID: folderID,
                accessToken: token
            )
            
            // Refresh folders
            await loadBookmarkFolders()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func vote(like: Bool) async {
        guard let item = item else { return }
        
        do {
            let token = try await AuthService.shared.getValidToken()
            try await contentService.vote(itemID: item.id, like: like, accessToken: token)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
