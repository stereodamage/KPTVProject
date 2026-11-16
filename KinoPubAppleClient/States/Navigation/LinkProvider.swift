//
//  LinkProvider.swift
//  KinoPubAppleClient
//
//  Navigation values handed out by the models. UI-free, so both the iOS/macOS and tvOS apps share it.
//

import Foundation
import KinoPubBackend

protocol NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable
  func player(for item: any PlayableItem) -> any Hashable
  func trailerPlayer(for item: any PlayableItem) -> any Hashable
  func seasons(for seasons: [Season]) -> any Hashable
  func season(for season: Season) -> any Hashable
  /// A filtered catalog (genre/country/year/etc.) opened from a detail page.
  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)?
  /// A person search (actor/director) opened from a detail page.
  func personSearch(query: String, field: String, title: String) -> (any Hashable)?
}

/// The one and only link provider: every section now navigates with the shared `Route` type.
struct RouteLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable { Route.details(item) }
  func player(for item: any PlayableItem) -> any Hashable { Route.player(item) }
  func trailerPlayer(for item: any PlayableItem) -> any Hashable { Route.trailerPlayer(item) }
  func seasons(for seasons: [Season]) -> any Hashable { Route.seasons(seasons) }
  func season(for season: Season) -> any Hashable { Route.season(season) }
  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)? {
    Route.filteredCatalog(filter, title)
  }
  func personSearch(query: String, field: String, title: String) -> (any Hashable)? {
    Route.personSearch(query, field, title)
  }
}
