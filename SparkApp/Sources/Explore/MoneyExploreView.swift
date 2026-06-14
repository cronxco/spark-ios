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
    @State private var expandedAccountGroupTypes: Set<String> = []

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
            .sparkDetailDestinations()
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

    private var pageHeader: some View {
        SparkMainPageHeader(title: "Money", subtitle: headerSubtitle)
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
        GlassCard(radius: 28, padding: SparkSpacing.xl) {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                Text("Net worth")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)

                let netWorth = vm.netWorth

                Text(SparkValueFormatting.currency(netWorth, code: "GBP"))
                    .font(SparkFonts.display(size: 44))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                let history = filteredHistory(vm: vm)
                let delta = netWorthDelta(history: history)
                let percent = netWorthDeltaPercent(history: history)

                if delta != 0 {
                    HStack(spacing: SparkSpacing.xs) {
                        Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                        Text("\(formatAmount(abs(delta))) · \(String(format: "%.1f%%", abs(percent))) · \(selectedRange.rangeLabel)")
                            .font(SparkTypography.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, SparkSpacing.md)
                    .padding(.vertical, SparkSpacing.xs)
                    .background(Color.domainMoney, in: Capsule())
                }

                chartBody(history: history, tint: Color.domainMoney)
                    .frame(height: 160)

                rangeChips
            }
        }
    }

    private var rangeChips: some View {
        RangeChipBar(
            items: HistoryRange.allCases.map(\.rawValue),
            selected: Binding(
                get: { selectedRange.rawValue },
                set: { value in
                    guard let range = HistoryRange(rawValue: value) else { return }
                    selectedRange = range
                }
            ),
            tint: .domainMoney
        )
    }

    @ViewBuilder
    private func chartBody(history: [BalanceAreaChart.Point], tint: Color) -> some View {
        if case .loading = viewModel?.historyState {
            LoadingShimmerCard()
        } else if history.count >= 2 {
            BalanceAreaChart(data: history, tint: tint, showMidline: true, showEndpoint: true)
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
                    HStack(spacing: SparkSpacing.sm) {
                        DomainGlyph(icon: "chart.pie.fill", tint: Color.domainMoney, size: 26)
                        Text("Where it lives")
                            .font(SparkFonts.display(.headline, weight: .bold))
                            .foregroundStyle(.primary)
                    }
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
                                    Text(formattedMoneyAmount(segment.value, currency: "GBP", fractionDigits: 0))
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
            HStack(spacing: SparkSpacing.sm) {
                SparkSectionHeader(title: "Accounts", icon: "sterlingsign", tint: Color.domainMoney)
                Button {
                    showCreateAccount = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.sparkTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.domainMoney, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Account")
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
        let isExpanded = !group.collapsedByDefault || expandedAccountGroupTypes.contains(group.rawType)

        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Button {
                guard group.collapsedByDefault else { return }
                withAnimation(.snappy(duration: 0.22)) {
                    toggleGroup(group.rawType)
                }
            } label: {
                AccountGroupHeader(group: group, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .accessibilityHint(group.collapsedByDefault ? "Toggles account group" : "")

            if isExpanded {
                ForEach(group.accounts) { account in
                    Button {
                        path.append(.account(id: account.id))
                    } label: {
                        MoneyAccountRow(account: account)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        toggleGroup(group.rawType)
                    }
                } label: {
                    CollapsedAccountGroupRow(group: group)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func groupedAccounts(_ accounts: [MoneyAccount]) -> [AccountGroup] {
        let order = [
            "current_account",
            "credit_card",
            "savings_account",
            "investment_account",
            "pension",
            "mortgage",
            "loan",
            "other"
        ]

        let grouped = Dictionary(grouping: accounts) { $0.accountType ?? "other" }
        let orderedTypes = order + grouped.keys
            .filter { !order.contains($0) }
            .sorted()

        return orderedTypes.compactMap { type in
            guard let accs = grouped[type], !accs.isEmpty else { return nil }
            let sorted = accs.sorted { $0.title < $1.title }
            let isDebt = isDebtAccountType(type)
            let balances = sorted.compactMap { $0.latestBalance?.balance }
            let total: Double? = balances.isEmpty ? nil : balances.reduce(0, +)
            return AccountGroup(
                rawType: type,
                type: accountTypeLabel(type),
                accounts: sorted,
                total: total,
                currency: sorted.first?.currency ?? "GBP",
                isDebt: isDebt,
                tint: accountGroupTint(for: type),
                icon: accountGroupIcon(for: type),
                collapsedByDefault: collapsedByDefault(for: type)
            )
        }
    }

    private func toggleGroup(_ rawType: String) {
        if expandedAccountGroupTypes.contains(rawType) {
            expandedAccountGroupTypes.remove(rawType)
        } else {
            expandedAccountGroupTypes.insert(rawType)
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

    private func formatAmount(_ value: Double) -> String {
        SparkValueFormatting.currency(value, code: "GBP")
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

    private func isDebtAccountType(_ type: String) -> Bool {
        ["credit_card", "mortgage", "loan"].contains(type)
    }

    private func collapsedByDefault(for type: String) -> Bool {
        ["savings_account", "investment_account", "pension"].contains(type)
    }

    private func accountGroupTint(for type: String) -> Color {
        switch type {
        case "savings_account": Color.sparkSuccess
        case "investment_account", "pension": Color.ocean300
        case "credit_card", "mortgage", "loan": Color.sparkError
        case "current_account": Color.domainMoney
        default: Color.secondary.opacity(0.6)
        }
    }

    private func accountGroupIcon(for type: String) -> String {
        switch type {
        case "current_account": "sterlingsign"
        case "savings_account": "banknote.fill"
        case "investment_account": "chart.line.uptrend.xyaxis"
        case "pension": "building.columns.fill"
        case "credit_card": "creditcard.fill"
        case "mortgage": "house.fill"
        case "loan": "doc.text.fill"
        default: "folder.fill"
        }
    }

    private var headerSubtitle: String {
        guard let vm = viewModel else { return "Loading accounts" }
        switch vm.loadState {
        case .idle, .loading:
            return vm.accounts.isEmpty ? "Loading accounts" : lastSyncedSubtitle(for: vm.accounts)
        case .error:
            return "Accounts unavailable"
        case .loaded:
            return vm.accounts.isEmpty ? "No accounts synced yet" : lastSyncedSubtitle(for: vm.accounts)
        }
    }

    private func lastSyncedSubtitle(for accounts: [MoneyAccount]) -> String {
        guard let lastUpdatedAt = accounts.map(\.updatedAt).max() else {
            return "No accounts synced yet"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(lastUpdatedAt) {
            return "Last synced today at \(SparkDateFormatting.shortTime(lastUpdatedAt))"
        }
        if calendar.isDateInYesterday(lastUpdatedAt) {
            return "Last synced yesterday at \(SparkDateFormatting.shortTime(lastUpdatedAt))"
        }
        return "Last synced \(Self.syncDateFormatter.string(from: lastUpdatedAt))"
    }

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

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
    let rawType: String
    let type: String
    let accounts: [MoneyAccount]
    let total: Double?
    let currency: String
    let isDebt: Bool
    let tint: Color
    let icon: String
    let collapsedByDefault: Bool
}

// MARK: - AccountGroupHeader

private struct AccountGroupHeader: View {
    let group: AccountGroup
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: SparkSpacing.sm) {
            SparkSectionHeader(title: group.type, icon: group.icon, tint: group.tint)
            Spacer()
            if let total = group.total {
                Text(formattedMoneyAmount(total, currency: group.currency))
                    .font(SparkTypography.monoSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(group.isDebt ? Color.sparkError : Color.primary)
            }
            if group.collapsedByDefault {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .padding(.top, SparkSpacing.xs)
    }

}

// MARK: - CollapsedAccountGroupRow

private struct CollapsedAccountGroupRow: View {
    let group: AccountGroup

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(icon: "chevron.right", tint: group.tint, size: 42)

            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(group.type)
                    .font(SparkTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(group.accounts.count) account\(group.accounts.count == 1 ? "" : "s")")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: SparkSpacing.sm)

            if let total = group.total {
                Text(formattedMoneyAmount(total, currency: group.currency))
                    .font(SparkFonts.display(size: 18))
                    .foregroundStyle(group.isDebt ? Color.sparkError : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, SparkSpacing.lg)
        .frame(height: 72)
        .contentShape(Rectangle())
        .sparkGlass(.roundedRect(20))
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
                Text(account.title)
                    .font(SparkTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let provider = account.provider {
                    Text(provider.capitalized)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            VStack(alignment: .trailing, spacing: SparkSpacing.xxs) {
                if let balance = account.latestBalance {
                    Text(formattedMoneyAmount(balance.balance, currency: account.currency))
                        .font(SparkFonts.display(size: 18))
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

    private func balanceColor(balance: Double, isNegative: Bool) -> Color {
        isNegative || balance < 0 ? Color.sparkError : Color.primary
    }
}

private func formattedMoneyAmount(_ value: Double, currency: String, fractionDigits: Int = 2) -> String {
    SparkValueFormatting.currency(
        value,
        code: currency,
        fractionDigits: fractionDigits
    )
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
