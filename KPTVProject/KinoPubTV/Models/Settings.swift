//
//  Settings.swift
//  KinoPubTV
//

import Foundation

// MARK: - App Settings

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let streamingType = "userStreamingType"
        static let serverLocation = "userServerLocation"
        static let quality = "userQuality"
        static let ac3Default = "userAC3Default"
        static let autoPlay = "userAutoPlay"
        static let showContinueAlert = "showContinueAlert"
        static let playNextSeason = "playNextSeason"
        static let showRatings = "showRatings"
        static let useTMDBMetadata = "useTMDBMetadata"
    }
    
    // MARK: - Properties
    
    var streamingType: StreamingType {
        get {
            if let raw = defaults.string(forKey: Keys.streamingType),
               let type = StreamingType(rawValue: raw) {
                return type
            }
            return .hls4
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.streamingType) }
    }
    
    var serverLocation: String? {
        get { defaults.string(forKey: Keys.serverLocation) }
        set { defaults.set(newValue, forKey: Keys.serverLocation) }
    }
    
    var preferredQuality: VideoQuality {
        get {
            if let raw = defaults.string(forKey: Keys.quality),
               let quality = VideoQuality(rawValue: raw) {
                return quality
            }
            return .best
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.quality) }
    }
    
    var ac3Default: Bool {
        get { defaults.bool(forKey: Keys.ac3Default) }
        set { defaults.set(newValue, forKey: Keys.ac3Default) }
    }
    
    var autoPlayNextEpisode: Bool {
        get { defaults.object(forKey: Keys.autoPlay) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.autoPlay) }
    }
    
    var showContinueAlert: Bool {
        get { defaults.object(forKey: Keys.showContinueAlert) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showContinueAlert) }
    }
    
    var playNextSeason: Bool {
        get { defaults.object(forKey: Keys.playNextSeason) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.playNextSeason) }
    }
    
    var showRatingsOnPosters: Bool {
        get { defaults.object(forKey: Keys.showRatings) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showRatings) }
    }
    
    // MARK: - TMDB Settings
    
    var useTMDBMetadata: Bool {
        get { defaults.object(forKey: Keys.useTMDBMetadata) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.useTMDBMetadata) }
    }
    
    private init() {}
}

// MARK: - Streaming Type

enum StreamingType: String, CaseIterable {
    case hls4
    case hls2
    case hls
    case http
    
    var displayName: String {
        switch self {
        case .hls4: return "HLS4 (рекомендуется)"
        case .hls2: return "HLS2"
        case .hls: return "HLS"
        case .http: return "HTTP"
        }
    }
    
    var description: String {
        switch self {
        case .hls4: return "Адаптивный поток с несколькими аудиодорожками и субтитрами"
        case .hls2: return "Адаптивный поток, одна аудиодорожка, без субтитров"
        case .hls: return "Неадаптивный поток, одна аудиодорожка, без субтитров"
        case .http: return "Неадаптивный поток с несколькими аудиодорожками"
        }
    }
}

// MARK: - Video Quality

enum VideoQuality: String, CaseIterable {
    case best = "best"
    case fourK = "2160p"
    case fullHD = "1080p"
    case hd = "720p"
    case sd = "480p"
    
    var displayName: String {
        switch self {
        case .best: return "Лучшее"
        case .fourK: return "4K (2160p)"
        case .fullHD: return "Full HD (1080p)"
        case .hd: return "HD (720p)"
        case .sd: return "SD (480p)"
        }
    }
}
