//
//  AuthView.swift
//  KinoPubTV
//

import SwiftUI

struct AuthView: View {
    @State private var deviceCode: DeviceCodeResponse?
    @State private var isLoading = false
    @State private var error: String?
    @State private var pollingTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "play.tv")
                .font(.system(size: 100))
                .foregroundColor(.accentColor)
            
            Text("KinoPub TV")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if isLoading && deviceCode == nil {
                ProgressView("Получение кода...")
            } else if let code = deviceCode {
                VStack(spacing: 20) {
                    Text("Для авторизации:")
                        .font(.headline)
                    
                    Text("1. Откройте \(code.verificationUri)")
                        .font(.title3)
                    
                    Text("2. Введите код:")
                        .font(.title3)
                    
                    Text(code.userCode)
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                    
                    ProgressView()
                        .padding(.top)
                    
                    Text("Ожидание авторизации...")
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = error {
                VStack(spacing: 10) {
                    Text(error)
                        .foregroundColor(.red)
                    
                    Button("Повторить") {
                        self.error = nil
                        Task {
                            await getDeviceCode()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(white: 0.85))
                    .foregroundStyle(.black)
                }
            }
        }
        .padding(100)
        .task {
            await getDeviceCode()
        }
        .onDisappear {
            pollingTask?.cancel()
        }
    }
    
    private func getDeviceCode() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await AuthService.shared.getDeviceCode()
            deviceCode = response
            startPolling(code: response.code, interval: response.interval)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func startPolling(code: String, interval: Int) {
        pollingTask?.cancel()
        
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                
                guard !Task.isCancelled else { break }
                
                do {
                    let tokenResponse = try await AuthService.shared.checkDeviceToken(code: code)
                    await MainActor.run {
                        AuthService.shared.saveTokens(tokenResponse)
                    }
                    break
                } catch let error as NetworkError {
                    // Continue polling for authorization_pending
                    if case .serverError(400) = error {
                        continue
                    }
                    await MainActor.run {
                        self.error = error.localizedDescription
                    }
                    break
                } catch {
                    // Continue polling
                    continue
                }
            }
        }
    }
}

#Preview {
    AuthView()
}
