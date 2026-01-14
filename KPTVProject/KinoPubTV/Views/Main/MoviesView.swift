//
//  MoviesView.swift
//  KinoPubTV
//

import SwiftUI

struct MoviesView: View {
    @State private var viewModel = MoviesViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 60) {
                    // Featured Carousel at the top
                    if !viewModel.featuredItems.isEmpty {
                        FeaturedCarousel(items: viewModel.featuredItems)
                    }
                    
                    if !viewModel.unwatchedItems.isEmpty {
                        ContentShelf(title: "Мои фильмы", items: viewModel.unwatchedItems)
                    }
                    
                    if !viewModel.hotItems.isEmpty {
                        ContentShelf(title: "Горячие фильмы", items: viewModel.hotItems)
                    }
                    
                    if !viewModel.popularItems.isEmpty {
                        ContentShelf(title: "Популярные фильмы", items: viewModel.popularItems)
                    }
                    
                    if !viewModel.freshItems.isEmpty {
                        ContentShelf(title: "Новые фильмы", items: viewModel.freshItems)
                    }
                    
                    if !viewModel.fourKItems.isEmpty {
                        ContentShelf(title: "4K фильмы", items: viewModel.fourKItems)
                    }
                    
                    if !viewModel.collections.isEmpty {
                        CollectionShelf(title: "Подборки", collections: viewModel.collections)
                    }
                }
                .padding(.vertical, 50)
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(itemID: item.id)
            }
            .overlay {
                if viewModel.isLoading && viewModel.hotItems.isEmpty {
                    ProgressView("Загрузка фильмов...")
                }
            }
            .alert("Ошибка", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .task {
                await viewModel.loadContent()
            }
            .refreshable {
                await viewModel.loadContent()
            }
        }
    }
}

// MARK: - Featured Carousel

struct FeaturedCarousel: View {
    let items: [Item]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 50) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        FeaturedCard(item: item)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 40)
            .focusSection()
        }
    }
}

struct FeaturedCard: View {
    let item: Item
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Wide background image
            AsyncImage(url: URL.secure(string: item.posters?.wide ?? item.posters?.big)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color(white: 0.15))
                @unknown default:
                    Rectangle()
                        .fill(Color(white: 0.15))
                }
            }
            .frame(width: 1000, height: 560)
            .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content overlay
            HStack(alignment: .bottom, spacing: 24) {
                // Small poster
                AsyncImage(url: URL.secure(string: item.posters?.medium)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)
                
                // Info
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.displayTitle)
                        .font(.system(size: 38, weight: .bold))
                        .lineLimit(2)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    
                    if let originalTitle = item.originalTitle {
                        Text(originalTitle)
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    // Metadata row
                    HStack(spacing: 16) {
                        if let year = item.year {
                            Text(String(year))
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        if let genre = item.genres?.first?.title {
                            Text(genre)
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        // Ratings
                        if let rating = item.kinopoiskRating, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(30)
        }
        .frame(width: 1000, height: 560)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    MoviesView()
}
