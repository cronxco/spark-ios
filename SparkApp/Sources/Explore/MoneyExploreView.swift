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

    /// The point a change is measured from, as a sentence ends it:
    /// "£1,204.00 above 1 month ago".
    var baselinePhrase: String {
        switch self {
        case .oneMonth: "1 month ago"
        case .threeMonths: "3 months ago"
        case .sixMonths: "6 months ago"
        case .oneYear: "a year ago"
        case .all: "the first balance"
        }
    }
}

/// Explore › Money as one page, ordered by what the reader acts on first:
/// what is safe to spend, whether the cards are covered, the bills before
/// payday, this month's spending, then net worth, accounts and pots.
struct MoneyExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MoneyExploreViewModel?
    @State private var planViewModel: MoneyPlanViewModel?
    @Binding var path: [DetailRoute]
    @State private var showCreateAccount = false
    @State private var selectedRange: HistoryRange = .oneMonth
    @State private var expandedGroups: Set<String> = ["current_account", "credit_card"]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.xxl) {
                    planSections(proxy: proxy)
                    worthSection(proxy: proxy)
                    potsSection
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.top, SparkSpacing.md)
                .padding(.bottom, SparkSpacing.xl)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("spark.integrationReauthorised"))) { _ in
            Task {
                await viewModel?.refresh()
                await planViewModel?.refresh()
            }
        }
        .refreshable {
            await planViewModel?.refresh()
            await viewModel?.refresh()
        }
        .sheet(isPresented: $showCreateAccount) {
            CreateAccountSheet { account in
                viewModel?.accountCreated(account)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MoneyExploreViewModel(apiClient: appModel.apiClient)
            }
            if planViewModel == nil {
                planViewModel = MoneyPlanViewModel(apiClient: appModel.apiClient)
            }
            await planViewModel?.load()
            await viewModel?.load()
        }
    }

    // MARK: Plan

    @ViewBuilder
    private func planSections(proxy: ScrollViewProxy) -> some View {
        if let vm = planViewModel {
            switch vm.loadState {
            case .idle where vm.plan == nil, .loading where vm.plan == nil:
                shimmer(heights: [220, 160, 120])
            case .error(let message):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load your plan",
                    message: message,
                    actionTitle: "Retry"
                ) { Task { await vm.refresh() } }
            default:
                if let plan = vm.plan {
                    MoneySafeToSpendCard(safe: plan.safeToSpend) {
                        withAnimation(.snappy(duration: 0.3)) { proxy.scrollTo("bills", anchor: .top) }
                    }
                    MoneyCardCoverSection(cover: plan.cover)
                    if !plan.safeToSpend.bills.isEmpty {
                        MoneyBillsSection(bills: plan.safeToSpend.bills)
                            .id("bills")
                    }
                    if let spending = vm.spending {
                        MoneySpendingSection(viewModel: vm, spending: spending, bufferEnabled: plan.bufferEnabled)
                    }
                }
            }
        } else {
            shimmer(heights: [220, 160, 120])
        }
    }

    @ViewBuilder
    private var potsSection: some View {
        if let vm = planViewModel, let plan = vm.plan {
            MoneyPotsSection(viewModel: vm, plan: plan)
                .id("pots")
        }
    }

    // MARK: Net worth

    @ViewBuilder
    private func worthSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            MoneySectionHeader(title: "Net worth", icon: .netWorth)
            if let vm = viewModel {
                switch vm.loadState {
                case .idle where vm.accounts.isEmpty, .loading where vm.accounts.isEmpty:
                    shimmer(heights: [260, 56, 56])
                case .error(let message):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load accounts",
                        message: message,
                        actionTitle: "Retry"
                    ) { Task { await vm.refresh() } }
                default:
                    if vm.accounts.isEmpty {
                        MoneyCard {
                            Text("No accounts yet. Add one to start tracking your net worth.")
                                .font(SparkTypography.body)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        worthCard(vm: vm)
                        accountGroups(vm: vm, proxy: proxy)
                    }
                    addAccountButton
                }
            } else {
                shimmer(heights: [260, 56, 56])
            }
        }
    }

    private func worthCard(vm: MoneyExploreViewModel) -> some View {
        let history = filteredHistory(vm: vm)
        let composition = Composition(accounts: vm.accounts.filter { $0.currency == "GBP" })
        return MoneyCard {
            MoneyHeroValue(pounds: vm.netWorth)
            comparison(history: history)
            chart(history: history)
                .frame(height: 160)
            RangeChipBar(HistoryRange.allCases, selected: selectedRange, tint: Color.domainMoney, label: \.rawValue) { range in
                selectedRange = range
            }
            if composition.held > 0 {
                compositionBar(composition)
                Text("\(gbp(composition.held)) held, less \(gbp(composition.owed)) owed")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if let freshness = freshnessLine(vm.accounts) {
                Text(freshness)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The change over the chosen range as a sentence. The arrow carries the
    /// direction in colour; the words stay secondary.
    @ViewBuilder
    private func comparison(history: [BalanceAreaChart.Point]) -> some View {
        if let first = history.first?.value, let last = history.last?.value, history.count >= 2 {
            let delta = last - first
            if abs(delta) >= 0.005 {
                HStack(spacing: SparkSpacing.xs + 2) {
                    SparkGlyph(delta > 0 ? .increase : .decrease, size: 11, relativeTo: .caption)
                        .foregroundStyle(delta > 0 ? Color.sparkSuccess : Color.sparkError)
                    Text("\(gbp(abs(delta))) \(delta > 0 ? "above" : "below") \(selectedRange.baselinePhrase)")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("No change since \(selectedRange.baselinePhrase)")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func chart(history: [BalanceAreaChart.Point]) -> some View {
        if case .loading = viewModel?.historyState {
            LoadingShimmerCard()
        } else if case .error(let message) = viewModel?.historyState {
            Text(message)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if history.count >= 2 {
            BalanceAreaChart(data: history, tint: Color.domainMoney, showMidline: true, showEndpoint: true)
        } else {
            RoundedRectangle(cornerRadius: SparkRadii.sm)
                .fill(Color.sparkSurface)
                .overlay {
                    Text("Not enough history yet")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    /// Where the money is held, as one stacked bar in steps of the money fill,
    /// with every share also written out beneath it (section 8, Bar).
    private func compositionBar(_ composition: Composition) -> some View {
        let segments = composition.segments
        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.element.type) { index, segment in
                        Rectangle()
                            .fill(Color.domainMoney.opacity(Composition.opacity(at: index)))
                            .frame(width: max(2, segment.share * (geometry.size.width - CGFloat(segments.count - 1) * 2)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
            .accessibilityHidden(true)
            MoneyMetadata(items: segments.map { "\(accountTypeLabel($0.type)) \(Int(($0.share * 100).rounded()))%" })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Held in " + ListFormatter.localizedString(byJoining: segments.map {
                    "\(accountTypeLabel($0.type)) \(Int(($0.share * 100).rounded())) percent"
                }))
        }
    }

    // MARK: Accounts

    private func accountGroups(vm: MoneyExploreViewModel, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: SparkSpacing.sm) {
            ForEach(groupedAccounts(vm.accounts), id: \.type) { group in
                accountGroup(group, proxy: proxy)
            }
        }
    }

    private func accountGroup(_ group: AccountGroup, proxy: ScrollViewProxy) -> some View {
        let isExpanded = expandedGroups.contains(group.type)
        return VStack(spacing: SparkSpacing.xs) {
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    if isExpanded { expandedGroups.remove(group.type) } else { expandedGroups.insert(group.type) }
                }
            } label: {
                MoneyRow(
                    title: accountTypeLabel(group.type),
                    metadata: groupMetadata(group),
                    value: group.total.map(gbp),
                    valueCaption: group.isDebt ? "owed" : nil,
                    ground: .surface,
                    disclosure: isExpanded ? .collapse : .expand
                ) {
                    DomainGlyph(groupIcon(group.type), tint: .domainMoney)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides these accounts" : "Shows these accounts")

            if isExpanded {
                VStack(spacing: SparkSpacing.xs) {
                    ForEach(group.accounts.filter { $0.kind != "monzo_pot" }) { account in
                        Button {
                            path.append(.account(id: account.id))
                        } label: {
                            MoneyRow(
                                title: account.title,
                                metadata: accountMetadata(account),
                                value: account.latestBalance.map { gbp(abs($0.balance)) } ?? "—",
                                valueCaption: account.isNegativeBalance ? "owed" : nil,
                                ground: .surface,
                                disclosure: .forward
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    let pots = group.accounts.filter { $0.kind == "monzo_pot" }
                    if !pots.isEmpty {
                        Button {
                            withAnimation(.snappy(duration: 0.3)) { proxy.scrollTo("pots", anchor: .top) }
                        } label: {
                            MoneyRow(
                                title: "Monzo pots (\(pots.count))",
                                metadata: ["Shown under Pots"],
                                value: gbp(pots.compactMap { $0.latestBalance?.balance }.reduce(0, +)),
                                ground: .surface,
                                disclosure: .forward
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, SparkSpacing.xl)
            }
        }
    }

    private var addAccountButton: some View {
        Button {
            showCreateAccount = true
        } label: {
            HStack(spacing: SparkSpacing.sm) {
                SparkGlyph(.add, size: 12, relativeTo: .subheadline)
                Text("Add account")
                    .font(SparkTypography.bodyStrong)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func groupMetadata(_ group: AccountGroup) -> [String] {
        let count = group.accounts.count
        var items = ["\(count) \(count == 1 ? "account" : "accounts")"]
        let stale = group.accounts.filter { isStale($0) }.count
        if stale > 0 {
            items.append("\(stale) older than a month")
        }
        return items
    }

    private func accountMetadata(_ account: MoneyAccount) -> [String] {
        var items: [String] = []
        if let provider = account.provider, !provider.isEmpty {
            items.append(provider.capitalized)
        }
        if let balance = account.latestBalance, isStale(account) {
            items.append("From \(Self.age(of: balance.time))")
        }
        return items
    }

    private func isStale(_ account: MoneyAccount, now: Date = .now) -> Bool {
        guard let time = account.latestBalance?.time else { return false }
        return now.timeIntervalSince(time) > 30 * 24 * 3600
    }

    /// "3 months ago", "a year ago", for a balance older than a month.
    static func age(of date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date, to: now)
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years >= 2 { return "\(years) years ago" }
        if years == 1 { return months > 0 ? "\(12 + months) months ago" : "a year ago" }
        if months <= 1 { return "a month ago" }
        return "\(months) months ago"
    }

    private func groupedAccounts(_ accounts: [MoneyAccount]) -> [AccountGroup] {
        let order = [
            "current_account", "credit_card", "savings_account", "investment_account",
            "pension", "mortgage", "loan", "other",
        ]
        let grouped = Dictionary(grouping: accounts) { $0.accountType ?? "other" }
        let types = order + grouped.keys.filter { !order.contains($0) }.sorted()
        return types.compactMap { type in
            guard let members = grouped[type], !members.isEmpty else { return nil }
            let balances = members.compactMap { $0.latestBalance?.balance }
            return AccountGroup(
                type: type,
                accounts: members.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending },
                total: balances.isEmpty ? nil : abs(balances.reduce(0, +)),
                isDebt: isDebtAccountType(type)
            )
        }
    }

    // MARK: Helpers

    private func filteredHistory(vm: MoneyExploreViewModel) -> [BalanceAreaChart.Point] {
        let cutoff: Date? = selectedRange.days.flatMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: .now).map { Calendar.current.startOfDay(for: $0) }
        }
        return vm.history(since: cutoff).map { BalanceAreaChart.Point(date: $0.date, value: $0.total) }
    }

    private func freshnessLine(_ accounts: [MoneyAccount]) -> String? {
        guard let latest = accounts.map(\.updatedAt).max() else { return nil }
        let calendar = Calendar.current
        let time = Self.timeFormatter.string(from: latest)
        if calendar.isDateInToday(latest) { return "Balances synced today at \(time)" }
        if calendar.isDateInYesterday(latest) { return "Balances synced yesterday at \(time)" }
        return "Balances synced \(Self.dateFormatter.string(from: latest))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMMM 'at' HH:mm"
        return formatter
    }()

    private func shimmer(heights: [CGFloat]) -> some View {
        VStack(spacing: SparkSpacing.sm) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                LoadingShimmerCard().frame(height: height)
            }
        }
    }
}

// MARK: - Supporting types

private struct AccountGroup {
    let type: String
    let accounts: [MoneyAccount]
    let total: Double?
    let isDebt: Bool
}

/// The positive balances by account type, for the composition bar.
private struct Composition {
    struct Segment {
        let type: String
        let value: Double
        let share: Double
    }

    let segments: [Segment]
    let held: Double
    let owed: Double

    init(accounts: [MoneyAccount]) {
        var byType: [String: Double] = [:]
        var held = 0.0
        var owed = 0.0
        for account in accounts {
            guard let balance = account.latestBalance?.balance else { continue }
            if account.isNegativeBalance || balance < 0 {
                owed += abs(balance)
            } else {
                held += balance
                byType[account.accountType ?? "other", default: 0] += balance
            }
        }
        self.held = held
        self.owed = owed
        segments = byType
            .map { Segment(type: $0.key, value: $0.value, share: held > 0 ? $0.value / held : 0) }
            .sorted { $0.value > $1.value }
    }

    static func opacity(at index: Int) -> Double {
        [1, 0.7, 0.45, 0.28, 0.16][min(index, 4)]
    }
}

private func accountTypeLabel(_ type: String) -> String {
    switch type {
    case "current_account": "Current accounts"
    case "savings_account": "Savings"
    case "mortgage": "Mortgages"
    case "investment_account": "Investments"
    case "credit_card": "Credit cards"
    case "loan": "Loans"
    case "pension": "Pensions"
    default: "Other"
    }
}

private func isDebtAccountType(_ type: String) -> Bool {
    ["credit_card", "mortgage", "loan"].contains(type)
}

private func groupIcon(_ type: String) -> SparkIcon {
    switch type {
    case "current_account": .bank
    case "credit_card": .paymentCard
    case "savings_account": .savingsPot
    case "investment_account": .investment
    case "pension": .bank
    case "mortgage": .home
    case "loan": .invoice
    default: .money
    }
}

private func gbp(_ value: Double) -> String {
    formattedMoneyAmount(value, currency: "GBP")
}

private func formattedMoneyAmount(_ value: Double, currency: String, fractionDigits: Int = 2) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits

    let symbol: String = switch currency {
    case "GBP": "£"
    case "EUR": "€"
    case "USD": "$"
    default: currency + " "
    }

    return symbol + (formatter.string(from: NSNumber(value: abs(value))) ?? "0")
}
