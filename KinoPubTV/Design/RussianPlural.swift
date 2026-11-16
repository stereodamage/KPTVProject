//
//  RussianPlural.swift
//  KinoPubTV
//
//  The app is Russian-only, so counted nouns use Russian plural rules directly:
//  1 серия · 3 серии · 5 серий · 11 серий · 21 серия.
//

enum RussianPlural {
  static func format(_ count: Int, one: String, few: String, many: String) -> String {
    let mod10 = count % 10, mod100 = count % 100
    let word: String
    if mod10 == 1 && mod100 != 11 {
      word = one
    } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
      word = few
    } else {
      word = many
    }
    return "\(count) \(word)"
  }

  static func episodes(_ count: Int) -> String { format(count, one: "серия", few: "серии", many: "серий") }
}
