//
//  FocusHandoff.swift
//  KinoPubTV
//

import SwiftUI

/// Reloads a list after a return without losing focus. If the focused card vanished, tvOS would keep no focus
/// at all, and «menu» would then quit the app. So focus moves to a card that stays BEFORE the list changes.
/// - load: the fresh data, or nil to keep the list as it is.
/// - handoff: moves focus off a card that will leave; returns true if it moved focus.
@MainActor
func refreshWithFocus<Value>(load: () async -> Value?, handoff: (Value) -> Bool,
                             apply: (Value) -> Void) async {
  // Let the pop finish, so tvOS has put focus back on the card the user opened.
  try? await Task.sleep(for: .milliseconds(600))
  guard !Task.isCancelled, let value = await load(), !Task.isCancelled else { return }
  if handoff(value) {
    try? await Task.sleep(for: .milliseconds(200))
    guard !Task.isCancelled else { return }
  }
  apply(value)
}
