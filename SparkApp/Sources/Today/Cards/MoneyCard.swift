import SparkUI
import SwiftUI

struct MoneyCard: View {
    let money: MoneySnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                GlassCardHeader(
                    icon: "sterlingsign",
                    tint: .domainMoney,
                    title: "Spent today"
                )

                if let display = money.spentTodayDisplay {
                    Text(display)
                        .font(SparkFonts.display(.title, weight: .bold))
                        .accessibilityLabel("Spent today \(display)")
                }

                if !money.recent.isEmpty {
                    Text("\(money.recent.count) transactions")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)

                    VStack(spacing: SparkSpacing.xs) {
                        ForEach(money.recent.prefix(2)) { tx in
                            HStack {
                                Text(tx.merchant)
                                    .font(SparkTypography.bodySmall)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: SparkSpacing.sm)
                                Text(MoneySnapshot.format(amount: abs(tx.amount), currency: tx.currency))
                                    .font(SparkTypography.monoSmall)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(.top, SparkSpacing.xs)
                }
            }
        }
    }
}
