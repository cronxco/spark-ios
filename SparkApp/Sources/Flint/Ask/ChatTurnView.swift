import SparkKit
import SparkUI
import SwiftUI

// MARK: - A turn

/// One turn of a Chat conversation. A question sits in a bubble on the
/// right. An answer is written on the page under Flint's byline: the steps
/// Flint took, then the answer in serif prose with SF for its structure,
/// cards under the paragraph or item that links them, the changes Flint
/// made, and on the latest answer up to two questions to ask next.
struct ChatTurnView: View {
    let turn: AskFlintViewModel.Turn
    let isLatest: Bool
    let activity: String?
    let undoingReceiptIDs: Set<String>
    let onOpen: (DetailRoute) -> Void
    let onUndo: (FlintAskChange) -> Void
    let onFollowUp: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch turn.role {
        case .user: question
        case .assistant: answer
        }
    }

    private var question: some View {
        HStack {
            Spacer(minLength: SparkSpacing.xxl)
            Text(turn.text)
                .font(SparkTypography.body)
                .padding(.horizontal, SparkSpacing.md)
                .padding(.vertical, SparkSpacing.sm)
                .background(Color.sparkAccent.opacity(0.18), in: RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous))
                .textSelection(.enabled)
        }
        .accessibilityLabel("You asked: \(turn.text)")
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            FlintByline(meta: turn.source == .local ? "On this device" : nil)

            if !turn.steps.isEmpty {
                ChatStepTrace(
                    steps: turn.steps, isStreaming: turn.isStreaming, elapsedMs: turn.elapsedMs, onOpen: onOpen)
            }

            if turn.isStreaming, turn.text.isEmpty {
                HStack(spacing: SparkSpacing.sm) {
                    ProgressView().controlSize(.small)
                    Text(activity ?? "Thinking")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .accessibilityElement(children: .combine)
            }

            if !turn.text.isEmpty {
                ChatAnswerBody(text: turn.text, cards: turn.cards, failed: turn.failed, onOpen: onOpen)
            }

            if turn.source == .local {
                Text("Answered from what this device could read. Flint can't make changes until Spark is reachable.")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(turn.changes) { change in
                AskFlintChangeCard(
                    change: change,
                    isUndoing: change.receiptId.map(undoingReceiptIDs.contains) ?? false,
                    onOpen: onOpen,
                    onUndo: { onUndo(change) }
                )
            }

            if isLatest, !turn.isStreaming, !turn.followUps.isEmpty {
                followUps
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: turn.isStreaming)
    }

    private var followUps: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            ForEach(turn.followUps, id: \.self) { question in
                Button {
                    onFollowUp(question)
                } label: {
                    Label(question, systemImage: "arrow.turn.down.right")
                        .font(SparkTypography.bodySmall)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, SparkSpacing.md)
                        .frame(minHeight: 44)
                        .sparkGlass(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Asks Flint this next")
            }
        }
        .padding(.top, SparkSpacing.xs)
    }
}

// MARK: - Steps

/// The steps Flint took. While the answer is written each step shows as it
/// runs; once it is done they fold into one line ("3 steps in 4.2s") that
/// opens them again in place.
struct ChatStepTrace: View {
    let steps: [FlintAskStep]
    let isStreaming: Bool
    let elapsedMs: Int?
    let onOpen: (DetailRoute) -> Void

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            if !isStreaming {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: SparkSpacing.xs) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Text(Self.summary(steps, elapsedMs: elapsedMs))
                    }
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 32)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.summary(steps, elapsedMs: elapsedMs))
                .accessibilityHint(isExpanded ? "Hides the steps" : "Shows the steps Flint took")
            }

            if isStreaming || isExpanded {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    ForEach(steps) { step in
                        ChatStepRow(step: step, onOpen: onOpen)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.leading, SparkSpacing.xs)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: steps.count)
        .animation(reduceMotion ? nil : .snappy, value: isStreaming)
    }

    /// "3 steps in 4.2s", or "Thought it through" when Flint used no tool.
    static func summary(_ steps: [FlintAskStep], elapsedMs: Int?) -> String {
        let tools = steps.filter { $0.kind == .tool }.count
        let base = switch tools {
        case 0: "Thought it through"
        case 1: "1 step"
        default: "\(tools) steps"
        }
        guard let elapsedMs, elapsedMs > 0 else { return base }
        let seconds = Double(elapsedMs) / 1000
        let time = seconds < 10
            ? String(format: "%.1fs", seconds)
            : "\(Int(seconds.rounded()))s"
        return "\(base) in \(time)"
    }
}

