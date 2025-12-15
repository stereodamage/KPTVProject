//
//  SearchView.swift
//  KinoPubTV
//

import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Поиск", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal, 100)
                    .onChange(of: viewModel.searchText) { _, _ in
                        Task {
                            await viewModel.search()
                        }
                    }
                
                if viewModel.isSearching {
                    ProgressView()
                } else if viewModel.searchText.isEmpty {
                    ContentUnavailableView(
                        "Поиск",
                        systemImage: "magnifyingglass",
                        description: Text("Начните вводить текст для поиска")
                    )
                } else if viewModel.movieResults.isEmpty && viewModel.serialResults.isEmpty {
                    ContentUnavailableView(
                        "Ничего не найдено",
                        systemImage: "magnifyingglass",
                        description: Text("Попробуйте изменить запрос")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 40) {
                            if !viewModel.movieResults.isEmpty {
                                ContentShelf(title: "Фильмы", items: viewModel.movieResults)
                            }
                            
                            if !viewModel.serialResults.isEmpty {
                                ContentShelf(title: "Сериалы", items: viewModel.serialResults)
                            }
                        }
                        .padding(.vertical, 30)
                    }
                }
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(itemID: item.id)
            }
        }
    }
}

#Preview {
    SearchView()
}
