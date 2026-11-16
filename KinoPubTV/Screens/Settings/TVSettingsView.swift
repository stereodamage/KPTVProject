//
//  TVSettingsView.swift
//  KinoPubTV
//
//  Laid out like the tvOS Settings app: account summary on the left, a focusable list on the right.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct TVSettingsView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    TVSettingsContent(model: ProfileModel(userService: appContext.userService,
                                          errorHandler: errorHandler,
                                          authState: authState))
  }
}

private struct TVSettingsContent: View {
  @StateObject private var model: ProfileModel
  @AppStorage(StreamQuality.userDefaultsKey) private var streamQuality: StreamQuality = .auto
  @AppStorage(TVSkipSegments.autoSkipKey) private var autoSkipIntro = false
  @State private var showLogout = false

  init(model: @autoclosure @escaping () -> ProfileModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    HStack(alignment: .center, spacing: 100) {
      account
        .frame(maxWidth: .infinity)
      List {
        Section {
          Picker("Maximum quality".localized, selection: $streamQuality) {
            ForEach(StreamQuality.allCases) { Text($0.title).tag($0) }
          }
          Toggle("Skip intros automatically".localized, isOn: $autoSkipIntro)
          NavigationLink("Streaming & device".localized, value: SettingsRoute.device)
        } header: {
          Text("Playback".localized)
        }
        Section {
          NavigationLink("Devices".localized, value: SettingsRoute.devices)
          NavigationLink("Storage".localized, value: SettingsRoute.storage)
        } header: {
          Text("Account".localized)
        }
        Section {
          NavigationLink("About".localized, value: SettingsRoute.about)
          Button(model.isLoggingOut ? "Signing out…".localized : "Sign out".localized, role: .destructive) {
            showLogout = true
          }
          .disabled(model.isLoggingOut)
        }
      }
      .pickerStyle(.navigationLink)
      // The focused row's platter grows past the list's bounds; clipping cut its left edge.
      .scrollClipDisabled()
      .frame(maxWidth: .infinity)
    }
    .navigationDestination(for: SettingsRoute.self) { route in
      switch route {
      case .device: TVDeviceSettingsView()
      case .devices: TVDevicesView()
      case .storage: TVStorageView()
      case .about: TVAboutView()
      }
    }
    .task { model.fetch() }
    .confirmationDialog("Sign out of kino.pub?".localized, isPresented: $showLogout) {
      Button("Sign out".localized, role: .destructive) { model.logout() }
      Button("Cancel".localized, role: .cancel) {}
    }
  }

