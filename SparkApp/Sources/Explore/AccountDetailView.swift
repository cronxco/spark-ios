import SparkKit
import SparkUI
import SwiftUI

struct AccountDetailView: View {
    let accountId: String

    @Environment(AppModel.self) private var appModel
    @State private var viewModel: AccountDetailViewModel?
    @State private var showAddBalance = false
    @State private var showEditAccount = false
    @State private var showArchiveConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                if let vm = viewModel {
                    switch vm.loadState {
                    case .loading:
                        shimmerPlaceholder
                    case .error(let msg):
                        EmptyState(
                            systemImage: "exclamationmark.triangle.fill",
                            title: "Couldn't load account",
                            message: msg,
                            actionTitle: "Retry"
                        ) { Task { await vm.load() } }
                    case .loaded:
                        if let account = vm.account {
                            balanceHero(account: account)
                            actionsRow(account: account)
                            detailsCard(account: account)
                            balanceHistorySection(vm: vm)
                        }
                    }
                } else {
                    shimmerPlaceholder
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xl)
        }
        .sparkAppBackground()
        .sparkMainNavigationTitle(viewModel?.account?.title ?? "Account")
        .navigationBarTitleDisplayMode(.inline)
        .sparkMainAppToolbar(isVisible: false)
        .task {
            if viewModel == nil {
                viewModel = AccountDetailViewModel(accountId: accountId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
        .sheet(isPresented: $showAddBalance) {
            if let vm = viewModel {
                AddBalanceSheet(accountId: accountId, currency: vm.account?.currency ?? "GBP") { entry in
                    vm.balanceAdded(entry)
                }
            }
        }
        .sheet(isPresented: $showEditAccount) {
            if let vm = viewModel, let account = vm.account {
                EditAccountSheet(account: account) { updated in
                    vm.accountUpdated(updated)
                }
            }
        }
        .confirmationDialog(
            "Archive Account",
            isPresented: $showArchiveConfirm,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) {
                Task {
                    do {
                        try await viewModel?.archive()
                    } catch {
                        // error surfaced via state
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will mark the account as archived and record a final £0 balance. It won't be deleted.")
        }
    }

    // MARK: - Sections

    private func balanceHero(account: MoneyAccount) -> some View {
        GlassCard(radius: 22, padding: SparkSpacing.xl, tint: balanceTint(account: account)) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(spacing: SparkSpacing.sm) {
                    Image(systemName: accountIcon(kind: account.kind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.domainMoney)
                    Text(accountTypeLabel(account.accountType))
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.secondary)
                    if let provider = account.provider {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(provider)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                }

                if let balance = account.latestBalance {
                    Text(formatAmount(balance.balance, currency: account.currency, isNegative: account.isNegativeBalance))
                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                        .foregroundStyle(balanceColor(balance: balance.balance, isNegative: account.isNegativeBalance))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("Updated \(balance.time.relativeFormatted)")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No balance recorded")
                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func actionsRow(account: MoneyAccount) -> some View {
        HStack(spacing: SparkSpacing.sm) {
            PillButton("Add Balance", systemImage: "plus.circle.fill", tint: Color.domainMoney) {
                showAddBalance = true
            }

            if account.kind == "manual_account" {
                PillButton("Edit", systemImage: "pencil", tint: .secondary) {
                    showEditAccount = true
                }
                PillButton("Archive", systemImage: "archivebox", tint: .orange) {
                    showArchiveConfirm = true
                }
            }
        }
    }

    private func detailsCard(account: MoneyAccount) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                GlassCardHeader(icon: "info.circle.fill", tint: Color.domainMoney, title: "Details")
                    .padding(.bottom, SparkSpacing.md)

                InspectorRow("Type") {
                    Text(accountTypeLabel(account.accountType))
                }
                InspectorRow("Currency") {
                    Text(account.currency)
                }
                if let provider = account.provider {
                    InspectorRow("Provider") {
                        Text(provider)
                    }
                }
                if let accountNumber = account.accountNumber {
                    InspectorRow("Account No.") {
                        Text(accountNumber)
                    }
                }
                if let sortCode = account.sortCode {
                    InspectorRow("Sort Code") {
                        Text(sortCode)
                    }
                }
                if let rate = account.interestRate {
                    InspectorRow("Interest") {
                        Text("\(String(format: "%.2f", rate))%")
                    }
                }
                if let startDate = account.startDate {
                    InspectorRow("Opened") {
                        Text(startDate)
                    }
                }
            }
        }
    }

    private func balanceHistorySection(vm: AccountDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Balance History")
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if vm.balances.isEmpty {
                GlassCard {
                    EmptyState(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "No balance history",
                        message: "Add a balance update to start tracking."
                    )
                }
            } else {
                VStack(spacing: SparkSpacing.xs) {
                    ForEach(vm.balances) { entry in
                        BalanceHistoryRow(
                            entry: entry,
                            currency: vm.account?.currency ?? "GBP",
                            isNegative: vm.account?.isNegativeBalance ?? false
                        )
                    }
                }

                if vm.hasMore {
                    Button {
                        Task { await vm.loadMoreBalances() }
                    } label: {
                        HStack {
                            if vm.isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(vm.isLoadingMore ? "Loading…" : "Load more")
                                .font(SparkTypography.bodySmall)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.lg))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingMore)
                }
            }
        }
    }

    private var shimmerPlaceholder: some View {
        VStack(spacing: SparkSpacing.sm) {
            LoadingShimmerCard().frame(height: 140)
            LoadingShimmerCard().frame(height: 56)
            LoadingShimmerCard().frame(height: 180)
        }
    }

    // MARK: - Helpers

    private func balanceTint(account: MoneyAccount) -> Color {
        guard let balance = account.latestBalance?.balance else { return .clear }
        if account.isNegativeBalance {
            return Color.sparkError.opacity(0.08)
        }
        return balance >= 0 ? Color.sparkSuccess.opacity(0.08) : Color.sparkError.opacity(0.08)
    }

    private func balanceColor(balance: Double, isNegative: Bool) -> Color {
        isNegative ? Color.sparkError : (balance >= 0 ? Color.sparkSuccess : Color.sparkError)
    }

    private func formatAmount(_ value: Double, currency: String, isNegative: Bool) -> String {
        let symbol: String = switch currency {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: currency + " "
        }
        return "\(symbol)\(String(format: "%.2f", abs(value)))"
    }

    private func accountTypeLabel(_ type: String?) -> String {
        switch type {
        case "current_account": "Current Account"
        case "savings_account": "Savings Account"
        case "mortgage": "Mortgage"
        case "investment_account": "Investment Account"
        case "credit_card": "Credit Card"
        case "loan": "Loan"
        case "pension": "Pension"
        default: type?.capitalized ?? "Account"
        }
    }

    private func accountIcon(kind: String) -> String {
        switch kind {
        case "credit_card": "creditcard.fill"
        case "monzo_account", "bank_account": "building.columns.fill"
        case "monzo_pot": "bitcoinsign.square.fill"
        default: "sterlingsign.circle.fill"
        }
    }
}

private struct BalanceHistoryRow: View {
    let entry: BalanceEntry
    let currency: String
    let isNegative: Bool

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(entry.time.formatted(date: .abbreviated, time: .omitted))
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.primary)
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            Text(formattedBalance)
                .font(SparkFonts.display(.callout, weight: .semibold))
                .foregroundStyle(balanceColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.md))
    }

    private var formattedBalance: String {
        let symbol: String = switch currency {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: currency + " "
        }
        return "\(symbol)\(String(format: "%.2f", abs(entry.balance)))"
    }

    private var balanceColor: Color {
        isNegative ? Color.sparkError : (entry.balance >= 0 ? Color.sparkSuccess : Color.sparkError)
    }
}

private extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
