import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class ObjectDetailViewModel {
    let objectId: String
    private(set) var state: DetailLoadState<ObjectDetail> = .loading

    private let apiClient: APIClient

    init(objectId: String, apiClient: APIClient) {
        self.objectId = objectId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let detail = try await apiClient.request(ObjectsEndpoint.detail(id: objectId))
            state = .loaded(detail)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }
}

struct ObjectDetailView: View {
    let objectId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ObjectDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load object",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.load() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.xxl)
            .padding(.bottom, SparkSpacing.xl)
        }
        .sparkAppBackground()
        .navigationTitle("Object")
        .navigationBarTitleDisplayMode(.inline)
        .sparkSubViewToolbar(
            shareItems: objectShareItems,
            rawTitle: "Raw object",
            rawPayload: objectRawPayload,
            refresh: { await viewModel?.load() }
        )
        .task(id: objectId) {
            if viewModel == nil {
                viewModel = ObjectDetailViewModel(objectId: objectId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    private var objectShareItems: [Any] {
        guard case .loaded(let detail) = viewModel?.state else {
            return ["Spark Object: \(objectId)"]
        }
        if let url = detail.object.url.flatMap(URL.init) {
            return [url]
        }
        return ["Spark Object: \(detail.object.title)"]
    }

    private var objectRawPayload: String? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        return SparkPrettyJSON.string(for: detail)
            ?? SparkPrettyJSON.fallback(entity: "object", id: detail.object.id, title: detail.object.title)
    }

    @ViewBuilder
    private func content(for detail: ObjectDetail) -> some View {
        heroSection(for: detail)

        if let summary = detail.aiSummary, !summary.isEmpty {
            SparkDetailInsightCard(label: "Insight", text: summary)
        }

        if !detail.tags.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Tags")
                TagChipRow(detail.tags)
            }
        }

        if !detail.relatedObjects.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Related", trailing: "\(detail.relatedObjects.count) objects")
                ForEach(detail.relatedObjects) { rel in
                    relatedObjectRow(rel)
                }
            }
        }

        if !detail.recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Recent events", trailing: "\(detail.recentEvents.count) events")
                ForEach(detail.recentEvents) { event in
                    NavigationLink {
                        EventDetailView(eventId: event.id)
                    } label: {
                        eventRowSummary(event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func heroSection(for detail: ObjectDetail) -> some View {
        SparkDetailHero(
            eyebrow: objectEyebrow(for: detail.object),
            status: detail.object.type.humanisedAction,
            title: detail.object.title,
            subtitle: objectSubtitle(for: detail.object),
            value: nil
        )
    }

    private func objectEyebrow(for object: EventObject) -> String {
        var parts = [
            object.concept.uppercased(),
            object.type.replacingOccurrences(of: "_", with: " ").uppercased()
        ]
        if let time = object.time {
            parts.append(SparkDetailFormatters.shortDate.string(from: time))
            parts.append(SparkDetailFormatters.shortTime.string(from: time))
        }
        return parts.joined(separator: " — ")
    }

    private func objectSubtitle(for object: EventObject) -> String? {
        if let content = object.content, !content.isEmpty {
            return content
        }
        if let url = object.url, let parsed = URL(string: url) {
            return parsed.host ?? url
        }
        return nil
    }

    private func relatedObjectRow(_ rel: ObjectDetail.Related) -> some View {
        SparkDetailLinkedRow(
            title: rel.title,
            subtitle: rel.concept,
            trailing: rel.relationship
        )
    }

    private func eventRowSummary(_ event: Event) -> some View {
        SparkDetailLinkedRow(
            title: eventTitle(for: event),
            subtitle: event.time.map { SparkDetailFormatters.compactDateTime.string(from: $0) },
            trailing: event.displayValue?.sparkPlainTextFromHTMLFragment ?? event.value?.sparkPlainTextFromHTMLFragment,
            tint: Color.domainTint(for: event.domain)
        )
    }

    private func eventTitle(for event: Event) -> String {
        let action = event.action.sparkActionTitle
        guard event.displayWithObject,
              let target = event.target?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty
        else {
            return action
        }
        return "\(action) \(target)"
    }
}
