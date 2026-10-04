#if DEBUG
import Foundation
import Testing
@testable import SparkKit

@Suite("API session retention")
struct APISessionStoreTests {
    private func request(_ path: String = "/up-to-speed?include_acknowledged=1") -> URLRequest {
        URLRequest(url: URL(string: "https://example.test" + path)!)
    }

    @Test func retentionAndExportLabelTruncation() {
        let store = APISessionStore(maxAttempts: 2, maxBytes: 6, bodyLimit: 4)
        let first = store.begin(request())
        store.response(first, status: 200, data: Data("123456".utf8))
        store.finish(first, outcome: "success")

        #expect(store.snapshot().entries[0].truncated)
        #expect(store.snapshot().entries[0].originalBytes == 6)

        let second = store.begin(request())
        store.response(second, status: 500, data: Data("abcd".utf8))

        let snapshot = store.snapshot()
        #expect(snapshot.evicted == 1)
        #expect(snapshot.entries.count == 1)
        #expect(snapshot.export.contains("include_acknowledged=1"))
        #expect(snapshot.export.contains("Attempt ID:"))
    }

    @Test func clearingDiscardsInFlightResponse() {
        let store = APISessionStore()
        let ticket = store.begin(request())
        store.clear()
        store.response(ticket, status: 200, data: Data("old account".utf8))
        store.finish(ticket, outcome: "success")
        #expect(store.snapshot().entries.isEmpty)
    }

    @Test func authenticationResponseBodyIsOmitted() {
        let store = APISessionStore()
        let ticket = store.begin(request("/api/oauth/token?code=secret"))
        store.response(ticket, status: 200, data: Data("secret".utf8))

        #expect(store.snapshot().entries[0].omitted)
        #expect(!store.snapshot().export.contains("secret"))
    }

    @Test func flintNoteResponseBodyIsOmitted() {
        let store = APISessionStore()
        let ticket = store.begin(request("/api/v1/mobile/flint/notes"))
        store.response(ticket, status: 200, data: Data(#"{"body":"private prose"}"#.utf8))

        #expect(store.snapshot().entries[0].omitted)
        #expect(!store.snapshot().export.contains("private prose"))
    }

    @Test func concurrentRetriesShareLogicalRequestIdentity() async {
        let store = APISessionStore()
        let logicalRequest = UUID()

        await withTaskGroup(of: Void.self) { group in
            for attempt in 1...20 {
                group.addTask {
                    let ticket = store.begin(request(), requestID: logicalRequest, attempt: attempt)
                    store.response(ticket, status: 304, data: Data())
                    store.finish(ticket, outcome: "not modified")
                }
            }
        }

        let entries = store.snapshot().entries
        #expect(entries.count == 20)
        #expect(Set(entries.map(\.id)).count == 20)
        #expect(Set(entries.map(\.requestID)) == [logicalRequest])
        #expect(entries.allSatisfy { $0.status == 304 && $0.outcome == "not modified" && $0.body.isEmpty })
    }
}
#endif
