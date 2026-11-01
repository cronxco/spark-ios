import Observation
import UIKit
import SparkKit
import SparkUI
import SwiftUI

// MARK: - View model

@MainActor
@Observable
final class TagsExploreViewModel {
    /// The most used tags, enough to fill every type's section. The
    /// first page also carries each type's true size (`TagPage.types`).
    private static let catalogueSize = 100

    private let apiClient: APIClient
    private(set) var mostUsed: [TagResource] = []
    private(set) var sections: [TagTypeGroup] = []
    private(set) var hasLoadedCatalogue = false

    private(set) var results: [TagResource] = []
    private(set) var resultsQuery: String?
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var error: String?
    /// A failed search, kept apart from `error` so it doesn't linger over
    /// the catalogue once the query is cleared.
    private(set) var searchError: String?
    private var requestGeneration = 0

    init(apiClient: APIClient) { self.apiClient = apiClient }

    var isEmpty: Bool { hasLoadedCatalogue && sections.isEmpty }

    func loadCatalogue() async {
        do {
            let page = try await apiClient.request(TagsEndpoint.list(limit: Self.catalogueSize))
            guard !Task.isCancelled else { return }
            mostUsed = TagCatalogue.mostUsed(page.data)
            sections = TagCatalogue.typeSections(tags: page.data, totals: page.types)
            hasLoadedCatalogue = true
            error = nil
        } catch APIError.notModified {
            hasLoadedCatalogue = true
        } catch {
            guard !Task.isCancelled else { return }
            SparkObservability.captureHandled(error)
            self.error = Self.message(for: error)
        }
    }

    /// Searches every tag, most used first. `reset: false` loads the next page.
    func search(_ query: String, reset: Bool = true) async {
        if !reset, isLoading || !hasMore { return }
        searchError = nil
        requestGeneration += 1
        let generation = requestGeneration
        isLoading = true
        defer {
            if generation == requestGeneration { isLoading = false }
        }
        do {
            let page = try await apiClient.request(
                TagsEndpoint.list(query: query, cursor: reset ? nil : nextCursor)
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            results = reset ? page.data : results + page.data
            resultsQuery = query
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch APIError.notModified {
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            SparkObservability.captureHandled(error)
            searchError = Self.message(for: error)
        }
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}

// MARK: - Screen

/// Explore's Tags section: the most used tags, then one section per tag
/// type, related types together and payment details collapsed. Tapping a
/// pill opens its peek card (`docs/design-language.md` section 7.5);
/// tapping a row opens the tag.
struct TagsExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TagsExploreViewModel?
    @State private var query = ""
    @State private var expanded: Set<String> = []

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.xxl) {
                TagSearchField(prompt: "Find tags", text: $query)

                if let error = trimmedQuery.isEmpty ? viewModel?.error : viewModel?.searchError {
                    Text(error)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(Color.sparkError)
                }

                if trimmedQuery.isEmpty {
                    catalogue
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xl)
        }
        .refreshable {
            if trimmedQuery.isEmpty {
                await viewModel?.loadCatalogue()
            } else {
                await viewModel?.search(trimmedQuery)
            }
        }
        .task(id: trimmedQuery) {
            guard !trimmedQuery.isEmpty else { return }
            // Wait for typing to pause before asking the server.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Coming back from a tag keeps the pages already loaded.
            if viewModel?.resultsQuery == trimmedQuery, viewModel?.searchError == nil { return }
            await viewModel?.search(trimmedQuery)
        }
        .task {
            if viewModel == nil { viewModel = TagsExploreViewModel(apiClient: appModel.apiClient) }
            if viewModel?.hasLoadedCatalogue == false { await viewModel?.loadCatalogue() }
        }
    }

    // MARK: Catalogue

