import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class BlockDetailViewModel {
    let blockId: String
    private(set) var state: DetailLoadState<BlockDetail> = .loading

    private let apiClient: APIClient

    init(blockId: String, apiClient: APIClient) {
        self.blockId = blockId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let detail = try await apiClient.request(BlocksEndpoint.detail(id: blockId))
            state = .loaded(detail)
        } catch APIError.notModified {
            return
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }
}

struct BlockDetailView: View {
    let blockId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: BlockDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load block",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.load() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(SparkSpacing.lg)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationTitle("Block")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: blockId) {
            if viewModel == nil {
                viewModel = BlockDetailViewModel(blockId: blockId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for detail: BlockDetail) -> some View {
        heroCard(for: detail.block)

        if isValueBlock(detail.block), let value = detail.block.value {
            valueCard(value: value, unit: detail.block.unit)
        }

        if let body = detail.block.content, !body.isEmpty {
            GlassCard {
                Text(LocalizedStringKey(body))
                    .font(SparkTypography.body)
                    .accessibilityLabel(body)
            }
        }

        if let summary = detail.aiSummary, !summary.isEmpty {
            GlassCard {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Color.sparkAccent)
                    Text(summary)
                        .font(SparkTypography.bodySmall)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let parent = detail.event {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("From event")
                GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                    HStack {
                        Text(parent.action.capitalized)
                            .font(SparkTypography.bodySmall)
                        Spacer(minLength: 0)
                        if let time = parent.time {
                            Text(Self.shortTimeFormatter.string(from: time))
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func heroCard(for block: Block) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel(block.blockType.replacingOccurrences(of: "_", with: " "))
                Text(block.title)
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let time = block.time {
                    Text(Self.shortTimeFormatter.string(from: time))
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func valueCard(value: String, unit: String?) -> some View {
        GlassCard {
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                Text(value)
                    .font(SparkFonts.display(.largeTitle, weight: .bold))
                    .foregroundStyle(Color.sparkAccent)
                if let unit {
                    Text(unit)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(value)\(unit.map { " \($0)" } ?? "")")
        }
    }

    private func isValueBlock(_ block: Block) -> Bool {
        block.blockType.lowercased().contains("value") && block.value != nil
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()
}
