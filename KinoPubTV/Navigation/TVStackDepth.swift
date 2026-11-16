//
//  TVStackDepth.swift
//  KinoPubTV
//

import SwiftUI

/// The routes pushed on one tab's stack. `TVStack` hands it, with `tvStackLevel`, to each pushed screen
/// directly: environment values set on the `NavigationStack` do not reach pushed screens on tvOS.
@Observable
final class TVStackModel {
  var path: [Route] = []
}

extension EnvironmentValues {
  /// This screen's position in its stack: 0 for the root, n for the n-th pushed screen.
  @Entry var tvStackLevel = 0
}

extension View {
  /// Runs `perform` while `needed` is true and this screen is the top of its stack: when `needed` turns
  /// true on top, or when the screen comes back on top. tvOS sends no onAppear to a screen a pop
  /// uncovers, and changing it while covered loses focus when the focused poster disappears.
  func refreshWhenOnTop(_ needed: Bool, perform: @escaping () -> Void) -> some View {
    modifier(RefreshWhenOnTop(needed: needed, perform: perform))
  }
}

private struct RefreshWhenOnTop: ViewModifier {
  let needed: Bool
  let perform: () -> Void

  @Environment(TVStackModel.self) private var stack: TVStackModel?
  @Environment(\.tvStackLevel) private var level

  private var depth: Int { stack?.path.count ?? 0 }

  func body(content: Content) -> some View {
    content
      .onChange(of: depth) { _, now in
        if needed, now == level { perform() }
      }
      .onChange(of: needed) { _, now in
        if now, depth == level { perform() }
      }
  }
}