    @ViewBuilder
    private var catalogue: some View {
        if let viewModel, viewModel.isEmpty {
            EmptyState(
                systemImage: "tag",
                title: "No tags yet",
                message: "Tags from your integrations, and the ones you add, show up here."
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, SparkSpacing.xxxl)
        } else if viewModel?.hasLoadedCatalogue != true, viewModel?.error == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, SparkSpacing.xxxl)
        } else if let viewModel {
            if !viewModel.mostUsed.isEmpty {
                MostUsedTagsSection(tags: viewModel.mostUsed)
            }
            ForEach(viewModel.sections) { group in
                TagTypeSectionView(
                    group: group,
                    isExpanded: !group.family.startsCollapsed || expanded.contains(group.type),
                    onToggle: { toggle(group.type) }
                )
            }
        }
    }

    private func toggle(_ type: String) {
        withAnimation(.snappy) {
            if expanded.contains(type) { expanded.remove(type) } else { expanded.insert(type) }
        }
    }

    // MARK: Search

    @ViewBuilder
    private var searchResults: some View {
        let results = viewModel?.resultsQuery == trimmedQuery ? viewModel?.results ?? [] : []
        if results.isEmpty {
            if viewModel?.isLoading == true
                || (viewModel?.resultsQuery != trimmedQuery && viewModel?.searchError == nil) {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SparkSpacing.xxxl)
            } else if viewModel?.searchError == nil {
                EmptyState(
                    systemImage: "magnifyingglass",
                    title: "No tags match",
                    message: "Try another word, or part of one."
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, SparkSpacing.xxxl)
            }
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkSectionCaption(text: resultsCaption(count: results.count))
                    .padding(.horizontal, SparkSpacing.xs)
                TagRowList(tags: results, showsType: true) {
                    Task { await viewModel?.search(trimmedQuery, reset: false) }
                }
            }
        }
    }

    private func resultsCaption(count: Int) -> String {
        let more = viewModel?.hasMore == true ? "+" : ""
        return count == 1 && more.isEmpty
            ? "1 tag matches \u{201C}\(trimmedQuery)\u{201D}"
            : "\(count)\(more) tags match \u{201C}\(trimmedQuery)\u{201D}"
    }
}

// MARK: - Most used

/// The section's hero: the five most used tags, each with a bar against the
/// top one. Payment details are left out (`TagFamily.ranksInMostUsed`).
private struct MostUsedTagsSection: View {
    let tags: [TagResource]

    private var top: Int { max(tags.map(\.totalCount).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.sm) {
                SparkGlyph(.chart, size: 16, relativeTo: .title3)
                    .foregroundStyle(.secondary)
                SectionLabel("Most used", style: .dayHeading)
            }

            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                ForEach(tags) { tag in
                    NavigationLink(value: tag.detailRoute) {
                        UsageRow(tag: tag, fraction: Double(tag.totalCount) / Double(top))
                    }
                    .buttonStyle(.plain)
                    .tagPreview(tag)
                }
                Text("Leaves out payment details, which every card payment carries.")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(SparkSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sparkContentSurface()
        }
    }

    private struct UsageRow: View {
        let tag: TagResource
        let fraction: Double

        var body: some View {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.sm) {
                    TagChip(tag.eventTag)
                    Text(TagTypeName.singular(tag.type))
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: SparkSpacing.sm)
                    Text(tag.totalCount, format: .number)
                        .font(SparkTypography.bodyStrong)
                        .monospacedDigit()
                }
                UsageBar(fraction: fraction)
            }
            .contentShape(.rect)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(tag.name), \(TagTypeName.singular(tag.type))")
            .accessibilityValue(tag.usesLabel)
            .accessibilityAddTraits(.isButton)
        }
    }

    /// A thin neutral bar from zero: tag colours stay on the pill (7.5).
    private struct UsageBar: View {
        let fraction: Double

        var body: some View {
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.primary.opacity(0.45))
                            .frame(width: max(4, proxy.size.width * min(max(fraction, 0), 1)))
                    }
                }
                .accessibilityHidden(true)
        }
    }
}

// MARK: - A type

/// One tag type: a heading with its size and See all, then its most used
/// tags as pills that open their peek cards. Payment-detail types start
/// collapsed behind their heading.
private struct TagTypeSectionView: View {
    let group: TagTypeGroup
    let isExpanded: Bool
    let onToggle: () -> Void

