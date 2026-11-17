import Foundation

/// Where focus goes when the focused card is about to leave a list.
public enum FocusNeighbor {
  /// The nearest id after `id` in `order` that `kept` still has, else the nearest one before it.
  public static func neighbor<ID: Equatable>(of id: ID, in order: [ID], kept: (ID) -> Bool) -> ID? {
    guard let index = order.firstIndex(of: id) else { return nil }
    return order[(index + 1)...].first(where: kept) ?? order[..<index].last(where: kept)
  }
}
