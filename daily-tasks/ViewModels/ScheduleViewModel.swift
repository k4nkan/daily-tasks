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
  let reason: String?  // Reason for AI placement

  enum SlotType {
    case calendarEvent(EKEvent)
    case task(TaskResponse)
    case freeTime
  }
}

/// Manages the logic for scheduling (integrating tasks into the calendar)
@Observable
class ScheduleViewModel {
  var scheduleSlots: [Date: [ScheduleSlot]] = [:]
  var isLoading = false
  var errorMessage: String?
  var hasCalendarAccess = false

  // For Export
  var isExporting = false
  var exportAlertMessage: String?
  var showExportAlert = false

  /// Starts requesting calendar permissions and fetching data
  func loadAndSchedule() async {
    // Only show full-screen loading if we don't have slots yet
    if scheduleSlots.isEmpty {
      isLoading = true
    }
    errorMessage = nil

    do {
      // Check calendar permissions
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

  /// Generates a realistic and dynamic schedule using the OpenAI API
  private func buildSchedule() async throws {
    // 1. Fetch tasks and existing events
    let allTasks = try await APIClient.fetchTasks()
    let pendingTasks = allTasks.filter {
      let status = $0.status?.lowercased() ?? ""
      return status == "not started" || status == "in progress"
    }

    print(
      "--- [ScheduleViewModel] Fetch count: \(allTasks.count) / Pending: \(pendingTasks.count) ---")

    let calendar = Calendar.current
    let now = Date()
    let currentHour = calendar.component(.hour, from: now)

    // If after 6 PM, schedule for tomorrow; otherwise, today
    let targetDayOffset = currentHour >= 18 ? 1 : 0
    guard let targetDayDate = calendar.date(byAdding: .day, value: targetDayOffset, to: now),
      let startOfActive = calendar.date(
        bySettingHour: activeStartHour, minute: 0, second: 0, of: targetDayDate),
      let endOfActive = calendar.date(
        bySettingHour: activeEndHour, minute: 0, second: 0, of: targetDayDate)
    else {
      return
    }

    let events = CalendarService.shared.fetchEvents(startDate: startOfActive, endDate: endOfActive)
    let dayKey = calendar.startOfDay(for: targetDayDate)

    // 2. Create prompt for OpenAI
    let prompt = constructAIPrompt(
      targetDate: targetDayDate,
      startHour: activeStartHour,
      endHour: activeEndHour,
      tasks: pendingTasks,
      existingEvents: events
    )

    // 3. call OpenAI API
    let openAIResponse = try await OpenAIService.shared.generateSchedule(prompt: prompt)

    print(
      "--- [ScheduleViewModel] AI response received: \(openAIResponse.suggested_slots.count) slots ---"
    )

    // 4. Reflect in the schedule slots
    let isoFormatter = ISO8601DateFormatter()
    // Support parsing strings without 'Z' or timezone by using natural options
    isoFormatter.formatOptions = [
      .withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime,
    ]

    var newSlots: [ScheduleSlot] = []

    // First, add existing calendar events
    for event in events {
      newSlots.append(
        ScheduleSlot(
          startTime: event.startDate, endTime: event.endDate, type: .calendarEvent(event),
          reason: nil))
    }

    // Add task schedules proposed by OpenAI
    for suggested in openAIResponse.suggested_slots {
      // Robust date parsing: if GPT misses the timezone, append '+09:00' (JST)
      let startTimeStr =
        suggested.start_time.contains("+") || suggested.start_time.contains("Z")
        ? suggested.start_time : suggested.start_time + "+09:00"
      let endTimeStr =
        suggested.end_time.contains("+") || suggested.end_time.contains("Z")
        ? suggested.end_time : suggested.end_time + "+09:00"

      guard let task = pendingTasks.first(where: { $0.id == suggested.task_id }),
        let startDate = isoFormatter.date(from: startTimeStr),
        let endDate = isoFormatter.date(from: endTimeStr)
      else {
        print("❌ [ScheduleViewModel] Failed to parse slot for Task ID: \(suggested.task_id)")
        continue
      }

      newSlots.append(
        ScheduleSlot(
          startTime: startDate, endTime: endDate, type: .task(task), reason: suggested.reason))
    }

    // Sort by start time
    newSlots.sort { $0.startTime < $1.startTime }

    print("--- [ScheduleViewModel] Total slots assigned: \(newSlots.count) ---")

    self.scheduleSlots = [dayKey: newSlots]
  }

  /// Constructs the prompt for the AI
  private func constructAIPrompt(
    targetDate: Date,
    startHour: Int,
    endHour: Int,
    tasks: [TaskResponse],
    existingEvents: [EKEvent]
  ) -> String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    let dateString = df.string(from: targetDate)

    // Prepare task list for the prompt
    let taskListString = tasks.map {
      "- ID: \($0.id), Title: \($0.title), Estimate: \($0.estimate_minutes ?? defaultEstimateMinutes)m, Priority: \($0.priority_label ?? "中"), Summary: \($0.summary ?? "")"
    }.joined(separator: "\n")

    // Prepare event list for the prompt
    let eventListString = existingEvents.map {
      "- Title: \($0.title), Start: \($0.startDate.formatted(date: .omitted, time: .shortened)), End: \($0.endDate.formatted(date: .omitted, time: .shortened))"
    }.joined(separator: "\n")

    return """
      You are a professional time management assistant.
      Please realistically schedule the user's incomplete tasks during free time on the calendar.

      # Prerequisites
      - Target Date: \(dateString)
      - Active Hours: \(startHour):00 - \(endHour):00
      - Lunch time (around 12 PM) and dinner time (around 7 PM) will not be added as events, but create a realistic plan that doesn't overcrowd those times.
      - Insert 5-15 minute breaks (buffers) before and after tasks, depending on the task's difficulty and length.
      - If the content suggests "going out" or "traveling" (based on title or summary), allow extra time for travel before and after.
      - Carefully read the task title and summary, and allocate more time for tasks that seem difficult (even if it exceeds the estimate).

      # List of Incomplete Tasks
      \(taskListString)

      # Existing Events
      \(eventListString.isEmpty ? "None" : eventListString)

      # Output Format
      Please respond only in the following JSON format.
      Crucially, provide start_time and end_time in ISO8601 format WITH timezone offset (e.g., \"\(dateString)T09:00:00+09:00\").

      {
        "suggested_slots": [
          {
            "task_id": "Task ID",
            "start_time": "Start date and time in ISO8601 format (e.g., 2024-03-31T09:00:00+09:00)",
            "end_time": "End date and time in ISO8601 format (e.g., 2024-03-31T10:00:00+09:00)",
            "reason": "Brief reason for placement at this time and considerations made"
          }
        ]
      }
      """
  }
}
