import Charts
import SparkKit
import SparkUI
import SwiftUI

enum HistoryRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "ALL"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .oneMonth: 30
        case .threeMonths: 90
        case .sixMonths: 180
        case .oneYear: 365
        case .all: nil
        }
    }

    var rangeLabel: String {
        switch self {
        case .oneMonth: "vs 1M"
        case .threeMonths: "vs 3M"
        case .sixMonths: "vs 6M"
        case .oneYear: "vs 1Y"
        case .all: "all time"
        }
    }
}

struct MoneyExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MoneyExploreViewModel?
    @State private var path: [DetailRoute] = []
    @State private var showCreateAccount = false
    @State private var selectedRange: HistoryRange = .oneMonth

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
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
            case .idle, .loading:
                shimmerPlaceholder
                    .padding(.horizontal, SparkSpacing.lg)
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load accounts",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await vm.refresh() } }
                .padding(.horizontal, SparkSpacing.lg)
            case .loaded:
                netWorthHero(vm: vm)
                    .padding(.horizontal, SparkSpacing.lg)

                if !vm.accounts.isEmpty {
                    compositionCard(vm: vm)
                        .padding(.horizontal, SparkSpacing.lg)
                }

                accountsSection(vm: vm)
                    .padding(.horizontal, SparkSpacing.lg)

                if !vm.rawFeedEntries.isEmpty {
                    RawFeedJSONView(entries: vm.rawFeedEntries)
                        .padding(.horizontal, SparkSpacing.lg)
                }
            }
        } else {
            shimmerPlaceholder
                .padding(.horizontal, SparkSpacing.lg)
        }
    }

    // MARK: - Net Worth Hero

    private func netWorthHero(vm: MoneyExploreViewModel) -> some View {
        GlassCard(radius: 22, padding: SparkSpacing.xl, tint: Color.domainMoney.opacity(0.06)) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                Text("NET WORTH")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                let netWorth = vm.netWorth
                let isPositive = netWorth >= 0
                let netWorthColor: Color = isPositive ? .sparkSuccess : .sparkError

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(formatInteger(netWorth))
                        .font(.system(size: 52, weight: .bold, design: .default))
                        .foregroundStyle(netWorthColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(formatDecimal(netWorth))
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .foregroundStyle(netWorthColor.opacity(0.7))
                }

                let history = filteredHistory(vm: vm)
                let delta = netWorthDelta(history: history)
                let percent = netWorthDeltaPercent(history: history)

                if delta != 0 {
                    HStack(spacing: SparkSpacing.xs) {
                        Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(formatAmount(abs(delta)))  \(String(format: "%.1f%%", abs(percent)))  \(selectedRange.rangeLabel)")
                            .font(SparkTypography.bodySmall)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(delta > 0 ? Color.sparkSuccess : Color.sparkError)
                }

                rangeChips

                chartBody(history: history, tint: netWorthColor)
                    .frame(height: 100)
            }
        }
    }

    private var rangeChips: some View {
        HStack(spacing: SparkSpacing.xs) {
            ForEach(HistoryRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(SparkTypography.monoSmall)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if selectedRange == range {
                                RoundedRectangle(cornerRadius: SparkRadii.sm)
                                    .fill(Color.domainMoney)
                            } else {
                                RoundedRectangle(cornerRadius: SparkRadii.sm)
                                    .fill(.primary.opacity(0.06))
                            }
                        }
                        .foregroundStyle(selectedRange == range ? .black : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func chartBody(history: [BalanceAreaChart.Point], tint: Color) -> some View {
        if case .loading = viewModel?.historyState {
            LoadingShimmerCard()
        } else if history.count >= 2 {
            BalanceAreaChart(data: history, tint: tint)
        } else {
            RoundedRectangle(cornerRadius: SparkRadii.sm)
                .fill(.primary.opacity(0.04))
                .overlay {
                    Text("Not enough history")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.tertiary)
                }
        }
    }

    // MARK: - Composition Card

    @ViewBuilder
    private func compositionCard(vm: MoneyExploreViewModel) -> some View {
        let segments = compositionSegments(vm.accounts)
        if !segments.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    GlassCardHeader(icon: "chart.pie.fill", tint: Color.domainMoney, title: "Where It Lives")
                        .padding(.bottom, SparkSpacing.md)

                    HStack(alignment: .center, spacing: SparkSpacing.lg) {
                        Chart(segments) { segment in
                            SectorMark(
                                angle: .value("Amount", segment.value),
                                innerRadius: .ratio(0.60),
                                angularInset: 1.5
                            )
                            .foregroundStyle(segment.color)
                            .cornerRadius(3)
                        }
                        .frame(width: 120, height: 120)

                        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                            ForEach(segments) { segment in
                                HStack(spacing: SparkSpacing.xs) {
                                    Circle()
                                        .fill(segment.color)
                                        .frame(width: 8, height: 8)
                                    Text(segment.type)
                                        .font(SparkTypography.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(formatAmount(segment.value))
                                        .font(SparkTypography.monoSmall)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private struct CompositionSegment: Identifiable {
        let id: String
        let type: String
        let value: Double
        let color: Color
    }

    private func compositionSegments(_ accounts: [MoneyAccount]) -> [CompositionSegment] {
        let grouped = Dictionary(grouping: accounts) { $0.accountType ?? "other" }
        return grouped.compactMap { type, accs in
            let total = accs.compactMap { acc -> Double? in
                guard let bal = acc.latestBalance?.balance, bal > 0 else { return nil }
                return acc.isNegativeBalance ? nil : bal
            }.reduce(0, +)
            guard total > 0 else { return nil }
            return CompositionSegment(
                id: type,
                type: accountTypeLabel(type),
                value: total,
                color: segmentColor(for: type)
            )
        }
        .sorted { $0.value > $1.value }
    }

    private func segmentColor(for type: String) -> Color {
        switch type {
        case "savings_account": Color.sparkSuccess
        case "investment_account", "pension": Color.ocean300
        case "current_account": Color.domainMoney
        case "credit_card", "mortgage", "loan": Color.sparkError
        default: Color.secondary.opacity(0.4)
        }
    }

    // MARK: - Accounts Section

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

            if vm.accounts.isEmpty {
                GlassCard {
                    EmptyState(
                        systemImage: "creditcard",
                        title: "No accounts yet",
                        message: "Tap + to add your first account.",
                        actionTitle: "Add Account"
                    ) { showCreateAccount = true }
                }
            } else {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    let groups = groupedAccounts(vm.accounts)
                    ForEach(groups, id: \.type) { group in
                        accountGroup(group: group)
                    }
                }
            }
        }
    }

    private func accountGroup(group: AccountGroup) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            AccountGroupHeader(
                label: group.type,
                count: group.accounts.count,
                total: group.total,
                currency: group.currency,
                isDebt: group.isDebt
            )

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
        let assetTypes = ["current_account", "savings_account", "investment_account", "pension"]
        let debtTypes = ["credit_card", "mortgage", "loan"]
        let order = assetTypes + debtTypes + ["other"]

        let grouped = Dictionary(grouping: accounts) { $0.accountType ?? "other" }
        return order.compactMap { type in
            guard let accs = grouped[type], !accs.isEmpty else { return nil }
            let sorted = accs.sorted { $0.title < $1.title }
            let isDebt = debtTypes.contains(type)
            let balances = sorted.compactMap { $0.latestBalance?.balance }
            let total: Double? = balances.isEmpty ? nil : balances.reduce(0, +)
            return AccountGroup(
                type: accountTypeLabel(type),
                accounts: sorted,
                total: total,
                currency: sorted.first?.currency ?? "GBP",
                isDebt: isDebt
            )
        }
    }

    // MARK: - Helpers

    private func filteredHistory(vm: MoneyExploreViewModel) -> [BalanceAreaChart.Point] {
        let cutoff: Date? = selectedRange.days.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: .now)!
        }
        return vm.netWorthHistory
            .filter { point in cutoff.map { point.date >= $0 } ?? true }
            .map { BalanceAreaChart.Point(date: $0.date, value: $0.total) }
    }

    private func netWorthDelta(history: [BalanceAreaChart.Point]) -> Double {
        guard let first = history.first?.value, let last = history.last?.value else { return 0 }
        return last - first
    }

    private func netWorthDeltaPercent(history: [BalanceAreaChart.Point]) -> Double {
        guard let first = history.first?.value, first != 0 else { return 0 }
        return (netWorthDelta(history: history) / abs(first)) * 100
    }

    private func formatInteger(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "£" + (f.string(from: NSNumber(value: abs(value))) ?? "0")
    }

    private func formatDecimal(_ value: Double) -> String {
        let cents = Int((abs(value) * 100).rounded()) % 100
        return String(format: ".%02d", cents)
    }

    private func formatAmount(_ value: Double) -> String {
        "£\(String(format: "%.2f", abs(value)))"
    }

    private func accountTypeLabel(_ type: String) -> String {
        switch type {
        case "current_account": "Current Accounts"
        case "savings_account": "Savings"
        case "mortgage": "Mortgages"
        case "investment_account": "Investments"
        case "credit_card": "Credit Cards"
        case "loan": "Loans"
        case "pension": "Pensions"
        default: "Other"
        }
    }

    private var shimmerPlaceholder: some View {
        VStack(spacing: SparkSpacing.sm) {
            LoadingShimmerCard().frame(height: 240)
            LoadingShimmerCard().frame(height: 160)
            LoadingShimmerCard().frame(height: 72)
            LoadingShimmerCard().frame(height: 72)
            LoadingShimmerCard().frame(height: 72)
        }
    }
}

