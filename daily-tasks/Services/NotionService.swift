import Foundation

// MARK: - Notion Error

enum NotionError: LocalizedError {
  case invalidURL
  case missingCredentials
  case networkError(Error)
  case decodingError(Error)
  case serverError(Int)

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "URLが無効です（Notion）"
    case .missingCredentials:
      return "Config.plist に NOTION_API_KEY または NOTION_DATASORCE_ID が設定されていません"
    case .networkError(let error):
      return "通信エラー（Notion）: \(error.localizedDescription)"
    case .decodingError:
      return "Notion からのレスポンス解析に失敗しました"
    case .serverError(let code):
      return "Notion サーバーエラー (HTTP \(code))"
    }
  }
}

// MARK: - Notion Service

/// Directly calls the Notion API to fetch tasks
enum NotionService {

  /// Loads configuration from Config.plist
  private static var configDict: [String: Any]? {
    guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path) as? [String: Any]
    else {
      return nil
    }
    return dict
  }

  private static var apiKey: String? {
    configDict?["NOTION_API_KEY"] as? String
  }

  private static var dataSourceID: String? {
    configDict?["NOTION_DATA_SOURCE_ID"] as? String
  }

  // MARK: - Public Methods

  /// Fetches tasks directly from Notion
  static func fetchTasks() async throws -> [TaskResponse] {
    guard let apiKey = apiKey, let dataSourceID = dataSourceID,
      !apiKey.isEmpty, !dataSourceID.isEmpty
    else {
      throw NotionError.missingCredentials
    }

    // According to NOTION_FETCH_GUIDE.md, using data_sources endpoint
    let urlString = "https://api.notion.com/v1/data_sources/\(dataSourceID)/query"
    guard let url = URL(string: urlString) else { throw NotionError.invalidURL }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("2026-03-11", forHTTPHeaderField: "Notion-Version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Filter to only get "Not started" or "In progress" tasks
    let filterBody: [String: Any] = [
      "filter": [
        "or": [
          [
            "property": "ステータス",
            "status": ["equals": "Not started"]
          ],
          [
            "property": "ステータス",
            "status": ["equals": "In progress"]
          ]
        ]
      ]
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: filterBody)
    } catch {
      throw NotionError.decodingError(error)
    }

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw NotionError.networkError(error)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NotionError.networkError(NSError(domain: "HTTPError", code: -1))
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw NotionError.serverError(httpResponse.statusCode)
    }

    do {
      let notionResponse = try JSONDecoder().decode(NotionResponse.self, from: data)
      return notionResponse.results.map { $0.toTaskResponse() }
    } catch {
      print("Notion Decoding Error: \(error)")
      throw NotionError.decodingError(error)
    }
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
