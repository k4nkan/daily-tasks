import Foundation

/// Centralized configuration management for the application.
/// Provides a single point of access for all values in Config.plist.
enum AppConfig {

  /// Loads the configuration dictionary from Config.plist.
  private static let config: [String: Any] = {
    guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path) as? [String: Any]
    else {
      print("⚠️ [AppConfig] Error: Config.plist not found or could not be loaded.")
      return [:]
    }
    return dict
  }()

  // MARK: - API Settings

  static var apiBaseURL: String {
    config["API_BASE_URL"] as? String ?? ""
  }

  static var apiKey: String {
    config["API_KEY"] as? String ?? ""
  }

  // MARK: - Notion Settings

  static var notionAPIKey: String {
    config["NOTION_API_KEY"] as? String ?? ""
  }

  static var notionDataSourceID: String {
    config["NOTION_DATA_SOURCE_ID"] as? String ?? ""
  }

  // MARK: - OpenAI Settings

  static var openAIKey: String {
    config["OPEN_AI_API_KEY"] as? String ?? ""
  }
}
