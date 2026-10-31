import SparkKit
import SparkUI
import SwiftUI
import UIKit

// The parts the Event, Block and Object screens share
// (`docs/design-language.md` §12.2): a centred hero on one content surface,
// the generated Summary card, the Flow featured section, score bars and the
// Details sheet.

// MARK: - Hero

/// How a detail hero says how this value compares, as in "↑ 3 above 30d
/// trend" (§3.4). Coloured by polarity, not by direction.
struct SparkDetailComparison: Equatable {
    enum Direction: Equatable { case up, down, steady }

    let direction: Direction
    let text: String
    /// Whether the move is a good one. `nil` reads as neutral.
    let isGood: Bool?

    /// Compares a value with its 30-day average. Higher is better except for
    /// money, where more spent is worse.
    static func make(value: Double, average: Double, unit: String?, domain: String) -> SparkDetailComparison {
        let delta = value - average
        let shown = SparkDetailNumber.format(abs(delta), unit: unit)
        let isZero = SparkDetailNumber.format(0, unit: unit) == shown
        if isZero {
            return SparkDetailComparison(direction: .steady, text: "In line with 30d trend", isGood: nil)
        }
        let higherIsBetter = domain.lowercased() != "money"
        let up = delta > 0
        return SparkDetailComparison(
            direction: up ? .up : .down,
            text: "\(shown) \(up ? "above" : "below") 30d trend",
            isGood: up == higherIsBetter
        )
    }

    var colour: Color {
        switch isGood {
        case true?: .sparkSuccess
        case false?: .sparkError
        case nil: .secondary
        }
    }

    var icon: SparkIcon {
        switch direction {
        case .up: .increase
        case .down: .decrease
        case .steady: .steady
        }
    }
}

enum SparkDetailNumber {
    /// A number from an API value string such as "86", "£6.80" or "1,240".
    static func parse(_ raw: String?) -> Double? {
        guard let raw = raw?.sparkPlainTextFromHTMLFragment else { return nil }
        let allowed = CharacterSet(charactersIn: "-0123456789.")
        let filtered = String(raw.replacingOccurrences(of: ",", with: "").unicodeScalars.filter { allowed.contains($0) })
        return Double(filtered)
    }

    static func format(_ value: Double, unit: String?) -> String {
        if let unit, ["GBP", "USD", "EUR", "JPY"].contains(unit.uppercased()) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = unit.uppercased()
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = value.rounded() == value ? 0 : 2
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(value) >= 10 ? 0 : 1
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// A 0–100 score: the ring pattern applies (§8).
    static func isScore(value: Double?, unit: String?) -> Bool {
        guard let value, (0...100).contains(value) else { return false }
        let unit = (unit ?? "").lowercased()
        return unit == "percent" || unit == "%" || unit == "score"
    }
}

/// What a detail hero shows under its title.
enum SparkDetailHeroValue {
    case hidden
    case text(String)
    /// A 0–100 score, drawn as a ring. `threshold` is the provider's
    /// "excellent" line as a share (0.85 for Oura).
    case score(Double, text: String, threshold: Double?)
}

/// The detail hero (§12.2): one content surface, centred. The glyph chip,
/// then the verb ("Had sleep score"), the subject ("Daily Sleep Summary"),
/// the value at 56pt in the hero colour or a ring for a score, how it
/// compares, and where and when it came from.
struct SparkDetailCentredHero<Comparison: View>: View {
    typealias Value = SparkDetailHeroValue

    let icon: String
    let domain: String
    let verb: String?
    let title: String
    var subtitle: String?
    var value: Value = .hidden
    var valueCaption: String?
    var source: String?
    var timePrefix: String?
    var time: Date?
    @ViewBuilder var comparison: () -> Comparison

