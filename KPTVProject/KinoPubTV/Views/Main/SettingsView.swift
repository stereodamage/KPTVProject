//
//  SettingsView.swift
//  KinoPubTV
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var settings = AppSettings.shared
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // Playback Settings Section
                Section("Настройки воспроизведения") {
                    // Streaming Type - now as navigation link to picker
                    NavigationLink {
                        List {
                            ForEach(StreamingType.allCases, id: \.self) { type in
                                Button {
                                    settings.streamingType = type
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(type.displayName)
                                            Text(type.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if settings.streamingType == type {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                        .navigationTitle("Тип потока")
                    } label: {
                        LabeledContent("Тип потока", value: settings.streamingType.displayName)
                    }
                    
                    // Video Quality - now as navigation link to picker
                    NavigationLink {
                        List {
                            ForEach(VideoQuality.allCases, id: \.self) { quality in
                                Button {
                                    settings.preferredQuality = quality
                                } label: {
                                    HStack {
                                        Text(quality.displayName)
                                        Spacer()
                                        if settings.preferredQuality == quality {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                        .navigationTitle("Качество видео")
                    } label: {
                        LabeledContent("Качество видео", value: settings.preferredQuality.displayName)
                    }
                    
                    // AC3 Default
                    Toggle("AC3 по умолчанию", isOn: $settings.ac3Default)
                    
                    // Auto Play
                    Toggle("Автовоспроизведение следующей серии", isOn: $settings.autoPlayNextEpisode)
                    
                    // Continue Alert
                    Toggle("Спрашивать о продолжении просмотра", isOn: $settings.showContinueAlert)
                    
                    // Play Next Season
                    Toggle("Автовоспроизведение следующего сезона", isOn: $settings.playNextSeason)
                }
                
                // Display Settings Section
                Section("Настройки отображения") {
                    Toggle("Показывать рейтинги на постерах", isOn: $settings.showRatingsOnPosters)
                }
                
                // TMDB Integration Section
                Section {
                    Toggle("Использовать метаданные TMDB", isOn: $settings.useTMDBMetadata)
                } header: {
                    Text("TMDB интеграция")
                } footer: {
                    Text("TMDB предоставляет названия эпизодов, описания и изображения на русском языке")
                }
                
                // Device Section
                Section("Устройство") {
                    if let device = viewModel.device {
                        LabeledContent("Название", value: device.title ?? "KinoPubTV")
                    }
                }
                
                // User Info Section - now as NavigationLink
                Section {
                    NavigationLink {
                        List {
                            if let user = viewModel.user {
                                LabeledContent("Пользователь", value: user.username)
                                
                                if let regDate = viewModel.registrationDate {
                                    LabeledContent("Дата регистрации", value: formatDate(regDate))
                                }
                                
                                if let endDate = viewModel.subscriptionEndDate {
                                    LabeledContent("Подписка до", value: formatDate(endDate))
                                }
                                
                                LabeledContent("Осталось дней", value: "\(viewModel.subscriptionDaysLeft)")
                            } else {
                                HStack {
                                    Text("Загрузка...")
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .navigationTitle("Данные о пользователе")
                    } label: {
                        HStack {
                            Label("Данные о пользователе", systemImage: "person.circle")
                            Spacer()
                            if let user = viewModel.user {
                                Text(user.username)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // App Data Section (Stats for Nerds style)
                Section {
                    NavigationLink {
                        List {
                            LabeledContent("Версия", value: viewModel.appVersion)
                            LabeledContent("Сборка", value: viewModel.buildNumber)
                            
                            if let device = viewModel.device {
                                LabeledContent("ID устройства", value: "\(device.id)")
                            }
                            
                            LabeledContent("tvOS", value: UIDevice.current.systemVersion)
                            LabeledContent("Модель", value: deviceModel())
                        }
                        .navigationTitle("Данные о приложении")
                    } label: {
                        Label("Данные о приложении", systemImage: "info.circle")
                    }
                }
                
                // Actions Section
                Section {
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        Text("Выйти из аккаунта")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                    .tint(.red)
                }
            }
            .listStyle(.grouped)
            .navigationTitle("Настройки")
            .alert("Ошибка", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .alert("Выход", isPresented: $showingLogoutAlert) {
                Button("Выйти", role: .destructive) {
                    viewModel.logout()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Вы уверены, что хотите выйти из аккаунта?")
            }
            .task {
                await viewModel.loadUserInfo()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

#Preview {
    SettingsView()
}
