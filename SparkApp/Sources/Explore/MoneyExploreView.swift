import SparkUI
import SwiftUI

struct MoneyExploreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "sterlingsign.circle.fill",
                                tint: .domainMoney,
                                title: "Spending Overview"
                            )
                            HStack(spacing: SparkSpacing.sm) {
                                SpendingPeriodCell(period: "Today", amount: "—")
                                SpendingPeriodCell(period: "This Week", amount: "—")
                                SpendingPeriodCell(period: "This Month", amount: "—")
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.md) {
                            GlassCardHeader(
                                icon: "list.bullet.rectangle",
                                tint: .domainMoney,
                                title: "Transactions"
                            )
                            EmptyState(
                                systemImage: "creditcard",
                                title: "No transactions yet",
                                message: "Connect a bank integration to see your transactions here."
                            )
                        }
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .navigationTitle("Money")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct SpendingPeriodCell: View {
    let period: String
    let amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
            Text(amount)
                .font(SparkTypography.titleStrong)
                .foregroundStyle(.primary)
            Text(period)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.sm))
    }
}
