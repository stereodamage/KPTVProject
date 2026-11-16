//
//  TVSearchView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// System tvOS search (on-screen keyboard + dictation) with results grouped into shelves.
struct TVSearchView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVSearchContent(model: SearchModel(itemsService: appContext.contentService,
                                       authState: authState,
                                       errorHandler: errorHandler))
  }
}

private struct TVSearchContent: View {
  @StateObject private var model: SearchModel

  init(model: @autoclosure @escaping () -> SearchModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        if model.query.trimmingCharacters(in: .whitespaces).count < 3 {
          if !model.recentItems.isEmpty {
            Shelf(title: "Recently viewed".localized) {
              ForEach(model.recentItems) { recent in
                PosterTile(imageURL: recent.poster, title: recent.title, subtitle: recent.subtitle,
                           value: Route.detailsByID(recent.id)) { EmptyView() }
                  .tileWidth(TVMetrics.posterColumns)
              }
            }
          }
        } else if model.searching && model.allResults.isEmpty {
          ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        } else if model.allResults.isEmpty {
          StatusView(systemImage: "magnifyingglass", title: "Nothing found".localized)
        } else {
          resultShelf("Titles".localized, model.titleResults)
          resultShelf("With actor".localized, model.castResults)
          resultShelf("By director".localized, model.directorResults)
        }
      }
    }
    .scrollClipDisabled()
    .searchable(text: $model.query, prompt: "Movies, series, people".localized)
  }

  @ViewBuilder
  private func resultShelf(_ title: String, _ items: [MediaItem]) -> some View {
    let real = items.filter { !($0.skeleton ?? false) }
    if !real.isEmpty {
      Shelf(title: "\(title) · \(real.count)") {
        ForEach(real) { item in
          PosterLockup(item: item).tileWidth(TVMetrics.posterColumns)
        }
      }
    }
  }
}
