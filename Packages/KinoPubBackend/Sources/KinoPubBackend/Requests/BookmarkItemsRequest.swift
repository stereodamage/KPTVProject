//
//  File.swift
//  
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation

public struct BookmarkItemsRequest: Endpoint {

  private var id: String
  private var page: Int?

  public init(id: String, page: Int? = nil) {
    self.id = id
    self.page = page
  }

  public var path: String {
    "/v1/bookmarks/\(id)"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    page.map { ["page": "\($0)"] }
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
