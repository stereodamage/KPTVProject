//
//  Artwork.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubUI

/// A fixed-aspect, rounded, disk-cached image tile. The aspect box is laid out first, so tiles keep
/// their size while loading and long titles never push the artwork around.
struct Artwork: View {
  let url: String?
  var aspectRatio: CGFloat = 2.0 / 3.0
  var placeholderSymbol = "film"

  var body: some View {
    Rectangle()
      .fill(Color.white.opacity(0.08))
      .aspectRatio(aspectRatio, contentMode: .fit)
      .overlay {
        CachedAsyncImage(url: url.flatMap(URL.init(string:))) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          Image(systemName: placeholderSymbol)
            .font(.system(size: 60))
            .foregroundStyle(.white.opacity(0.25))
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: TVMetrics.cornerRadius, style: .continuous))
  }
}
