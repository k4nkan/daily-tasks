import EventKit
import Foundation
import Observation

// MARK: - Constants
private let activeStartHour = 9
private let activeEndHour = 22
private let defaultEstimateMinutes = 60

// MARK: - Time Slot Model
struct ScheduleSlot: Identifiable {
  let id = UUID()
  let startTime: Date
  let endTime: Date
  let type: SlotType
  let reason: String?

  enum SlotType {
    case calendarEvent(EKEvent)
    case task(TaskResponse)
    case freeTime
  }
}

/// Manages the logic for scheduling (integrating tasks into the calendar)
@Observable
class ScheduleViewModel {
  // MARK: - State
  var scheduleSlots: [Date: [ScheduleSlot]] = [:]
  var isLoading = false
  var errorMessage: String?
  var hasCalendarAccess = false
  var selectedDate: Date = Calendar.current.startOfDay(for: Date())

  // MARK: - Export State
  var isExporting = false
  var exportAlertMessage: String?
  var showExportAlert = false

  // MARK: - Formatters
  private let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime,
    ]
    return formatter
  }()

  // MARK: - Public Methods

  /// Starts requesting calendar permissions and fetching data
  func loadAndSchedule() async {
    isLoading = true
    errorMessage = nil

    do {
      hasCalendarAccess = try await CalendarService.shared.requestAccess()
      if hasCalendarAccess {
        try await buildSchedule()
      } else {
        errorMessage = "カレンダーのアクセス権限が必要です。設定から許可してください。"
      }
    } catch {
      errorMessage = "スケジュールの読み込みに失敗しました: \(error.localizedDescription)"
    }

    isLoading = false
  }

  /// Checks the current calendar permission status without prompting
  func checkAccessStatus() {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      hasCalendarAccess = status == .fullAccess || status == .authorized
    } else {
      hasCalendarAccess = status == .authorized
    }
  }

  /// Batch writes events to the calendar
  func exportToCalendar() async {
    isExporting = true
    var successCount = 0
    var errorCount = 0

    for (_, slots) in scheduleSlots {
      for slot in slots {
        if case .task(let task) = slot.type {
          do {
            try CalendarService.shared.saveEvent(
              title: task.title,
              startDate: slot.startTime,
              endDate: slot.endTime,
              notes: task.summary
            )
            successCount += 1
          } catch {
            errorCount += 1
          }
        }
      }
    }

    isExporting = false
    if errorCount > 0 {
      exportAlertMessage = "\(successCount)件保存しましたが、\(errorCount)件のエラーが発生しました。"
    } else {
      exportAlertMessage = "\(successCount)件のタスクをカレンダーに保存しました"
    }
    showExportAlert = true
  }

  // MARK: - Private Methods

  /// Generates a realistic and dynamic schedule using the OpenAI API
  private func buildSchedule() async throws {
    // 1. Fetch tasks and events
    let allTasks = try await NotionService.fetchTasks()
    let pendingTasks = allTasks.filter {
      let status = $0.status?.lowercased() ?? ""
      return status == "not started" || status == "in progress"
    }

    let calendar = Calendar.current
    let now = Date()

    guard
      let startOfActive = calendar.date(
        bySettingHour: activeStartHour, minute: 0, second: 0, of: selectedDate),
      let endOfActive = calendar.date(
        bySettingHour: activeEndHour, minute: 0, second: 0, of: selectedDate)
    else {
      return
    }

    let events = CalendarService.shared.fetchEvents(startDate: startOfActive, endDate: endOfActive)
    let dayKey = calendar.startOfDay(for: selectedDate)

    // 2. Call OpenAI API
    let prompt = constructAIPrompt(
      targetDate: selectedDate,
      currentTime: now,
      tasks: pendingTasks,
      existingEvents: events
    )
    let openAIResponse = try await OpenAIService.shared.generateSchedule(prompt: prompt)

    // 3. Process AI Response
    var newSlots: [ScheduleSlot] = []

    // Add calendar events
    for event in events {
      newSlots.append(
        ScheduleSlot(
          startTime: event.startDate, endTime: event.endDate, type: .calendarEvent(event),
          reason: nil))
    }

    // Add suggested tasks
    for suggested in openAIResponse.suggested_slots {
      // Robust parsing: GPT sometimes misses timezone, so we append JST if missing
      let startTimeStr =
        suggested.start_time.hasSuffix("Z") || suggested.start_time.contains("+")
        ? suggested.start_time : suggested.start_time + "+09:00"
      let endTimeStr =
        suggested.end_time.hasSuffix("Z") || suggested.end_time.contains("+")
        ? suggested.end_time : suggested.end_time + "+09:00"

      if let task = pendingTasks.first(where: { $0.id == suggested.task_id }),
        let startDate = isoFormatter.date(from: startTimeStr),
        let endDate = isoFormatter.date(from: endTimeStr)
      {
        newSlots.append(
          ScheduleSlot(
            startTime: startDate, endTime: endDate, type: .task(task), reason: suggested.reason))
      }
    }

    newSlots.sort { $0.startTime < $1.startTime }
    self.scheduleSlots = [dayKey: newSlots]
  }

  private func constructAIPrompt(
    targetDate: Date, currentTime: Date, tasks: [TaskResponse], existingEvents: [EKEvent]
  ) -> String {
    let dateString = formatDate(targetDate, format: "yyyy-MM-dd")
    let currentTimeString = formatDate(currentTime, format: "HH:mm")

    let taskListString = tasks.map {
      "- ID: \($0.id), Title: \($0.title), Estimate: \($0.estimate_minutes ?? defaultEstimateMinutes)m, Priority: \($0.priority_label ?? "中"), Deadline: \($0.deadline ?? "None"), Summary: \($0.summary ?? "")"
    }.joined(separator: "\n")

    let eventListString = existingEvents.map {
      "- Title: \($0.title), Start: \(formatTime($0.startDate)), End: \(formatTime($0.endDate))"
    }.joined(separator: "\n")

    return """
      You are a professional time management assistant.
      Please realistically schedule the user's incomplete tasks during free time on the calendar with a focus on QUALITY and SUSTAINABILITY.

      # RULES
      - NO OVERLAPS allowed.
      - 5-10 minute buffer between items.
      - You can schedule partial tasks (chunks).
      - Lunch (~12PM) and Dinner (~7PM) should be respected.

      # CONTEXT
      - Current Time: \(currentTimeString)
      - Target Date: \(dateString)
      - Active Hours: \(activeStartHour):00 - \(activeEndHour):00
      - STRICTION: If the Target Date is today, do NOT schedule tasks before \(currentTimeString).

      # INCOMPLETE TASKS
      \(taskListString)

      # CALENDAR STATUS
      \(eventListString.isEmpty ? "No events scheduled." : eventListString)

      # OUTPUT FORMAT (JSON only)
      {
        "suggested_slots": [
          {
            "task_id": "Task ID",
            "start_time": "ISO8601 (e.g., \(dateString)T09:00:00+09:00)",
            "end_time": "ISO8601",
            "reason": "Brief Japanese reason"
          }
        ]
      }
      """
  }

  // MARK: - Helpers

  private func formatDate(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
