//
//  LocalResumeMatch.swift
//  KinoPubBackend
//

public enum LocalResumeMatch {
  public static func matches(entrySeason: Int?, entryEpisode: Int?, season: Int?, episode: Int?) -> Bool {
    if let season {
      return entrySeason == season && entryEpisode == episode
    }
    guard entrySeason == nil else { return false }
    // Thin cards (history, search) have no `videos`, so an unknown version number still matches.
    if let entryEpisode, let episode { return entryEpisode == episode }
    return true
  }
}
