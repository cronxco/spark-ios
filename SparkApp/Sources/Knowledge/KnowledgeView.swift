import SparkUI
import SwiftUI

struct KnowledgeView: View {
    private let placeholderTags = [
        "swift", "ios", "productivity", "health", "reading",
        "work", "travel", "recipes", "finance", "notes",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "bookmark.fill",
                                tint: .domainKnowledge,
                                title: "Bookmarks"
                            )
                            EmptyState(
                                systemImage: "bookmark.circle",
                                title: "No bookmarks yet",
                                message: "Save articles, links and notes from the share sheet — coming in Phase 3."
                            )
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "tag.fill",
                                tint: .domainKnowledge,
                                title: "Tags"
                            )
                            TagChipRow(placeholderTags, allowAdd: false)
                                .opacity(0.4)
                            Text("Tag your events, blocks and objects to organise your knowledge base.")
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .navigationTitle("Knowledge")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
