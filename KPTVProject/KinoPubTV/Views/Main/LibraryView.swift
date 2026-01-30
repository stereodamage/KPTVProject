//
//  LibraryView.swift
//  KinoPubTV
//

import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    
    var body: some View {
        NavigationStack {
            mainContent
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            filtersView
            Divider()
            contentGridView
        }
        .navigationDestination(for: Item.self) { item in
            DetailView(itemID: item.id)
        }
        .task {
            await viewModel.loadReferences()
            await viewModel.loadItems(reset: true)
        }
    }
    
    @ViewBuilder
    private var filtersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                typeFilterMenu
                genreFilterMenu
                countryFilterMenu
                yearFilterMenu
                qualityFilterMenu
                sortFilterMenu
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 20)
        }
    }
    
    private var typeFilterMenu: some View {
        Menu {
            Button("Все") {
                viewModel.selectedType = nil
                reloadContent()
            }
            ForEach(ContentType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    viewModel.selectedType = type
                    reloadContent()
                }
            }
        } label: {
            filterLabel("Тип", value: viewModel.selectedType?.displayName ?? "Все")
        }
    }
    
    private var genreFilterMenu: some View {
        Menu {
            Button("Все") {
                viewModel.selectedGenre = nil
                reloadContent()
            }
            ForEach(viewModel.genres) { genre in
                Button(genre.title) {
                    viewModel.selectedGenre = genre
                    reloadContent()
                }
            }
        } label: {
            filterLabel("Жанр", value: viewModel.selectedGenre?.title ?? "Все")
        }
    }
    
    private var countryFilterMenu: some View {
        Menu {
            Button("Все") {
                viewModel.selectedCountry = nil
                reloadContent()
            }
            ForEach(viewModel.countries) { country in
                Button(country.title) {
                    viewModel.selectedCountry = country
                    reloadContent()
                }
            }
        } label: {
            filterLabel("Страна", value: viewModel.selectedCountry?.title ?? "Все")
        }
    }
    
    private var yearFilterMenu: some View {
        Menu {
            Button("Все") {
                viewModel.selectedYear = nil
                reloadContent()
            }
            ForEach(viewModel.availableYears, id: \.self) { year in
                Button(String(year)) {
                    viewModel.selectedYear = year
                    reloadContent()
                }
            }
        } label: {
            filterLabel("Год", value: viewModel.selectedYear.map { String($0) } ?? "Все")
        }
    }
    
    private var qualityFilterMenu: some View {
        Menu {
            Button("Все") {
                viewModel.selectedQuality = nil
                reloadContent()
            }
            ForEach(viewModel.availableQualities, id: \.self) { quality in
                Button(quality) {
                    viewModel.selectedQuality = quality
                    reloadContent()
                }
            }
        } label: {
            filterLabel("Качество", value: viewModel.selectedQuality ?? "Все")
        }
    }
    
    private var sortFilterMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { sort in
                Button(sort.displayName) {
                    viewModel.selectedSort = sort
                    reloadContent()
                }
            }
        } label: {
            filterLabel("Сортировка", value: viewModel.selectedSort.displayName)
        }
    }
    
    private func filterLabel(_ title: String, value: String) -> some View {
        HStack {
            Text("\(title): \(value)")
                .lineLimit(1)
            Image(systemName: "chevron.down")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func reloadContent() {
        Task {
            await viewModel.applyFilters()
        }
    }
    
    @ViewBuilder
    private var contentGridView: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5),
                spacing: 50
            ) {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 16) {
                        NavigationLink(value: item) {
                            PosterCard(item: item)
                        }
                        .buttonStyle(.card)
                        
                        ItemMetadata(item: item, width: 250)
                    }
                    .onAppear {
                        if item == viewModel.items.last {
                            Task {
                                await viewModel.loadNextPage()
                            }
                        }
                    }
                }
            }
            .padding(50)
            
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            }
        }
    }
}

#Preview {
    LibraryView()
}
