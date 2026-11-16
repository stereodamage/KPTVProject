import Foundation
import XCTest
@testable import KinoPubBackend

final class CreditsTests: XCTestCase {

  /// Cut from the live kpapp.link staff reply for film 301, plus edge cases (reply order kept).
  private let json = """
  [
    {"staffId": 23330, "nameRu": "Лана Вачовски", "nameEn": "Lana Wachowski", "description": "в титрах: The Wachowski Brothers", "posterUrl": "https://kp/23330.jpg", "professionText": "Режиссеры", "professionKey": "DIRECTOR"},
    {"staffId": 7836, "nameRu": "Киану Ривз", "nameEn": "Keanu Reeves", "description": "Neo", "posterUrl": "https://kp/7836.jpg", "professionText": "Актеры", "professionKey": "ACTOR"},
    {"staffId": 23330, "nameRu": "Лана Вачовски", "nameEn": "Lana Wachowski", "description": "камео", "posterUrl": "https://kp/23330.jpg", "professionText": "Актеры", "professionKey": "ACTOR"},
    {"staffId": 7836, "nameRu": "Киану Ривз", "nameEn": "Keanu Reeves", "description": "Neo", "posterUrl": "https://kp/7836.jpg", "professionText": "Актеры", "professionKey": "ACTOR"},
    {"staffId": 555, "nameRu": null, "nameEn": "John Doe", "description": " ", "posterUrl": "", "professionText": "Актеры", "professionKey": "ACTOR"},
    {"staffId": 556, "nameRu": "", "nameEn": "", "description": "Agent", "posterUrl": null, "professionText": "Актеры", "professionKey": "ACTOR"},
    {"staffId": 23330, "nameRu": "Лана Вачовски", "nameEn": "Lana Wachowski", "description": "", "posterUrl": "https://kp/23330.jpg", "professionText": "Продюсеры", "professionKey": "PRODUCER"},
    {"staffId": 777, "nameRu": "Ярослава Турылёва", "nameEn": null, "description": null, "posterUrl": null, "professionText": "Режиссеры дубляжа", "professionKey": "VOICE_DIRECTOR"},
    {"staffId": 23330, "nameRu": "Лана Вачовски", "nameEn": "Lana Wachowski", "description": "в титрах: The Wachowski Brothers", "posterUrl": "https://kp/23330.jpg", "professionText": "Сценаристы", "professionKey": "WRITER"},
    {"staffId": 999, "nameRu": "Оуэн Патерсон", "nameEn": "Owen Paterson", "description": "постановщик", "posterUrl": null, "professionText": "Художники", "professionKey": "DESIGN"}
  ]
  """

  private func staff() throws -> [KpStaffMember] {
    try JSONDecoder().decode([KpStaffMember].self, from: Data(json.utf8))
  }

  private func group(_ groups: [CreditGroup], _ id: String) -> CreditGroup? {
    groups.first { $0.id == id }
  }

  func testGroupOrder_KnownRolesFirstThenReplyOrder() throws {
    let groups = Credits.groups(staff: try staff())
    XCTAssertEqual(groups.map(\.id), ["DIRECTOR", "ACTOR", "WRITER", "PRODUCER", "DESIGN", "VOICE_DIRECTOR"])
  }

  func testGroupTitles_OwnForKnownRoles_ServerTextOtherwise() throws {
    let groups = Credits.groups(staff: try staff())
    XCTAssertEqual(group(groups, "DIRECTOR")?.title, "Режиссёры")
    XCTAssertEqual(group(groups, "ACTOR")?.title, "Актёры")
    XCTAssertEqual(group(groups, "VOICE_DIRECTOR")?.title, "Режиссёры дубляжа")
  }

  func testActors_DedupedByStaffId_EmptyNamesSkipped() throws {
    let actors = group(Credits.groups(staff: try staff()), "ACTOR")?.people ?? []
    XCTAssertEqual(actors.map(\.name), ["Киану Ривз", "Лана Вачовски", "John Doe"])
  }

  func testRoles() throws {
    let groups = Credits.groups(staff: try staff())
    XCTAssertEqual(group(groups, "ACTOR")?.people.first?.role, "Neo")
    XCTAssertNil(group(groups, "ACTOR")?.people.last?.role, "blank description → nil")
    XCTAssertNil(group(groups, "DIRECTOR")?.people.first?.role, "the group title says it")
    XCTAssertNil(group(groups, "WRITER")?.people.first?.role, "a credit note is not a role")
    XCTAssertEqual(group(groups, "DESIGN")?.people.first?.role, "постановщик")
  }

