import SparkKit
import SparkUI
import SwiftUI

struct MoneyExploreView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: MoneyExploreViewModel?
    @State private var path: [DetailRoute] = []

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
                default:
                    EmptyView()
                }
            }
            .refreshable {
                await viewModel?.refresh()
            }
            .sparkMainAppToolbar()
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
                Text("\(merchant.count) transaction\(merchant.count == 1 ? "" : "s")")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
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
