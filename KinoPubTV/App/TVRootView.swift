//
//  TVRootView.swift
//  KinoPubTV
//

import SwiftUI

/// Signed out → full-screen device activation; signed in → the sidebar app.
struct TVRootView: View {
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler
  @State private var didCheck = false

  var body: some View {
    Group {
      if !didCheck {
        ProgressView()
      } else if authState.userState == .authorized {
        TVMainView()
      } else {
        TVAuthView(authState: authState, errorHandler: errorHandler)
      }
    }
    .task {
      await authState.check()
      didCheck = true
    }
  }
}
