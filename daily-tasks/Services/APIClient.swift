import Foundation

/// Handles communication with the backend API.
/// Refactored to use AppConfig and NetworkManager.
enum APIClient {

  /// Fetches the task list (GET /api/tasks)
  static func fetchTasks() async throws -> [TaskResponse] {
    let baseURL = AppConfig.apiBaseURL
    let apiKey = AppConfig.apiKey

    guard let url = URL(string: "\(baseURL)/api/tasks") else {
      throw NetworkError.invalidURL
    }

    let headers = ["X-API-Key": apiKey]

    return try await NetworkManager.performRequest(
      url: url,
      headers: headers,
      decodingStrategy: .useDefaultKeys
    )
  }

  /// Adds a task (POST /api/tasks)
  static func createTask(_ task: TaskCreateRequest) async throws {
    let baseURL = AppConfig.apiBaseURL
    let apiKey = AppConfig.apiKey

    guard let url = URL(string: "\(baseURL)/api/tasks") else {
      throw NetworkError.invalidURL
    }

    let headers = ["X-API-Key": apiKey]

    // Use a dummy response type since the API might return empty or simple JSON
    struct EmptyResponse: Codable {}

    let _: EmptyResponse = try await NetworkManager.performPost(
      url: url,
      body: task,
      headers: headers
    )
  }
}
