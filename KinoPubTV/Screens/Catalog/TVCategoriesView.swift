//
//  TVCategoriesView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// The catalog sections that don't get their own sidebar entry, as a grid of card buttons.
/// Each opens the shared `TVCatalogView` with the section's type (+ genre for presets).
struct TVCategoriesView: View {
  struct Category: Identifiable {
    let title: String
    let systemImage: String
    let filter: MediaItemsFilter
    var id: String { title }
  }

  static let categories: [Category] = {
    let types: [MediaType] = [.documovie, .docuserial, .tvshow, .concert]
    let presets: [CatalogPreset] = [.cartoonSeries, .anime, .standup, .threeD]
    return presets.map { Category(title: $0.title.localized, systemImage: $0.systemImage, filter: $0.filter) }
      + types.map { Category(title: $0.title.localized, systemImage: $0.systemImage,
                             filter: MediaItemsFilter(contentType: $0, genres: [], countries: [])) }
  }()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        Text("Categories".localized).font(.title2.bold())
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TVMetrics.itemSpacing),
                                 count: TVMetrics.wideColumns),
                  spacing: TVMetrics.itemSpacing) {
          ForEach(Self.categories) { category in
            NavigationLink(value: Route.filteredCatalog(category.filter, category.title)) {
              // A clear 16:9 box takes the full column width; the card platter wraps it.
              Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                  VStack(spacing: 20) {
                    Image(systemName: category.systemImage).font(.system(size: 64))
                    Text(category.title)
                      .font(.headline)
                      .multilineTextAlignment(.center)
                      .lineLimit(2)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  .padding(24)
                }
            }
            .buttonStyle(.card)
          }
        }
      }
    }
    .scrollClipDisabled()
  }
}

#Preview {
  NavigationStack { TVCategoriesView() }
}
