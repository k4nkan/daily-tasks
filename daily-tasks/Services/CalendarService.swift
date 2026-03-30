import EventKit
import Foundation

/// カレンダーから予定を取得するサービスクラス
class CalendarService {
  static let shared = CalendarService()
  private let eventStore = EKEventStore()

  private init() {}

  /// カレンダーへのアクセス権限を要求する
  func requestAccess() async throws -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)

    switch status {
    case .authorized, .fullAccess:
      return true
    case .notDetermined:
      if #available(iOS 17.0, *) {
        // iOS 17以降は fullAccess または writeOnly を要求
        let granted = try await eventStore.requestFullAccessToEvents()
        return granted
      } else {
        // iOS 16以前
        let granted = try await eventStore.requestAccess(to: .event)
        return granted
      }
    case .denied, .restricted, .writeOnly:
      // 読み込みが必要なため、writeOnlyでは不十分
      return false
    @unknown default:
      return false
    }
  }

  /// 指定した期間のカレンダーイベントを取得する
  func fetchEvents(startDate: Date, endDate: Date) -> [EKEvent] {
    // 権限があるか一度確認
    guard
      EKEventStore.authorizationStatus(for: .event) == .fullAccess
        || EKEventStore.authorizationStatus(for: .event) == .authorized
    else {
      return []
    }

    let calendars = eventStore.calendars(for: .event)
    // カレンダーがない、または取得できない場合
    guard !calendars.isEmpty else { return [] }

    let predicate = eventStore.predicateForEvents(
      withStart: startDate, end: endDate, calendars: calendars)
    let events = eventStore.events(matching: predicate)

    // 開始日時でソート
    return events.sorted { $0.startDate < $1.startDate }
  }

  /// カレンダーに予定を追加する
  func saveEvent(title: String, startDate: Date, endDate: Date, notes: String?) throws {
    // 権限があるか一度確認
    guard
      EKEventStore.authorizationStatus(for: .event) == .authorized
        || EKEventStore.authorizationStatus(for: .event) == .fullAccess
    else {
      throw NSError(
        domain: "CalendarService", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "カレンダーのアクセス権限がありません"])
    }

    let calendars = eventStore.calendars(for: .event)
    // デフォルトのカレンダー、もしくは書き込み可能なカレンダーを取得
    guard
      let defaultCalendar = eventStore.defaultCalendarForNewEvents
        ?? calendars.first(where: { $0.allowsContentModifications })
    else {
      throw NSError(
        domain: "CalendarService", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "書き込み可能なカレンダーが見つかりません"])
    }

    let newEvent = EKEvent(eventStore: eventStore)
    newEvent.calendar = defaultCalendar
    newEvent.title = title
    newEvent.startDate = startDate
    newEvent.endDate = endDate
    newEvent.notes = notes

    try eventStore.save(newEvent, span: .thisEvent, commit: true)
  }
}
