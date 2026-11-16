//
//  TVRouteDestination.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// Resolves a `Route` into a tvOS screen, building its model from the app context.
struct TVRouteDestination: View {
  let route: Route

  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    switch route {
    case .details(let item):
      detail(id: item.id)
    case .detailsByID(let id):
      detail(id: id)
    case .player(let item):
      TVPlayerView(session: session(item, mode: .media))
    case .trailerPlayer(let item):
      TVPlayerView(session: session(item, mode: .trailer))
    case .mediaList(let items, let title):
      TVMediaListView(title: title, items: items)
    case .filteredCatalog(let filter, let title):
      TVCatalogView(title: title, filter: filter)
    case .genre(let id, let title):
      // A non-positive id means "the whole section" (no genre facet).
      TVCatalogView(title: title,
                    filter: MediaItemsFilter(contentType: .movie, genres: id > 0 ? [id] : [], countries: []))
    case .personSearch(let name, let field, let title):
      TVPersonView(name: name, field: field, title: title)
    default:
      TVComingSoon()
    }
  }

  private func session(_ item: any PlayableItem, mode: WatchMode) -> TVPlaybackSession {
    let context = appContext
    let make: (any PlayableItem) -> PlayerManager = { item in
      PlayerManager(playItem: item, watchMode: mode,
                    downloadedFilesDatabase: context.downloadedFilesDatabase,
                    actionsService: context.actionsService)
    }
    return TVPlaybackSession(manager: make(item), makeManager: make)
  }

  private func detail(id: Int) -> some View {
    TVDetailView(model: MediaItemModel(mediaItemId: id,
                                       itemsService: appContext.contentService,
                                       downloadManager: appContext.downloadManager,
                                       linkProvider: RouteLinkProvider(),
                                       errorHandler: errorHandler))
  }
}

/// A plain titled grid of posters (e.g. "See All" for a shelf).
struct TVMediaListView: View {
  let title: String
  let items: [MediaItem]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        Text(title).font(.title2.bold())
        PosterGrid(items: items) { PosterLockup(item: $0) }
      }
    }
    .scrollClipDisabled()
  }
}
