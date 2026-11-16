//
//  KinoPubTVApp.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubUI

@main
struct KinoPubTVApp: App {
  @StateObject private var errorHandler = ErrorHandler()
  @StateObject private var authState = AuthState(authService: AppContext.shared.authService,
                                                 accessTokenService: AppContext.shared.accessTokenService,
                                                 deviceService: AppContext.shared.deviceService)

  init() {
    // Russian-only app: pin the bundle language before any string is looked up. This also overrides
    // a language picked in an older build's settings (it was stored in the same key).
    UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
    ImageCache.shared.purgeExpired()
  }

  var body: some Scene {
    WindowGroup {
      TVRootView()
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "ru"))
        .environment(\.appContext, AppContext.shared)
        .environmentObject(authState)
        .environmentObject(errorHandler)
        .environmentObject(AppContext.shared.libraryState)
        .task(id: authState.userState) {
          if authState.userState == .authorized {
            await AppContext.shared.deviceService.registerDeviceName()
            await AppContext.shared.deviceService.syncCapabilities()
          }
        }
    }
  }
}
