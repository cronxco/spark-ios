import Foundation

public enum KnowledgeTasksEndpoint {
  public static func list(cursor: String? = nil) -> Endpoint<KnowledgeTasksPage> {
    Endpoint(
      method: .get, path: "/tasks",
      query: [URLQueryItem(name: "include_deleted", value: "1")]
        + (cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? []))
  }
  public static func projects(cursor: String? = nil) -> Endpoint<KnowledgeProjectsPage> {
    Endpoint(
      method: .get, path: "/projects",
      query: cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [])
  }
  public static func write(id: String?, body: Data, version: String?) -> Endpoint<
    KnowledgeTaskResponse
  > {
    Endpoint(
      method: id == nil ? .post : .patch, path: id.map { "/tasks/\($0)" } ?? "/tasks",
      body: body, contentType: "application/json", headers: version.map { ["If-Match": $0] } ?? [:])
  }
  public static func action(id: String, body: Data, version: String) -> Endpoint<
    KnowledgeTaskResponse
  > {
    Endpoint(
      method: .post, path: "/tasks/\(id)/actions", body: body, contentType: "application/json",
      headers: ["If-Match": version])
  }
  public static func project(id: String? = nil, body: Data, version: String? = nil) -> Endpoint<
    KnowledgeProjectResponse
  > {
    Endpoint(
      method: id == nil ? .post : .patch, path: id.map { "/projects/\($0)" } ?? "/projects",
      body: body, contentType: "application/json", headers: version.map { ["If-Match": $0] } ?? [:])
  }
  public static func history(id: String, page: Int = 1) -> Endpoint<KnowledgeTaskHistoryPage> {
    Endpoint(
      method: .get, path: "/tasks/\(id)/history",
      query: [URLQueryItem(name: "page", value: String(page))])
  }
  public static func deleteProject(id: String, version: String) -> Endpoint<EmptyResponse> {
    Endpoint(method: .delete, path: "/projects/\(id)", headers: ["If-Match": version])
  }
}
