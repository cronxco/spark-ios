import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Knowledge task outbox", .serialized) @MainActor
struct KnowledgeTaskOutboxTests {
  private static let host = "task-outbox.spark.test"
  @Test("a failed capture survives recreation and replays the same mutation")
  func captureSurvivesRestart() async throws {
    let client = try await makeClient()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let account = UUID().uuidString
    await AppStubURLProtocol.set(host: Self.host) { _ in (Data(), 503, [:]) }
    let first = KnowledgeTasksViewModel(
      api: client, accountID: account, storageDirectory: directory)
    await first.save(task: nil, fields: ["title": "Buy milk"])
    let change = try #require(first.pending.first)
    let second = KnowledgeTasksViewModel(
      api: client, accountID: account, storageDirectory: directory)
    #expect(second.pending.first?.id == change.id)
    #expect(second.pending.first?.body == change.body)
    await AppStubURLProtocol.set(host: Self.host) { _ in
      (Data(Self.taskResponse.utf8), 201, ["Content-Type": "application/json"])
    }
    await second.flush()
    #expect(second.pending.isEmpty)
    #expect(second.tasks.first?.id == "task-1")
    let requests = await AppStubURLProtocol.recorded(host: Self.host)
    #expect(requests.count == 1)
    #expect(requests.first?.httpBody == change.body)
  }
  @Test("a version conflict stays visible and is never silently retried")
  func conflictWaitsForReview() async throws {
    let client = try await makeClient()
    await AppStubURLProtocol.set(host: Self.host) { _ in (Data(Self.taskResponse.utf8), 201, [:]) }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = KnowledgeTasksViewModel(
      api: client, accountID: UUID().uuidString, storageDirectory: directory)
    await model.save(task: nil, fields: ["title": "Buy milk"])
    let task = try #require(model.tasks.first)
    await AppStubURLProtocol.set(host: Self.host) { _ in
      (Data(#"{"message":"Task changed"}"#.utf8), 412, [:])
    }
    await model.act(task, action: "complete")
    #expect(model.pending.first?.error != nil)
    await model.flush()
    #expect(await AppStubURLProtocol.recorded(host: Self.host).count == 1)
    #expect(model.tasks.first?.status == "open")
  }
  @Test("route vocabulary preserves recovery intent and sends task links to Knowledge")
  func routesPreserveIntent() {
    #expect(
      AppModel.route(from: "integration-reauth:connection-1")
        == .integrationReauth(id: "connection-1"))
    #expect(AppModel.route(from: "task:task-1") == .knowledgeTask(id: "task-1"))
    #expect(AppModel.route(from: "project:project-1") == .knowledgeProject(id: "project-1"))
  }
  @Test("logout invalidates a suspended refresh before it can publish any account data")
  func refreshDoesNotPublishAfterLogout() async throws {
    let client = try await makeClient()
    let gate = ResponseGate()
    await AppStubURLProtocol.set(host: Self.host) { request in
      if request.url?.path.hasSuffix("/tasks") == true {
        return (Data(Self.taskPage.utf8), 200, [:])
      }
      if request.url?.path.hasSuffix("/projects") == true {
        return (Data(Self.projectPage.utf8), 200, [:])
      }
      await gate.wait()
      return (Data(#"{"data":[],"has_more":false}"#.utf8), 200, [:])
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = KnowledgeTasksViewModel(api: client, accountID: UUID().uuidString, storageDirectory: directory)
    let refresh = Task { await model.refresh() }
    await gate.waitUntilStarted()
    try KnowledgeTasksViewModel.clearAccounts()
    await gate.release()
    #expect(await refresh.value == false)
    #expect(model.tasks.isEmpty)
    #expect(model.projects.isEmpty)
    #expect(model.topics.isEmpty)
  }
  @Test("logout invalidates a suspended project save before it changes the model")
  func projectSaveDoesNotPublishAfterLogout() async throws {
    let client = try await makeClient()
    let gate = ResponseGate()
    await AppStubURLProtocol.set(host: Self.host) { _ in
      await gate.wait()
      return (Data(Self.projectResponse.utf8), 201, [:])
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = KnowledgeTasksViewModel(api: client, accountID: UUID().uuidString, storageDirectory: directory)
    let save = Task { await model.saveProject(nil, fields: ["title": "Old account project"]) }
    await gate.waitUntilStarted()
    try KnowledgeTasksViewModel.clearAccounts()
    await gate.release()
    await save.value
    #expect(model.projects.isEmpty)
  }
  private nonisolated static let taskPage = """
    {"data":[{"id":"task-1","title":"Buy milk","version":"v1","lifecycle":"persistent","status":"open","schedule_timezone":"UTC","priority":"normal","position":0,"origin":"native","carried_days":0,"overdue":false,"visible_on_date":false,"thread_ids":[],"sync":{"status":"synced"}}],"has_more":false,"schedule_timezone":"UTC"}
    """
  private nonisolated static let projectPage = """
    {"data":[{"id":"project-1","title":"Old account project","status":"active","hide_tasks":true,"version":"v1"}],"has_more":false}
    """
  private nonisolated static let projectResponse = """
    {"data":{"id":"project-1","title":"Old account project","status":"active","hide_tasks":true,"version":"v1"}}
    """
  private actor ResponseGate {
    private var response: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var didStart = false
    func wait() async {
      await withCheckedContinuation { continuation in
        response = continuation
        didStart = true
        started?.resume()
        started = nil
      }
    }
    func waitUntilStarted() async {
      if didStart { return }
      await withCheckedContinuation { started = $0 }
    }
    func release() {
      response?.resume()
      response = nil
    }
  }
  private func makeClient() async throws -> APIClient {
    let store = KeychainTokenStore(
      service: "task-outbox.\(UUID().uuidString)", account: "test", accessGroup: nil)
    try await store.store(access: "token", refresh: "refresh", expiresIn: 3_600)
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [AppStubURLProtocol.self]
    return APIClient(
      environment: APIEnvironment(
        baseURL: URL(string: "https://\(Self.host)/api/v1/mobile")!,
        oauthAuthorizeURL: URL(string: "https://\(Self.host)/oauth/authorize")!, name: "test"),
      session: URLSession(configuration: config), tokenStore: store)
  }
  private nonisolated static let taskResponse = """
    {"data":{"id":"task-1","title":"Buy milk","version":"\\\"v1\\\"","lifecycle":"persistent","status":"open","schedule_timezone":"UTC","priority":"normal","position":0,"origin":"native","carried_days":0,"overdue":false,"visible_on_date":false,"thread_ids":[],"sync":{"status":"synced"}}}
    """
}
