//
//  TVHomeView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

struct TVHomeView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVHomeContent(model: HomeModel(itemsService: appContext.contentService,
                                   authState: authState,
                                   errorHandler: errorHandler))
  }
}

private struct TVHomeContent: View {
  @StateObject private var model: HomeModel

  init(model: @autoclosure @escaping () -> HomeModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        if !model.featured.isEmpty {
          Shelf {
            ForEach(model.featured) { item in
              FeaturedLockup(item: item).tileWidth(TVMetrics.featuredColumns)
            }
          }
        }

        if !model.continueWatching.isEmpty {
          Shelf(title: "Continue Watching".localized) {
            ForEach(model.continueWatching) { entry in
              WideLockup(imageURL: entry.item.posters.wide ?? entry.item.posters.big,
                         title: entry.item.localizedTitle,
                         subtitle: entry.subtitle,
                         progress: entry.progress,
                         watched: entry.finished,
                         value: Route.details(entry.item))
              .tileWidth(TVMetrics.wideColumns)
            }
          }
        }

        ForEach(model.shelves) { shelf in
          Shelf(title: shelf.title) {
            ForEach(shelf.items) { item in
              PosterLockup(item: item).tileWidth(TVMetrics.posterColumns)
            }
            if let filter = shelf.filter, !shelf.items.isEmpty {
              SeeAllLockup(value: .filteredCatalog(filter, shelf.title)).tileWidth(TVMetrics.posterColumns)
            }
          }
        }
      }
    }
    .scrollClipDisabled()
    .task {
      await model.fetchData()
    }
    // `.task` does not run again after a pop (e.g. back from the player), so reload when back on top.
    .refreshWhenOnTop(true) { Task { await model.fetchData() } }
  }
}
