//
//  MainTabView.swift
//  KinoPubTV
//

import SwiftUI

struct MainTabView: View {
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: Int = 1  // Default to Movies
    @State private var deepLinkItemID: Int?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Text("🔍")
                }
                .tag(0)
            
            NavigationStack(path: $navigationPath) {
                MoviesView()
                    .navigationDestination(for: Item.self) { item in
                        DetailView(itemID: item.id)
                    }
            }
            .tabItem {
                Label("Фильмы", systemImage: "film")
            }
            .tag(1)
            
            SerialsView()
                .tabItem {
                    Label("Сериалы", systemImage: "tv")
                }
                .tag(2)
            
            TVView()
                .tabItem {
                    Label("ТВ", systemImage: "play.tv")
                }
                .tag(3)
            
            MyContentView()
                .tabItem {
                    Label("Мои", systemImage: "heart")
                }
                .tag(4)
            
            LibraryView()
                .tabItem {
                    Label("Библиотека", systemImage: "books.vertical")
                }
                .tag(5)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                }
                .tag(6)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToItem"))) { notification in
            if let itemID = notification.userInfo?["itemID"] as? Int {
                print("🔗 MainTabView received itemID: \(itemID)")
                deepLinkItemID = itemID
            }
        }
        .fullScreenCover(item: Binding(
            get: { deepLinkItemID.map { DeepLinkItem(id: $0) } },
            set: { deepLinkItemID = $0?.id }
        )) { item in
            NavigationStack {
                DetailView(itemID: item.id)
            }
            .background(Color(white: 0.15))
            .ignoresSafeArea()
        }
    }
}

// Helper for Identifiable binding
private struct DeepLinkItem: Identifiable {
    let id: Int
}

#Preview {
    MainTabView()
}
