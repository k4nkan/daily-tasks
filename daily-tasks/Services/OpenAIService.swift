import Foundation

/// Service responsible for communicating with the OpenAI API
class OpenAIService {
  static let shared = OpenAIService()

  // Reads API Key from Config.plist
  private var apiKey: String? {
    guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path) as? [String: Any]
    else {
      return nil
    }
    return dict["OPEN_AI_API_KEY"] as? String
  }

  private let baseURL = "https://api.openai.com/v1/chat/completions"

  /// Sends a prompt to OpenAI and fetches a structured schedule (JSON)
  func generateSchedule(prompt: String) async throws -> AIScheduleResponse {
    guard let apiKey = apiKey else {
      throw NSError(
        domain: "OpenAIService", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "OPEN_AI_API_KEY が Config.plist に設定されていません"])
    }

    guard let url = URL(string: baseURL) else {
      throw NSError(
        domain: "OpenAIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "無効なURLです"])
    }

    // Create request body
    let requestBody: [String: Any] = [
      "model": "gpt-4o",
      "messages": [
        ["role": "system", "content": "You are a professional time management assistant."],
        ["role": "user", "content": prompt],
      ],
      "response_format": ["type": "json_object"],
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse,
      !(200...299).contains(httpResponse.statusCode)
    {
      let errorBody = String(data: data, encoding: .utf8) ?? "unknown error"
      print("❌ OpenAI API Error Status: \(httpResponse.statusCode)\nBody: \(errorBody)")
      throw NSError(
        domain: "OpenAIService", code: 3,
        userInfo: [NSLocalizedDescriptionKey: "OpenAI API エラー (HTTP \(httpResponse.statusCode))"])
    }

    // Parse OpenAI response
    let decodedResponse: OpenAIResponse
    do {
      decodedResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
    } catch {
      print("❌ OpenAI Response Decoding Error: \(error)")
      if let rawString = String(data: data, encoding: .utf8) {
        print("Raw Response Body: \(rawString)")
      }
      throw error
    }

    guard let jsonString = decodedResponse.choices.first?.message.content else {
      print("❌ OpenAI returned no content.")
      throw NSError(
        domain: "OpenAIService", code: 4,
        userInfo: [NSLocalizedDescriptionKey: "OpenAI からの有効な回答が得られませんでした"])
    }

    // Convert JSON string to data
    guard let jsonData = jsonString.data(using: .utf8) else {
      print("❌ Failed to convert OpenAI text to UTF8 data: \(jsonString)")
      throw NSError(
        domain: "OpenAIService", code: 5,
        userInfo: [NSLocalizedDescriptionKey: "OpenAI の回答を解析できませんでした"])
    }

    do {
      return try JSONDecoder().decode(AIScheduleResponse.self, from: jsonData)
    } catch {
      print("❌ OpenAI Schedule JSON Decoding Error: \(error)")
      print("Attempted JSON string: \(jsonString)")
      throw error
    }
  }
}

// MARK: - Data Models for OpenAI API

struct OpenAIResponse: Codable {
  let choices: [Choice]

  struct Choice: Codable {
    let message: Message
  }

  struct Message: Codable {
    let content: String
  }
}

/// Format of the schedule returned by the AI
struct AIScheduleResponse: Codable {
  let suggested_slots: [SuggestedSlot]

  struct SuggestedSlot: Codable {
    let task_id: String
    let start_time: String  // ISO8601
    let end_time: String  // ISO8601
    let reason: String?  // Reason for placing at that time
  }
}
