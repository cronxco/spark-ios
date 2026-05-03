import SparkKit
import SparkUI
import SwiftUI

struct MoneyExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MoneyExploreViewModel?
    @State private var path: [DetailRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: SparkSpacing.lg) {
                    if let vm = viewModel {
                        switch vm.loadState {
                        case .idle:
                            shimmerPlaceholder
                        case .loading where vm.spend == nil:
                            shimmerPlaceholder
                        case .error(let msg) where vm.spend == nil:
                            EmptyState(
                                systemImage: "exclamationmark.triangle.fill",
                                title: "Couldn't load money data",
                                message: msg,
                                actionTitle: "Retry"
                            ) { Task { await vm.refresh() } }
                        default:
                            spendingOverviewCard(vm: vm)
                            if let spend = vm.spend, !spend.topMerchants.isEmpty {
                                topMerchantsCard(merchants: spend.topMerchants, currency: spend.currency)
                            }
                            transactionsCard(vm: vm)
                        }
                    } else {
                        shimmerPlaceholder
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .background(Color.sparkSurface.ignoresSafeArea())
            .navigationTitle("Money")
            .navigationBarTitleDisplayMode(.large)
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
        }
        .task {
            if viewModel == nil {
                viewModel = MoneyExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    // MARK: - Spending overview

    private func spendingOverviewCard(vm: MoneyExploreViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(
                    icon: "sterlingsign.circle.fill",
                    tint: .domainMoney,
                    title: "Spending Overview"
                )
                if let spend = vm.spend {
                    HStack(spacing: SparkSpacing.sm) {
                        SpendingPeriodCell(
                            period: "Today",
                            amount: formatAmount(spend.total, currency: spend.currency)
                        )
                        SpendingPeriodCell(
                            period: "Transactions",
                            amount: "\(spend.transactionCount)"
                        )
                    }
                } else {
                    HStack(spacing: SparkSpacing.sm) {
                        SpendingPeriodCell(period: "Today", amount: "—")
                        SpendingPeriodCell(period: "Transactions", amount: "—")
                    }
                }
            }
        }
    }

    // MARK: - Top merchants

    private func topMerchantsCard(merchants: [SpendWidget.Merchant], currency: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(icon: "cart.fill", tint: .domainMoney, title: "Top Merchants")
                VStack(spacing: 0) {
                    ForEach(merchants, id: \.id) { merchant in
                        HStack(spacing: SparkSpacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(merchant.name)
                                    .font(SparkTypography.body)
                                Text("\(merchant.count) transaction\(merchant.count == 1 ? "" : "s")")
                                    .font(SparkTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: SparkSpacing.sm)
                            Text(formatAmount(merchant.total, currency: currency))
                                .font(SparkTypography.bodyStrong)
                                .foregroundStyle(Color.domainMoney)
                        }
                        .padding(.vertical, SparkSpacing.sm)
                        if merchant.id != merchants.last?.id {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Transactions

    private func transactionsCard(vm: MoneyExploreViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                GlassCardHeader(
                    icon: "list.bullet.rectangle",
                    tint: .domainMoney,
                    title: "Recent Transactions"
                )
                if vm.transactions.isEmpty {
                    EmptyState(
                        systemImage: "creditcard",
                        title: "No transactions yet",
                        message: "Connect a bank integration to see your transactions here."
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.transactions) { event in
                            Button {
                                path.append(.event(id: event.id))
                            } label: {
                                TransactionRow(event: event)
                            }
                            .buttonStyle(.plain)
                            if event.id != vm.transactions.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shimmer placeholder

    private var shimmerPlaceholder: some View {
        VStack(spacing: SparkSpacing.lg) {
            LoadingShimmerCard().frame(height: 120)
            LoadingShimmerCard().frame(height: 180)
            LoadingShimmerCard().frame(height: 200)
        }
    }

    // MARK: - Helpers

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

// MARK: - Transaction row

private struct TransactionRow: View {
    let event: Event

    private var merchant: String {
        event.target?.title ?? event.actor?.title ?? event.service.capitalized
    }

    private var amount: String {
        guard let value = event.value else { return "" }
        let unit = event.unit ?? ""
        let symbol: String = switch unit {
        case "GBP": "£"
        case "EUR": "€"
        case "USD": "$"
        default: unit.isEmpty ? "" : unit + " "
        }
        return "\(symbol)\(value)"
    }

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.domainMoney.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "sterlingsign")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.domainMoney)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(merchant)
                    .font(SparkTypography.body)
                    .lineLimit(1)
                if let time = event.time {
                    Text(time.formatted(date: .abbreviated, time: .omitted))
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: SparkSpacing.sm)

            if !amount.isEmpty {
                Text(amount)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, SparkSpacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - Spending period cell

private struct SpendingPeriodCell: View {
    let period: String
    let amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
            Text(amount)
                .font(SparkTypography.titleStrong)
                .foregroundStyle(.primary)
            Text(period)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.sm))
    }
}
