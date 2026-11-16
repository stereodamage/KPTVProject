//
//  TVPlaybackSession.swift
//  KinoPubTV
//

import Foundation
import Combine
import KinoPubBackend

/// Owns the current `PlayerManager` and swaps it for the next episode; the on-screen player stays.
@MainActor
final class TVPlaybackSession: ObservableObject {
  /// Views read the manager only through the session, so nothing they keep holds an old one.
  private(set) var manager: PlayerManager {
    didSet { forward() }
  }
  private let makeManager: (any PlayableItem) -> PlayerManager
  private var forwarding: AnyCancellable?

  init(manager: PlayerManager, makeManager: @escaping (any PlayableItem) -> PlayerManager) {
    self.manager = manager
    self.makeManager = makeManager
    forward()
  }

  func advance(to episode: Episode) {
    manager.finishNow()
    manager.player.pause()
    objectWillChange.send()
    manager = makeManager(episode)
  }

  private func forward() {
    forwarding = manager.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
  }
}
