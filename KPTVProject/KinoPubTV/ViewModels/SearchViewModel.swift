//
//  SearchViewModel.swift
//  KinoPubTV
//

import Foundation
import Combine

@MainActor
@Observable
final class SearchViewModel {
    var searchText = ""
    var movieResults: [Item] = []
    var serialResults: [Item] = []
    
    var isSearching = false
    var error: String?
    
    private let contentService = ContentService.shared
    private var searchTask: Task<Void, Never>?
    
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            movieResults = []
            serialResults = []
            return
        }
        
        searchTask?.cancel()
        
        searchTask = Task {
            isSearching = true
            
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                
                guard !Task.isCancelled else { return }
                
                let token = try await AuthService.shared.getValidToken()
                let response = try await contentService.search(query: query, accessToken: token)
                
                guard !Task.isCancelled else { return }
                
                var movies: [Item] = []
                var serials: [Item] = []
                
                for item in response.items {
                    if item.isSerial {
                        serials.append(item)
                    } else {
                        movies.append(item)
                    }
                }
                
                movieResults = movies
                serialResults = serials
                
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
            
            isSearching = false
        }
    }
    
    func clearResults() {
        searchText = ""
        movieResults = []
        serialResults = []
        error = nil
    }
}
