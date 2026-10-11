import Foundation
import Observation
import SparkKit

@Observable @MainActor
final class KnowledgeTasksViewModel {
  struct Pending: Codable, Identifiable {
    var id: String
    var entityID: String?
    var version: String?
    var action: Bool
    var body: Data
    var title: String
    var error: String?
  }
  struct Snapshot: Codable {
    var tasks: [KnowledgeTask]
    var projects: [KnowledgeProject]
    var pending: [Pending]
  }
  private(set) var tasks: [KnowledgeTask] = []
  private(set) var projects: [KnowledgeProject] = []
  private(set) var topics: [FlintTopic] = []
  private(set) var pending: [Pending] = []
  private(set) var loading = false
  private(set) var lastRefreshSucceeded = false
  private(set) var timezone = TimeZone.current.identifier
  var error: String?
  var filter = "today"
  var search = ""
  private let api: APIClient
  private let file: URL
  private var flushing = false
  private static var cacheGeneration = 0
  private let generation: Int
  init(api: APIClient, accountID: String, storageDirectory: URL? = nil) {
    self.api = api
    generation = Self.cacheGeneration
    let scope = Data(api.cacheScope.utf8).base64EncodedString().replacingOccurrences(
      of: "/", with: "_"
    ).replacingOccurrences(of: "+", with: "-")
    file = (storageDirectory ?? Self.directory).appendingPathComponent(scope + "-" + accountID)
      .appendingPathExtension("json")
    if let data = try? Data(contentsOf: file),
      let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
    {
      tasks = snapshot.tasks
      projects = snapshot.projects
      pending = snapshot.pending
    }
  }
  static var directory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("KnowledgeTasks", isDirectory: true)
  }
  static func clearAccounts() throws {
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
    cacheGeneration += 1
  }
  @discardableResult private func persist() -> Bool {
    guard generation == Self.cacheGeneration else { return false }
    do {
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(
        Snapshot(tasks: tasks, projects: projects, pending: pending))
      try data.write(
        to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      return true
    } catch {
      self.error = "Couldn't save offline changes: \(error.localizedDescription)"
      return false
    }
  }
  var visible: [KnowledgeTask] {
    tasks.filter { task in
      let matches =
        search.isEmpty || task.title.localizedCaseInsensitiveContains(search)
        || (task.content?.localizedCaseInsensitiveContains(search) ?? false)
      let included =
        switch filter {
        case "today":
          task.isVisible(on: task.localDate())
            && (task.origin == "integration"
              || !projects.contains(where: {
                $0.id == task.projectID && $0.status == "paused" && $0.hideTasks
              }))
        case "inbox": task.availabilityOn == nil && task.status == "open"
        case "history":
          task.effectiveStatus(on: task.localDate()) != "open" && task.status != "deleted"
        case "deleted": task.status == "deleted"
        default: task.status != "deleted"
        }
      return matches && included
    }.sorted {
      ($0.priority == "important" ? 0 : 1, $0.position, $0.title) < (
        $1.priority == "important" ? 0 : 1, $1.position, $1.title
      )
    }
  }
  @discardableResult func refresh() async -> Bool {
    guard !loading, generation == Self.cacheGeneration else { return false }
    loading = true
    lastRefreshSucceeded = false
    error = nil
    defer { loading = false }
    await flush()
    do {
      var refreshedTimezone = timezone
      var all: [KnowledgeTask] = []
      var cursor: String?
      var seen: Set<String> = []
      repeat {
        let page = try await api.request(KnowledgeTasksEndpoint.list(cursor: cursor))
        guard generation == Self.cacheGeneration else { return false }
        refreshedTimezone = page.scheduleTimezone ?? refreshedTimezone
        all += page.data
        cursor = page.nextCursor
        if let cursor, !seen.insert(cursor).inserted { throw APIError.noData }
      } while cursor != nil
      var allProjects: [KnowledgeProject] = []
      cursor = nil
      seen = []
      repeat {
        let page = try await api.request(KnowledgeTasksEndpoint.projects(cursor: cursor))
        allProjects += page.data
        cursor = page.nextCursor
        if let cursor, !seen.insert(cursor).inserted { throw APIError.noData }
      } while cursor != nil
      var allTopics: [FlintTopic] = []
      cursor = nil
      seen = []
      repeat {
        let page = try await api.request(FlintTopicsEndpoint.list(limit: 100, cursor: cursor))
        allTopics += page.data
        cursor = page.nextCursor
        if let cursor, !seen.insert(cursor).inserted { throw APIError.noData }
      } while cursor != nil
      guard generation == Self.cacheGeneration else { return false }
      tasks = all
      projects = allProjects
      topics = allTopics
      timezone = refreshedTimezone
      persist()
      lastRefreshSucceeded = true
      return true
    } catch {
      guard generation == Self.cacheGeneration else { return false }
      self.error = error.localizedDescription
      return false
    }
  }
  @discardableResult func save(task: KnowledgeTask?, fields: [String: Any]) async -> Bool {
    var values = fields
    let mutation = UUID().uuidString.lowercased()
    values["client_mutation_id"] = mutation
    do {
      let body = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
      return await enqueue(
        Pending(
          id: mutation, entityID: task?.id, version: task?.version, action: false, body: body,
          title: values["title"] as? String ?? "Task"))
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func act(_ task: KnowledgeTask, action: String, date: String? = nil) async {
    let mutation = UUID().uuidString.lowercased()
    var fields = ["action": action, "client_mutation_id": mutation]
    if let date { fields["availability_on"] = date }
    do {
      let body = try JSONEncoder().encode(fields)
      await enqueue(
        Pending(
          id: mutation, entityID: task.id, version: task.version, action: true, body: body,
          title: task.title))
    } catch { self.error = error.localizedDescription }
  }
  @discardableResult private func enqueue(_ change: Pending) async -> Bool {
    guard change.entityID == nil || !pending.contains(where: { $0.entityID == change.entityID })
    else {
      error = "This task already has a pending change. Sync or discard it before editing again."
      return false
    }
    pending.append(change)
    guard persist() else {
      pending.removeAll { $0.id == change.id }
      return false
    }
    await flush()
    return true
  }
  func discard(_ id: String) {
    pending.removeAll { $0.id == id }
    persist()
  }
  func flush() async {
    guard !flushing else { return }
    flushing = true
    defer { flushing = false }
    for change in pending where change.error == nil {
      guard generation == Self.cacheGeneration else { return }
      do {
        let response: KnowledgeTaskResponse
        if change.action, let id = change.entityID, let version = change.version {
          response = try await api.request(
            KnowledgeTasksEndpoint.action(id: id, body: change.body, version: version))
        } else {
          response = try await api.request(
            KnowledgeTasksEndpoint.write(
              id: change.entityID, body: change.body, version: change.version))
        }
        guard generation == Self.cacheGeneration else { return }
        tasks.removeAll { $0.id == response.data.id }
        tasks.append(response.data)
        pending.removeAll { $0.id == change.id }
        persist()
      } catch let failure as APIError {
        if case .transport = failure {
          error = "Changes saved on this device. Pull to refresh when connected."
          return
        }
        if case .httpStatus(let status, _, _) = failure, status >= 500 {
          error = "Spark is unavailable. Your changes will retry."
          return
        }
        if let index = pending.firstIndex(where: { $0.id == change.id }) {
          pending[index].error = failure.localizedDescription
        }
        error = failure.localizedDescription
        persist()
      } catch {
        self.error = error.localizedDescription
        return
      }
    }
  }
  func saveProject(_ project: KnowledgeProject?, fields: [String: Any]) async {
    guard generation == Self.cacheGeneration else { return }
    error = nil
    do {
      let data = try JSONSerialization.data(withJSONObject: fields)
      let response = try await api.request(
        KnowledgeTasksEndpoint.project(id: project?.id, body: data, version: project?.version))
      guard generation == Self.cacheGeneration else { return }
      projects.removeAll { $0.id == response.data.id }
      projects.append(response.data)
      persist()
    } catch { self.error = error.localizedDescription }
  }
  func history(_ task: KnowledgeTask) async -> [KnowledgeTaskHistory] {
    do { return try await api.request(KnowledgeTasksEndpoint.history(id: task.id)).data } catch {
      self.error = error.localizedDescription
      return []
    }
  }
  func removeProject(_ project: KnowledgeProject) async -> Bool {
    error = nil
    do {
      _ = try await api.request(
        KnowledgeTasksEndpoint.deleteProject(id: project.id, version: project.version))
      guard generation == Self.cacheGeneration else { return false }
      projects.removeAll { $0.id == project.id }
      await refresh()
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
}
