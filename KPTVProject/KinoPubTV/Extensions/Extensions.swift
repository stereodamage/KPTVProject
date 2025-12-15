//
//  Extensions.swift
//  KinoPubTV
//

import Foundation
import SwiftUI

// MARK: - tvOS Font Sizes

extension Font {
    /// tvOS-optimized font sizes for 10-foot UI
    struct TVSize {
        // Primary text sizes (readable from couch)
        static let title1: CGFloat = 76      // Large titles
        static let title2: CGFloat = 57      // Section headers
        static let title3: CGFloat = 48      // Subsection headers
        static let headline: CGFloat = 38    // Important text
        static let body: CGFloat = 29        // Body text (minimum for tvOS)
        static let callout: CGFloat = 31     // Secondary info
        static let subheadline: CGFloat = 29 // Tertiary info
        static let footnote: CGFloat = 25    // Small details
        static let caption: CGFloat = 23     // Metadata
        static let caption2: CGFloat = 20    // Smallest recommended
    }
    
    // Convenience methods for tvOS-optimized fonts
    static func tvTitle1(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.title1, weight: weight)
    }
    
    static func tvTitle2(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.title2, weight: weight)
    }
    
    static func tvTitle3(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.title3, weight: weight)
    }
    
    static func tvHeadline(weight: Font.Weight = .semibold) -> Font {
        .system(size: TVSize.headline, weight: weight)
    }
    
    static func tvBody(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.body, weight: weight)
    }
    
    static func tvCallout(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.callout, weight: weight)
    }
    
    static func tvSubheadline(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.subheadline, weight: weight)
    }
    
    static func tvFootnote(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.footnote, weight: weight)
    }
    
    static func tvCaption(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.caption, weight: weight)
    }
    
    static func tvCaption2(weight: Font.Weight = .regular) -> Font {
        .system(size: TVSize.caption2, weight: weight)
    }
}

// MARK: - Date Formatting

extension Date {
    func russianFormatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: self)
    }
    
    func russianFormattedWithTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: self)
    }
}

// MARK: - Duration Formatting

extension Int {
    var formattedDuration: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        
        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        } else {
            return "\(minutes)м"
        }
    }
}

// MARK: - String Extensions

extension String {
    var russianTitle: String {
        components(separatedBy: " / ").first ?? self
    }
    
    var originalTitle: String? {
        let parts = components(separatedBy: " / ")
        return parts.count > 1 ? parts[1] : nil
    }
}

// MARK: - Array Extensions

extension Array where Element == Item {
    func filterMovies() -> [Item] {
        filter { !$0.isSerial }
    }
    
    func filterSerials() -> [Item] {
        filter { $0.isSerial }
    }
}

// MARK: - URL Extensions

extension String {
    /// Converts HTTP URLs to HTTPS for App Transport Security compliance
    var secureURL: String {
        if hasPrefix("http://") {
            return replacingOccurrences(of: "http://", with: "https://")
        }
        return self
    }
}

extension URL {
    /// Creates a URL with HTTPS scheme if the original was HTTP
    static func secure(string: String?) -> URL? {
        guard let string = string else { return nil }
        return URL(string: string.secureURL)
    }
}

// MARK: - Audio Track Formatting

extension AudioTrack {
    /// Formats the audio track info like: "Дубляж (LostFilm) (RUS) (AC3)"
    /// Matches reference: titleParts.push(`${audio.type.title}`), titleParts.push(`${audio.author.title}`)
    var formattedDescription: String {
        var titleParts: [String] = []
        
        // Audio type (Дубляж, Многоголосый, etc.) - from type.title
        if let typeTitle = type?.title, !typeTitle.isEmpty {
            titleParts.append(typeTitle)
        }
        
        // Author (LostFilm, Видеосервис, etc.) - from author.title
        if let authorTitle = author?.title, !authorTitle.isEmpty {
            titleParts.append(authorTitle)
        }
        
        var result = titleParts.joined(separator: ". ")
        
        // Language code (RUS, ENG, etc.)
        if let langCode = lang, !langCode.isEmpty {
            result += result.isEmpty ? langCode.uppercased() : " (\(langCode.uppercased()))"
        }
        
        // Codec (AC3)
        if let codecStr = codec, codecStr.lowercased() == "ac3" {
            result += " (AC3)"
        }
        
        return result.isEmpty ? "Аудио \(index ?? 1)" : result
    }
    
