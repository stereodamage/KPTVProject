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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .animation(.default, value: authService.isAuthenticated)
        }
    }
}
