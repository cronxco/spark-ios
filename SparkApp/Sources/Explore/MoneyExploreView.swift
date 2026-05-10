import SparkKit
import SparkUI
import SwiftUI

struct MoneyExploreView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: MoneyExploreViewModel?
    @State private var path: [DetailRoute] = []
    @State private var showCreateAccount = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    pageHeader
                        .padding(.horizontal, SparkSpacing.lg)

                    content
                }
                .padding(.top, SparkSpacing.md)
                .padding(.bottom, SparkSpacing.xl)
            }
            .sparkAppBackground()
            .sparkMainNavigationTitle("Money")
            .navigationDestination(for: DetailRoute.self) { route in
                switch route {
                case .event(let id):
                    EventDetailView(eventId: id)
                case .account(let id):
                    AccountDetailView(accountId: id)
                default:
                    EmptyView()
                }
            }
            .refreshable {
                await viewModel?.refresh()
            }
            .sparkMainAppToolbar()
            .sheet(isPresented: $showCreateAccount) {
                CreateAccountSheet { account in
                    viewModel?.accountCreated(account)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MoneyExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm = viewModel {
            switch vm.loadState {
            case .idle:
                shimmerPlaceholder
                    .padding(.horizontal, SparkSpacing.lg)
            case .loading where vm.spend == nil:
                shimmerPlaceholder
                    .padding(.horizontal, SparkSpacing.lg)
            case .error(let msg) where vm.spend == nil:
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load money data",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await vm.refresh() } }
                .padding(.horizontal, SparkSpacing.lg)
            default:
                accountsSection(vm: vm)
                    .padding(.horizontal, SparkSpacing.lg)

                spendingHeroCard(vm: vm)
                    .padding(.horizontal, SparkSpacing.lg)

                if let spend = vm.spend, !spend.topMerchants.isEmpty {
                    merchantsSection(merchants: spend.topMerchants, currency: spend.currency)
                        .padding(.horizontal, SparkSpacing.lg)
                }

                transactionsSection(vm: vm)
                    .padding(.horizontal, SparkSpacing.lg)
            }
        } else {
            shimmerPlaceholder
                .padding(.horizontal, SparkSpacing.lg)
        }
    }

    private var pageHeader: some View {
        SparkMainPageHeader(title: "Money", subtitle: headerSubtitle)
    }

    @ViewBuilder
    private func accountsSection(vm: MoneyExploreViewModel) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack {
                Text("Accounts")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    showCreateAccount = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.domainMoney)
                }
                .buttonStyle(.plain)
            }

            switch vm.accountsState {
            case .idle, .loading:
                VStack(spacing: SparkSpacing.xs) {
                    LoadingShimmerCard().frame(height: 72)
                    LoadingShimmerCard().frame(height: 72)
                    LoadingShimmerCard().frame(height: 72)
                }
            case .error:
                GlassCard {
                    EmptyState(
                        systemImage: "creditcard.trianglebadge.exclamationmark",
                        title: "Couldn't load accounts",
                        message: "Pull to refresh."
                    )
                }
            case .loaded where vm.accounts.isEmpty:
                GlassCard {
                    EmptyState(
                        systemImage: "creditcard",
                        title: "No accounts yet",
                        message: "Tap + to create a manual account.",
                        actionTitle: "Add Account"
                    ) { showCreateAccount = true }
                }
            default:
                VStack(spacing: SparkSpacing.xs) {
                    ForEach(groupedAccounts(vm.accounts), id: \.type) { group in
                        accountGroupSection(group: group)
                    }
                }
            }
        }
    }

    private func accountGroupSection(group: AccountGroup) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            HStack {
                Text(group.type)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                Spacer()
                if let total = group.total {
                    Text(formatAmount(total, currency: group.currency))
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(group.isDebt ? Color.sparkError : Color.sparkSuccess)
                }
            }
            .padding(.top, SparkSpacing.xs)

            ForEach(group.accounts) { account in
                Button {
                    path.append(.account(id: account.id))
                } label: {
                    MoneyAccountRow(account: account)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func groupedAccounts(_ accounts: [MoneyAccount]) -> [AccountGroup] {
        let order = ["current_account", "savings_account", "investment_account", "pension",
                     "credit_card", "mortgage", "loan", "other"]
        let grouped = Dictionary(grouping: accounts) { $0.accountType ?? "other" }

        return order.compactMap { type in
            guard let accs = grouped[type], !accs.isEmpty else { return nil }
            let sorted = accs.sorted { $0.title < $1.title }
            let isDebt = ["credit_card", "mortgage", "loan"].contains(type)
            let total: Double? = sorted.compactMap { $0.latestBalance?.balance }.isEmpty ? nil :
                sorted.compactMap { $0.latestBalance?.balance }.reduce(0, +)
            let currency = sorted.first?.currency ?? "GBP"
            return AccountGroup(
                type: accountTypeLabel(type),
                accounts: sorted,
                total: total,
                currency: currency,
                isDebt: isDebt
            )
        }
    }

    private func accountTypeLabel(_ type: String) -> String {
        switch type {
        case "current_account": "Current Accounts"
        case "savings_account": "Savings Accounts"
        case "mortgage": "Mortgages"
        case "investment_account": "Investments"
        case "credit_card": "Credit Cards"
        case "loan": "Loans"
        case "pension": "Pensions"
        default: "Other"
        }
    }

    private func spendingHeroCard(vm: MoneyExploreViewModel) -> some View {
        GlassCard(radius: 22, padding: SparkSpacing.xl) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(alignment: .top, spacing: SparkSpacing.sm) {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        HStack(spacing: SparkSpacing.sm) {
                            Image(systemName: "sterlingsign.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.domainMoney)
                            Text("Daily Spend")
                                .font(SparkTypography.bodyStrong)
                                .foregroundStyle(headerTextColor)
                        }

                        if let spend = vm.spend {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                Text(formatAmount(spend.total, currency: spend.currency))
                                    .font(SparkFonts.display(.largeTitle, weight: .bold))
                                    .foregroundStyle(Color.domainMoney)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.caption2)
                                    Text("\(spend.transactionCount) transactions")
                                        .font(SparkTypography.monoSmall)
                                }
                                .foregroundStyle(Color.sparkSuccess)
                            }
                        } else {
                            LoadingShimmerCard()
                                .frame(width: 140, height: 74)
                        }
                    }

                    Spacer(minLength: SparkSpacing.md)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.domainMoney)
                        .frame(width: 48, height: 48)
                        .background {
                            Circle().fill(Color.domainMoney.opacity(0.12))
                        }
                }

                HStack(spacing: SparkSpacing.sm) {
                    MoneyStatCell(
                        title: "Merchants",
                        value: "\(vm.spend?.topMerchants.count ?? 0)"
                    )
                    MoneyStatCell(
                        title: "Feed",
                        value: "\(vm.transactions.count)"
                    )
                }
            }
        }
    }

    private func merchantsSection(merchants: [SpendWidget.Merchant], currency: String) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Top merchants")
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: SparkSpacing.sm) {
                ForEach(merchants, id: \.id) { merchant in
                    MoneyMerchantRow(merchant: merchant, currency: currency)
                }
            }
        }
    }

    private func transactionsSection(vm: MoneyExploreViewModel) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Recent transactions")
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if vm.transactions.isEmpty {
                GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
                    EmptyState(
                        systemImage: "creditcard",
                        title: "No transactions yet",
                        message: "Connect a bank integration to see your transactions here."
                    )
                }
            } else {
                VStack(spacing: SparkSpacing.sm) {
                    ForEach(vm.transactions) { event in
                        Button {
                            path.append(.event(id: event.id))
                        } label: {
                            MoneyTransactionRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var shimmerPlaceholder: some View {
        VStack(spacing: SparkSpacing.sm) {
            LoadingShimmerCard().frame(height: 198)
            LoadingShimmerCard().frame(height: 104)
            LoadingShimmerCard().frame(height: 104)
            LoadingShimmerCard().frame(height: 104)
        }
    }

    private func formatAmount(_ value: Double, currency: String) -> String {
        let symbol: String = switch currency {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: currency + " "
        }
        return "\(symbol)\(String(format: "%.2f", value))"
    }

    private var headerTextColor: Color {
        colorScheme == .dark ? Color.spark100 : Color.sparkTextPrimary
    }

    private var headerSubtitle: String {
        switch viewModel?.loadState {
        case .loaded:
            let count = viewModel?.transactions.count ?? 0
            return "\(count) recent transaction\(count == 1 ? "" : "s")"
        case .error:
            return "Money data unavailable"
        case .loading:
            return "Loading spending signals"
        case .idle, .none:
            return "Spending and transaction signals"
        }
    }
}

private struct AccountGroup {
    let type: String
    let accounts: [MoneyAccount]
    let total: Double?
    let currency: String
    let isDebt: Bool
}

private struct MoneyAccountRow: View {
    let account: MoneyAccount

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            Image(systemName: accountIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: SparkRadii.sm)
                        .fill(Color.domainMoney)
                )

            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(account.title)
                    .font(SparkTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let provider = account.provider {
                    Text(provider)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            if let balance = account.latestBalance {
                Text(formattedBalance(balance.balance, currency: account.currency))
                    .font(SparkFonts.display(.callout, weight: .bold))
                    .foregroundStyle(balanceColor(balance: balance.balance, isNegative: account.isNegativeBalance))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("—")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .frame(height: 72)
        .contentShape(Rectangle())
        .sparkGlass(.roundedRect(20))
    }

    private var accountIcon: String {
        switch account.kind {
        case "credit_card": "creditcard.fill"
        case "monzo_account", "bank_account": "building.columns.fill"
        case "monzo_pot": "bitcoinsign.square.fill"
        default: "sterlingsign.circle.fill"
        }
    }

    private func formattedBalance(_ value: Double, currency: String) -> String {
        let symbol: String = switch currency {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: currency + " "
        }
        return "\(symbol)\(String(format: "%.2f", abs(value)))"
    }

    private func balanceColor(balance: Double, isNegative: Bool) -> Color {
        isNegative ? Color.sparkError : (balance >= 0 ? Color.sparkSuccess : Color.sparkError)
    }
}

private struct MoneyMerchantRow: View {
    let merchant: SpendWidget.Merchant
    let currency: String

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            Image(systemName: "cart.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: SparkRadii.sm)
                        .fill(Color.domainMoney)
                )

            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(merchant.name)
                    .font(SparkTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let count = merchant.count {
                    Text("\(count) transaction\(count == 1 ? "" : "s")")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            Text(formatAmount(merchant.total, currency: currency))
                .font(SparkFonts.display(.title3, weight: .bold))
                .foregroundStyle(Color.domainMoney)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .frame(height: 92)
        .sparkGlass(.roundedRect(20))
    }

    private func formatAmount(_ value: Double, currency: String) -> String {
        let symbol: String = switch currency {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: currency + " "
        }
        return "\(symbol)\(String(format: "%.2f", value))"
    }
}

private struct MoneyTransactionRow: View {
    let event: Event

    private var merchant: String {
        event.target?.title ?? event.actor?.title ?? event.service.capitalized
    }

    private var amount: String {
        if let displayValue = event.displayValue?.sparkPlainTextFromHTMLFragment, !displayValue.isEmpty {
            return displayValue
        }
        guard let value = event.value else { return "" }
        let plainValue = value.sparkPlainTextFromHTMLFragment
        let unit = event.unit ?? ""
        if !unit.isEmpty, plainValue.localizedCaseInsensitiveContains(unit) {
            return plainValue
        }
        let symbol: String = switch unit {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: unit.isEmpty ? "" : unit + " "
        }
        return "\(symbol)\(plainValue)"
    }

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            Image(systemName: "sterlingsign")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: SparkRadii.sm)
                        .fill(Color.domainMoney)
                )

            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(merchant)
                    .font(SparkTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let time = event.time {
                    Text(time.formatted(date: .abbreviated, time: .omitted))
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            if !amount.isEmpty {
                Text(amount)
                    .font(SparkFonts.display(.title3, weight: .bold))
                    .foregroundStyle(Color.domainMoney)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .frame(height: 92)
        .contentShape(Rectangle())
        .sparkGlass(.roundedRect(20))
    }
}

private struct MoneyStatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
            Text(value)
                .font(SparkTypography.titleStrong)
                .foregroundStyle(.primary)
            Text(title)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.sm))
    }
}