/// One step: what Flint did, what it covered, what it found, and the records
/// it found, which open.
private struct ChatStepRow: View {
    let step: FlintAskStep
    let onOpen: (DetailRoute) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
            icon
                .frame(width: 18)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(step.label)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = step.detail, !detail.isEmpty {
                    Text(detail)
                        .font(SparkTypography.caption)
                        .italic(step.kind == .reasoning)
                        .foregroundStyle(.secondary)
                        .lineLimit(step.kind == .reasoning ? 6 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let result = step.result {
                    Text(result)
                        .font(SparkTypography.caption)
                        .foregroundStyle(step.status == .failed ? Color.sparkError : .secondary)
                }
                if !step.records.isEmpty {
                    records
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var icon: some View {
        switch step.status {
        case .running:
            ProgressView().controlSize(.mini)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Color.sparkError)
                .accessibilityHidden(true)
        case .done:
            Image(systemName: Self.symbol(step.glyph))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var records: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.xs) {
                ForEach(step.records) { record in
                    Button {
                        if let route = record.deepLink?.detailRoute { onOpen(route) }
                    } label: {
                        Label(record.title, systemImage: AskFlintGlyph.kind(record.kind))
                            .font(SparkTypography.caption)
                            .lineLimit(1)
                            .padding(.horizontal, SparkSpacing.sm)
                            .frame(minHeight: 32)
                            .sparkGlass(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this record")
                }
            }
        }
    }

    /// The server names a Font Awesome glyph; the row draws its SF Symbol.
    static func symbol(_ glyph: String?) -> String {
        switch glyph {
        case "magnifying-glass": "magnifyingglass"
        case "list": "list.bullet"
        case "sun": "sun.max"
        case "chart-line": "chart.xyaxis.line"
        case "face-smile": "face.smiling"
        case "sterling-sign": "sterlingsign"
        case "note-sticky": "note.text"
        case "newspaper": "newspaper"
        case "plug": "powerplug"
        case "calendar": "calendar"
        case "cube": "cube"
        case "tag": "tag"
        case "pen": "pencil"
        case "link": "link"
        case "trash": "trash"
        case "plus": "plus"
        case "bolt": "bolt"
        case "lightbulb": "lightbulb"
        default: "gearshape"
        }
    }
}

// MARK: - The answer

/// An answer read block by block: paragraphs in serif, headings, list
/// markers, tables and code in SF, and the cards for the events a block
/// links under that block. Inside a list, calendar entries and metrics are
/// slim rows, so a week of plans stays a list.
struct ChatAnswerBody: View {
    let text: String
    let cards: [LinkedEventCard]
    let failed: Bool
    let onOpen: (DetailRoute) -> Void

    var body: some View {
        let blocks = MarkdownBlocks.parse(FlintAskText.linkified(text))
        let placed = Self.place(cards, in: blocks)

        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            ForEach(blocks) { block in
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    ChatBlockView(block: block, failed: failed)
                    if let linked = placed.byBlock[block.id], !linked.isEmpty {
                        cardsView(linked, under: block)
                    }
                }
            }
            if !placed.unplaced.isEmpty {
                EventCardRow(placed.unplaced) { onOpen(.event(id: $0.event.id)) }
            }
        }
        .tint(.sparkHighlight)
    }

    @ViewBuilder
    private func cardsView(_ linked: [LinkedEventCard], under block: MarkdownBlock) -> some View {
        if case .listItem(_, let depth) = block.kind {
            let slim = linked.filter { $0.layout == .calendar || $0.layout == .metric }
            let full = linked.filter { $0.layout != .calendar && $0.layout != .metric }
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                ForEach(slim) { card in
                    ChatSlimCardRow(card: card) { onOpen(.event(id: card.event.id)) }
                }
                EventCardRow(full) { onOpen(.event(id: $0.event.id)) }
            }
            .padding(.leading, ChatBlockView.indent(depth: depth))
        } else {
            EventCardRow(linked) { onOpen(.event(id: $0.event.id)) }
        }
    }

