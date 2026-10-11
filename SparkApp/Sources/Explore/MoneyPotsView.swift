import SparkKit
import SparkUI
import SwiftUI

/// Explore › Money › Pots: balances, goals, inferred interest and the choice of card buffer pot.
struct MoneyPotsView: View {
    let viewModel: MoneyPlanViewModel

    var body: some View {
        if let plan = viewModel.plan {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                stripCard(plan.strip)
                potsCard(plan)
                interestCard(plan.interest)
            }
            .padding(.horizontal, SparkSpacing.lg)
        } else if case .error(let message) = viewModel.loadState {
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load your pots",
                message: message,
                actionTitle: "Retry"
            ) { Task { await viewModel.refresh() } }
            .padding(.horizontal, SparkSpacing.lg)
        } else {
            LoadingShimmerCard()
                .padding(.horizontal, SparkSpacing.lg)
        }
    }

    private func stripCard(_ strip: PlanStrip) -> some View {
        GlassCard(radius: SparkRadii.hero, padding: SparkSpacing.xl) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text("In savings pots")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                Text(MoneyPlanFormat.pounds(strip.inPots))
                    .font(SparkFonts.display(size: 44))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if let month = strip.latestMonth {
                    Text("\(MoneyPlanFormat.pounds(strip.latestInterest)) interest in \(MoneyPlanFormat.monthLabel(month)). About \(MoneyPlanFormat.pounds(strip.runRate)) a year, roughly \(MoneyPlanFormat.pounds(strip.taxEstimate)) tax at the higher rate.")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func potsCard(_ plan: MoneyPlan) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                SparkSectionHeader(title: "Pots", icon: "banknote.fill", tint: Color.domainMoney)
                if plan.pots.isEmpty {
                    Text("No Monzo pots with a balance yet.")
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                }
                ForEach(plan.pots) { pot in
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        HStack {
                            Text(pot.name).font(SparkTypography.body)
                            if plan.cover.pot?.id == pot.id {
                                Text("Card buffer")
                                    .font(SparkTypography.captionStrong)
                                    .foregroundStyle(Color.domainMoney)
                            }
                            Spacer()
                            Text(MoneyPlanFormat.pounds(pot.balance)).font(SparkTypography.bodyStrong)
                        }
                        if let goal = pot.goal, goal > 0 {
                            ProgressView(value: min(1, Double(pot.balance) / Double(goal)))
                                .tint(Color.domainMoney)
                        }
                        if pot.interest > 0 {
                            Text("\(MoneyPlanFormat.pounds(pot.interest)) last interest")
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        let isBuffer = plan.cover.pot?.id == pot.id
                        Button(isBuffer ? "Stop using as card buffer" : "Use as card buffer") {
                            Task { await viewModel.setBufferPot(pot, enabled: !isBuffer) }
                        }
                    }
                }
                Text("Press and hold a pot to choose it as the card buffer.")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                if let error = viewModel.bufferError {
                    Text(error).font(SparkTypography.caption).foregroundStyle(Color.sparkError)
                }
            }
        }
    }

    @ViewBuilder
    private func interestCard(_ months: [InterestMonth]) -> some View {
        if !months.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    SparkSectionHeader(title: "Interest", icon: "percent", tint: Color.domainMoney)
                    Text("Monzo doesn't report pot interest, so Spark works it out from each pot's balance on the 1st.")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                    ForEach(months) { month in
                        HStack {
                            Text(MoneyPlanFormat.monthLabel(month.month))
                                .font(SparkTypography.body)
                            if month.estimated {
                                Text("Estimated")
                                    .font(SparkTypography.captionStrong)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(MoneyPlanFormat.pounds(month.total)).font(SparkTypography.bodyStrong)
                        }
                    }
                }
            }
        }
    }
}
