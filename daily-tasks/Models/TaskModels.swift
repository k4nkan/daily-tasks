import Foundation

// MARK: - API Response Model (GET /api/tasks)

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

// MARK: - Task Creation Request Model (POST /api/tasks)

struct TaskCreateRequest: Codable {
  let title: String
  let summary: String?
  let deadline: String?
  let estimate_label: String?
  let priority_label: String?
  let task_types: [String]
  let status: String?
}
