import SparkUI
import SwiftUI

struct MediaCard: View {
    let media: MediaSnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                GlassCardHeader(
                    icon: "music.note",
                    tint: .domainMedia,
                    title: "Listening",
                    trailing: media.spotifyMinutes.map { "\($0) min" }
                )

                HStack(spacing: SparkSpacing.md) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.ember300, .ember200, .spark200],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .clipShape(.rect(cornerRadius: SparkRadii.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: SparkRadii.sm)
                                .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        if let track = media.topTrack {
                            Text(track)
                                .font(SparkTypography.bodyStrong)
                                .lineLimit(1)
                        }
                        if let artist = media.topArtist {
                            Text(artist)
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if media.lastSongAt != nil {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.sparkSuccess)
                                    .frame(width: 6, height: 6)
                                Text("PLAYING")
                                    .font(SparkTypography.monoSmall)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}