    private var family: TagFamily { group.family }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            if family.startsCollapsed {
                collapsibleHeader
            } else {
                header
            }
            if isExpanded {
                pills
            }
        }
    }

    private var header: some View {
        HStack(spacing: SparkSpacing.sm) {
            DomainGlyph(family.icon, tint: family.tint)
            title
            Spacer(minLength: SparkSpacing.sm)
            if group.hiddenCount > 0 {
                NavigationLink(value: DetailRoute.tagType(group.type)) {
                    HStack(spacing: SparkSpacing.xs) {
                        Text("See all")
                        SparkGlyph(.forward, size: 11, relativeTo: .body)
                    }
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("See all \(group.title.lowercased())")
            }
        }
    }

    private var collapsibleHeader: some View {
        Button(action: onToggle) {
            HStack(spacing: SparkSpacing.md) {
                DomainGlyph(family.icon, tint: family.tint)
                VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                    title
                    Text(family.title)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: SparkSpacing.sm)
                SparkGlyph(isExpanded ? .collapse : .expand, size: 12, relativeTo: .body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .sparkContentSurface()
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Hides these tags" : "Shows these tags")
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            SectionLabel(group.title, style: .dayHeading)
            Text("(\(group.tagsCount))")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var pills: some View {
        FlowLayout(spacing: SparkSpacing.xs + 2) {
            ForEach(group.tags) { tag in
                ExploreTagChip(tag: tag)
            }
            if group.hiddenCount > 0 {
                NavigationLink(value: DetailRoute.tagType(group.type)) {
                    Text("+\(group.hiddenCount) more")
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, SparkSpacing.sm)
                        .frame(minHeight: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(group.hiddenCount) more \(group.title.lowercased())")
            }
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkContentSurface()
    }
}

/// A pill that opens its peek card, whose button pushes the tag's screen.
private struct ExploreTagChip: View {
    let tag: TagResource

    @Environment(\.openDetailRoute) private var openDetailRoute

    var body: some View {
        if let openDetailRoute {
            PeekableTagChip(tag.eventTag, facts: tag.peekFacts) {
                openDetailRoute(tag.detailRoute)
            }
        } else {
            NavigationLink(value: tag.detailRoute) { TagChip(tag.eventTag) }
                .buttonStyle(.plain)
        }
    }
}

// MARK: - Shared pieces

/// Search, inline rather than `.searchable`: the tab's one navigation stack
/// is shared by every Explore section, so a search bar attached to it would
/// show on all of them.
struct TagSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: SparkSpacing.sm) {
            SparkGlyph(.search, size: 14, relativeTo: .body)
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .font(SparkTypography.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 32, minHeight: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, SparkSpacing.md + 2)
        .frame(minHeight: 44)
        .sparkContentSurface(radius: SparkRadii.md)
    }
}

/// Tags as rows on one surface: the pill, optionally its type, the number of
/// uses and a chevron. A row opens the tag; a long press previews it.
struct TagRowList: View {
    let tags: [TagResource]
    let showsType: Bool
    /// Called when the last row appears, to load the next page.
    let onReachEnd: () -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(tags) { tag in
                NavigationLink(value: tag.detailRoute) {
                    row(tag)
                }
                .buttonStyle(.plain)
                .tagPreview(tag)
                .onAppear {
                    if tag.id == tags.last?.id { onReachEnd() }
                }
                if tag.id != tags.last?.id {
                    Divider().padding(.leading, SparkSpacing.lg)
                }
            }
        }
        .sparkContentSurface()
    }

    private func row(_ tag: TagResource) -> some View {
        HStack(spacing: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                TagChip(tag.eventTag)
                if showsType {
                    Text(TagTypeName.singular(tag.type))
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: SparkSpacing.sm)
            Text(tag.totalCount, format: .number)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            SparkGlyph(.forward, size: 11, relativeTo: .body)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.sm)
        .frame(minHeight: 52)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsType ? "\(tag.name), \(TagTypeName.singular(tag.type))" : tag.name)
        .accessibilityValue(tag.usesLabel)
        .accessibilityAddTraits(.isButton)
    }
}

private extension View {
    /// Long press previews the tag's peek card (7.1), with a way onwards.
    func tagPreview(_ tag: TagResource) -> some View {
        modifier(TagPreviewModifier(tag: tag))
    }
}

private struct TagPreviewModifier: ViewModifier {
    let tag: TagResource

    @Environment(\.openDetailRoute) private var openDetailRoute

    func body(content: Content) -> some View {
        content.contextMenu {
            if let openDetailRoute {
                Button {
                    openDetailRoute(tag.detailRoute)
                } label: {
                    Label("View tagged items", systemImage: "tag")
                }
            }
            Button {
                UIPasteboard.general.string = tag.name
            } label: {
                Label("Copy name", systemImage: "doc.on.doc")
            }
        } preview: {
            TagPeekCard(tag: tag.eventTag, facts: tag.peekFacts, onOpen: nil)
                .background(Color.sparkElevated)
        }
    }
}

extension TagResource {
    var detailRoute: DetailRoute { .tag(id: id, name: name, type: type) }

    var peekFacts: [PeekCard.Fact] {
        [
            PeekCard.Fact("Tagged events", eventsCount.formatted()),
            PeekCard.Fact("Tagged objects", objectsCount.formatted()),
        ]
    }

    var usesLabel: String { totalCount == 1 ? "1 use" : "\(totalCount.formatted()) uses" }
}

extension TagFamily {
    var icon: SparkIcon {
        switch self {
        case .yours, .other: .tag
        case .people: .person
        case .music: .track
        case .spending: .money
        case .paymentDetails: .paymentCard
        }
    }

    /// The family's glyph tint: its domain where it has one (6), else neutral.
    var tint: Color {
        switch self {
        case .music: .domainMedia
        case .spending, .paymentDetails: .domainMoney
        case .yours, .people, .other: .primary
        }
    }
}
