import SparkKit
import SparkUI
import SwiftUI

/// Supplemental detail lives inside the scaffold, so it participates in dwell geometry.
struct DigestSupplementView: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel
    @State private var loading = false
    @State private var recovered = false
    @State private var failure: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let digest = viewModel.digestCache[item.id] {
            if recovered, let summary = digest.summary {
                DisclosureGroup(isExpanded: viewModel.disclosureBinding("\(item.id)-recovered")) {
                    SparkLongFormContentView(text: summary)
                } label: {
                    disclosureLabel("Recovered digest detail")
                }
                .tint(Color.sparkLink)
            }
            let notes = digest.blocks.filter {
                $0.kind == .flintEditorialNote && $0.content?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
            if !notes.isEmpty {
                DisclosureGroup(isExpanded: viewModel.disclosureBinding("\(item.id)-editorial")) {
                    VStack(alignment: .leading, spacing: SparkSpacing.md) {
                        ForEach(notes) { note in
                            if notes.count > 1 { Text(note.title).font(SparkTypography.bodyStrong) }
                            SparkLongFormContentView(text: note.content ?? "")
                            StoryReferences(references: note.references ?? [], sourceURL: note.url)
                        }
                    }
                    .padding(.top, SparkSpacing.md)
                } label: {
                    disclosureLabel("Editorial note")
                }
                // The accent role, like every disclosure link (§3.1). It
                // inherited the app's amber tint, about 1.6:1 on the wash.
                .tint(Color.sparkLink)
            }
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text(failure ?? "Digest detail is unavailable. Editorial notes may not have loaded.")
                    .font(SparkTypography.bodySmall)
                Button(loading ? "Loading…" : "Retry detail") {
                    Task {
                        loading = true
                        defer { loading = false }
                        do { _ = try await viewModel.recapDigest(for: item); failure = nil; recovered = true }
                        catch { failure = "Could not load digest detail. Try again." }
                    }
                }
                .disabled(loading)
            }
        }
    }
}

/// A disclosure's title in the accent role. The chevron takes the same
/// colour from the group's tint.
@MainActor
func disclosureLabel(_ title: String) -> some View {
    Text(title)
        .font(SparkTypography.bodySmall)
        .foregroundStyle(Color.sparkLink)
}

struct StoryReferences: View {
    let references: [EntityReference]
    var sourceURL: String? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        EntityRefChipRow(references: references) { reference in
            let kind = reference.type == .integration ? "integrations" : reference.type.rawValue
            let suffix = reference.type == .integration ? "/details" : ""
            if reference.type != .unknown,
               let url = URL(string: "https://spark.cronx.co/\(kind)/\(reference.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? reference.id)\(suffix)") {
                openURL(url)
            }
        }
        if let sourceURL, let url = URL(string: sourceURL) {
            Link("Open source", destination: url)
        }
    }
}
