//
//  TVVersionPicker.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct TVVersionPicker: View {
  let videos: [Video]
  let onPick: (Video) -> Void

  var body: some View {
    let facts = FilmVersions.differingFacts(videos)
    VStack(alignment: .leading, spacing: 30) {
      Text("Choose a version".localized).font(.title2.bold())
      // A List inside a tvOS sheet collapses to one row's height; a VStack sizes the sheet to fit.
      VStack(spacing: 20) {
        ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
          Button { onPick(video) } label: {
            HStack(spacing: 30) {
              CachedAsyncImage(url: URL(string: video.thumbnail)) { image in
                image.resizable().scaledToFill()
              } placeholder: {
                Image(systemName: "film").foregroundStyle(.secondary)
              }
              .frame(width: 192, height: 108)
              .background(Color.white.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
              VStack(alignment: .leading, spacing: 6) {
                Text(FilmVersions.rowTitle(video)).font(.headline).lineLimit(1)
                if !facts[index].isEmpty {
                  Text(facts[index].joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
    .frame(width: 1000)
    .padding(60)
  }
}

#Preview {
  let json = """
  [{"id":1,"title":"Театральная версия","thumbnail":"","duration":8040,"tracks":1,"number":1,"ac3":0,
    "audios":[{"id":1,"index":0,"codec":"aac","channels":2,"lang":"rus"}],"watched":0,
    "watching":{"status":0,"time":0},"subtitles":[],
    "files":[{"codec":"h264","w":1920,"h":1080,"quality":"1080p","quality_id":3,
              "url":{"http":"","hls":"","hls4":"","hls2":""}}]},
   {"id":2,"title":"Режиссёрская версия","thumbnail":"","duration":9720,"tracks":1,"number":2,"ac3":0,
    "audios":[{"id":2,"index":0,"codec":"aac","channels":2,"lang":"rus"},
              {"id":3,"index":1,"codec":"aac","channels":2,"lang":"eng"}],"watched":0,
    "watching":{"status":0,"time":1200},"subtitles":[],
    "files":[{"codec":"hevc","w":3840,"h":2160,"quality":"2160p","quality_id":5,
              "url":{"http":"","hls":"","hls4":"","hls2":""}}]},
   {"id":3,"title":"","thumbnail":"","duration":8040,"tracks":1,"number":3,"ac3":0,
    "audios":[{"id":4,"index":0,"codec":"aac","channels":2,"lang":"rus"}],"watched":0,
    "watching":{"status":0,"time":0},"subtitles":[],
    "files":[{"codec":"h264","w":1920,"h":1080,"quality":"1080p","quality_id":3,
              "url":{"http":"","hls":"","hls4":"","hls2":""}}]}]
  """
  let videos = (try? JSONDecoder().decode([Video].self, from: Data(json.utf8))) ?? []
  return TVVersionPicker(videos: videos) { _ in }
}