    /// Each card goes under the first block that links its event; a card no
    /// block links goes at the end.
    static func place(
        _ cards: [LinkedEventCard], in blocks: [MarkdownBlock]
    ) -> (byBlock: [Int: [LinkedEventCard]], unplaced: [LinkedEventCard]) {
        var remaining = Dictionary(cards.map { ($0.event.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        var byBlock: [Int: [LinkedEventCard]] = [:]

        for block in blocks {
            for id in linkedEventIDs(in: block) {
                guard let card = remaining.removeValue(forKey: id) else { continue }
                byBlock[block.id, default: []].append(card)
            }
        }

        let unplaced = cards.filter { remaining[$0.event.id.lowercased()] != nil }
        return (byBlock, unplaced)
    }

    /// The event ids a block links, in order, lowercased.
    static func linkedEventIDs(in block: MarkdownBlock) -> [String] {
        let runs = ([block.content] + block.cells).flatMap { $0.runs.compactMap(\.link) }
        var seen = Set<String>()
        return runs.compactMap { url -> String? in
            guard case .event(let id) = DeepLink.parse(url) else { return nil }
            let key = id.lowercased()
            return seen.insert(key).inserted ? key : nil
        }
    }
}

/// One Markdown block.
private struct ChatBlockView: View {
    let block: MarkdownBlock
    let failed: Bool

    static func indent(depth: Int) -> CGFloat {
        CGFloat(max(0, depth - 1)) * 18
    }

    private var ink: Color { failed ? .sparkError : .primary }

    var body: some View {
        switch block.kind {
        case .paragraph:
            prose(block.content)

        case .heading(let level):
            Text(Self.styled(block.content))
                .font(level <= 2 ? SparkTypography.title.weight(.semibold) : SparkTypography.bodyStrong)
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, SparkSpacing.xs)
                .accessibilityAddTraits(.isHeader)

        case .listItem(let marker, let depth):
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                Text(marker ?? "")
                    .font(SparkTypography.bodySmall.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 14, alignment: .leading)
                    .accessibilityHidden(true)
                prose(block.content)
            }
            .padding(.leading, Self.indent(depth: depth))

        case .quote:
            HStack(alignment: .top, spacing: SparkSpacing.md) {
                Rectangle()
                    .fill(Color.sparkHighlight)
                    .frame(width: 3)
                    .clipShape(.capsule)
                Text(Self.styled(block.content))
                    .font(SparkTypography.longFormBodySmall.italic())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .code:
            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(SparkTypography.mono)
                    .foregroundStyle(ink)
                    .textSelection(.enabled)
                    .padding(SparkSpacing.md)
            }
            .background(Color.sparkSurface, in: .rect(cornerRadius: SparkRadii.md))

        case .rule:
            Divider().padding(.vertical, SparkSpacing.xs)

        case .tableRow(let isHeader):
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
                ForEach(Array(block.cells.enumerated()), id: \.offset) { _, cell in
                    Text(Self.styled(cell))
                        .font(isHeader ? SparkTypography.captionStrong : SparkTypography.caption)
                        .monospacedDigit()
                        .foregroundStyle(isHeader ? .secondary : ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func prose(_ content: AttributedString) -> some View {
        Text(Self.styled(content))
            .font(SparkTypography.longFormBodySmall)
            .lineSpacing(4)
            .foregroundStyle(ink)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    /// Linked facts in the highlight token, semibold and not underlined
    /// (design language §3.3). The link stays, so a tap opens the record.
    static func styled(_ content: AttributedString) -> AttributedString {
        var content = content
        for run in content.runs where run.link != nil {
            content[run.range].foregroundColor = Color.sparkHighlight
            content[run.range].underlineStyle = nil
            content[run.range].inlinePresentationIntent =
                (run.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
        }
        return content
    }
}

/// A calendar entry or metric inside a list: one line with its glyph, what
/// it is and its time or value, on the domain's tinted fill.
private struct ChatSlimCardRow: View {
    let card: LinkedEventCard
    let action: () -> Void

    private var tint: Color { EntityPresentation.tint(domain: card.event.domain) }

    private var title: String {
        card.layout == .calendar ? (card.details?.title ?? "Calendar entry") : card.label
    }

    private var trailing: String? {
        guard card.layout == .calendar else { return card.heroValue }
        if card.details?.allDay == true { return "All day" }
        return card.details?.startsAt.map { ChatHomeModel.time($0) }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SparkSpacing.sm) {
                SparkGlyph(.domain(card.event.domain), size: 13, relativeTo: .callout)
                    .foregroundStyle(tint)
                Text(title)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: SparkSpacing.sm)
                if let trailing {
                    Text(trailing)
                        .font(SparkTypography.captionStrong)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, SparkSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(
                Color.sparkElevated.mix(with: tint, by: 0.09),
                in: RoundedRectangle(cornerRadius: SparkRadii.sm, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this event")
    }
}
