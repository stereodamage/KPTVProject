//
//  KPTVProjectApp.swift
//  KPTVProject
//
//  Created by Artem Demidov on 12/14/25.
//

import SwiftUI

@main
struct KPTVProjectApp: App {
    @State private var authService = AuthService.shared
    @State private var navigationPath = NavigationPath()
    
    init() {
        // Set app locale to match system locale (important for API requests)
        setupLocale()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .onOpenURL { url in
                            handleDeepLink(url)
                        }
                        .task {
                            // Update Top Shelf on app launch
                            await TopShelfService.shared.updateTopShelf(
                                contentType: AppSettings.shared.topShelfContentType
                            )
                        }
                } else {
                    AuthView()
                }
            }
            .animation(.default, value: authService.isAuthenticated)
        }
    }
    
    private func setupLocale() {
        // App is Russian-oriented, locale settings are in Info.plist
        if let preferredLanguage = Locale.preferredLanguages.first {
            print("🌍 App locale: \(preferredLanguage)")
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle kptv://item/{id} URLs from Top Shelf
        print("🔗 Deep link received: \(url)")
        
        guard url.scheme == "kptv" else {
            print("🔗 Unknown scheme: \(url.scheme ?? "nil")")
            return
        }
        
        // URL format: kptv://item/12345
        // host = "item", pathComponents = ["/", "12345"]
        guard url.host == "item" else {
            print("🔗 Unknown host: \(url.host ?? "nil")")
            return
        }
        
        // Get the ID from path
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let itemIDString = pathComponents.first,
              let itemID = Int(itemIDString) else {
            print("🔗 Could not parse item ID from: \(url.pathComponents)")
            return
        }
        
        print("🔗 Navigating to item: \(itemID)")
        
        // Post notification to navigate to item
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToItem"),
            object: nil,
            userInfo: ["itemID": itemID]
        )
    }
}
