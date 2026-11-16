//
//  TVCollectionsView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// The Collections tab: kino.pub's curated collections as a paged grid of cards, with a sort switch.
struct TVCollectionsView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVCollectionsContent(model: CollectionsModel(collectionsService: appContext.collectionsService,
                                                 authState: authState,
                                                 errorHandler: errorHandler))
  }
}

private struct TVCollectionsContent: View {
  @StateObject private var model: CollectionsModel

  init(model: @autoclosure @escaping () -> CollectionsModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    TVCollectionsPage(collections: model.collections, isLoading: model.isLoading, sort: $model.selectedSort) {
      if let last = model.collections.last { model.loadMoreContent(after: last) }
    }
  }
}

struct TVCollectionsPage: View {
  let collections: [Collection]
  let isLoading: Bool
  @Binding var sort: CollectionsSort
  var onAppearLast: () -> Void = {}

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        Text("Collections".localized).font(.title2.bold())
        Picker("", selection: $sort) {
          ForEach(CollectionsSort.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .focusSection()

        if collections.isEmpty {
          if isLoading {
            ProgressView().frame(maxWidth: .infinity, minHeight: 400)
          } else {
            StatusView(systemImage: "square.stack", title: "Nothing here yet".localized)
              .frame(maxWidth: .infinity, minHeight: 400)
          }
        } else {
          PosterGrid(items: collections, columns: TVMetrics.wideColumns, onAppearLast: onAppearLast) { collection in
            WideLockup(imageURL: collection.posters?.big ?? collection.posters?.medium,
                       title: collection.title,
                       subtitle: collection.itemsCount.map(String.init),
                       value: Route.collection(collection))
          }
          .focusSection()
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
  }
}

#Preview {
  let collections = (1...8).map { Collection(id: $0, title: "Лучшие фильмы о космосе", itemsCount: 20 + $0) }
  return NavigationStack {
    TVCollectionsPage(collections: collections, isLoading: false, sort: .constant(.new))
  }
}
