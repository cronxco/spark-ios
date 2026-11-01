import SparkKit
import SparkUI
import SwiftUI

/// Explore › Money › Pots: the interest the pots earn, then the pots
/// themselves, with the choice of card buffer pot on a long press.
struct MoneyPotsSection: View {
    let viewModel: MoneyPlanViewModel
    let plan: MoneyPlan
    @State private var showsAll = false

    private static let leadingCount = 4

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            MoneySectionHeader(title: "Pots", icon: .savingsPot, count: plan.pots.count)
            interestCard
            if plan.pots.isEmpty {
                MoneyCard {
                    Text("No Monzo pots with a balance yet.")
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: SparkSpacing.sm) {
                    ForEach(shown) { pot in
                        potRow(pot)
                    }
                    if hidden > 0 {
                        MoneyShowMoreButton(title: "\(hidden) more \(hidden == 1 ? "pot" : "pots")") {
                            withAnimation(.snappy(duration: 0.22)) { showsAll = true }
                        }
                    }
                }
                Text("Press and hold a pot to choose it as the card buffer.")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                if let error = viewModel.bufferError {
                    MoneyStatusChip(text: error)
                }
            }
        }
    }

    // MARK: Interest

    @ViewBuilder
    private var interestCard: some View {
        let strip = plan.strip
        MoneyCard {
            MoneyEyebrow(
                icon: .interest,
                label: "Interest",
                trailing: strip.latestMonth.map { MoneyPlanFormat.monthName($0) }
            )
            if strip.latestMonth != nil {
                MoneyHeroValue(pence: strip.latestInterest)
            } else {
                Text("—")
                    .font(SparkTypography.cardValue)
                    .foregroundStyle(.secondary)
            }
            Text("On \(MoneyPlanFormat.amount(strip.inPots)) in pots")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
            if plan.interest.count >= 2 {
                MoneyInterestBars(months: Array(plan.interest.reversed()))
            }
            if strip.monthsRecorded > 0 {
                stats(strip)
            }
            Text(footnote)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footnote: String {
        let base = "Monzo doesn't report pot interest, so Spark works it out from each pot's balance on the 1st."
        return plan.interest.contains(where: \.estimated) ? base + " Dashed months are estimates." : base
    }

    /// The stat grid (section 8): label above value, centred, no dividers.
    private func stats(_ strip: PlanStrip) -> some View {
        Grid(horizontalSpacing: SparkSpacing.sm, verticalSpacing: SparkSpacing.sm) {
            GridRow {
                stat("A year at this rate", MoneyPlanFormat.pounds(roundedToPounds(strip.runRate)))
                stat("Last 12 months", MoneyPlanFormat.pounds(roundedToPounds(strip.twelveMonths)))
                stat("Tax, higher rate", MoneyPlanFormat.pounds(roundedToPounds(strip.taxEstimate)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func roundedToPounds(_ pence: Int) -> Int {
        Int((Double(pence) / 100).rounded()) * 100
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: SparkSpacing.xxs) {
            Text(label)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(SparkTypography.bodyStrong)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Pots

    /// The biggest pots, then any with a goal or the card buffer, so the
    /// pots that need a look are never folded away.
    private var shown: [PlanPot] {
        guard !showsAll else { return plan.pots }
        var ids = Set(plan.pots.prefix(Self.leadingCount).map(\.id))
        for pot in plan.pots where (pot.goal ?? 0) > 0 || pot.id == plan.cover.pot?.id {
            ids.insert(pot.id)
        }
        return plan.pots.filter { ids.contains($0.id) }
    }

    private var hidden: Int { plan.pots.count - shown.count }

    private func potRow(_ pot: PlanPot) -> some View {
        let isBuffer = plan.cover.pot?.id == pot.id
        return VStack(alignment: .leading, spacing: SparkSpacing.xs + 2) {
            MoneyRow(
                title: pot.name,
                metadata: metadata(pot, isBuffer: isBuffer),
                value: MoneyPlanFormat.amount(pot.balance),
                ground: .surface
            )
            if let goal = pot.goal, goal > 0 {
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    MoneyBar(
                        fraction: Double(pot.balance) / Double(goal),
                        accessibilityText: "\(MoneyPlanFormat.amount(pot.balance)) of \(MoneyPlanFormat.amount(goal)) goal"
                    )
                    Text("\(MoneyPlanFormat.amount(pot.balance)) of \(MoneyPlanFormat.amount(goal)) goal")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, SparkSpacing.md)
                .padding(.bottom, SparkSpacing.sm)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous)
                .fill(Color.sparkElevated)
        }
        .contextMenu {
            Button(isBuffer ? "Stop using as card buffer" : "Use as card buffer") {
                Task { await viewModel.setBufferPot(pot, enabled: !isBuffer) }
            }
        }
    }

    private func metadata(_ pot: PlanPot, isBuffer: Bool) -> [String] {
        var items: [String] = []
        if pot.share >= 0.01 {
            items.append("\(Int((pot.share * 100).rounded()))% of pots")
        } else {
            items.append("Under 1% of pots")
        }
        if let aer = pot.aer {
            items.append(String(format: "%.2f%% AER", aer * 100))
        } else {
            items.append("No interest")
        }
        if isBuffer { items.append("Card buffer") }
        return items
    }
}

/// Interest by month as bars from zero (section 8, Trend): earlier months at
/// half fill, the latest at full fill and labelled, estimated months as a
/// dashed outline. The usual range is the band of the middle half of the
/// measured months.
struct MoneyInterestBars: View {
    /// Oldest first.
    let months: [InterestMonth]

    private var maxValue: Double {
        Double(months.map(\.total).max() ?? 1) * 1.04
    }

    private var band: ClosedRange<Double>? {
        let measured = months.filter { !$0.estimated }.map { Double($0.total) }.sorted()
        guard measured.count >= 4 else { return nil }
        let low = measured[measured.count / 4]
        let high = measured[(measured.count * 3) / 4]
        return low...high
    }

    var body: some View {
        VStack(spacing: SparkSpacing.xs) {
            GeometryReader { proxy in
                let height = proxy.size.height - 18
                ZStack(alignment: .bottomLeading) {
                    if let band {
                        Rectangle()
                            .fill(Color.domainMoney.opacity(0.18))
                            .frame(height: max(2, (band.upperBound - band.lowerBound) / maxValue * height))
                            .offset(y: -(band.lowerBound / maxValue * height))
                    }
                    HStack(alignment: .bottom, spacing: SparkSpacing.xs + 2) {
                        ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                            bar(month, isLatest: index == months.count - 1, height: height)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 118)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
            }
            HStack(spacing: SparkSpacing.xs + 2) {
                ForEach(months) { month in
                    Text(MoneyPlanFormat.monthInitial(month.month))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func bar(_ month: InterestMonth, isLatest: Bool, height: CGFloat) -> some View {
        let barHeight = max(2, Double(month.total) / maxValue * height)
        let shape = UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
        return VStack(spacing: 2) {
            if isLatest {
                Text(MoneyPlanFormat.pounds(Int((Double(month.total) / 100).rounded()) * 100))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            Group {
                if month.estimated {
                    shape.strokeBorder(Color.domainMoney, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                } else {
                    shape.fill(Color.domainMoney.opacity(isLatest ? 1 : 0.5))
                }
            }
            .frame(height: barHeight)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private var accessibilityText: String {
        guard let first = months.first, let last = months.last else { return "Interest by month" }
        var text = "Pot interest by month, \(MoneyPlanFormat.monthLabel(first.month)) to \(MoneyPlanFormat.monthLabel(last.month)). \(MoneyPlanFormat.monthName(last.month)) \(MoneyPlanFormat.amount(last.total))."
        let estimated = months.filter(\.estimated).map { MoneyPlanFormat.monthName($0.month) }
        if !estimated.isEmpty {
            text += " Estimated: \(ListFormatter.localizedString(byJoining: estimated))."
        }
        return text
    }
}
