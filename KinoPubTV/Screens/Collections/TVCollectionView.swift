//
//  TVCollectionView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// One kino.pub collection as a poster grid with a sort menu.
struct TVCollectionView: View {
  let collection: Collection

  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVCollectionContent(model: CollectionDetailModel(collection: collection,
                                                     collectionsService: appContext.collectionsService,
                                                     errorHandler: errorHandler))
  }
}

private struct TVCollectionContent: View {
  @StateObject private var model: CollectionDetailModel
  @State private var loaded = false

  init(model: @autoclosure @escaping () -> CollectionDetailModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    TVCollectionPage(title: model.collection.title, items: model.items, isLoading: model.isLoading,
                     sort: $model.selectedSort)
      .task {
        guard !loaded else { return }
        loaded = true
        await model.fetchItems()
      }
  }
}

struct TVCollectionPage: View {
  let title: String
  let items: [MediaItem]
  let isLoading: Bool
  @Binding var sort: MediaItemsSort

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
          Text(title).font(.title2.bold()).lineLimit(1)
          if !isLoading {
            Text(verbatim: String(items.count)).font(.title3).foregroundStyle(.secondary)
          }
          Spacer()
          FilterMenu(title: "Sort".localized, value: sort.localizedTitle, systemImage: "arrow.up.arrow.down",
                     active: sort != .default) {
            Picker("Sort".localized, selection: $sort) {
              ForEach(MediaItemsSort.allCases) { Text($0.localizedTitle).tag($0) }
            }
          }
          .font(.callout)
          .lineLimit(1)
          .fixedSize()
        }
        .focusSection()

        if isLoading && items.isEmpty {
          ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        } else if items.isEmpty {
          StatusView(systemImage: "square.stack", title: "Nothing here yet".localized)
            .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          PosterGrid(items: items) { PosterLockup(item: $0) }
            .focusSection()
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
  }
}

#Preview {
  NavigationStack {
    TVCollectionPage(title: "Лучшие фильмы о космосе", items: (1...9).map { MediaItem.mock(id: $0) },
                     isLoading: false, sort: .constant(.default))
  }
}
