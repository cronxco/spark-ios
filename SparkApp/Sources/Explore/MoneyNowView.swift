import SparkKit
import SparkUI
import SwiftUI

// Explore › Money, the sections about now: what is safe to spend, whether
// the cards are covered, the bills before payday and this month's spending.

/// The page's hero: what is left once the cards and the bills before payday
/// are paid, and how that adds up.
struct MoneySafeToSpendCard: View {
    let safe: SafeToSpend
    var onShowBills: () -> Void

    var body: some View {
        MoneyCard {
            MoneyEyebrow(icon: .budget, label: "Safe to spend", trailing: safe.payday == nil ? nil : "Until payday")
            MoneyHeroValue(pence: safe.amount)
                .accessibilityLabel("Safe to spend, \(MoneyPlanFormat.amount(safe.amount))")
            if safe.amount < 0 {
                MoneyStatusChip(text: safe.payday == nil ? "Short" : "Short before payday")
            }
            VStack(alignment: .leading, spacing: 0) {
                line("In current accounts", MoneyPlanFormat.amount(safe.available))
                line("Owed on cards", MoneyPlanFormat.amount(-safe.owedOnCards))
                if safe.upcomingBills > 0 || !safe.bills.isEmpty {
                    Button(action: onShowBills) {
                        line(
                            safe.bills.isEmpty ? "Bills before payday" : "Bills before payday (\(safe.bills.count))",
                            MoneyPlanFormat.amount(-safe.upcomingBills),
                            disclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows the bills")
                }
            }
            if let payday = MoneyPlanFormat.paydayLine(safe.payday, known: safe.paydayKnown) {
                Text(payday)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func line(_ label: String, _ value: String, disclosure: Bool = false) -> some View {
        HStack(spacing: SparkSpacing.sm) {
            Text(label)
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
            Spacer(minLength: SparkSpacing.sm)
            Text(value)
                .font(SparkTypography.bodyStrong)
                .monospacedDigit()
                .foregroundStyle(.primary)
            if disclosure {
                SparkGlyph(.forward, size: 11, relativeTo: .caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card cover

/// Whether the buffer pot holds enough for what the cards owe.
struct MoneyCardCoverSection: View {
    let cover: CardCover

    private var owing: [CardCover.Card] { cover.cards.filter { $0.owed > 0 } }
    private var clear: [CardCover.Card] { cover.cards.filter { $0.owed <= 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            MoneySectionHeader(title: "Card cover", icon: .paymentCard)
            MoneyCard {
                status
                if let pot = cover.pot, cover.owed > 0 {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs + 2) {
                        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                            Text(pot.name)
                                .font(SparkTypography.bodyStrong)
                                .lineLimit(1)
                            Spacer(minLength: SparkSpacing.sm)
                            Text("\(MoneyPlanFormat.amount(pot.balance)) of \(MoneyPlanFormat.amount(cover.owed))")
                                .font(SparkTypography.body)
                                .monospacedDigit()
                        }
                        MoneyBar(
                            fraction: Double(pot.balance) / Double(cover.owed),
                            accessibilityText: "\(pot.name) holds \(MoneyPlanFormat.amount(pot.balance)) of \(MoneyPlanFormat.amount(cover.owed)) owed"
                        )
                    }
                }
                if !owing.isEmpty {
                    VStack(spacing: SparkSpacing.sm) {
                        ForEach(owing) { card in
                            MoneyRow(
                                title: card.name,
                                metadata: metadata(card),
                                value: MoneyPlanFormat.amount(card.owed),
                                valueCaption: "owed"
                            ) {
                                DomainGlyph(.paymentCard, tint: .domainMoney)
                            }
                        }
                    }
                }
                if let footnote {
                    Text(footnote)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch cover.status {
        case .short:
            MoneyStatusChip(text: "Short by \(MoneyPlanFormat.amount(cover.shortfall))")
        case .covered:
            HStack(spacing: SparkSpacing.xs + 2) {
                SparkGlyph(.success, size: 14, relativeTo: .body)
                    .foregroundStyle(Color.sparkSuccess)
                Text(cover.owed > 0 ? "Covered" : "Nothing owed on the cards")
                    .font(SparkTypography.bodyStrong)
            }
        case .noBuffer:
            Text("No buffer pot is set. Press and hold a pot under Pots to choose one.")
                .font(SparkTypography.body)
                .foregroundStyle(.secondary)
        }
    }

    private func metadata(_ card: CardCover.Card) -> [String] {
        var items = ["\(card.transactions) since \(MoneyPlanFormat.shortDay(card.since))"]
        if card.buffered > 0 {
            items.append("\(MoneyPlanFormat.amount(card.buffered)) buffered")
        }
        return items
    }

    private var footnote: String? {
        var parts: [String] = []
        if !clear.isEmpty {
            let names = ListFormatter.localizedString(byJoining: clear.map(\.name))
            parts.append("\(names) \(clear.count == 1 ? "owes" : "owe") nothing.")
        }
        if cover.pot != nil {
            parts.append("Press and hold a pot to change the buffer.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - Bills

/// The bills that leave before payday, grouped by the day they go.
struct MoneyBillsSection: View {
    let bills: [SafeToSpend.Bill]
    @State private var showsAll = false

    private static let collapsedCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            MoneySectionHeader(title: "Bills before payday", icon: .calendarEvent, count: bills.count)
            MoneyCard(spacing: SparkSpacing.sm) {
                ForEach(days, id: \.due) { day in
                    Text(MoneyPlanFormat.dueLabel(day.due))
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(.secondary)
                        .padding(.top, SparkSpacing.xs)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(day.bills) { bill in
                        MoneyRow(title: bill.payee, value: MoneyPlanFormat.amount(bill.amount))
                    }
                }
                if hidden > 0 {
                    MoneyShowMoreButton(title: "\(hidden) more, to \(MoneyPlanFormat.shortDay(bills.last?.due ?? ""))") {
                        withAnimation(.snappy(duration: 0.22)) { showsAll = true }
                    }
                }
            }
        }
    }

    private var shown: [SafeToSpend.Bill] {
        showsAll ? bills : Array(bills.prefix(Self.collapsedCount))
    }

    private var hidden: Int { bills.count - shown.count }

    /// Consecutive bills on the same day, in the server's order.
    private var days: [(due: String, bills: [SafeToSpend.Bill])] {
        var result: [(due: String, bills: [SafeToSpend.Bill])] = []
        for bill in shown {
            if let last = result.last, last.due == bill.due {
                result[result.count - 1].bills.append(bill)
            } else {
                result.append((bill.due, [bill]))
            }
        }
        return result
    }
}

// MARK: - Spending

/// This month's card spending, with Add to buffer when the buffer is on.
struct MoneySpendingSection: View {
    let viewModel: MoneyPlanViewModel
    let spending: Spending
    let bufferEnabled: Bool
    @State private var showsAll = false

    private static let collapsedCount = 8

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                MoneySectionHeader(title: "Spending in \(MoneyPlanFormat.monthName(spending.month))", icon: .payment)
                if bufferEnabled {
                    Button(viewModel.isSelecting ? "Done" : "Select") { viewModel.toggleSelecting() }
                        .font(SparkTypography.bodyStrong)
                        .frame(minHeight: 44)
                }
            }
            MoneyCard {
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    MoneyHeroValue(pence: spending.total, font: SparkTypography.hero, fractionFont: SparkTypography.compactValue)
                    Text("Card spending only, without pot moves, direct debits or transfers")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if let message = viewModel.bufferMessage {
                    Text(message).font(SparkTypography.caption).foregroundStyle(.secondary)
                }
                if let error = viewModel.bufferError {
                    MoneyStatusChip(text: error)
                }
                if let preview = viewModel.preview {
                    confirmation(preview)
                } else if viewModel.isSelecting, !viewModel.selectedIds.isEmpty {
                    Button("Add \(viewModel.selectedIds.count) to buffer (\(MoneyPlanFormat.amount(viewModel.selectedTotal)))") {
                        Task { await viewModel.reviewBuffer() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.domainMoney)
                    .foregroundStyle(Color.sparkOnAccent)
                }

                if spending.transactions.isEmpty {
                    Text("No card spending this month.")
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: SparkSpacing.sm) {
                        ForEach(shown) { transaction in
                            transactionRow(transaction)
                        }
                    }
                    if hidden > 0 {
                        MoneyShowMoreButton(title: "Show all \(visibleLimit) payments") {
                            withAnimation(.snappy(duration: 0.22)) { showsAll = true }
                        }
                    }
                }
            }
        }
    }

    /// The list stops at 100, as it always has.
    private var visibleLimit: Int { min(spending.transactions.count, 100) }

    private var shown: [SpendingTransaction] {
        Array(spending.transactions.prefix(showsAll || viewModel.isSelecting ? visibleLimit : Self.collapsedCount))
    }

    private var hidden: Int { visibleLimit - shown.count }

    private func confirmation(_ preview: BufferPreview) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text("Move \(MoneyPlanFormat.amount(preview.total)) into \(preview.pot.name)?")
                .font(SparkTypography.bodyStrong)
            Text("Monzo transfers this from your current account into the pot. Spark can't undo it.")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
            ForEach(preview.transactions) { transaction in
                MoneyRow(title: transaction.merchant, value: MoneyPlanFormat.amount(transaction.amount))
            }
            HStack {
                Button("Move the money") { Task { await viewModel.confirmBuffer() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.domainMoney)
                    .foregroundStyle(Color.sparkOnAccent)
                    .disabled(viewModel.isMoving)
                Button("Cancel") { viewModel.cancelBuffer() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func transactionRow(_ transaction: SpendingTransaction) -> some View {
        Button {
            viewModel.toggle(transaction)
        } label: {
            MoneyRow(
                title: transaction.merchant,
                metadata: metadata(transaction),
                // Spending reads plain; a refund is money in, so it shows +£ (section 9).
                value: transaction.amount < 0
                    ? MoneyPlanFormat.amount(-transaction.amount, signed: true)
                    : MoneyPlanFormat.amount(transaction.amount)
            ) {
                if viewModel.isSelecting {
                    let selected = viewModel.selectedIds.contains(transaction.id)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(transaction.canAddToBuffer ? Color.domainMoney : Color.secondary.opacity(0.4))
                        .accessibilityLabel(selected ? "Selected" : "Not selected")
                } else {
                    DomainGlyph(.payment, tint: .domainMoney)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isSelecting || !transaction.canAddToBuffer)
    }

    private func metadata(_ transaction: SpendingTransaction) -> [String] {
        var items = [transaction.account, SparkRelativeTime.string(for: transaction.time)]
        if transaction.pending { items.append("Pending") }
        switch transaction.buffer {
        case "linked": items.append("Buffered")
        case "requested": items.append("Buffer requested")
        case "failed": items.append("Buffer failed")
        default: break
        }
        return items
    }
}
