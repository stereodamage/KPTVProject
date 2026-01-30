//
//  ItemCard.swift
//  KinoPubTV
//
//

import SwiftUI

struct ItemCard: View {
    let item: Item
    var width: CGFloat = 400
    var height: CGFloat = 225
    
    var body: some View {
        // The focusable card part (Image + Badges)
        ZStack(alignment: .topTrailing) {
            // Background image
            AsyncImage(url: URL.secure(string: item.posters?.wide ?? item.posters?.big ?? item.posters?.medium)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                @unknown default:
                    Rectangle()
                        .fill(Color(white: 0.15))
                }
            }
            .frame(width: width, height: height)
            .clipped()
            
            // Badges
            HStack(spacing: 8) {
                if item.subscribed == true {
                    Text("СМОТРЮ")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                if let newCount = item.new, newCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 18))
                        Text("\(newCount)")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(12)
        }
        // We don't clip shape here because the button style will handle the corner radius
    }
}

struct ItemMetadata: View {
    let item: Item
    var width: CGFloat
    var height: CGFloat = 50  // Fixed height to prevent overflow on focus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayTitle)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                if let year = item.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let rating = item.kinopoiskRating, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", rating))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

// MARK: - Poster Card (Portrait style for grids)

struct PosterCard: View {
    let item: Item
    var width: CGFloat = 250
    var height: CGFloat = 375
    
    var body: some View {
        // Poster Image
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL.secure(string: item.posters?.medium ?? item.posters?.big)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                @unknown default:
                    Rectangle()
                        .fill(Color(white: 0.15))
                }
            }
            .frame(width: width, height: height)
            .clipped()
            
            // Badges
            HStack(spacing: 8) {
                if item.subscribed == true {
                    Text("СМОТРЮ")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                if let newCount = item.new, newCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 18))
                        Text("\(newCount)")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(12)
        }
    }
}

struct SmallRatingBadge: View {
    let source: RatingSource
    let rating: Double
    
    enum RatingSource {
        case kinopoisk
        case imdb
        
        var label: String {
            switch self {
            case .kinopoisk: return "КП"
            case .imdb: return "IMDb"
            }
        }
        
        var color: Color {
            switch self {
            case .kinopoisk: return .orange
            case .imdb: return .yellow
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(source.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(source.color)
            Text(String(format: "%.1f", rating))
                .font(.caption2)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    ItemCard(
        item: Item(
            id: 1,
            title: "Тестовый фильм / Test Movie",
            type: "movie",
            subtype: nil,
            year: 2024,
            cast: nil,
            director: nil,
            voice: nil,
            duration: nil,
            langs: nil,
            ac3: nil,
            subtitles: nil,
            quality: 1080,
            genres: nil,
            countries: nil,
            plot: nil,
            imdb: nil,
            imdbRating: 8.5,
            imdbVotes: nil,
            kinopoisk: nil,
            kinopoiskRating: 7.8,
            kinopoiskVotes: nil,
            rating: nil,
            ratingPercentage: nil,
            ratingVotes: nil,
            views: nil,
            comments: nil,
            finished: nil,
            advert: nil,
            inWatchlist: nil,
            subscribed: true,
            posters: nil,
            trailer: nil,
            seasons: nil,
            videos: nil,
            createdAt: nil,
            updatedAt: nil,
            poorQuality: nil,
            new: 3
        )
    )
}
