import Foundation

public struct KnowledgeTask: Codable, Sendable, Identifiable, Hashable {
  public let id: String
  public let title: String
  public let version: String
  public let content: String?
  public let lifecycle: String
  public let status: String
  public let availabilityOn: String?
  public let expiresOn: String?
  public let dueOn: String?
  public let reviewOn: String?
  public let scheduleTimezone: String
  public let priority: String
  public let position: Int
  public let origin: String
  public let carriedDays: Int
  public let overdue: Bool
  public let visibleOnDate: Bool
  public let projectID: String?
  public let projectTitle: String?
  public let threadIDs: [String]
  public let sourceURL: String?
  public let recurrence: String?
  public let remindAt: String?
  public let context: [KnowledgeTaskContext]?
  public let sync: TaskSync
  public let action: TaskRecoveryAction?
  enum CodingKeys: String, CodingKey {
    case id, title, version, content, lifecycle, status, priority, position, origin, overdue,
      recurrence, sync, action, context
    case remindAt = "remind_at"
    case availabilityOn = "availability_on"
    case expiresOn = "expires_on"
    case dueOn = "due_on"
    case reviewOn = "review_on"
    case scheduleTimezone = "schedule_timezone"
    case carriedDays = "carried_days"
    case visibleOnDate = "visible_on_date"
    case projectID = "project_id"
    case projectTitle = "project_title"
    case threadIDs = "thread_ids"
    case sourceURL = "source_url"
  }
  public func effectiveStatus(on date: String) -> String {
    if status == "open", let expiresOn, date >= expiresOn { return "expired" }
    return status
  }
  public func isVisible(on date: String) -> Bool {
    guard let availabilityOn else { return false }
    return availabilityOn <= date && effectiveStatus(on: date) == "open"
  }
  public func localDate(at instant: Date = .now) -> String {
    let format = DateFormatter()
    format.calendar = Calendar(identifier: .gregorian)
    format.locale = Locale(identifier: "en_US_POSIX")
    format.timeZone = TimeZone(identifier: scheduleTimezone) ?? TimeZone(secondsFromGMT: 0)
    format.dateFormat = "yyyy-MM-dd"
    return format.string(from: instant)
  }
}
public struct KnowledgeTaskContext: Codable, Sendable, Hashable {
  public let kind: String
  public let id: String
  public let title: String?
}
public struct TaskSync: Codable, Sendable, Hashable {
  public let status: String
  public let reason: String?
}
public struct TaskRecoveryAction: Codable, Sendable, Hashable {
  public let kind: String
  public let integrationID: String
  public let url: String
  public let deepLink: String
  enum CodingKeys: String, CodingKey {
    case kind, url
    case integrationID = "integration_id"
    case deepLink = "deep_link"
  }
}
public struct KnowledgeProject: Codable, Sendable, Identifiable, Hashable {
  public let id: String
  public let title: String
  public let content: String?
  public let status: String
  public let targetOn: String?
  public let hideTasks: Bool
  public let nextActionTaskID: String?
  public let suggestedNextActionID: String?
  public let progress: KnowledgeProjectProgress?
  public let version: String
  enum CodingKeys: String, CodingKey {
    case id, title, content, status, version, progress
    case suggestedNextActionID = "suggested_next_action_id"
    case targetOn = "target_on"
    case hideTasks = "hide_tasks"
    case nextActionTaskID = "next_action_task_id"
  }
}
public struct KnowledgeProjectProgress: Codable, Sendable, Hashable {
  public let total: Int
  public let completed: Int
  public let open: Int
  public let expired: Int
}
public struct KnowledgeTasksPage: Codable, Sendable {
  public let data: [KnowledgeTask]
  public let nextCursor: String?
  public let hasMore: Bool
  public let scheduleTimezone: String?
  enum CodingKeys: String, CodingKey {
    case data
    case nextCursor = "next_cursor"
    case hasMore = "has_more"
    case scheduleTimezone = "schedule_timezone"
  }
}
public struct KnowledgeProjectsPage: Codable, Sendable {
  public let data: [KnowledgeProject]
  public let nextCursor: String?
  public let hasMore: Bool
  enum CodingKeys: String, CodingKey {
    case data
    case nextCursor = "next_cursor"
    case hasMore = "has_more"
  }
}
public struct KnowledgeTaskResponse: Codable, Sendable { public let data: KnowledgeTask }
public struct KnowledgeProjectResponse: Codable, Sendable { public let data: KnowledgeProject }

public struct KnowledgeTaskHistory: Codable, Sendable, Identifiable {
  public let id: String
  public let action: String
  public let time: String?
}
public struct KnowledgeTaskHistoryPage: Decodable, Sendable {
  public let data: [KnowledgeTaskHistory]
}
