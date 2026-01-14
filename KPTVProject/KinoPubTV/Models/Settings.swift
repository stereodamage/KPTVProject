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
        static let topShelfContent = "topShelfContent"
    }
    
    // MARK: - Backing Storage (for @Observable tracking)
    
    private var _streamingType: StreamingType
    private var _serverLocation: String?
    private var _preferredQuality: VideoQuality
    private var _ac3Default: Bool
    private var _autoPlayNextEpisode: Bool
    private var _showContinueAlert: Bool
    private var _playNextSeason: Bool
    private var _showRatingsOnPosters: Bool
    private var _useTMDBMetadata: Bool
    private var _topShelfContentType: TopShelfContentType
    
    // MARK: - Properties
    
    var streamingType: StreamingType {
        get { _streamingType }
        set {
            _streamingType = newValue
            defaults.set(newValue.rawValue, forKey: Keys.streamingType)
        }
    }
    
    var serverLocation: String? {
        get { _serverLocation }
        set {
            _serverLocation = newValue
            defaults.set(newValue, forKey: Keys.serverLocation)
        }
    }
    
    var preferredQuality: VideoQuality {
        get { _preferredQuality }
        set {
            _preferredQuality = newValue
            defaults.set(newValue.rawValue, forKey: Keys.quality)
        }
    }
    
    var ac3Default: Bool {
        get { _ac3Default }
        set {
            _ac3Default = newValue
            defaults.set(newValue, forKey: Keys.ac3Default)
        }
    }
    
    var autoPlayNextEpisode: Bool {
        get { _autoPlayNextEpisode }
        set {
            _autoPlayNextEpisode = newValue
            defaults.set(newValue, forKey: Keys.autoPlay)
        }
    }
    
    var showContinueAlert: Bool {
        get { _showContinueAlert }
        set {
            _showContinueAlert = newValue
            defaults.set(newValue, forKey: Keys.showContinueAlert)
        }
    }
    
    var playNextSeason: Bool {
        get { _playNextSeason }
        set {
            _playNextSeason = newValue
            defaults.set(newValue, forKey: Keys.playNextSeason)
        }
    }
    
    var showRatingsOnPosters: Bool {
        get { _showRatingsOnPosters }
        set {
            _showRatingsOnPosters = newValue
            defaults.set(newValue, forKey: Keys.showRatings)
        }
    }
    
    var useTMDBMetadata: Bool {
        get { _useTMDBMetadata }
        set {
            _useTMDBMetadata = newValue
            defaults.set(newValue, forKey: Keys.useTMDBMetadata)
        }
    }
    
    var topShelfContentType: TopShelfContentType {
        get { _topShelfContentType }
        set {
            _topShelfContentType = newValue
            defaults.set(newValue.rawValue, forKey: Keys.topShelfContent)
            Task {
                await TopShelfService.shared.updateTopShelf(contentType: newValue)
            }
        }
    }
    
    private init() {
        // Load all values from UserDefaults into backing storage
        if let raw = defaults.string(forKey: Keys.streamingType),
           let type = StreamingType(rawValue: raw) {
            _streamingType = type
        } else {
            _streamingType = .hls4
        }
        
        _serverLocation = defaults.string(forKey: Keys.serverLocation)
        
        if let raw = defaults.string(forKey: Keys.quality),
           let quality = VideoQuality(rawValue: raw) {
            _preferredQuality = quality
        } else {
            _preferredQuality = .best
        }
        
        _ac3Default = defaults.bool(forKey: Keys.ac3Default)
        _autoPlayNextEpisode = defaults.object(forKey: Keys.autoPlay) as? Bool ?? true
        _showContinueAlert = defaults.object(forKey: Keys.showContinueAlert) as? Bool ?? true
        _playNextSeason = defaults.object(forKey: Keys.playNextSeason) as? Bool ?? true
        _showRatingsOnPosters = defaults.object(forKey: Keys.showRatings) as? Bool ?? true
        _useTMDBMetadata = defaults.object(forKey: Keys.useTMDBMetadata) as? Bool ?? true
        
        if let raw = defaults.string(forKey: Keys.topShelfContent),
           let type = TopShelfContentType(rawValue: raw) {
            _topShelfContentType = type
        } else {
            _topShelfContentType = .continueWatching
        }
    }
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
