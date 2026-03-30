import Foundation

// MARK: - APIエラー定義

enum APIError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case missingBaseURL
    case unauthorized          // 401: APIキーが間違っている
    case headerMissing         // 422: APIキーヘッダーがない
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

// MARK: - APIクライアント

/// バックエンドAPIとの通信を担当
/// enum + static methods で、インスタンス管理を不要にしている
enum APIClient {

    /// Config.plist の内容を辞書として読み込む（キャッシュ的に一度だけ）
    private static var configDict: [String: Any]? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict
    }

    /// Config.plist から baseURL を読み取る
    private static var baseURL: String? {
        configDict?["API_BASE_URL"] as? String
    }

    /// Config.plist から API Key を読み取る
    private static var apiKey: String? {
        configDict?["API_KEY"] as? String
    }

    // MARK: - Public Methods

    /// タスク一覧を取得する（GET /api/tasks）
    static func fetchTasks() async throws -> [TaskResponse] {
        let data = try await performRequest(path: "/api/tasks", method: "GET")

        do {
            return try JSONDecoder().decode([TaskResponse].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// タスクを追加する（POST /api/tasks）
    static func createTask(_ task: TaskCreateRequest) async throws {
        let body = try JSONEncoder().encode(task)
        _ = try await performRequest(path: "/api/tasks", method: "POST", body: body)
    }

    // MARK: - Private

    /// 共通のHTTPリクエスト処理
    /// baseURL と apiKey を毎回チェックし、レスポンスのステータスコードでエラーを分岐する
    private static func performRequest(path: String, method: String, body: Data? = nil) async throws -> Data {
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

        // ステータスコードに応じてエラーを返す
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
