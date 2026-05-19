import SparkUI
import SwiftUI
import UIKit

struct RawFeedJSONView: View {
    let title: String
    let entries: [RawFeedJSONEntry]

    @State private var isExpanded = false
    @State private var didCopy = false
    @State private var copiedEntryID: String?

    init(title: String = "Raw feed json", entries: [RawFeedJSONEntry]) {
        self.title = title
        self.entries = entries
    }

    init(title: String, json: String) {
        self.title = title
        self.entries = [RawFeedJSONEntry(title: title, body: json)]
    }

    var body: some View {
        GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: SparkSpacing.sm) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)

                        Text(title)
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)

                        Button {
                            UIPasteboard.general.string = entries.map(\.body).joined(separator: "\n\n")
                            didCopy = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.4))
                                didCopy = false
                            }
                        } label: {
                            Label(didCopy ? "Copied" : entries.count == 1 ? "Copy" : "Copy all", systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(SparkTypography.captionStrong)
                                .foregroundStyle(didCopy ? Color.sparkSuccess : Color.sparkTextPrimary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: SparkSpacing.md) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                HStack(spacing: SparkSpacing.sm) {
                                    Text(entry.title)
                                        .font(SparkTypography.monoSmall)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)

                                    Spacer(minLength: 0)

                                    Button {
                                        UIPasteboard.general.string = entry.body
                                        copiedEntryID = entry.id
                                        Task {
                                            try? await Task.sleep(for: .seconds(1.4))
                                            if copiedEntryID == entry.id {
                                                copiedEntryID = nil
                                            }
                                        }
                                    } label: {
                                        Label(copiedEntryID == entry.id ? "Copied" : "Copy", systemImage: copiedEntryID == entry.id ? "checkmark.circle.fill" : "doc.on.doc")
                                            .font(SparkTypography.captionStrong)
                                            .foregroundStyle(copiedEntryID == entry.id ? Color.sparkSuccess : Color.sparkTextPrimary)
                                    }
                                    .buttonStyle(.borderless)
                                }

                                ScrollView(.horizontal, showsIndicators: true) {
                                    Text(entry.body)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .padding(SparkSpacing.md)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: SparkRadii.md))
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct RawFeedJSONEntry: Identifiable, Sendable {
    let title: String
    let body: String

    var id: String { title }
}
