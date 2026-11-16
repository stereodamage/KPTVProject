import Foundation

/// The one rating shown or sorted for a title: IMDb when available, then Kinopoisk, then kino.pub's own.
public enum PreferredRating {
  public static func pick(imdb: Double?, kinopoisk: Double?,
                          votes: Int, percentage: Double) -> (source: String, value: Double)? {
    if let imdb, imdb > 0 { return ("IMDb", imdb) }
    if let kinopoisk, kinopoisk > 0 { return ("КиноПоиск", kinopoisk) }
    if votes > 0, percentage > 0 { return ("kino.pub", percentage / 10) }
    return nil
  }
}

public extension MediaItem {
  var preferredRating: (source: String, value: Double)? {
    PreferredRating.pick(imdb: imdbRating, kinopoisk: kinopoiskRating,
                         votes: ratingVotes, percentage: ratingPercentage)
  }
}
