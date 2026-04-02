import Foundation

/// Service responsible for communicating with the OpenAI API
class OpenAIService {
  static let shared = OpenAIService()

  private let baseURL = "https://api.openai.com/v1/chat/completions"

  /// Sends a prompt to OpenAI and fetches a structured schedule (JSON)
  func generateSchedule(prompt: String) async throws -> AIScheduleResponse {
    let apiKey = AppConfig.openAIKey
    guard !apiKey.isEmpty else {
      throw NetworkError.unauthorized
    }

    guard let url = URL(string: baseURL) else {
      throw NetworkError.invalidURL
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

    let headers = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(apiKey)",
    ]

    let bodyData: Data
    do {
      bodyData = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      throw NetworkError.decodingError(error)
    }

    // 1. Fetch response from OpenAI
    let openAIResponse: OpenAIResponse = try await NetworkManager.performRequest(
      url: url,
      method: "POST",
      headers: headers,
      body: bodyData
    )

    // 2. Extract nested JSON content
    guard let jsonString = openAIResponse.choices.first?.message.content,
      let jsonData = jsonString.data(using: .utf8)
    else {
      throw NetworkError.decodingError(
        NSError(
          domain: "OpenAIService", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "OpenAI returned empty content"]))
    }

    // 3. Decode the actual schedule
    do {
      return try JSONDecoder().decode(AIScheduleResponse.self, from: jsonData)
    } catch {
      print("❌ [OpenAIService] Schedule Decoding Error: \(error)")
      throw NetworkError.decodingError(error)
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
