//
//  DeviceSettingsModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class DeviceSettingsModel: ObservableObject {

  private var deviceService: DeviceService
  private var errorHandler: ErrorHandler
  private var deviceId: Int?
  private var saveChain: Task<Void, Never>?
  private var knownSignature: String?

  @Published var settings: DeviceSettings = DeviceSettings()
  @Published var isLoading: Bool = false
  @Published var isSaving: Bool = false
  @Published var deviceTitle: String = ""
  /// The settings did not load: saving now would write the defaults over the user's real settings.
  @Published var loadFailed: Bool = false
  /// Flips true briefly after a successful save to drive the "Saved" confirmation toast.
  @Published var didSave: Bool = false

  init(deviceService: DeviceService, errorHandler: ErrorHandler) {
    self.deviceService = deviceService
    self.errorHandler = errorHandler
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      #if DEBUG
      if UserDefaults.standard.bool(forKey: "tvFailSettingsLoad") { throw URLError(.cannotLoadFromNetwork) }
      #endif
      let device = try await deviceService.fetchCurrentDevice()
      deviceTitle = device.title ?? ""
      settings = try await deviceService.fetchSettings(deviceId: device.id)
      deviceId = device.id
      knownSignature = signature
      loadFailed = false
    } catch {
      Logger.app.debug("load device settings error: \(error)")
      deviceId = nil
      loadFailed = true
      errorHandler.setError(error)
    }
  }

  var signature: String {
    "\(settings.streamingType)-\(settings.serverLocation)-\(settings.support4k)-\(settings.supportHevc)-\(settings.supportHdr)"
  }

  /// Each save waits for the earlier ones and sends the settings as they are when it runs.
  func enqueueSave() {
    guard deviceId != nil, !loadFailed, signature != knownSignature else { return }
    knownSignature = signature
    let previous = saveChain
    saveChain = Task {
      await previous?.value
      await save()
    }
  }

  func save() async {
    guard let deviceId, !loadFailed else { return }
    Logger.app.debug("save device settings: \(String(describing: self.settings))")
    isSaving = true
    defer { isSaving = false }
    do {
      try await deviceService.updateSettings(deviceId: deviceId, settings: settings)
      // Keep what the user chose (optimistic). We intentionally do NOT re-fetch here: the server
      // can be briefly eventually-consistent, and re-reading stale values made the toggles appear
      // to "reset" right after saving.
      confirmSaved()
    } catch {
      Logger.app.debug("save device settings error: \(error)")
      errorHandler.setError(error)
    }
  }

  /// iOS-standard success feedback: a success haptic plus a brief "Saved" confirmation toast.
  private func confirmSaved() {
    #if os(iOS)
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    #endif
    didSave = true
    Task {
      try? await Task.sleep(nanoseconds: 1_800_000_000)
      didSave = false
    }
  }
}
