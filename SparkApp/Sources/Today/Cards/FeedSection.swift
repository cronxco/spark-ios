import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct FeedSection: View {
    let date: Date
    @Query private var allEvents: [CachedEvent]

    private var dayEvents: [CachedEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return allEvents
            .filter { e in
                guard let t = e.time else { return false }
                return t >= start && t < end
            }
            .sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    var body: some View {
        if !dayEvents.isEmpty {
            GlassCard {
                GlassCardHeader(icon: "list.bullet", tint: .sparkAccent, title: "Timeline")
                ForEach(dayEvents) { event in
                    NavigationLink(value: DetailRoute.event(id: event.id)) {
                        EventRow(
                            title: event.actorTitle ?? event.action,
                            subtitle: event.targetTitle,
                            timestamp: event.time ?? .now,
                            iconSystemName: Self.icon(for: event.domain),
                            tintColor: Self.tint(for: event.domain)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private static func icon(for domain: String) -> String {
        switch domain {
        case "health": return "moon.zzz.fill"
        case "activity": return "figure.walk"
        case "money": return "creditcard.fill"
        case "media": return "music.note"
        case "knowledge": return "book.fill"
        default: return "bolt.fill"
        }
    }

    private static func tint(for domain: String) -> Color {
        switch domain {
        case "health": return .domainHealth
        case "activity": return .domainActivity
        case "money": return .domainMoney
        case "media": return .domainMedia
        case "knowledge": return .domainKnowledge
        default: return .sparkAccent
        }
    }
}
