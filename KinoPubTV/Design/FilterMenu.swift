//
//  FilterMenu.swift
//  KinoPubTV
//

import SwiftUI

/// A filter as a pop-up menu button: shows the facet name, or its current value once set.
struct FilterMenu<Content: View>: View {
  let title: String
  var value: String?
  let systemImage: String
  var active: Bool?
  @ViewBuilder var content: () -> Content

  var body: some View {
    Menu {
      content()
    } label: {
      Label(value ?? title, systemImage: systemImage)
        .fontWeight((active ?? (value != nil)) ? .semibold : .regular)
    }
  }
}
