import Foundation

// MARK: - API Error Definitions

enum APIError: LocalizedError {
  case invalidURL
  case missingAPIKey
  case missingBaseURL
  case unauthorized  // 401: Incorrect API Key
  case headerMissing  // 422: Missing API Key header
  case httpError(Int)
  case decodingError(Error)
  case networkError(Error)

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "URLが無効です"
    case .missingAPIKey:
      return "Config.plist に API_KEY が設定されていません"
    case .missingBaseURL:
      return "Config.plist が見つからないか、API_BASE_URL が未設定です"
    case .unauthorized:
      return "API Key が正しくありません (401)"
    case .headerMissing:
      return "API Key ヘッダーが不足しています (422)"
    case .httpError(let code):
      return "サーバーエラー (HTTP \(code))"
    case .decodingError:
      return "レスポンスの解析に失敗しました"
    case .networkError(let error):
      return "通信エラー: \(error.localizedDescription)"
    }
  }
}

// MARK: - API Client

/// Handles communication with the backend API
/// Uses enum + static methods to avoid instance management
enum APIClient {

  /// Loads the contents of Config.plist as a dictionary (cached once)
  private static var configDict: [String: Any]? {
    guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path) as? [String: Any]
    else {
      return nil
    }
    return dict
  }

  /// Reads baseURL from Config.plist
  private static var baseURL: String? {
    configDict?["API_BASE_URL"] as? String
  }

  /// Reads API Key from Config.plist
  private static var apiKey: String? {
    configDict?["API_KEY"] as? String
  }

  // MARK: - Public Methods

  /// Fetches the task list (GET /api/tasks)
  static func fetchTasks() async throws -> [TaskResponse] {
    let data = try await performRequest(path: "/api/tasks", method: "GET")

    do {
      return try JSONDecoder().decode([TaskResponse].self, from: data)
    } catch {
      throw APIError.decodingError(error)
    }
  }

  /// Adds a task (POST /api/tasks)
  static func createTask(_ task: TaskCreateRequest) async throws {
    let body = try JSONEncoder().encode(task)
    _ = try await performRequest(path: "/api/tasks", method: "POST", body: body)
  }

  // MARK: - Private

  /// Common HTTP request processing
  /// Checks baseURL and apiKey every time and branches errors by response status code
  private static func performRequest(path: String, method: String, body: Data? = nil) async throws
    -> Data
  {
    guard let baseURL = baseURL else { throw APIError.missingBaseURL }
    guard let apiKey = apiKey else { throw APIError.missingAPIKey }
    guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

    if let body = body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw APIError.networkError(error)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.networkError(NSError(domain: "HTTPError", code: -1))
    }

    // Returns error based on status code
    guard (200...299).contains(httpResponse.statusCode) else {
      switch httpResponse.statusCode {
      case 401: throw APIError.unauthorized
      case 422: throw APIError.headerMissing
      default: throw APIError.httpError(httpResponse.statusCode)
      }
    }

    return data
  }
}
