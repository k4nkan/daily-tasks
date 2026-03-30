import EventKit
import Foundation

/// Service class to fetch events from the calendar
class CalendarService {
  static let shared = CalendarService()
  private let eventStore = EKEventStore()
  private let calendarName = "Task Management"

  private init() {}

  /// Request access permission to the calendar
  func requestAccess() async throws -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)

    switch status {
    case .authorized, .fullAccess:
      return true
    case .notDetermined:
      if #available(iOS 17.0, *) {
        // iOS 17 and later require fullAccess or writeOnly
        let granted = try await eventStore.requestFullAccessToEvents()
        return granted
      } else {
        // iOS 16 and earlier
        let granted = try await eventStore.requestAccess(to: .event)
        return granted
      }
    case .denied, .restricted, .writeOnly:
      // writeOnly is insufficient since reading is required
      return false
    @unknown default:
      return false
    }
  }

  /// Fetch calendar events for a specified period
  func fetchEvents(startDate: Date, endDate: Date) -> [EKEvent] {
    // Check if permission is granted
    guard
      EKEventStore.authorizationStatus(for: .event) == .fullAccess
        || EKEventStore.authorizationStatus(for: .event) == .authorized
    else {
      return []
    }

    let calendars = eventStore.calendars(for: .event)
    // If no calendar exists or cannot be fetched
    guard !calendars.isEmpty else { return [] }

    let predicate = eventStore.predicateForEvents(
      withStart: startDate, end: endDate, calendars: calendars)
    let events = eventStore.events(matching: predicate)

    // Sort by start date
    return events.sorted { $0.startDate < $1.startDate }
  }

  /// Add an event to the calendar
  func saveEvent(title: String, startDate: Date, endDate: Date, notes: String?) throws {
    // Check if permission is granted
    guard
      EKEventStore.authorizationStatus(for: .event) == .authorized
        || EKEventStore.authorizationStatus(for: .event) == .fullAccess
    else {
      throw NSError(
        domain: "CalendarService", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])
    }

    let targetCalendar: EKCalendar?
    do {
      targetCalendar = try findOrCreateCalendar()
    } catch {
      print(
        "⚠️ [CalendarService] Failed to find/create 'Task Management' calendar: \(error.localizedDescription). Falling back to default."
      )
      targetCalendar = eventStore.defaultCalendarForNewEvents
    }

    guard let finalCalendar = targetCalendar else {
      throw NSError(
        domain: "CalendarService", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "No writable calendar found"])
    }

    let newEvent = EKEvent(eventStore: eventStore)
    newEvent.calendar = finalCalendar
    newEvent.title = title
    newEvent.startDate = startDate
    newEvent.endDate = endDate
    newEvent.notes = notes

    try eventStore.save(newEvent, span: .thisEvent, commit: true)
  }

  /// Find or create the "Task Management" calendar
  private func findOrCreateCalendar() throws -> EKCalendar {
    let calendars = eventStore.calendars(for: .event)
    if let existing = calendars.first(where: { $0.title == calendarName }) {
      return existing
    }

    // Not found, create it
    let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
    newCalendar.title = calendarName

    // Choose a suitable source (prefer iCloud/CalDAV, then Local)
    let sources = eventStore.sources
    if let bestSource = sources.first(where: { $0.sourceType == .calDAV })
      ?? sources.first(where: { $0.sourceType == .local }) ?? sources.first
    {
      newCalendar.source = bestSource
    } else {
      throw NSError(
        domain: "CalendarService", code: 3,
        userInfo: [NSLocalizedDescriptionKey: "No suitable calendar source found"])
    }

    try eventStore.saveCalendar(newCalendar, commit: true)
    return newCalendar
  }
}
