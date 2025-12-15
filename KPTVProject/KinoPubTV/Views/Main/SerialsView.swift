//
//  SerialsView.swift
//  KinoPubTV
//

import SwiftUI

struct SerialsView: View {
    @State private var viewModel = SerialsViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 40) {
                    // Featured Carousel at the top
                    if !viewModel.featuredItems.isEmpty {
                        FeaturedCarousel(items: viewModel.featuredItems)
                    }
                    
                    if !viewModel.popularItems.isEmpty {
                        ContentShelf(title: "Популярные сериалы", items: viewModel.popularItems)
                    }
                    
                    if !viewModel.mostSubscribed.isEmpty {
                        ContentShelf(title: "Больше всего подписчиков", items: viewModel.mostSubscribed)
                    }
                    
                    if !viewModel.hotItems.isEmpty {
                        ContentShelf(title: "Горячие сериалы", items: viewModel.hotItems)
                    }
                    
                    if !viewModel.freshItems.isEmpty {
                        ContentShelf(title: "Новые сериалы", items: viewModel.freshItems)
                    }
                    
                    if !viewModel.fourKItems.isEmpty {
                        ContentShelf(title: "4K сериалы", items: viewModel.fourKItems)
                    }
                }
                .padding(.vertical, 50)
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(itemID: item.id)
            }
            .overlay {
                if viewModel.isLoading && viewModel.popularItems.isEmpty {
                    ProgressView("Загрузка сериалов...")
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

#Preview {
    SerialsView()
}
