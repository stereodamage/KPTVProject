//
//  PersonLockup.swift
//  KinoPubTV
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

/// A person as a round photo with name and role. Actors and directors open their kino.pub filmography;
/// other crew has no kino.pub filter, so their card only takes focus (the remote must reach every card).
/// The card draws its own focus lift: tvOS's button styles put a rounded-square plate behind the circle.
struct PersonLockup: View {
  let person: CreditPerson
  @FocusState private var focused: Bool

  var body: some View {
    if let filter = person.filter {
      NavigationLink(value: Route.personSearch(person.name, filter.rawValue, person.name)) {
        PersonCard(person: person, focused: focused)
      }
      .buttonStyle(LiftlessButtonStyle())
      .focused($focused)
    } else {
      PersonCard(person: person, focused: focused)
        .focusable()
        .focused($focused)
    }
  }
}

private struct PersonCard: View {
  let person: CreditPerson
  let focused: Bool

  var body: some View {
    VStack(spacing: 16) {
      CachedAsyncImage(url: person.photo.flatMap(URL.init(string:))) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Image(systemName: "person.fill").font(.system(size: 70)).foregroundStyle(.white.opacity(0.3))
      }
      .frame(width: 200, height: 200)
      .background(Color.white.opacity(focused ? 0.2 : 0.08))
      .clipShape(Circle())
      .circleFocusLift(focused)
      VStack(spacing: 4) {
        Text(person.name).font(.caption).lineLimit(1)
        if let role = person.role, !role.isEmpty {
          Text(role).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
      }
    }
    .frame(width: 220)
  }
}

/// A button with no system focus effect: the label draws its own lift (built-in styles add a platter).
private struct LiftlessButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    configuration.label
  }
}

private extension View {
  func circleFocusLift(_ focused: Bool) -> some View {
    scaleEffect(focused ? 1.1 : 1)
      .shadow(color: .black.opacity(focused ? 0.5 : 0), radius: 18, y: 10)
      .animation(.easeOut(duration: 0.15), value: focused)
  }
}

extension SearchPerson {
  var creditPerson: CreditPerson {
    CreditPerson(id: "n-\(name)", name: name, role: roleLabel,
                 photo: ActorImageProvider.photoURLString(for: name),
                 filter: isActor ? .cast : .director)
  }
}

/// «Все» at the end of a row of people.
struct PeopleSeeAllLockup: View {
  let value: Route
  @FocusState private var focused: Bool

  var body: some View {
    NavigationLink(value: value) {
      VStack(spacing: 16) {
        Circle()
          .fill(Color.white.opacity(focused ? 0.2 : 0.1))
          .frame(width: 200, height: 200)
          .overlay {
            Image(systemName: "chevron.right.circle").font(.system(size: 64)).foregroundStyle(.secondary)
          }
          .circleFocusLift(focused)
        Text("See All".localized).font(.caption)
      }
      .frame(width: 220)
    }
    .buttonStyle(LiftlessButtonStyle())
    .focused($focused)
  }
}
