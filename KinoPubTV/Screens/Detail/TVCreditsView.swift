//
//  TVCreditsView.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend

/// Full Cast & Crew: one titled grid of people per role.
struct TVCreditsView: View {
  let title: String
  var subtitle: String?
  let groups: [CreditGroup]

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: TVMetrics.shelfSpacing) {
        VStack(alignment: .leading, spacing: 8) {
          Text(title).font(.title2.bold()).lineLimit(1)
          if let subtitle {
            Text(subtitle).font(.title3).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        ForEach(groups) { group in
          VStack(alignment: .leading, spacing: 24) {
            if groups.count > 1 {
              Text(verbatim: "\(group.title) · \(group.people.count)").font(.headline).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TVMetrics.itemSpacing, alignment: .top),
                                     count: 7),
                      spacing: TVMetrics.shelfSpacing) {
              ForEach(group.people) { PersonLockup(person: $0) }
            }
          }
          .focusSection()
        }
      }
      .padding(.bottom, 60)
    }
    .scrollClipDisabled()
  }
}

#Preview {
  let staff = """
  [{"staffId": 1, "nameRu": "Лана Вачовски", "professionKey": "DIRECTOR"},
   {"staffId": 2, "nameRu": "Киану Ривз", "description": "Neo", "professionKey": "ACTOR"},
   {"staffId": 3, "nameRu": "Лоренс Фишбёрн", "description": "Morpheus", "professionKey": "ACTOR"},
   {"staffId": 4, "nameRu": "Кэрри-Энн Мосс", "description": "Trinity", "professionKey": "ACTOR"},
   {"staffId": 5, "nameRu": "Джоэл Сильвер", "professionKey": "PRODUCER"},
   {"staffId": 6, "nameRu": "Оуэн Патерсон", "description": "постановщик", "professionKey": "DESIGN"}]
  """
  let members = (try? JSONDecoder().decode([KpStaffMember].self, from: Data(staff.utf8))) ?? []
  return NavigationStack {
    TVCreditsView(title: "Актёры и съёмочная группа", subtitle: "Матрица", groups: Credits.groups(staff: members))
  }
}
