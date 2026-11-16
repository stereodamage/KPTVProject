//
//  TVCatalogView.swift
//  KinoPubTV
//
//  The one browse screen behind Movies / Series / Cartoons, the Categories hub, Home's "See All"
//  and genre links: a row of native tvOS filter menus above a paginated 6-column poster grid.
//  Filters are pop-up menus (not a form sheet) so each facet is one click away from the grid.
//

import SwiftUI
import KinoPubBackend

struct TVCatalogView: View {
  let title: String
  let filter: MediaItemsFilter

  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  init(title: String, filter: MediaItemsFilter) {
    self.title = title
    self.filter = filter
  }

  /// A whole section of one content type (e.g. the Movies tab).
  init(title: String, contentType: MediaType) {
    self.init(title: title, filter: MediaItemsFilter(contentType: contentType, genres: [], countries: []))
  }

  var body: some View {
    TVCatalogContent(catalog: MediaCatalog(itemsService: appContext.contentService,
                                           authState: authState,
                                           errorHandler: errorHandler,
                                           filter: filter),
                     title: title,
                     base: filter,
                     service: appContext.contentService)
  }
}

private struct TVCatalogContent: View {
  @StateObject private var catalog: MediaCatalog
  let title: String
  /// The filter the screen opened with. Facets it fixes (a preset's genre) aren't offered as menus,
  /// and "Clear" returns here rather than to an unfiltered catalog.
  let base: MediaItemsFilter
  let service: VideoContentService

  @State private var genres: [MediaGenre] = []
  @State private var countries: [Country] = []

  init(catalog: @autoclosure @escaping () -> MediaCatalog, title: String, base: MediaItemsFilter,
       service: VideoContentService) {
    _catalog = StateObject(wrappedValue: catalog())
    self.title = title
    self.base = base
    self.service = service
  }

  private var current: MediaItemsFilter { catalog.activeFilter ?? base }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        VStack(alignment: .leading, spacing: 30) {
          Text(title).font(.title2.bold())
          filterBar
        }
        .focusSection()

        if isEmptyResult {
          StatusView(systemImage: "line.3.horizontal.decrease.circle", title: "Nothing found".localized)
            .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          PosterGrid(items: catalog.items, onAppearLast: loadMore) { PosterLockup(item: $0) }
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
    .task { await loadOptions() }
  }

  private var isEmptyResult: Bool {
    catalog.items.isEmpty && catalog.pagination != nil
  }

  private func loadMore() {
    guard let last = catalog.items.last, !(last.skeleton ?? false),
          let page = catalog.pagination, page.current < page.total else { return }
    catalog.loadMoreContent(after: last)
  }

  private func loadOptions() async {
    guard genres.isEmpty else { return }
    async let g = try? service.fetchGenres(type: base.contentType)
    async let c = try? service.fetchCountries()
    genres = await g ?? []
    countries = (await c ?? []).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }

  // MARK: - Filter bar

