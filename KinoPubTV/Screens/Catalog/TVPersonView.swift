//
//  TVPersonView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

/// An actor's or director's filmography (opened from a cast lockup): portrait + paginated grid.
struct TVPersonView: View {
  let name: String
  /// `cast` or `director` — kino.pub's person filter field.
  let field: String
  let title: String

  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVPersonContent(model: SearchModel(itemsService: appContext.contentService,
                                       authState: authState,
                                       errorHandler: errorHandler),
                    name: name, field: field, title: title)
  }
}

private struct TVPersonContent: View {
  @StateObject private var model: SearchModel
  let name: String
  let field: String
  let title: String

  init(model: @autoclosure @escaping () -> SearchModel, name: String, field: String, title: String) {
    _model = StateObject(wrappedValue: model())
    self.name = name
    self.field = field
    self.title = title
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        HStack(spacing: 30) {
          PersonPortrait(name: name, size: 140)
          VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            Text((field == "director" ? "Director" : "Actor").localized)
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }

        if !model.searching && model.results.isEmpty {
          StatusView(systemImage: "person.crop.rectangle", title: "Nothing found".localized)
            .frame(maxWidth: .infinity, minHeight: 400)
        } else {
          PosterGrid(items: model.results, onAppearLast: loadMore) { PosterLockup(item: $0) }
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
    .task {
      guard model.results.isEmpty else { return }
      model.preset(query: name, field: field)
    }
  }

  private func loadMore() {
    guard let last = model.results.last else { return }
    model.loadMoreContent(after: last)
  }
}

/// Round headshot from kino.pub's actor CDN, with a silhouette fallback.
struct PersonPortrait: View {
  let name: String
  var size: CGFloat = 200

  var body: some View {
    CachedAsyncImage(url: ActorImageProvider.photoURL(for: name)) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      Image(systemName: "person.fill").font(.system(size: size * 0.35)).foregroundStyle(.white.opacity(0.3))
    }
    .frame(width: size, height: size)
    .background(Color.white.opacity(0.08))
    .clipShape(Circle())
  }
}
