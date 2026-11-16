//
//  TVSportView.swift
//  KinoPubTV
//
//  Live sport channels as a TV guide: the channel list on the left (now playing + progress per row),
//  and the focused channel's schedule on the right. Select a channel to watch it full screen.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct TVSportView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVSportContent(model: SportModel(itemsService: appContext.contentService,
                                     epgService: appContext.epgService,
                                     authState: authState,
                                     errorHandler: errorHandler))
  }
}

private struct TVSportContent: View {
  @StateObject private var model: SportModel
  @FocusState private var focusedChannel: Int?

  init(model: @autoclosure @escaping () -> SportModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    // Re-evaluates now/next and the progress bars every 30 s.
    TimelineView(.periodic(from: .now, by: 30)) { context in
      let now = context.date
      if model.isLoading && model.channels.isEmpty {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if model.channels.isEmpty {
        StatusView(systemImage: "sportscourt", title: "No channels".localized)
      } else {
        HStack(alignment: .top, spacing: 80) {
          channelList(now: now)
            .frame(width: 900)
          if let channel = highlighted {
            ChannelSchedule(channel: channel, model: model, now: now)
              .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        }
      }
    }
    .navigationTitle("Sport".localized)
  }

  /// The channel the right-hand panel describes: the focused row, else the last one focused.
  private var highlighted: TVChannel? {
    if let id = focusedChannel, let channel = model.channels.first(where: { $0.id == id }) { return channel }
    return model.selectedChannel ?? model.channels.first
  }

  private func channelList(now: Date) -> some View {
    ScrollView {
      LazyVStack(spacing: 18) {
        ForEach(model.channels) { channel in
          NavigationLink(value: Route.player(channel)) {
            ChannelRow(channel: channel,
                       current: model.currentProgram(for: channel, at: now),
                       loadingGuide: model.isLoadingGuide,
                       hasGuide: model.hasGuide,
                       now: now)
          }
          .buttonStyle(.card)
          .focused($focusedChannel, equals: channel.id)
        }
      }
      .padding(.vertical, 20)
    }
    .scrollClipDisabled()
    .focusSection()
    .onChange(of: focusedChannel) { _, id in
      if let id, let channel = model.channels.first(where: { $0.id == id }) {
        model.selectedChannel = channel
      }
    }
  }
}

private struct ChannelRow: View {
  let channel: TVChannel
  let current: EPGProgram?
  let loadingGuide: Bool
  let hasGuide: Bool
  let now: Date

  var body: some View {
    HStack(spacing: 30) {
      ChannelLogo(url: channel.logo)
        .frame(width: 150, height: 90)
      VStack(alignment: .leading, spacing: 8) {
        Text(channel.title).font(.headline).lineLimit(1)
        if let current {
          Text(current.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          ProgressBar(value: current.progress(at: now))
            .frame(maxWidth: 420)
        } else if loadingGuide {
          Text("Loading guide…".localized).font(.caption).foregroundStyle(.secondary)
        } else if hasGuide {
          Text("No programme info".localized).font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
      Image(systemName: "dot.radiowaves.left.and.right")
        .foregroundStyle(.red)
        .font(.callout)
    }
    .padding(.horizontal, 30)
    .padding(.vertical, 22)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Right-hand panel: what's on now (large), then the rest of today's lineup with start times.
private struct ChannelSchedule: View {
  let channel: TVChannel
  @ObservedObject var model: SportModel
  let now: Date

  var body: some View {
    let upcoming = model.upcoming(for: channel, at: now, limit: 8)
    VStack(alignment: .leading, spacing: 36) {
      HStack(spacing: 30) {
        ChannelLogo(url: channel.logo).frame(width: 200, height: 120)
        VStack(alignment: .leading, spacing: 6) {
          Text(channel.title).font(.title3.bold())
          Label("Live".localized, systemImage: "circle.fill")
            .font(.caption.bold())
            .foregroundStyle(.red)
        }
      }

      if let current = upcoming.first, current.isLive(at: now) {
        VStack(alignment: .leading, spacing: 14) {
          Text("Now".localized.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
          Text(current.title).font(.headline).lineLimit(2)
          HStack(spacing: 20) {
            ProgressBar(value: current.progress(at: now)).frame(width: 400)
            Text(Self.minutesLeft(until: current.stop, from: now)).font(.caption).foregroundStyle(.secondary)
          }
        }
      }

      let later = upcoming.filter { !$0.isLive(at: now) }
      if !later.isEmpty {
        VStack(alignment: .leading, spacing: 18) {
          Text("Later".localized.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
          ForEach(later) { program in
            HStack(alignment: .firstTextBaseline, spacing: 30) {
              Text(program.start.formatted(date: .omitted, time: .shortened))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
              Text(program.title).font(.callout).lineLimit(1)
            }
          }
        }
      } else if upcoming.isEmpty {
        Text(model.isLoadingGuide ? "Loading guide…".localized : "No programme info for this channel.".localized)
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      if let updated = model.guideUpdatedAt {
        Text("\("Guide updated".localized) \(updated.formatted(date: .omitted, time: .shortened))")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .animation(.easeOut(duration: 0.2), value: channel.id)
  }

  static func minutesLeft(until stop: Date, from now: Date) -> String {
    let minutes = max(Int(stop.timeIntervalSince(now) / 60), 1)
    return String(format: "%d min left".localized, minutes)
  }
}

private struct ChannelLogo: View {
  let url: String?

  var body: some View {
    CachedAsyncImage(url: url.flatMap(URL.init(string:))) { image in
      image.resizable().scaledToFit()
    } placeholder: {
      Image(systemName: "tv").font(.system(size: 44)).foregroundStyle(.white.opacity(0.3))
    }
    .padding(10)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
