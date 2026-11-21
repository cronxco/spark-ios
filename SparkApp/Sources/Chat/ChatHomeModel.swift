import Foundation
import Observation
import SparkKit

/// The Chat home's list: every conversation with Flint, newest first and
/// grouped by day, narrowed by a search when one is typed.
@MainActor
@Observable
final class ChatHomeModel {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    /// The conversations last active on one day.
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let conversations: [FlintAskConversation]
    }

    private(set) var conversations: [FlintAskConversation] = []
    private(set) var state: State = .loading
    /// Set when a delete fails; the list keeps the conversation.
    private(set) var deleteError: String?
    var search = ""

    private let service: any AskFlintServing
    /// The load whose result may still be shown. A newer search replaces it,
    /// so a slow older answer can't overwrite a newer one.
    private var loadID: UUID?

    init(service: any AskFlintServing) {
        self.service = service
    }

    var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var sections: [Section] {
        Self.sections(conversations)
    }

    func load() async {
        let id = UUID()
        loadID = id
        if conversations.isEmpty { state = .loading }

        do {
            let query = trimmedSearch
            let found = try await service.conversations(search: query.isEmpty ? nil : query)
            guard loadID == id else { return }
            conversations = found
            state = .loaded
        } catch {
            guard loadID == id, !error.isAPICancellation else { return }
            state = .failed(AskFlintViewModel.message(for: error, inConversation: false))
        }
    }

    func delete(_ conversation: FlintAskConversation) async {
        do {
            try await service.delete(conversationId: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
            deleteError = nil
        } catch {
            deleteError = "Couldn't delete that conversation. \(AskFlintViewModel.message(for: error))"
        }
    }

    // MARK: - Grouping

    /// Conversations grouped by the day they were last active, in the order
    /// given: "Today", "Yesterday", then "Sun 22 Nov".
    static func sections(
        _ conversations: [FlintAskConversation], now: Date = .now, calendar: Calendar = .current
    ) -> [Section] {
        var sections: [Section] = []
        for conversation in conversations {
            let date = conversation.updatedAt ?? conversation.createdAt
            let day = date.map { calendar.startOfDay(for: $0) }
            let id = day.map { String(Int($0.timeIntervalSince1970)) } ?? "undated"

            if let last = sections.last, last.id == id {
                sections[sections.count - 1] = Section(
                    id: id, title: last.title, conversations: last.conversations + [conversation])
            } else {
                let title = date.map { dayTitle($0, now: now, calendar: calendar) } ?? "Earlier"
                sections.append(Section(id: id, title: title, conversations: [conversation]))
            }
        }
        return sections
    }

    static func dayTitle(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.dateFormat = sameYear ? "EEE d MMM" : "EEE d MMM yyyy"
        return formatter.string(from: date)
    }

    /// A 24-hour time, "08:10", whatever the device's clock setting.
    static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
