import SparkKit
import SparkUI
import SwiftUI

/// Header for the person detail screen: avatar, name and what kind of person
/// record it is. Falls back to initials when there is no usable photo.
struct PersonHero: View {
    let person: EventObject
    let eventCount: Int

    private static let avatarSize: CGFloat = 88

    var body: some View {
        HStack(alignment: .center, spacing: SparkSpacing.lg) {
            avatar
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text("Person — \(person.type.sparkSentenceCase)")
                    .font(SparkTypography.mono)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(person.title)
                    .font(SparkFonts.display(.largeTitle, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .accessibilityAddTraits(.isHeader)
                if eventCount > 0 {
                    Text(eventCount == 1 ? "1 recent event" : "\(eventCount) recent events")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let url = person.mediaURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: some View {
        ZStack {
            Circle().fill(Color.sparkAccent.opacity(0.15))
            Text(Self.initials(for: person.title))
                .font(SparkFonts.display(.title, weight: .bold))
                .foregroundStyle(Color.sparkAccent)
        }
    }

    private static func initials(for name: String) -> String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