  private var filterBar: some View {
    HStack(spacing: 24) {
      FilterMenu(title: "Sort".localized, value: catalog.sort.titleKey.localized,
                 systemImage: "arrow.up.arrow.down", active: catalog.sort != .updated) {
        Picker("Sort".localized, selection: $catalog.sort) {
          ForEach(SortOption.allCases) { Text($0.titleKey.localized).tag($0) }
        }
      }

      if base.genres.isEmpty, !genres.isEmpty {
        FilterMenu(title: "Genre".localized, value: genres.first { $0.id == current.genres.first }?.title,
                   systemImage: "theatermasks") {
          Picker("Genre".localized, selection: genreBinding) {
            Text("Any".localized).tag(Int?.none)
            ForEach(genres) { Text($0.title).tag(Int?.some($0.id)) }
          }
        }
      }

      if !countries.isEmpty {
        FilterMenu(title: "Country".localized,
                   value: countries.first { $0.id == current.countries.first }?.title,
                   systemImage: "globe") {
          Picker("Country".localized, selection: countryBinding) {
            Text("Any".localized).tag(Int?.none)
            ForEach(countries) { Text($0.title).tag(Int?.some($0.id)) }
          }
        }
      }

      FilterMenu(title: "Year".localized, value: YearRange.label(for: current.year), systemImage: "calendar") {
        Picker("Year".localized, selection: binding(\.year)) {
          Text("Any".localized).tag(String?.none)
          ForEach(YearRange.options, id: \.value) { Text($0.label).tag(String?.some($0.value)) }
        }
      }

      // IMDb where the title has it, Kinopoisk otherwise — the same rule the posters display.
      FilterMenu(title: "Rating".localized, value: current.ratingMin.map { "★ \(Int($0))+" },
                 systemImage: "star") {
        Picker("Rating".localized, selection: binding(\.ratingMin)) {
          Text("Any".localized).tag(Double?.none)
          ForEach([6.0, 7.0, 8.0], id: \.self) { Text(verbatim: "★ \(Int($0))+").tag(Double?.some($0)) }
        }
      }

      FilterMenu(title: "Quality".localized, value: qualityLabel, systemImage: "sparkles.tv") {
        Toggle("4K", isOn: binding(\.want4K))
        Toggle("HD", isOn: binding(\.wantHD))
        Toggle("5.1", isOn: binding(\.wantAC3))
      }

      if hasFacetsBeyondBase {
        Button("Clear".localized, systemImage: "xmark") { catalog.apply(filter: base) }
      }
    }
    .font(.callout)
  }

  private var qualityLabel: String? {
    let parts = [current.want4K ? "4K" : nil, current.wantHD ? "HD" : nil, current.wantAC3 ? "5.1" : nil]
      .compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// Sort is a separate control, so it's ignored when deciding whether facets were added.
  private var hasFacetsBeyondBase: Bool {
    var lhs = current, rhs = base
    lhs.sort = nil
    rhs.sort = nil
    return lhs != rhs
  }

  // MARK: - Bindings into the active filter

  private func update(_ change: (inout MediaItemsFilter) -> Void) {
    var next = current
    change(&next)
    guard next != current else { return }
    catalog.apply(filter: next)
  }

  private func binding<Value>(_ keyPath: WritableKeyPath<MediaItemsFilter, Value>) -> Binding<Value> {
    Binding(get: { current[keyPath: keyPath] },
            set: { value in update { $0[keyPath: keyPath] = value } })
  }

  private var genreBinding: Binding<Int?> {
    Binding(get: { current.genres.first },
            set: { id in update { $0.genres = id.map { [$0] } ?? [] } })
  }

  private var countryBinding: Binding<Int?> {
    Binding(get: { current.countries.first },
            set: { id in update { $0.countries = id.map { [$0] } ?? [] } })
  }
}

/// A filter as a pop-up menu button: shows the facet name, or its current value once set.
private struct FilterMenu<Content: View>: View {
  let title: String
  var value: String?
  let systemImage: String
  var active: Bool?
  @ViewBuilder var content: () -> Content

  var body: some View {
    Menu {
      content()
    } label: {
      Label(value ?? title, systemImage: systemImage)
        .fontWeight((active ?? (value != nil)) ? .semibold : .regular)
    }
  }
}

/// Year presets for the filter: the last few years individually, then decades.
enum YearRange {
  struct Option {
    let label: String
    let value: String
  }

  static let options: [Option] = {
    let year = Calendar.current.component(.year, from: Date())
    var result = (0..<3).map { Option(label: String(year - $0), value: String(year - $0)) }
    let decade = year / 10 * 10
    for start in stride(from: decade, through: 1980, by: -10) {
      result.append(Option(label: "\(start)–\(start + 9)", value: "\(start)-\(start + 9)"))
    }
    result.append(Option(label: "1900–1979", value: "1900-1979"))
    return result
  }()

  static func label(for value: String?) -> String? {
    guard let value else { return nil }
    return options.first { $0.value == value }?.label ?? value.replacingOccurrences(of: "-", with: "–")
  }
}
