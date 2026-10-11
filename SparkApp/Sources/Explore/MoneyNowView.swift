import SparkKit
import SparkUI
import SwiftUI

/// Explore › Money › Now: what is safe to spend, whether the cards are covered, the budgets that
/// need attention, and the spending-only list with Add to buffer.
struct MoneyNowView: View {
    let viewModel: MoneyPlanViewModel

    var body: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            if viewModel.plan == nil {
                LoadingShimmerCard()
                    .padding(.horizontal, SparkSpacing.lg)
            } else {
                content
            }
        case .error(let message):
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load your plan",
                message: message,
                actionTitle: "Retry"
            ) { Task { await viewModel.refresh() } }
            .padding(.horizontal, SparkSpacing.lg)
        case .loaded:
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let plan = viewModel.plan {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                safeToSpendCard(plan.safeToSpend)
                coverCard(plan.cover)
                budgetsSection(plan.budgets)
                if let spending = viewModel.spending {
                    spendingSection(spending, bufferEnabled: plan.bufferEnabled)
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
    }

    // MARK: - Safe to spend

    private func safeToSpendCard(_ safe: SafeToSpend) -> some View {
        GlassCard(radius: SparkRadii.hero, padding: SparkSpacing.xl) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text("Safe to spend")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                Text(MoneyPlanFormat.pounds(safe.amount))
                    .font(SparkFonts.display(size: 44))
                    .foregroundStyle(safe.amount < 0 ? Color.sparkError : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text("\(MoneyPlanFormat.pounds(safe.available)) in current accounts, less \(MoneyPlanFormat.pounds(safe.owedOnCards)) owed on cards")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Card cover

    private func coverCard(_ cover: CardCover) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                SparkSectionHeader(title: "Card cover", icon: "creditcard.fill", tint: Color.domainMoney)
                Text(coverHeadline(cover))
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(coverColor(cover.status))
                ForEach(cover.cards) { card in
                    HStack {
                        VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                            Text(card.name).font(SparkTypography.body)
                            Text("\(card.transactions) transactions since \(card.since)")
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: SparkSpacing.xxs) {
                            Text(MoneyPlanFormat.pounds(card.owed)).font(SparkTypography.bodyStrong)
                            Text("\(MoneyPlanFormat.pounds(card.buffered)) buffered")
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func coverHeadline(_ cover: CardCover) -> String {
        switch cover.status {
        case .noBuffer: "No buffer pot is set. Choose one under Pots."
        case .covered: "Covered. \(cover.pot?.name ?? "Your buffer") holds \(MoneyPlanFormat.pounds(cover.pot?.balance ?? 0)) against \(MoneyPlanFormat.pounds(cover.owed)) owed."
        case .short: "Short by \(MoneyPlanFormat.pounds(cover.shortfall)). \(cover.pot?.name ?? "Your buffer") holds \(MoneyPlanFormat.pounds(cover.pot?.balance ?? 0)) against \(MoneyPlanFormat.pounds(cover.owed)) owed."
        }
    }

    private func coverColor(_ status: CardCover.Status) -> Color {
        switch status {
        case .covered: Color.sparkSuccess
        case .short: Color.sparkError
        case .noBuffer: Color.secondary
        }
    }

    // MARK: - Budgets

    @ViewBuilder
    private func budgetsSection(_ budgets: [BudgetProgress]) -> some View {
        if !budgets.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    SparkSectionHeader(title: "Budgets", icon: "chart.bar.fill", tint: Color.domainMoney)
                    ForEach(budgets.prefix(3)) { budget in
                        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                            HStack {
                                Text(budget.name).font(SparkTypography.body)
                                Spacer()
                                Text("\(MoneyPlanFormat.pounds(budget.spent)) of \(MoneyPlanFormat.pounds(budget.limit))")
                                    .font(SparkTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: min(1, max(0, budget.ratio)))
                                .tint(budgetColor(budget.status))
                        }
                    }
                }
            }
        }
    }

    private func budgetColor(_ status: BudgetProgress.Status) -> Color {
        switch status {
        case .ok: Color.sparkSuccess
        case .atRisk: Color.orange
        case .over: Color.sparkError
        }
    }

    // MARK: - Spending

    private func spendingSection(_ spending: Spending, bufferEnabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack {
                SparkSectionHeader(title: "Spending", icon: "sterlingsign", tint: Color.domainMoney)
                Spacer()
                if bufferEnabled {
                    Button(viewModel.isSelecting ? "Done" : "Select") { viewModel.toggleSelecting() }
                        .font(SparkTypography.bodySmall)
                }
            }
            Text("\(MoneyPlanFormat.monthLabel(spending.month)): \(MoneyPlanFormat.pounds(spending.total)). Card spending only, with no pot moves, direct debits or transfers.")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)

            if let message = viewModel.bufferMessage {
                Text(message).font(SparkTypography.caption).foregroundStyle(Color.sparkSuccess)
            }
            if let error = viewModel.bufferError {
                Text(error).font(SparkTypography.caption).foregroundStyle(Color.sparkError)
            }

            if let preview = viewModel.preview {
                confirmation(preview)
            } else if viewModel.isSelecting, !viewModel.selectedIds.isEmpty {
                Button("Add \(viewModel.selectedIds.count) to buffer (\(MoneyPlanFormat.pounds(viewModel.selectedTotal)))") {
                    Task { await viewModel.reviewBuffer() }
                }
                .buttonStyle(.borderedProminent)
            }

            if spending.transactions.isEmpty {
                Text("No spending this month.")
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                GlassCard {
                    VStack(spacing: SparkSpacing.sm) {
                        ForEach(spending.transactions.prefix(100)) { transaction in
                            transactionRow(transaction)
                        }
                    }
                }
            }
        }
    }

    private func confirmation(_ preview: BufferPreview) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text("Move \(MoneyPlanFormat.pounds(preview.total)) into \(preview.pot.name)?")
                    .font(SparkTypography.bodyStrong)
                Text("Monzo transfers this from your current account into the pot. Spark can't undo it.")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                ForEach(preview.transactions) { transaction in
                    HStack {
                        Text(transaction.merchant).font(SparkTypography.bodySmall)
                        Spacer()
                        Text(MoneyPlanFormat.pounds(transaction.amount)).font(SparkTypography.bodySmall)
                    }
                }
                HStack {
                    Button("Move the money") { Task { await viewModel.confirmBuffer() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isMoving)
                    Button("Cancel") { viewModel.cancelBuffer() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func transactionRow(_ transaction: SpendingTransaction) -> some View {
        Button {
            viewModel.toggle(transaction)
        } label: {
            HStack(spacing: SparkSpacing.md) {
                if viewModel.isSelecting {
                    Image(systemName: viewModel.selectedIds.contains(transaction.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(transaction.canAddToBuffer ? Color.domainMoney : Color.secondary.opacity(0.3))
                }
                VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                    Text(transaction.merchant)
                        .font(SparkTypography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(MoneyPlanFormat.categoryLabel(transaction.category)) · \(transaction.account)\(bufferLabel(transaction))")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(MoneyPlanFormat.pounds(transaction.amount))
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(transaction.amount < 0 ? Color.sparkSuccess : .primary)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSelecting && !transaction.canAddToBuffer)
    }

    private func bufferLabel(_ transaction: SpendingTransaction) -> String {
        switch transaction.buffer {
        case "linked": " · Buffered"
        case "requested": " · Buffer requested"
        case "failed": " · Buffer failed"
        default: ""
        }
    }
}
