import SparkKit
import SparkUI
import SwiftUI

/// The most recent digest's opening claim, and nothing else.
///
/// No byline, no timestamp, no call to action: the whole card is the link
/// into the digest, and the words are the only thing on it. Serif, because
/// the design system reserves serif for long-form reading and a digest is
/// exactly that.
///
/// "Most recent" deliberately reaches back past midnight — before the morning
/// brief has run, the newest thing Flint has written is last night's evening
/// digest, and showing that beats showing nothing.
struct DigestOpenerCard: View {
    let digest: FlintDigest
    let onOpen: () -> Void

    var body: some View {
        if let opener = digest.opener {
            Button(action: onOpen) {
                Text(opener)
                    .font(SparkTypography.longFormBodySmall)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SparkSpacing.lg)
                    .sparkGlass(.roundedRect(SparkRadii.lg))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(opener))
            .accessibilityHint("Opens the full digest")
        }
    }

    /// The card no longer says which run it came from, so the accessible name
    /// carries it: the difference between this morning's brief and last
    /// night's is not visible otherwise.
    private func accessibilityLabel(_ opener: String) -> String {
        let source = [digest.period?.displayName, digest.title]
            .compactMap { $0 }
            .first ?? "Digest"
        return "\(source). \(opener)"
    }
}