    var body: some View {
        VStack(spacing: SparkSpacing.sm) {
            DomainGlyph(icon: icon, tint: Color.domainTint(for: domain), size: 42)
                .accessibilityHidden(true)

            if let verb, !verb.isEmpty {
                Text(verb)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.secondary)
                    .padding(.top, SparkSpacing.xs)
            }

            Text(title)
                .font(SparkFonts.display(.title, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .accessibilityAddTraits(.isHeader)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            valueView

            if let valueCaption, !valueCaption.isEmpty {
                Text(valueCaption)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }

            comparison()

            meta
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.top, SparkSpacing.xl)
        .padding(.bottom, SparkSpacing.lg + 4)
        .sparkContentSurface(radius: SparkRadii.lg)
    }

    @ViewBuilder
    private var valueView: some View {
        switch value {
        case .hidden:
            EmptyView()
        case .text(let text):
            Text(text)
                .font(SparkFonts.display(size: 56, relativeTo: .largeTitle, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.sparkHero(domain: domain))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        case .score(let score, let text, let threshold):
            ScoreRing(
                fraction: score / 100,
                text: text,
                tint: Color.domainTint(for: domain),
                diameter: 152,
                threshold: threshold,
                valueColor: Color.sparkHero(domain: domain)
            )
            .padding(.top, SparkSpacing.xs)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(text) out of 100")
        }
    }

    private var meta: some View {
        HStack(spacing: SparkSpacing.md) {
            if let source, !source.isEmpty {
                Text(source)
            }
            if let time {
                HStack(spacing: SparkSpacing.xs) {
                    if let timePrefix { Text(timePrefix) }
                    SparkTimeText(time, font: Font.system(.footnote))
                }
            }
        }
        .font(Font.system(.footnote))
        .foregroundStyle(.secondary)
    }
}

extension SparkDetailCentredHero where Comparison == EmptyView {
    init(
        icon: String,
        domain: String,
        verb: String?,
        title: String,
        subtitle: String? = nil,
        value: Value = .hidden,
        valueCaption: String? = nil,
        source: String? = nil,
        timePrefix: String? = nil,
        time: Date? = nil
    ) {
        self.init(
            icon: icon, domain: domain, verb: verb, title: title, subtitle: subtitle,
            value: value, valueCaption: valueCaption, source: source,
            timePrefix: timePrefix, time: time, comparison: { EmptyView() }
        )
    }
}

/// The comparison line under a hero value.
struct SparkDetailComparisonLine: View {
    let comparison: SparkDetailComparison

    var body: some View {
        HStack(spacing: SparkSpacing.xs) {
            SparkGlyph(comparison.icon, size: 12, relativeTo: .subheadline)
                .foregroundStyle(comparison.colour)
            Text(comparison.text)
                .foregroundStyle(.secondary)
        }
        .font(SparkTypography.bodySmall)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Summary

/// Generated text that adds to the page, on the generated card (§3.5). When
/// the generated text is the page, use the band instead.
struct SparkDetailSummaryCard: View {
    var label = "Summary"
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                SparkGlyph(.flint, size: 12, relativeTo: .caption)
                Text(label)
            }
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.secondary)

            Text(text)
                .font(SparkTypography.longFormBodySmall)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGeneratedSurface()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Flow

/// An event's actor object, the action with its value, and its target
/// object, top to bottom (§12.2). It is the page's one featured section: an
/// even 2pt info stroke at 10% (§5.3). The actor shows even when it is you.
struct SparkDetailFlowSection: View {
    struct Party {
        let id: String?
        let title: String
        let typeName: String
        let type: String?
    }

    let actor: Party?
    let action: String
    let value: String?
    let domain: String
    let icon: String
    let target: Party?

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Flow", icon: .steady)

            VStack(spacing: SparkSpacing.xs + 2) {
                if let actor {
                    partyView(actor, role: "Actor", labelFirst: true)
                    arrow
                }

                HStack(spacing: SparkSpacing.sm) {
                    Image(systemName: icon)
                        .foregroundStyle(Color.domainTint(for: domain))
                        .accessibilityHidden(true)
                    Text(action)
                        .font(SparkTypography.bodyStrong)
                    if let value, !value.isEmpty {
                        Text(value)
                            .font(SparkTypography.body)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if let target {
                    arrow
                    partyView(target, role: "Object", labelFirst: false)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(SparkSpacing.lg)
            .sparkContentSurface(radius: SparkRadii.lg)
            .overlay {
                RoundedRectangle(cornerRadius: SparkRadii.lg, style: .continuous)
                    .strokeBorder(Color.sparkInfo.opacity(0.10), lineWidth: 2)
            }
        }
    }

    private var arrow: some View {
        SparkGlyph(.decrease, size: 12, relativeTo: .caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 2)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func partyView(_ party: Party, role: String, labelFirst: Bool) -> some View {
        let label = Text(role)
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.secondary)
        VStack(spacing: SparkSpacing.xs) {
            if labelFirst { label }
            chip(party)
            Text(party.typeName)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
            if !labelFirst { label }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(role): \(party.title), \(party.typeName)")
    }

    @ViewBuilder
    private func chip(_ party: Party) -> some View {
        let reference = EntityReference(type: .object, id: party.id ?? "", title: party.title, domain: party.type)
        if let id = party.id, !id.isEmpty {
            NavigationLink {
                ObjectDetailView(objectId: id)
            } label: {
                EntityRefChip(reference)
            }
            .buttonStyle(.plain)
        } else {
            EntityRefChip(reference)
        }
    }
}

// MARK: - Score bars

/// A labelled 0–100 bar, the Bar pattern (§8), for contributor blocks. The
/// value is also written out, so the bar is never the only reading.
struct SparkDetailScoreBar: View {
    let label: String
    let value: Double
    let tint: Color
    var threshold: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                Text(label)
                    .font(SparkTypography.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: SparkSpacing.sm)
                Text(SparkDetailNumber.format(value, unit: nil))
                    .font(SparkTypography.bodyStrong)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint)
                        .frame(width: width * min(max(value / 100, 0), 1))
                    if let threshold {
                        Capsule()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 2, height: 12)
                            .offset(x: width * threshold - 1)
                    }
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(SparkDetailNumber.format(value, unit: nil)) out of 100")
    }
}

/// Contributor blocks as bars in one card, each opening its block.
struct SparkDetailContributorList: View {
    let blocks: [Block]
    let domain: String
    var threshold: Double?
    let parent: Event?

    var body: some View {
        VStack(spacing: SparkSpacing.xs) {
            ForEach(blocks) { block in
                NavigationLink {
                    BlockDetailView(blockId: block.id, parent: parent)
                } label: {
                    HStack(spacing: SparkSpacing.md) {
                        SparkDetailScoreBar(
                            label: block.title,
                            value: block.displayValue?.number ?? 0,
                            tint: Color.domainTint(for: domain),
                            threshold: threshold
                        )
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, SparkSpacing.sm)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.xs)
        .sparkContentSurface(radius: SparkRadii.lg)
    }

    /// Contributors are 0–100 blocks; anything else keeps its usual card.
    static func isContributor(_ block: Block) -> Bool {
        block.kind == .contributor && block.displayValue?.number != nil
    }
}

// MARK: - Details sheet

/// The technical facts behind a record, out of the page and into a sheet
/// opened from the toolbar's sliders button (§12.2). Each row is an
/// InspectorRow; IDs are mono and can be copied.
struct SparkDetailInfo {
    struct Row: Identifiable {
        let key: String
        let value: String
        var isMono = false
        var isCopyable = false

        var id: String { key }
    }

    var rows: [Row]
    var openTitle: String?
    var openURL: URL?
}

struct SparkDetailInfoSheet: View {
    let info: SparkDetailInfo

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(info.rows) { row in
                        InspectorRow(row.key, isMono: row.isMono) {
                            HStack(spacing: SparkSpacing.sm) {
                                Text(row.value)
                                    .lineLimit(row.isMono ? 1 : 3)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                if row.isCopyable {
                                    Spacer(minLength: 0)
                                    Button {
                                        UIPasteboard.general.string = row.value
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .frame(minWidth: 44, minHeight: 32)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Copy \(row.key.lowercased())")
                                }
                            }
                        }
                    }

                    if let url = info.openURL {
                        Button {
                            openURL(url)
                        } label: {
                            HStack {
                                Text(info.openTitle ?? "Open source")
                                    .font(SparkTypography.bodyStrong)
                                Spacer()
                                SparkGlyph(.openExternal, size: 13)
                            }
                            .foregroundStyle(Color.sparkAccent)
                            .padding(.vertical, SparkSpacing.md)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.md)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

enum SparkDetailDateText {
    /// "Saturday 31 October 2026, 05:48:05", for the Details sheet.
    static func full(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEEE d MMMM yyyy, HH:mm:ss"
        return f
    }()
}
