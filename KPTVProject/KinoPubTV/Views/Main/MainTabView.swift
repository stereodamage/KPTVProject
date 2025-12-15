//
//  MainTabView.swift
//  KinoPubTV
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MoviesView()
                .tabItem {
                    Label("Фильмы", systemImage: "film")
                }
            
            SerialsView()
                .tabItem {
                    Label("Сериалы", systemImage: "tv")
                }
            
            MyContentView()
                .tabItem {
                    Label("Мои", systemImage: "heart")
                }
            
            TVView()
                .tabItem {
                    Label("ТВ", systemImage: "play.tv")
                }
            
            SearchView()
                .tabItem {
                    Label("Поиск", systemImage: "magnifyingglass")
                }
            
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
        }
        .persistentSystemOverlays(.visible)
    }
}

#Preview {
    MainTabView()
}
