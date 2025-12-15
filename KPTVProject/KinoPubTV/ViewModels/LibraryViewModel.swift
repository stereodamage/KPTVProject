//
//  LibraryViewModel.swift
//  KinoPubTV
//

import Foundation

@MainActor
@Observable
final class LibraryViewModel {
    var items: [Item] = []
    var genres: [Genre] = []
    var countries: [Country] = []
    
    var selectedType: ContentType?
    var selectedGenre: Genre?
    var selectedCountry: Country?
    var selectedYear: Int?
    var selectedQuality: String?
    var selectedSort: SortOption = .created
    
    var currentPage = 1
    var totalPages = 1
    var isLoading = false
    var error: String?
    
    private let contentService = ContentService.shared
    
    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((1912...currentYear).reversed())
    }
    
    var availableQualities: [String] {
        ["480p", "720p", "1080p", "4k"]
    }
    
    func loadReferences() async {
        do {
            let token = try await AuthService.shared.getValidToken()
            
            async let genresResponse = contentService.getGenres(type: selectedType, accessToken: token)
            async let countriesResponse = contentService.getCountries(accessToken: token)
            
            let (g, c) = try await (genresResponse, countriesResponse)
            
            genres = g.items
            countries = c.items
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func loadItems(reset: Bool = false) async {
        if reset {
            currentPage = 1
            items = []
        }
        
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            let response = try await contentService.getItems(
                type: selectedType,
                page: currentPage,
                sort: selectedSort,
                genre: selectedGenre?.id,
                country: selectedCountry?.id,
                year: selectedYear,
                quality: selectedQuality,
                accessToken: token
            )
            
            if reset {
                items = response.items
            } else {
                items.append(contentsOf: response.items)
            }
            
            if let pagination = response.pagination {
                totalPages = pagination.total
            }
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadNextPage() async {
        guard currentPage < totalPages, !isLoading else { return }
        currentPage += 1
        await loadItems()
    }
    
    func applyFilters() async {
        await loadItems(reset: true)
    }
    
    func clearFilters() {
        selectedType = nil
        selectedGenre = nil
        selectedCountry = nil
        selectedYear = nil
        selectedQuality = nil
        selectedSort = .created
    }
}