    /// Formats with index prefix like: "01. Дубляж. LostFilm (RUS) (AC3)"
    func formattedWithIndex(_ idx: Int) -> String {
        let indexStr = String(format: "%02d", idx + 1)
        return "\(indexStr). \(formattedDescription)"
    }
    
    /// Formats as a single line for AVPlayer metadata: "Russian - AniLibria - AC3"
    var formattedForPlayer: String {
        var parts: [String] = []
        
        // Language name (full name instead of code)
        if let langCode = lang, !langCode.isEmpty {
            parts.append(LanguageHelper.localizedName(for: langCode))
        }
        
        // Author/studio name
        if let authorTitle = author?.title, !authorTitle.isEmpty {
            parts.append(authorTitle)
        } else if let typeTitle = type?.title, !typeTitle.isEmpty {
            // Fall back to type if no author
            parts.append(typeTitle)
        }
        
        // Codec
        if let codecStr = codec, !codecStr.isEmpty {
            parts.append(codecStr.uppercased())
        }
        
        return parts.isEmpty ? "Аудио \(index ?? 1)" : parts.joined(separator: " - ")
    }
    
    /// Formats for UI without codec (codec is shown as a separate tag)
    var formattedTitle: String {
        var parts: [String] = []
        
        if let langCode = lang, !langCode.isEmpty {
            parts.append(LanguageHelper.localizedName(for: langCode))
        }
        
        if let authorTitle = author?.title, !authorTitle.isEmpty {
            parts.append(authorTitle)
        } else if let typeTitle = type?.title, !typeTitle.isEmpty {
            parts.append(typeTitle)
        }
        
        return parts.isEmpty ? "Аудио \(index ?? 1)" : parts.joined(separator: " - ")
    }
}

// MARK: - Language Helper

struct LanguageHelper {
    static let languageNames: [String: String] = [
        "rus": "Русский",
        "eng": "Английский",
        "ukr": "Украинский",
        "fre": "Французский",
        "ger": "Немецкий",
        "spa": "Испанский",
        "ita": "Итальянский",
        "por": "Португальский",
        "fin": "Финский",
        "jpn": "Японский",
        "chi": "Китайский",
        "pol": "Польский",
        "swe": "Шведский",
        "nor": "Норвежский",
        "dut": "Голландский",
        "nld": "Нидерландский",
        "dan": "Датский",
        "kor": "Корейский",
        "hin": "Хинди",
        "heb": "Иврит",
        "gre": "Греческий",
        "hun": "Венгерский",
        "ice": "Исландский",
        "rum": "Молдавский",
        "slo": "Словацкий",
        "tur": "Турецкий",
        "cze": "Чешский",
        "ron": "Румынский",
        "baq": "Баскский",
        "fil": "Филиппинский",
        "glg": "Галицкий",
        "hrv": "Хорватский",
        "ind": "Индонезийский",
        "may": "Малайский",
        "nob": "Норвежский Бокмл",
        "tha": "Тайский",
        "vie": "Вьетнамский",
        "ara": "Арабский",
        "cat": "Каталонский",
        "lit": "Литовский",
        "lav": "Латышский",
        "est": "Эстонский",
        "slv": "Словенский",
        "bul": "Болгарский",
        "und": "Неопределённый",
        "unk": "Неопределённый"
    ]
    
    static func localizedName(for code: String) -> String {
        languageNames[code.lowercased()] ?? code.uppercased()
    }
}
