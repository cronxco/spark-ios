import SwiftUI

/// A Font Awesome glyph from the manifest (`SparkIcon`), drawn in the bundled
/// font so it scales with Dynamic Type beside its text. Takes the foreground
/// style it is given: a domain glyph its domain fill, an interface glyph
/// stays neutral (`docs/design-language.md` section 6).
///
/// Decorative by default, because a label sits beside every glyph. Give it an
/// `accessibilityLabel` where it stands alone.
public struct SparkGlyph: View {
    let icon: SparkIcon
    let size: CGFloat
    let style: Font.TextStyle

    public init(_ icon: SparkIcon, size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) {
        self.icon = icon
        self.size = size
        self.style = style
    }

    public var body: some View {
        Text(icon.glyph)
            .font(SparkFonts.icon(size: size, relativeTo: style))
            .accessibilityHidden(true)
    }
}

public extension SparkIcon {
    /// The domain's own glyph (section 3.2), or `link` for a domain the
    /// design language does not name.
    static func domain(_ domain: String?) -> SparkIcon {
        switch (domain ?? "").lowercased() {
        case "health": .health
        case "activity": .activity
        case "money": .money
        case "media": .media
        case "knowledge": .knowledge
        case "online": .online
        case "anomaly": .anomaly
        default: .link
        }
    }

    /// An event's glyph, from what happened rather than only where: music
    /// for "listened to", a book for "read", a receipt for a payment. The
    /// timeline and the event screen both draw this, so an event looks the
    /// same in each. Anything unmatched takes its domain's glyph.
    static func event(action: String?, service: String? = nil, domain: String?) -> SparkIcon {
        let action = (action ?? "").lowercased()
        let service = (service ?? "").lowercased()
        // Whole words of the snake_case action, so "ran" never matches
        // "transfer". A pattern with an underscore matches as written.
        let words = Set(action.split(separator: "_").map(String.init))
        func has(_ patterns: String...) -> Bool {
            patterns.contains { $0.contains("_") ? action.contains($0) : words.contains($0) }
        }

        // Health and activity readings
        if has("sleep", "slept", "sleeping") { return .sleep }
        if has("bedtime", "went_to_bed") { return .bedtime }
        if has("hrv") { return .hrv }
        if has("heart") { return .heartRate }
        if has("oxygen", "spo2") { return .bloodOxygen }
        if has("stress") { return .stress }
        if has("resilience") { return .resilience }
        if has("breath", "respiratory") { return .breathing }
        if has("step", "steps") { return .steps }
        if has("stand") { return .stand }
        if has("calorie", "calories", "energy_burned") { return .energy }
        if has("workout", "exercise", "lifted", "trained") { return .workout }
        if has("distance", "walked", "ran", "cycled") { return .distance }
        if has("readiness", "_score") { return .score }
        if has("morning_checkin", "morning_check_in") { return .morning }
        if has("afternoon_checkin", "afternoon_check_in") { return .afternoon }

        // Media and knowledge
        if has("listened", "played_track", "scrobbled") || service == "spotify" && has("played") { return .track }
        if has("watched", "played") { return .media }
        if has("read", "reading", "finished_book", "started_book") { return .book }
        if has("bookmarked", "saved", "clipped") { return .article }
        if has("photo", "photos", "took_picture") { return .photo }

        // Money
        if has("pot") { return .savingsPot }
        if has("transfer") { return .transfer }
        if has("balance") { return .balance }
        if has("salary", "income", "received_payment") { return .income }
        if has("invoice") { return .invoice }
        if has("card_payment", "payment", "purchase", "spent", "paid") { return .payment }

        // Time and place
        if has("visited", "arrived", "checked_in", "departed") { return .place }
        if service.contains("calendar") || has("had_event", "meeting", "attended") { return .calendarEvent }
        if has("completed_task", "task") { return .task }
        if service == "flint" { return .flint }

        return .domain(domain)
    }
}

#if os(iOS)
import UIKit

public extension SparkIcon {
    /// The glyph drawn into a template image, for the places that take only
    /// an image, such as a tab bar item. Elsewhere, use `SparkGlyph`, which
    /// scales with Dynamic Type.
    @MainActor func image(pointSize: CGFloat = 22) -> Image {
        Image(uiImage: uiImage(pointSize: pointSize))
    }

    @MainActor func uiImage(pointSize: CGFloat) -> UIImage {
        SparkFonts.registerBundledFonts()
        let font = UIFont(name: SparkFonts.iconPostScriptName, size: pointSize)
            ?? .systemFont(ofSize: pointSize)
        let text = NSAttributedString(string: glyph, attributes: [.font: font])
        let size = text.size()
        let canvas = CGSize(width: ceil(size.width), height: ceil(size.height))
        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            text.draw(at: .zero)
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
#endif
