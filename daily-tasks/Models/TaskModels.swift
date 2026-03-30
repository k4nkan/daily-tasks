import Foundation

// MARK: - APIレスポンス用モデル（GET /api/tasks）

struct TaskResponse: Codable, Identifiable {
  let id: String
  let title: String
  let summary: String?
  let deadline: String?
  let estimate_label: String?
  let estimate_minutes: Int?
  let priority_label: String?
  let priority_value: Int?
  let task_types: [String]
  let status: String?
}

// MARK: - タスク追加リクエスト用モデル（POST /api/tasks）

struct TaskCreateRequest: Codable {
  let title: String
  let summary: String?
  let deadline: String?
  let estimate_label: String?
  let priority_label: String?
  let task_types: [String]
  let status: String?
}
