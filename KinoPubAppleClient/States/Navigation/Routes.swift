//
//  Routes.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

/// A single navigation route type shared by every section's `NavigationStack`.
///
/// Using one element type across all detail stacks is what keeps `NavigationSplitView` happy:
/// when the sidebar swaps the detail column from one section's stack to another, SwiftUI
/// reconciles the column's path against the new one. If the two stacks had *different* path
/// element types it traps with `AnyNavigationPath.Error.comparisonTypeMismatch`. With a single
/// `Route` type the comparison always succeeds, so no per-selection `.id` hack is needed.
enum Route: Hashable {
  case details(MediaItem)
  /// Open a media detail by id (used where only the id is known, e.g. the watching list).
  case detailsByID(Int)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  /// A filtered catalog (genre/country/year/etc.) opened from a detail page.
  case filteredCatalog(MediaItemsFilter, String)
  /// A person search (actor/director): (query, field, title).
  case personSearch(String, String, String)
  /// A genre browse grid: (genreId, title). genreId 0 means "all of this section".
  case genre(Int, String)
  case bookmark(Bookmark)
  case collection(Collection)
  /// A "see all" grid of already-loaded items (a search section opened in full): (items, title).
  case mediaList([MediaItem], String)
  /// A "see all" grid of people surfaced from a search (Cast & Crew): (people, title). Tapping a
  /// person opens their filmography, like the Cast & Crew on a film page / Apple TV.
  case castCrew([SearchPerson], String)
  /// A film's full Cast & Crew grouped by role: (film title, groups).
  case credits(String, [CreditGroup])

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(0); hasher.combine(item)
    case .detailsByID(let id):
      hasher.combine(1); hasher.combine(id)
    case .seasons(let seasons):
      hasher.combine(2); hasher.combine(seasons)
    case .season(let season):
      hasher.combine(3); hasher.combine(season)
    case .player(let item):
      hasher.combine(4); hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(5); hasher.combine(item.id)
    case .filteredCatalog(let filter, let title):
      hasher.combine(6); hasher.combine(filter); hasher.combine(title)
    case .personSearch(let query, let field, let title):
      hasher.combine(7); hasher.combine(query); hasher.combine(field); hasher.combine(title)
    case .genre(let id, let title):
      hasher.combine(8); hasher.combine(id); hasher.combine(title)
    case .bookmark(let bookmark):
      hasher.combine(9); hasher.combine(bookmark)
    case .collection(let collection):
      hasher.combine(10); hasher.combine(collection)
    case .mediaList(let items, let title):
      hasher.combine(11); hasher.combine(items); hasher.combine(title)
    case .castCrew(let people, let title):
      hasher.combine(12); hasher.combine(people); hasher.combine(title)
    case .credits(let title, let groups):
      hasher.combine(13); hasher.combine(title); hasher.combine(groups)
    }
  }

  static func == (lhs: Route, rhs: Route) -> Bool {
    switch (lhs, rhs) {
    case let (.details(a), .details(b)): return a == b
    case let (.detailsByID(a), .detailsByID(b)): return a == b
    case let (.seasons(a), .seasons(b)): return a == b
    case let (.season(a), .season(b)): return a == b
    case let (.player(a), .player(b)), let (.trailerPlayer(a), .trailerPlayer(b)): return a.id == b.id
    case let (.filteredCatalog(a, t1), .filteredCatalog(b, t2)): return a == b && t1 == t2
    case let (.personSearch(q1, f1, t1), .personSearch(q2, f2, t2)): return q1 == q2 && f1 == f2 && t1 == t2
    case let (.genre(a, t1), .genre(b, t2)): return a == b && t1 == t2
    case let (.bookmark(a), .bookmark(b)): return a == b
    case let (.collection(a), .collection(b)): return a == b
    case let (.mediaList(a, t1), .mediaList(b, t2)): return a == b && t1 == t2
    case let (.castCrew(a, t1), .castCrew(b, t2)): return a == b && t1 == t2
    case let (.credits(t1, a), .credits(t2, b)): return t1 == t2 && a == b
    default: return false
    }
  }
}
