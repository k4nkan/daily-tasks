import Foundation

/// Generic Networking error.
enum NetworkError: LocalizedError {
  case invalidURL
  case serverError(Int)
  case decodingError(Error)
  case networkError(Error)
  case unauthorized
  case forbidden

  var errorDescription: String? {
    switch self {
    case .invalidURL: return "無効なURLです"
    case .serverError(let code): return "サーバーエラー (HTTP \(code))"
    case .decodingError: return "データの解析に失敗しました"
    case .networkError(let error): return "通信エラー: \(error.localizedDescription)"
    case .unauthorized: return "認証エラー (HTTP 401)"
    case .forbidden: return "アクセス拒否 (HTTP 403)"
    }
  }
}

/// A centralized networking manager to handle general HTTP requests.
enum NetworkManager {

  /// Common configuration for JSON Decoder
  private static let jsonDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()

  /// Generic request function that performs an HTTP request and decodes the response.
  static func performRequest<T: Codable>(
    url: URL,
    method: String = "GET",
    headers: [String: String] = [:],
    body: Data? = nil,
    decodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
  ) async throws -> T {

    var request = URLRequest(url: url)
    request.httpMethod = method

    // Apply default and custom headers
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

    if let body = body {
      request.httpBody = body
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      }
    }

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw NetworkError.networkError(error)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.serverError(-1)
    }

    // Handle common HTTP status codes
    switch httpResponse.statusCode {
    case 200...299:
      break
    case 401:
      throw NetworkError.unauthorized
    case 403:
      throw NetworkError.forbidden
    default:
      throw NetworkError.serverError(httpResponse.statusCode)
    }

    // Use custom decoder to handle different key and date strategies
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = decodingStrategy

    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      print("❌ [NetworkManager] Decoding Error: \(error)")
      // If it's a raw string response or something else, handle accordingly if needed
      throw NetworkError.decodingError(error)
    }
  }

  /// Helper to perform a POST with a JSON body and direct serialization.
  static func performPost<T: Codable, B: Encodable>(
    url: URL,
    body: B,
    headers: [String: String] = [:],
    decodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
  ) async throws -> T {
    let bodyData = try JSONEncoder().encode(body)
    return try await performRequest(
      url: url, method: "POST", headers: headers, body: bodyData, decodingStrategy: decodingStrategy
    )
  }
}
