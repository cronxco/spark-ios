import SparkUI
import SwiftUI

struct MetricsExploreView: View {
    @State private var filterDomain: MetricDomain? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    domainFilter
                        .padding(.horizontal, SparkSpacing.lg)

                    ForEach(visibleCategories, id: \.title) { category in
                        GlassCard {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                GlassCardHeader(
                                    icon: category.icon,
                                    tint: category.tint,
                                    title: category.title
                                )
                                EmptyState(
                                    systemImage: category.icon,
                                    title: "No data yet",
                                    message: "Metrics will appear here once your integrations sync."
                                )
                            }
                        }
                        .padding(.horizontal, SparkSpacing.lg)
                    }
                }
                .padding(.vertical, SparkSpacing.xl)
            }
            .navigationTitle("Metrics")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var domainFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                Button { filterDomain = nil } label: {
                    TagChip("All", isGhost: filterDomain != nil)
                }
                .buttonStyle(.plain)
                ForEach(MetricDomain.allCases, id: \.self) { domain in
                    Button { filterDomain = domain } label: {
                        TagChip(domain.label, isGhost: filterDomain != domain)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var visibleCategories: [MetricCategory] {
        if let filter = filterDomain {
            MetricCategory.all.filter { $0.domain == filter }
        } else {
            MetricCategory.all
        }
    }
}

private enum MetricDomain: CaseIterable {
    case health, activity, money, media

    var label: String {
        switch self {
        case .health: "Health"
        case .activity: "Activity"
        case .money: "Money"
        case .media: "Media"
        }
    }
}

private struct MetricCategory {
    let domain: MetricDomain
    let title: String
    let icon: String
    let tint: Color

    static let all: [MetricCategory] = [
        .init(domain: .health, title: "Sleep Score", icon: "moon.zzz.fill", tint: .sparkOcean),
        .init(domain: .health, title: "Heart Rate", icon: "heart.fill", tint: .domainHealth),
        .init(domain: .activity, title: "Steps", icon: "figure.walk", tint: .domainActivity),
        .init(domain: .activity, title: "Calories", icon: "flame.fill", tint: .domainActivity),
        .init(domain: .money, title: "Daily Spend", icon: "sterlingsign.circle.fill", tint: .domainMoney),
        .init(domain: .media, title: "Screen Time", icon: "iphone", tint: .domainMedia),
    ]
}