  /// Left half, like the tvOS Settings app: a big emblem with the account summary under it.
  private var account: some View {
    let user = model.userData
    let since = Date(timeIntervalSince1970: user.registrationDate).formatted(date: .long, time: .omitted)
    return VStack(spacing: 40) {
      Image("AppLogo")
        .resizable()
        .scaledToFit()
        .frame(height: 260)
        .padding(70)
        .background(
          LinearGradient(colors: [Color(white: 0.24), Color(white: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
          in: RoundedRectangle(cornerRadius: 40, style: .continuous))
      VStack(spacing: 12) {
        Text(user.username).font(.title3.bold())
        Text("\(user.subscription.remainingDays) \("days".localized) · \(user.subscription.endDateFormatted)")
          .foregroundStyle(.secondary)
        Text("\("Member since".localized) \(since)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)
    }
    .redacted(reason: (user.skeleton ?? false) ? .placeholder : [])
  }
}

enum SettingsRoute: Hashable {
  case device, devices, storage, about
}

// MARK: - Streaming & device (server-side settings for this device)

private struct TVDeviceSettingsView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    Content(model: DeviceSettingsModel(deviceService: appContext.deviceService, errorHandler: errorHandler))
  }

  private struct Content: View {
    @StateObject var model: DeviceSettingsModel
    @State private var loaded = false

    init(model: @autoclosure @escaping () -> DeviceSettingsModel) {
      _model = StateObject(wrappedValue: model())
    }

    /// Saved automatically on every change — there's no Save button on a TV.
    private var signature: String {
      let s = model.settings
      return "\(s.streamingType)-\(s.serverLocation)-\(s.support4k)-\(s.supportHevc)-\(s.supportHdr)"
    }

    var body: some View {
      SettingsPage(title: "Streaming & device".localized,
                   footnote: "kino.pub applies changes within a minute.".localized) {
        if model.isLoading && !loaded {
          ProgressView()
        } else {
          List {
            if !model.deviceTitle.isEmpty {
              LabeledContent("Device".localized, value: model.deviceTitle)
            }
            Section {
              Picker("Stream type".localized, selection: $model.settings.streamingType) {
                ForEach(model.settings.streamingTypeOptions) { Text($0.label).tag($0.id) }
              }
              Picker("Server location".localized, selection: $model.settings.serverLocation) {
                ForEach(model.settings.serverLocationOptions) { Text($0.label).tag($0.id) }
              }
            }
            .pickerStyle(.navigationLink)
            Section("Formats".localized) {
              Toggle("4K", isOn: $model.settings.support4k)
              Toggle("HEVC", isOn: $model.settings.supportHevc)
              Toggle("HDR", isOn: $model.settings.supportHdr)
            }
          }
        }
      }
      .task {
        await model.load()
        loaded = true
      }
      .onChange(of: signature) { _, _ in
        if loaded { Task { await model.save() } }
      }
    }
  }
}

// MARK: - Devices

@MainActor
private final class TVDevicesModel: ObservableObject {
  @Published var devices: [ManagedDevice] = []
  @Published var currentId: Int?
  @Published var isLoading = true
  private let deviceService: DeviceService
  private let errorHandler: ErrorHandler

  init(deviceService: DeviceService, errorHandler: ErrorHandler) {
    self.deviceService = deviceService
    self.errorHandler = errorHandler
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    currentId = try? await deviceService.fetchCurrentDevice().id
    do {
      devices = try await deviceService.listDevices()
    } catch {
      errorHandler.setError(error)
    }
  }

  func remove(_ device: ManagedDevice) async {
    do {
      try await deviceService.removeDevice(id: device.id)
      devices.removeAll { $0.id == device.id }
    } catch {
      errorHandler.setError(error)
    }
  }
}

private struct TVDevicesView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    Content(model: TVDevicesModel(deviceService: appContext.deviceService, errorHandler: errorHandler))
  }

  private struct Content: View {
    @StateObject var model: TVDevicesModel
    @State private var pendingRemove: ManagedDevice?

    init(model: @autoclosure @escaping () -> TVDevicesModel) {
      _model = StateObject(wrappedValue: model())
    }

    var body: some View {
      SettingsPage(title: "Devices".localized,
                   footnote: "Select a device to remove it from your account.".localized) {
        if model.isLoading && model.devices.isEmpty {
          ProgressView()
        } else {
          List(model.devices, id: \.id) { device in
            Button {
              if device.id != model.currentId { pendingRemove = device }
            } label: {
              HStack(spacing: 24) {
                Image(systemName: (device.isBrowser ?? false) ? "globe" : "tv")
                  .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                  Text(Self.name(device))
                  if let detail = Self.detail(device) {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                  }
                }
                Spacer()
                if device.id == model.currentId {
                  Text("This device".localized).font(.caption).foregroundStyle(Color.KinoPub.accent)
                }
              }
            }
          }
        }
      }
      .task { await model.load() }
      .confirmationDialog(pendingRemove.map { Self.name($0) } ?? "",
                          isPresented: Binding(get: { pendingRemove != nil }, set: { if !$0 { pendingRemove = nil } })) {
        Button("Remove device".localized, role: .destructive) {
          if let device = pendingRemove { Task { await model.remove(device) } }
        }
        Button("Cancel".localized, role: .cancel) {}
      }
    }

    static func name(_ device: ManagedDevice) -> String {
      if device.isBrowser ?? false { return "Web browser".localized }
      let title = device.title?.trimmingCharacters(in: .whitespaces) ?? ""
      if !title.isEmpty { return title }
      let hardware = device.hardware?.trimmingCharacters(in: .whitespaces) ?? ""
      return hardware.isEmpty ? "Unknown device".localized : hardware
    }

    static func detail(_ device: ManagedDevice) -> String? {
      var parts: [String] = []
      if let software = device.software?.trimmingCharacters(in: .whitespaces), !software.isEmpty { parts.append(software) }
      if let last = device.lastSeen {
        parts.append(Date(timeIntervalSince1970: last).formatted(date: .abbreviated, time: .shortened))
      }
      return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
  }
}

// MARK: - Storage

private struct TVStorageView: View {
  @Environment(\.appContext) private var appContext
  @State private var imageBytes = Int64(ImageCache.shared.diskUsageBytes())
  @State private var guideBytes = EPGServiceImpl.diskUsageBytes()

  var body: some View {
    SettingsPage(title: "Storage".localized,
                 footnote: "tvOS may also clear these caches on its own when space runs low.".localized) {
      List {
        LabeledContent("Posters & artwork".localized, value: Self.format(imageBytes))
        LabeledContent("TV guide".localized, value: Self.format(guideBytes))
        Button("Clear cache".localized, role: .destructive) {
          ImageCache.shared.clear()
          Task {
            await appContext.epgService.clearCache()
            imageBytes = Int64(ImageCache.shared.diskUsageBytes())
            guideBytes = EPGServiceImpl.diskUsageBytes()
          }
        }
      }
    }
  }

  static func format(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}

// MARK: - About

private struct TVAboutView: View {
  private let repo = "https://github.com/dungeon-master-xx/kinopub-apple-client"

  var body: some View {
    SettingsPage(title: "About".localized,
                 footnote: "Community fork of leoru/kinopub-apple-client. Not affiliated with kino.pub.".localized) {
      HStack(spacing: 80) {
        VStack(alignment: .leading, spacing: 24) {
          Text("KinoPub for Apple TV").font(.title3.bold())
          Text("\("Version".localized) \(Bundle.main.appVersionLong) (\(Bundle.main.appBuild))")
            .foregroundStyle(.secondary)
          // SkipDB data is ODbL: attribution is required.
          Text("Skip data attribution".localized).font(.caption).foregroundStyle(.secondary)
          Text("Source code, issues and the install guide:".localized).padding(.top, 20)
          Text(repo.replacingOccurrences(of: "https://", with: ""))
            .font(.callout)
            .foregroundStyle(Color.KinoPub.accent)
        }
        QRCodeView(text: repo)
          .frame(width: 320, height: 320)
          .padding(24)
          .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      }
      // Gives the page something focusable so Menu/back and the sidebar keep working.
      .focusable()
    }
  }
}

/// Shared chrome for settings sub-pages: title, content, explanatory footnote.
private struct SettingsPage<Content: View>: View {
  let title: String
  var footnote: String?
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 40) {
      content()
        .scrollClipDisabled()
      if let footnote {
        Text(footnote).font(.caption).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: 1200, maxHeight: .infinity, alignment: .top)
    .frame(maxWidth: .infinity)
    .navigationTitle(title)
  }
}
