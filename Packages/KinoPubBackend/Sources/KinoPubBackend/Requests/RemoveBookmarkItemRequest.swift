import Foundation

/// Removes one title from one folder — `POST /v1/bookmarks/remove-item`. `folder` is required here on purpose:
/// without it the server removes the title from every folder.
public struct RemoveBookmarkItemRequest: Endpoint {
  public var item: Int
  public var folder: Int

  public init(item: Int, folder: Int) {
    self.item = item
    self.folder = folder
  }

  public var path: String {
    "/v1/bookmarks/remove-item"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    ["item": item, "folder": folder]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
