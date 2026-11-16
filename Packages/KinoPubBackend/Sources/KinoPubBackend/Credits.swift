import Foundation

/// kino.pub's person filter on `/v1/items`: only actors and directors have one.
public enum PersonFilter: String, Hashable, Sendable {
  case cast
  case director
}

public struct CreditPerson: Hashable, Identifiable, Sendable {
  /// The same for one person in every group ("kp-<staffId>" or "n-<name>").
  public let id: String
  public let name: String
  public let role: String?
  public let photo: String?
  public let filter: PersonFilter?

  public init(id: String, name: String, role: String?, photo: String?, filter: PersonFilter?) {
    self.id = id
    self.name = name
    self.role = role
    self.photo = photo
    self.filter = filter
  }
}

public struct CreditGroup: Hashable, Identifiable, Sendable {
  /// The Kinopoisk profession key, e.g. "ACTOR".
  public let id: String
  public let title: String
  public var people: [CreditPerson]

  public init(id: String, title: String, people: [CreditPerson]) {
    self.id = id
    self.title = title
    self.people = people
  }
}

/// Groups a film's cast and crew by role for the Cast & Crew screen and the detail row.
public enum Credits {
  private static let order = ["DIRECTOR", "ACTOR", "WRITER", "PRODUCER", "OPERATOR", "COMPOSER", "DESIGN", "EDITOR"]
  private static let titles = [
    "DIRECTOR": "Режиссёры", "ACTOR": "Актёры", "WRITER": "Сценаристы", "PRODUCER": "Продюсеры",
    "OPERATOR": "Операторы", "COMPOSER": "Композиторы", "DESIGN": "Художники", "EDITOR": "Монтажёры",
    "VOICE_DIRECTOR": "Режиссёры дубляжа", "TRANSLATOR": "Переводчики"
  ]

  public static func groups(staff: [KpStaffMember]) -> [CreditGroup] {
    var groups: [String: CreditGroup] = [:]
    var replyOrder: [String] = []
    for member in staff {
      let name = member.displayName
      guard !name.isEmpty else { continue }
      let key = member.professionKey ?? "OTHER"
      if groups[key] == nil {
        replyOrder.append(key)
        groups[key] = CreditGroup(id: key, title: titles[key] ?? nonEmpty(member.professionText) ?? key, people: [])
      }
      let id = "kp-\(member.staffId)"
      guard groups[key]?.people.contains(where: { $0.id == id }) == false else { continue }
      groups[key]?.people.append(CreditPerson(id: id, name: name, role: role(of: member, key: key),
                                              photo: nonEmpty(member.posterUrl), filter: filter(for: key)))
    }
    return sorted(replyOrder).compactMap { groups[$0] }
  }

  /// The fallback when Kinopoisk has no staff for the title: kino.pub's own director and cast names.
  public static func groups(directors: [String], cast: [String], photo: (String) -> String?) -> [CreditGroup] {
    func group(_ key: String, _ names: [String]) -> CreditGroup? {
      var seen = Set<String>()
      let people = names.compactMap { raw -> CreditPerson? in
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, seen.insert(name).inserted else { return nil }
        return CreditPerson(id: "n-\(name)", name: name, role: nil, photo: photo(name), filter: filter(for: key))
      }
      return people.isEmpty ? nil : CreditGroup(id: key, title: titles[key] ?? key, people: people)
    }
    return [group("DIRECTOR", directors), group("ACTOR", cast)].compactMap { $0 }
  }

  /// The detail screen's row: directors, then actors, each person once.
  public static func row(_ groups: [CreditGroup], directorRole: String, limit: Int = 30) -> [CreditPerson] {
    var seen = Set<String>()
    var row: [CreditPerson] = []
    for key in ["DIRECTOR", "ACTOR"] {
      for person in groups.first(where: { $0.id == key })?.people ?? [] where row.count < limit {
        guard seen.insert(person.id).inserted else { continue }
        row.append(key == "DIRECTOR"
                   ? CreditPerson(id: person.id, name: person.name, role: directorRole,
                                  photo: person.photo, filter: person.filter)
                   : person)
      }
    }
    return row
  }

  private static func sorted(_ keys: [String]) -> [String] {
    keys.enumerated()
      .sorted { lhs, rhs in
        let l = order.firstIndex(of: lhs.element) ?? order.count + lhs.offset
        let r = order.firstIndex(of: rhs.element) ?? order.count + rhs.offset
        return l < r
      }
      .map(\.element)
  }

  private static func role(of member: KpStaffMember, key: String) -> String? {
    guard key != "DIRECTOR" else { return nil }
    return nonEmpty(member.description.map(withoutCreditNote))
  }

  /// Drops Kinopoisk's «в титрах: …» note: "Choi (в титрах: Marc Gray)" → "Choi",
  /// "по декорациям, в титрах: X" → "по декорациям".
  private static func withoutCreditNote(_ text: String) -> String {
    let lower = text.lowercased()
    guard let range = lower.range(of: "в титрах") else { return text }
    var head = String(text[..<range.lowerBound])
    while let last = head.last, " ,;(".contains(last) { head.removeLast() }
    return head
  }

  private static func filter(for key: String) -> PersonFilter? {
    switch key {
    case "ACTOR": return .cast
    case "DIRECTOR": return .director
    default: return nil
    }
  }

  private static func nonEmpty(_ text: String?) -> String? {
    let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }
}
