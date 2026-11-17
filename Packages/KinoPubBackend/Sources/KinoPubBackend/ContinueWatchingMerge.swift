import Foundation

/// Merges the server's Continue Watching entries with local resume points (one entry per title id).
public enum ContinueWatchingMerge {
  /// - fresh: the server entries from this load, or nil when the history request failed.
  /// - cached: the server entries from the last good load (used only when `fresh` is nil).
  /// - local: local resume points.
  /// Fresh history wins for every title it lists; local adds only the titles it does not list. Without fresh
  /// history, each cached entry is replaced by a newer local one (newer progress, or the credits reached), so
  /// the row stays current offline. Order is not defined: the caller sorts.
  public static func merge<Entry>(fresh: [Entry]?, cached: [Entry], local: [Entry],
                                  id: (Entry) -> Int, watchedAt: (Entry) -> TimeInterval) -> [Entry] {
    if let fresh {
      let listed = Set(fresh.map(id))
      return fresh + local.filter { !listed.contains(id($0)) }
    }
    var byId = Dictionary(cached.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
    for entry in local where (byId[id(entry)].map(watchedAt) ?? -.infinity) < watchedAt(entry) {
      byId[id(entry)] = entry
    }
    return Array(byId.values)
  }
}
