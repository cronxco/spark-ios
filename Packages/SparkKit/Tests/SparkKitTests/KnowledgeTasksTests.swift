import Foundation
import Testing

@testable import SparkKit

@Suite struct KnowledgeTasksTests {
  private func task(
    lifecycle: String = "week", status: String = "open", expiry: String? = "2026-10-31"
  ) throws -> KnowledgeTask {
    let object: [String: Any] = [
      "id": "task-1", "title": "Call the bank", "version": "\"opaque\"", "lifecycle": lifecycle,
      "status": status, "availability_on": "2026-10-24", "expires_on": expiry as Any? ?? NSNull(),
      "schedule_timezone": "Europe/London", "priority": "normal", "position": 0, "origin": "native",
      "carried_days": 0,
      "overdue": false, "visible_on_date": true, "thread_ids": [], "sync": ["status": "synced"],
    ]
    return try JSONDecoder().decode(
      KnowledgeTask.self, from: JSONSerialization.data(withJSONObject: object))
  }
  @Test func weekWindowRemainsCalendarBoundAcrossDST() throws {
    let task = try task()
    #expect(task.isVisible(on: "2026-10-30"))
    #expect(!task.isVisible(on: "2026-10-31"))
    #expect(task.effectiveStatus(on: "2026-10-31") == "expired")
    #expect(!task.isVisible(on: "2026-10-23"))
  }
  @Test func persistentTasksKeepTheirIdentityAndCompletedTasksStayClosed() throws {
    #expect(try task(lifecycle: "persistent", expiry: nil).isVisible(on: "2029-01-01"))
    #expect(try task(status: "completed").effectiveStatus(on: "2026-11-01") == "completed")
  }
  @Test func lifecycleUsesCapturedScheduleTimezone() throws {
    let instant = try #require(ISO8601DateFormatter().date(from: "2026-10-24T23:30:00Z"))
    #expect(try task().localDate(at: instant) == "2026-10-25")
  }
  @Test func endpointsCarryVersionsAndReplayableBodies() throws {
    let body = try JSONEncoder().encode(["title": "Task", "client_mutation_id": UUID().uuidString])
    let create = KnowledgeTasksEndpoint.write(id: nil, body: body, version: nil)
    #expect(create.path == "/tasks" && create.method == .post)
    let edit = KnowledgeTasksEndpoint.write(id: "task-1", body: body, version: "\"version\"")
    #expect(edit.path == "/tasks/task-1" && edit.method == .patch)
    #expect(edit.headers["If-Match"] == "\"version\"")
    #expect(edit.body == body)
    #expect(
      KnowledgeTasksEndpoint.action(id: "task-1", body: body, version: "v").path
        == "/tasks/task-1/actions")
  }
}
