import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Chat home")
@MainActor
struct ChatHomeModelTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    /// Sat 21 Nov 2026, 09:00 in London.
    private static let now = Date(timeIntervalSince1970: 1_795_251_600)

    private static func conversation(_ id: String, hoursAgo: Double) -> FlintAskConversation {
        FlintAskConversation(id: id, title: id, updatedAt: now.addingTimeInterval(-hoursAgo * 3600))
    }

    @Test("conversations are grouped by the day they were last active")
    func sections() {
        let conversations = [
            Self.conversation("a", hoursAgo: 1),
            Self.conversation("b", hoursAgo: 3),
            Self.conversation("c", hoursAgo: 20),
            Self.conversation("d", hoursAgo: 24 * 6),
            FlintAskConversation(id: "e", title: "e"),
        ]

        let sections = ChatHomeModel.sections(conversations, now: Self.now, calendar: Self.calendar)

        #expect(sections.map(\.title) == ["Today", "Yesterday", "Sun 15 Nov", "Earlier"])
        #expect(sections.map { $0.conversations.map(\.id) } == [["a", "b"], ["c"], ["d"], ["e"]])
    }

    @Test("a date in another year names the year, and times are 24-hour")
    func dateFormats() {
        let lastYear = Self.now.addingTimeInterval(-400 * 24 * 3600)
        #expect(ChatHomeModel.dayTitle(lastYear, now: Self.now, calendar: Self.calendar) == "Fri 17 Oct 2025")

        let afternoon = Self.now.addingTimeInterval(6 * 3600 + 5 * 60)
        #expect(ChatHomeModel.time(afternoon, calendar: Self.calendar) == "15:05")
    }

    @Test("a search is sent trimmed, and an empty one is not sent")
    func searchIsSent() async {
        let service = StubConversationService(conversations: [Self.conversation("a", hoursAgo: 1)])
        let model = ChatHomeModel(service: service)

        await model.load()
        model.search = "  sleep "
        await model.load()

        #expect(await service.searches == [nil, "sleep"])
        #expect(model.state == .loaded)
        #expect(model.conversations.map(\.id) == ["a"])
    }

    @Test("a failed load says why, and a failed delete keeps the conversation")
    func failures() async {
        let service = StubConversationService(conversations: [Self.conversation("a", hoursAgo: 1)])
        let model = ChatHomeModel(service: service)
        await model.load()

        await service.setFails(true)
        await model.delete(model.conversations[0])
        #expect(model.conversations.count == 1)
        #expect(model.deleteError != nil)

        let empty = ChatHomeModel(service: service)
        await empty.load()
        #expect(empty.state == .failed("Can't reach Spark. Check your connection and try again."))
    }

    @Test("a deleted conversation leaves the list")
    func delete() async {
        let service = StubConversationService(conversations: [
            Self.conversation("a", hoursAgo: 1), Self.conversation("b", hoursAgo: 2),
        ])
        let model = ChatHomeModel(service: service)
        await model.load()

        await model.delete(model.conversations[0])

        #expect(model.conversations.map(\.id) == ["b"])
        #expect(await service.deleted == ["a"])
        #expect(model.deleteError == nil)
    }
}

private actor StubConversationService: AskFlintServing {
    private let conversations: [FlintAskConversation]
    private var fails = false
    private(set) var searches: [String?] = []
    private(set) var deleted: [String] = []

    init(conversations: [FlintAskConversation]) {
        self.conversations = conversations
    }

    func setFails(_ fails: Bool) { self.fails = fails }

    func stream(message: String, conversationId: String?) async throws -> AsyncThrowingStream<FlintAskStreamEvent, Error> {
        throw APIError.noData
    }

    func undo(receiptId: String) async throws -> Bool { false }

    func conversations(search: String?) async throws -> [FlintAskConversation] {
        searches.append(search)
        if fails { throw APIError.transport(URLError(.notConnectedToInternet)) }
        return conversations
    }

    func messages(conversationId: String) async throws -> [FlintAskMessage] { [] }

    func delete(conversationId: String) async throws {
        if fails { throw APIError.transport(URLError(.notConnectedToInternet)) }
        deleted.append(conversationId)
    }
}