  func testRoles_CreditNotesRemovedInsideText() {
    func role(_ text: String, _ key: String) -> String? {
      let member = try? JSONDecoder().decode(KpStaffMember.self, from: Data("""
        {"staffId": 1, "nameRu": "X", "description": "\(text)", "professionKey": "\(key)"}
        """.utf8))
      return member.flatMap { Credits.groups(staff: [$0]).first?.people.first?.role }
    }
    XCTAssertEqual(role("Choi (в титрах: Marc Gray)", "ACTOR"), "Choi")
    XCTAssertEqual(role("по декорациям, в титрах: Lisa Brennan", "DESIGN"), "по декорациям")
    XCTAssertNil(role("(в титрах: Marc Gray)", "ACTOR"))
  }

  func testGroupTitles_KnownExtraRolesUseYo() {
    let groups = Credits.groups(staff: (try? JSONDecoder().decode([KpStaffMember].self, from: Data("""
      [{"staffId": 1, "nameRu": "A", "professionText": "Режиссеры дубляжа", "professionKey": "VOICE_DIRECTOR"},
       {"staffId": 2, "nameRu": "B", "professionText": "Переводчики", "professionKey": "TRANSLATOR"}]
      """.utf8))) ?? [])
    XCTAssertEqual(groups.map(\.title), ["Режиссёры дубляжа", "Переводчики"])
  }

  func testFiltersAndPhotos() throws {
    let groups = Credits.groups(staff: try staff())
    XCTAssertEqual(group(groups, "ACTOR")?.people.first?.filter, .cast)
    XCTAssertEqual(group(groups, "DIRECTOR")?.people.first?.filter, .director)
    XCTAssertNil(group(groups, "PRODUCER")?.people.first?.filter)
    XCTAssertEqual(group(groups, "ACTOR")?.people.first?.photo, "https://kp/7836.jpg")
    XCTAssertNil(group(groups, "ACTOR")?.people.last?.photo, "empty URL → nil")
  }

  func testPersonIdIsTheSameInEveryGroup() throws {
    let groups = Credits.groups(staff: try staff())
    XCTAssertEqual(group(groups, "DIRECTOR")?.people.first?.id, group(groups, "WRITER")?.people.first?.id)
  }

  func testRow_DirectorsThenActors_EachPersonOnce() throws {
    let row = Credits.row(Credits.groups(staff: try staff()), directorRole: "Режиссёр")
    XCTAssertEqual(row.map(\.name), ["Лана Вачовски", "Киану Ривз", "John Doe"])
    XCTAssertEqual(row.first?.role, "Режиссёр")
    XCTAssertEqual(row.first?.filter, .director)
  }

  func testRow_Limit() throws {
    let row = Credits.row(Credits.groups(staff: try staff()), directorRole: "Режиссёр", limit: 2)
    XCTAssertEqual(row.count, 2)
  }

  func testRow_EmptyWhenOnlyCrew() {
    let groups = [CreditGroup(id: "PRODUCER", title: "Продюсеры",
                              people: [CreditPerson(id: "kp-1", name: "A", role: nil, photo: nil, filter: nil)])]
    XCTAssertTrue(Credits.row(groups, directorRole: "Режиссёр").isEmpty)
  }

  func testFallbackFromKinoPubNames() {
    let groups = Credits.groups(directors: ["Джеймс Ганн", " "], cast: ["Крис Пратт", "Зои Салдана", "Крис Пратт"],
                                photo: { "https://cdn/\($0)" })
    XCTAssertEqual(groups.map(\.id), ["DIRECTOR", "ACTOR"])
    XCTAssertEqual(groups[0].people.map(\.name), ["Джеймс Ганн"])
    XCTAssertEqual(groups[0].people.first?.filter, .director)
    XCTAssertEqual(groups[1].people.map(\.name), ["Крис Пратт", "Зои Салдана"])
    XCTAssertEqual(groups[1].people.first?.photo, "https://cdn/Крис Пратт")
    XCTAssertEqual(groups[1].people.first?.filter, .cast)
  }

  func testFallback_NoDirectorsGivesOnlyActors() {
    let groups = Credits.groups(directors: [], cast: ["Крис Пратт"], photo: { _ in nil })
    XCTAssertEqual(groups.map(\.id), ["ACTOR"])
  }
}
