//
//  TVAuthView.swift
//  KinoPubTV
//
//  Device activation, TV style: no typing on the TV — scan the QR code (or open the URL) on a phone
//  and enter the code shown here. The screen flips to the app by itself once activation lands.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import KinoPubUI

struct TVAuthView: View {
  @StateObject private var model: AuthModel

  init(authState: AuthState, errorHandler: ErrorHandler) {
    _model = StateObject(wrappedValue: AuthModel(authService: AppContext.shared.authService,
                                                 authState: authState,
                                                 errorHandler: errorHandler))
  }

  var body: some View {
    HStack(alignment: .center, spacing: 120) {
      VStack(alignment: .leading, spacing: 48) {
        Text("Sign in to kino.pub".localized)
          .font(.title2.bold())

        step(1, "On your phone or computer, open".localized) {
          Text(model.activationDisplayURL.isEmpty ? "kino.pub/device" : model.activationDisplayURL)
            .font(.headline)
            .foregroundStyle(Color.KinoPub.accent)
        }

        step(2, "Enter this code".localized) {
          Text(model.deviceCode.isEmpty ? "······" : model.deviceCode)
            .font(.system(size: 110, weight: .bold, design: .monospaced))
            .kerning(16)
            .contentTransition(.numericText())
        }

        Text("This screen continues automatically once the device is activated.".localized)
          .font(.callout)
          .foregroundStyle(.secondary)

        Button {
          model.fetchDeviceCode()
        } label: {
          Label("Get a new code".localized, systemImage: "arrow.clockwise")
        }
      }
      .frame(maxWidth: 1000, alignment: .leading)

      VStack(spacing: 24) {
        QRCodeView(text: model.verificationURL.isEmpty ? "https://kino.pub/device" : model.verificationURL)
          .frame(width: 420, height: 420)
          .padding(30)
          .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        Text("Scan with your phone".localized)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.KinoPub.background.ignoresSafeArea())
    .task { model.fetchDeviceCode() }
    .onDisappear { model.cancelPolling() }
  }

  private func step<Content: View>(_ number: Int, _ title: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(alignment: .top, spacing: 28) {
      Text(verbatim: String(number))
        .font(.headline)
        .frame(width: 64, height: 64)
        .background(Color.white.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 12) {
        Text(title).font(.callout).foregroundStyle(.secondary)
        content()
      }
    }
  }
}

/// Crisp QR code rendered with Core Image (no network, no dependency).
struct QRCodeView: View {
  let text: String

  var body: some View {
    if let image = Self.render(text) {
      Image(decorative: image, scale: 1)
        .interpolation(.none)
        .resizable()
        .scaledToFit()
    }
  }

  private static func render(_ text: String) -> CGImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    return CIContext().createCGImage(output, from: output.extent)
  }
}