// MARK: - Supporting Types

private struct AccountGroup {
    let type: String
    let accounts: [MoneyAccount]
    let total: Double?
    let currency: String
    let isDebt: Bool
}

// MARK: - AccountGroupHeader

private struct AccountGroupHeader: View {
    let label: String
    let count: Int
    let total: Double?
    let currency: String
    let isDebt: Bool

    var body: some View {
        HStack(spacing: SparkSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isDebt ? Color.sparkError : Color.sparkSuccess)
                .frame(width: 7, height: 7)
            Text(label)
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let total {
                Text(formatAmount(total, currency: currency))
                    .font(SparkTypography.monoSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(isDebt ? Color.sparkError : Color.sparkSuccess)
            }
        }
        .padding(.top, SparkSpacing.xs)
    }

    private func formatAmount(_ value: Double, currency: String) -> String {
        let symbol: String = switch currency {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: currency + " "
        }
        return "\(symbol)\(String(format: "%.2f", abs(value)))"
    }
}

// MARK: - BankTile

private struct BankTile: View {
    let provider: String?
    let title: String
    let size: CGFloat

    init(provider: String?, title: String, size: CGFloat = 42) {
        self.provider = provider
        self.title = title
        self.size = size
    }

    var body: some View {
        let (from, to) = issuerTintColors(provider: provider)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(initials)
                .font(.system(size: size * 0.33, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let source = provider ?? title
        let words = source.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
        return String(source.prefix(2)).uppercased()
    }
}

// MARK: - MoneyAccountRow

private struct MoneyAccountRow: View {
    let account: MoneyAccount

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            BankTile(provider: account.provider, title: account.title)

            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                HStack(spacing: SparkSpacing.xs) {
                    Text(account.title)
                        .font(SparkTypography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let type = account.accountType {
                        Text(accountTypeChip(type))
                            .font(SparkTypography.caption)
                            .foregroundStyle(Color.domainMoney)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.domainMoney.opacity(0.12), in: Capsule())
                    }
                }
                if let provider = account.provider {
                    Text(provider.capitalized)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            VStack(alignment: .trailing, spacing: SparkSpacing.xxs) {
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

    private func accountTypeChip(_ type: String) -> String {
        switch type {
        case "current_account": "Current"
        case "savings_account": "Savings"
        case "mortgage": "Mortgage"
        case "investment_account": "Investment"
        case "credit_card": "Credit"
        case "loan": "Loan"
        case "pension": "Pension"
        default: type.capitalized
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

// MARK: - Issuer Tint Helper

private func issuerTintColors(provider: String?) -> (Color, Color) {
    switch provider?.lowercased() {
    case "monzo":    return (Color(red: 0.953, green: 0.612, blue: 0.518), Color(red: 0.831, green: 0.369, blue: 0.271))
    case "starling": return (Color(red: 0.565, green: 0.537, blue: 0.855), Color(red: 0.310, green: 0.278, blue: 0.647))
    case "amex":     return (Color(red: 0.435, green: 0.584, blue: 0.780), Color(red: 0.176, green: 0.341, blue: 0.565))
    case "halifax":  return (Color(red: 0.482, green: 0.612, blue: 0.800), Color(red: 0.204, green: 0.369, blue: 0.580))
    default:         return (Color.domainMoney.opacity(0.7), Color.domainMoney)
    }
}
