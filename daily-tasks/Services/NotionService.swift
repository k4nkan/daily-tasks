import Foundation

/// Directly calls the Notion API to fetch tasks
enum NotionService {

  /// Fetches tasks directly from Notion
  static func fetchTasks() async throws -> [TaskResponse] {
    let apiKey = AppConfig.notionAPIKey
    let dataSourceID = AppConfig.notionDataSourceID

    guard !apiKey.isEmpty, !dataSourceID.isEmpty else {
      throw NetworkError.serverError(401)  // Or a more specific error
    }

    let urlString = "https://api.notion.com/v1/data_sources/\(dataSourceID)/query"
    guard let url = URL(string: urlString) else { throw NetworkError.invalidURL }

    let headers = [
      "Authorization": "Bearer \(apiKey)",
      "Notion-Version": "2026-03-11",
      "Content-Type": "application/json",
    ]

    // Filter to only get "Not started" or "In progress" tasks
    let filterBody: [String: Any] = [
      "filter": [
        "or": [
          [
            "property": "ステータス",
            "status": ["equals": "Not started"],
          ],
          [
            "property": "ステータス",
            "status": ["equals": "In progress"],
          ],
        ]
      ]
    ]

    let bodyData: Data
    do {
      bodyData = try JSONSerialization.data(withJSONObject: filterBody)
    } catch {
      throw NetworkError.decodingError(error)
    }

    let response: NotionResponse = try await NetworkManager.performRequest(
      url: url,
      method: "POST",
      headers: headers,
      body: bodyData
    )

    return response.results.map { $0.toTaskResponse() }
  }

  /// Creates a new task in Notion
  static func createTask(_ task: TaskCreateRequest) async throws {
    let apiKey = AppConfig.notionAPIKey
    let dataSourceID = AppConfig.notionDataSourceID

    guard !apiKey.isEmpty, !dataSourceID.isEmpty else {
      throw NetworkError.serverError(401)
    }

    let urlString = "https://api.notion.com/v1/pages"
    guard let url = URL(string: urlString) else { throw NetworkError.invalidURL }

    let headers = [
      "Authorization": "Bearer \(apiKey)",
      "Notion-Version": "2026-03-11",
      "Content-Type": "application/json",
    ]

    // Construct properties dynamically
    var properties: [String: Any] = [
      "Name": [
        "title": [["text": ["content": task.title]]]
      ],
      "ステータス": [
        "status": ["name": task.status ?? "Not started"]
      ],
    ]

    if let summary = task.summary {
      properties["タスク概要"] = [
        "rich_text": [["text": ["content": summary]]]
      ]
    }

    if let deadline = task.deadline {
      properties["締切"] = [
        "date": ["start": deadline]
      ]
    }

    if let estimate = task.estimate_label {
      properties["見積もり"] = [
        "select": ["name": estimate]
      ]
    }

    if let priority = task.priority_label {
      properties["重要度"] = [
        "select": ["name": priority]
      ]
    }

    let body: [String: Any] = [
      "parent": [
        "type": "data_source_id",
        "data_source_id": dataSourceID,
      ],
      "properties": properties,
    ]

    let bodyData: Data
    do {
      bodyData = try JSONSerialization.data(withJSONObject: body)
    } catch {
      throw NetworkError.decodingError(error)
    }

    // Notion returns the created page, but we don't need it for now
    let _: NotionPage = try await NetworkManager.performRequest(
      url: url,
      method: "POST",
      headers: headers,
      body: bodyData
    )
  }

  // MARK: - Private Parser

  /// Helper to convert "1h" or "- 1.5h" to Int minutes
  /// Based on TaskAddViewModel.estimateOptions
  fileprivate static func parseEstimateToMinutes(_ label: String?) -> Int? {
    guard let label = label else { return nil }

    // Remove "- " and "h -" then find numeric parts
    let cleanLabel = label.replacingOccurrences(of: "- ", with: "")
      .replacingOccurrences(of: "h -", with: "")
      .replacingOccurrences(of: "h", with: "")
      .trimmingCharacters(in: .whitespaces)

    if let hours = Double(cleanLabel) {
      return Int(hours * 60)
    }
    return nil
  }
}

// MARK: - Notion Response Mapping Structs
// These match the internal structure of Notion's JSON response

struct NotionResponse: Codable {
  let results: [NotionPage]
}

struct NotionPage: Codable {
  let id: String
  let properties: NotionProperties

  /// Maps Notion's complex structure back to our TaskResponse model
  func toTaskResponse() -> TaskResponse {
    let title = properties.Name.title.first?.plain_text ?? "No Title"
    let status = properties.status?.status?.name
    let deadline = properties.deadline?.date?.start
    let estimate = properties.estimate?.select?.name
    let summary = properties.summary?.rich_text.first?.plain_text

    return TaskResponse(
      id: id,
      title: title,
      summary: summary,
      deadline: deadline,
      estimate_label: estimate,
      estimate_minutes: NotionService.parseEstimateToMinutes(estimate),
      priority_label: properties.priority?.select?.name,
      priority_value: nil,
      task_types: properties.taskTypes?.multi_select.map { $0.name } ?? [],
      status: status
    )
  }
}

struct NotionProperties: Codable {
  let Name: NotionTitleProperty
  let status: NotionStatusProperty?
  let deadline: NotionDateProperty?
  let estimate: NotionSelectProperty?
  let priority: NotionSelectProperty?
  let taskTypes: NotionMultiSelectProperty?
  let summary: NotionRichTextProperty?

  enum CodingKeys: String, CodingKey {
    case Name
    case status = "ステータス"
    case deadline = "締切"
    case estimate = "見積もり"
    case priority = "重要度"
    case taskTypes = "タスクタイプ"
    case summary = "タスク概要"
  }
}

struct NotionTitleProperty: Codable {
  let title: [NotionText]
}

struct NotionRichTextProperty: Codable {
  let rich_text: [NotionText]
}

struct NotionText: Codable {
  let plain_text: String
}

struct NotionStatusProperty: Codable {
  let status: NotionStatus?
}

struct NotionStatus: Codable {
  let name: String
}

struct NotionDateProperty: Codable {
  let date: NotionDate?
}

struct NotionDate: Codable {
  let start: String
}

struct NotionSelectProperty: Codable {
  let select: NotionSelect?
}

struct NotionSelect: Codable {
  let name: String
}

struct NotionMultiSelectProperty: Codable {
  let multi_select: [NotionSelect]
}
