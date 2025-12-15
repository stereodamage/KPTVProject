//
//  Pluralization.swift
//  KinoPubTV
//
//  Russian pluralization rules
//

import Foundation

extension Int {
    /// Returns the correct plural form for Russian language
    /// - Parameters:
    ///   - one: Form for 1 (e.g., "фильм")
    ///   - few: Form for 2-4 (e.g., "фильма")
    ///   - many: Form for 5+ and 0 (e.g., "фильмов")
    /// - Returns: Properly pluralized string
    func pluralized(one: String, few: String, many: String) -> String {
        let mod10 = self % 10
        let mod100 = self % 100
        
        if mod10 == 1 && mod100 != 11 {
            return "\(self) \(one)"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            return "\(self) \(few)"
        } else {
            return "\(self) \(many)"
        }
    }
}

enum RussianPlural {
    /// Pluralize "сезон" (season)
    static func seasons(_ count: Int) -> String {
        count.pluralized(one: "сезон", few: "сезона", many: "сезонов")
    }
    
    /// Pluralize "серия" (episode)
    static func episodes(_ count: Int) -> String {
        count.pluralized(one: "серия", few: "серии", many: "серий")
    }
    
    /// Pluralize "фильм" (movie)
    static func movies(_ count: Int) -> String {
        count.pluralized(one: "фильм", few: "фильма", many: "фильмов")
    }
    
    /// Pluralize "сериал" (series)
    static func series(_ count: Int) -> String {
        count.pluralized(one: "сериал", few: "сериала", many: "сериалов")
    }
    
    /// Pluralize "элемент" (item)
    static func items(_ count: Int) -> String {
        count.pluralized(one: "элемент", few: "элемента", many: "элементов")
    }
}
