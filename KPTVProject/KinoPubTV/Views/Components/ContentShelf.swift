//
//  ContentShelf.swift
//  KinoPubTV
//

import SwiftUI

struct ContentShelf: View {
    let title: String
    let items: [Item]
    var itemWidth: CGFloat = 400
    var itemHeight: CGFloat = 225
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 50)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 24) {
                            NavigationLink(value: item) {
                                ItemCard(
                                    item: item,
                                    width: itemWidth,
                                    height: itemHeight
                                )
                            }
                            .buttonStyle(.card)
                            
                            ItemMetadata(item: item, width: itemWidth)
                        }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.vertical, 40)
                .focusSection()
            }
        }
    }
}

// MARK: - Collection Shelf

struct CollectionShelf: View {
    let title: String
    let collections: [Collection]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 50)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(collections) { collection in
                        VStack(alignment: .leading, spacing: 24) {
                            NavigationLink {
                                CollectionDetailView(collection: collection)
                            } label: {
                                CollectionCard(collection: collection)
                            }
                            .buttonStyle(.card)
                            
                            Text(collection.title)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                                .frame(width: 300, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.vertical, 40)
                .focusSection()
            }
        }
    }
}

struct CollectionCard: View {
    let collection: Collection
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL.secure(string: collection.posters?.big)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(white: 0.15))
            }
            .frame(width: 300, height: 450)
            .clipped()
        }
        // Let .card buttonStyle handle focus effects for Apple TV compliance
    }
}

// MARK: - Collection Detail View

struct CollectionDetailView: View {
    let collection: Collection
    
    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var totalPages = 1
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5),
                spacing: 50
            ) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 24) {
                        NavigationLink(value: item) {
                            PosterCard(item: item)
                        }
                        .buttonStyle(.card)
                        
                        ItemMetadata(item: item, width: 250)
                    }
                    .onAppear {
                        if item == items.last && currentPage < totalPages {
                            Task {
                                await loadMore()
                            }
                        }
                    }
                }
            }
            .padding(50)
            
            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle(collection.title)
        .task {
            await loadItems()
        }
    }
    
    private func loadItems() async {
        isLoading = true
        
        do {
            let token = try await AuthService.shared.getValidToken()
            let response = try await ContentService.shared.getCollectionItems(
                collectionID: collection.id,
                page: currentPage,
                accessToken: token
            )
            items = response.items
            if let pagination = response.pagination {
                totalPages = pagination.total
            }
        } catch {
            print("Error loading collection: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadMore() async {
        guard !isLoading else { return }
        currentPage += 1
        isLoading = true
        
        do {
            let token = try await AuthService.shared.getValidToken()
            let response = try await ContentService.shared.getCollectionItems(
                collectionID: collection.id,
                page: currentPage,
                accessToken: token
            )
            items.append(contentsOf: response.items)
        } catch {
            print("Error loading more: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ContentShelf(
            title: "Тестовая полка",
            items: []
        )
    }
}
