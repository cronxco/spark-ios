import SwiftUI
import SparkKit

/// Single source of truth for mapping a Spark entity's domain/service/action
/// to its tint colour and SF Symbol. Consolidates logic that was duplicated
/// in `MetricPresentation` and `Color.domainTint(for:)`.
public enum EntityPresentation {
    public static func tint(domain: String?) -> Color {
        switch (domain ?? "").lowercased() {
        case "health": .domainHealth
        case "activity": .domainActivity
        case "money": .domainMoney
        case "media": .domainMedia
        case "knowledge": .domainKnowledge
        case "anomaly": .domainAnomaly
        default: .sparkAccent
        }
    }

    /// Action-keyword matching takes priority (preserves prior
    /// `MetricPresentation.icon` behaviour exactly), then domain, then a
    /// generic per-entity-type fallback for references that carry no action.
    public static func icon(
        domain: String? = nil,
        service: String? = nil,
        action: String? = nil,
        type: String? = nil
    ) -> String {
        let action = action ?? ""
        let domain = (domain ?? "").lowercased()
        let service = service ?? ""

        if action.localizedCaseInsensitiveContains("sleep") { return "moon.zzz.fill" }
        if action.localizedCaseInsensitiveContains("heart") { return "heart.fill" }
        if action.localizedCaseInsensitiveContains("hrv") { return "waveform.path.ecg" }
        if action.localizedCaseInsensitiveContains("step") { return "figure.walk" }
        if action.localizedCaseInsensitiveContains("calorie") { return "flame.fill" }
        if service.localizedCaseInsensitiveContains("monzo") || domain == "money" { return "sterlingsign.circle.fill" }
        if domain == "media" { return "iphone" }
        if domain == "activity" { return "figure.run" }
        if domain == "health" { return "heart.text.square.fill" }

        switch (type ?? "").lowercased() {
        case "event": return "bolt.fill"
        case "object": return "cube.fill"
        case "block": return "square.grid.2x2.fill"
        case "place": return "mappin.circle.fill"
        case "integration": return "puzzlepiece.extension.fill"
        default: return "chart.line.uptrend.xyaxis"
        }
    }

    public static func icon(for reference: EntityReference) -> String {
        icon(
            domain: reference.domain,
            service: reference.service,
            action: nil,
            type: reference.type.rawValue
        )
    }

    public static func tint(for reference: EntityReference) -> Color {
        tint(domain: reference.domain)
    }
}
