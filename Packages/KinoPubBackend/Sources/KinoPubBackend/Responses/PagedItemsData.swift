import Foundation

/// An `items` list with the optional `pagination` block, for replies that may or may not be paged.
public struct PagedItemsData<T: Codable>: Codable {
  public var items: [T]
  public var pagination: Pagination?

  public init(items: [T], pagination: Pagination? = nil) {
    self.items = items
    self.pagination = pagination
  }

  public var hasNextPage: Bool {
    guard let pagination else { return false }
    return pagination.current < pagination.total
  }
}
