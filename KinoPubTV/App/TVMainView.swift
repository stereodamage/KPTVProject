//
//  TVMainView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

enum TVTab: String, Hashable {
  case search, home, watching, movies, series, cartoons, catalog, bookmarks, history, collections, sport, settings
}

/// The tvOS 18 sidebar: collapses to a slim tab rail over full-bleed content and expands when the
/// remote moves left. Each tab owns its navigation stack, so Menu pops within the tab first.
struct TVMainView: View {
  @State private var tab: TVTab = Self.initialTab

  /// Debug builds can open straight on a section: launch with `-tvTab settings` (any `TVTab` name).
  private static var initialTab: TVTab {
#if DEBUG
    if let raw = UserDefaults.standard.string(forKey: "tvTab"), let tab = TVTab(rawValue: raw) { return tab }
#endif
    return .home
  }

  var body: some View {
    TabView(selection: $tab) {
      Tab("Search".localized, systemImage: "magnifyingglass", value: TVTab.search, role: .search) {
        TVStack { TVSearchView() }
      }
      Tab("Home".localized, systemImage: "house", value: TVTab.home) {
        TVStack { TVHomeView() }
      }
      Tab("Watching".localized, systemImage: "play.tv", value: TVTab.watching) {
        TVStack { TVWatchingView() }
      }
      TabSection("Catalog".localized) {
        Tab("Movies".localized, systemImage: "film", value: TVTab.movies) {
          TVStack { TVCatalogView(title: "Movies".localized, contentType: .movie) }
        }
        Tab("Series".localized, systemImage: "tv", value: TVTab.series) {
          TVStack { TVCatalogView(title: "Series".localized, contentType: .serial) }
        }
        Tab("Cartoons".localized, systemImage: "teddybear", value: TVTab.cartoons) {
          TVStack { TVCatalogView(title: "Cartoons".localized, filter: CatalogPreset.cartoons.filter) }
        }
        Tab("Categories".localized, systemImage: "square.grid.2x2", value: TVTab.catalog) {
          TVStack { TVCategoriesView() }
        }
      }
      TabSection("Library".localized) {
        Tab("Bookmarks".localized, systemImage: "bookmark", value: TVTab.bookmarks) {
          TVStack { TVBookmarksView() }
        }
        Tab("History".localized, systemImage: "clock.arrow.circlepath", value: TVTab.history) {
          TVStack { TVHistoryView() }
        }
        Tab("Collections".localized, systemImage: "square.stack", value: TVTab.collections) {
          TVStack { TVCollectionsView() }
        }
      }
      Tab("Sport".localized, systemImage: "sportscourt", value: TVTab.sport) {
        TVStack { TVSportView() }
      }
      Tab("Settings".localized, systemImage: "gearshape", value: TVTab.settings) {
        TVStack { TVSettingsView() }
      }
    }
    .tabViewStyle(.sidebarAdaptable)
  }
}

/// A tab's navigation stack with every `Route` destination registered.
struct TVStack<Root: View>: View {
  @ViewBuilder var root: () -> Root
  @State private var stack = TVStackModel()

  var body: some View {
    @Bindable var stack = stack
    NavigationStack(path: $stack.path) {
      root()
        .navigationDestination(for: Route.self) { route in
          // Set on each destination: values set on the NavigationStack do not reach pushed screens.
          TVRouteDestination(route: route)
            .environment(\.tvStackLevel, (stack.path.lastIndex(of: route) ?? stack.path.count - 1) + 1)
            .environment(stack)
        }
    }
    .environment(stack)
  }
}
