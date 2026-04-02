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
  var selectedDate: Date = Calendar.current.startOfDay(for: Date())

  // For Export
  var isExporting = false
  var exportAlertMessage: String?
  var showExportAlert = false

  /// Starts requesting calendar permissions and fetching data
  func loadAndSchedule() async {
    // Only show full-screen loading if we don't have slots yet
    isLoading = true
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

  /// Checks the current calendar permission status without prompting the user
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

  /// Generates a realistic and dynamic schedule using the OpenAI API
  private func buildSchedule() async throws {
    // 1. Fetch tasks and existing events
    let allTasks = try await NotionService.fetchTasks()
    let pendingTasks = allTasks.filter {
      let status = $0.status?.lowercased() ?? ""
      return status == "not started" || status == "in progress"
    }

    print(
      "--- [ScheduleViewModel] Fetch count: \(allTasks.count) / Pending: \(pendingTasks.count) ---")

    let calendar = Calendar.current
    let now = Date()

    // Base start/end of day logic on selectedDate
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

    // 2. Create prompt for OpenAI
    let prompt = constructAIPrompt(
      targetDate: selectedDate,
      currentTime: now,
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
    currentTime: Date,
    startHour: Int,
    endHour: Int,
    tasks: [TaskResponse],
    existingEvents: [EKEvent]
  ) -> String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    let dateString = df.string(from: targetDate)

    let tf = DateFormatter()
    tf.dateFormat = "HH:mm"
    let currentTimeString = tf.string(from: currentTime)

    // Prepare task list for the prompt
    let taskListString = tasks.map {
      "- ID: \($0.id), Title: \($0.title), Estimate: \($0.estimate_minutes ?? defaultEstimateMinutes)m, Priority: \($0.priority_label ?? "中"), Deadline: \($0.deadline ?? "None"), Summary: \($0.summary ?? "")"
    }.joined(separator: "\n")

    // Prepare event list for the prompt
    let eventListString = existingEvents.map {
      "- Title: \($0.title), Start: \($0.startDate.formatted(date: .omitted, time: .shortened)), End: \($0.endDate.formatted(date: .omitted, time: .shortened))"
    }.joined(separator: "\n")

    return """
      You are a professional time management assistant.
      Please realistically schedule the user's incomplete tasks during free time on the calendar with a focus on QUALITY and SUSTAINABILITY.

      # STRICT ZERO OVERLAP POLICY
      - ABSOLUTELY NO OVERLAPS are allowed.
      - Each suggested_slot must have a distinct start and end time.
      - A suggested_slot must never overlap with another suggested_slot.
      - A suggested_slot must never overlap with a FIXED_NON_NEGOTIABLE_EVENTS.
      - Any plan with an overlap is a FAILURE.

      # Flexible Scheduling Rules
      - **Partial Progress**: You do NOT have to schedule the full "Estimate" for a task in one sitting. If a task is estimated at 60m but only 30m fits, you can schedule a 30m "chunk" of work.
      - **Selective Scheduling**: You do NOT have to schedule every task listed. Only include tasks that fit realistically without overcrowding.
      - **Buffers**: Ensure a minimum 5-10 minute buffer between any two consecutive items (tasks or events).

      # Prerequisites
      - Current Time: \(currentTimeString)
      - Target Date: \(dateString)
      - Active Hours: \(startHour):00 - \(endHour):00
      - STRICTION: If the Target Date is today, do NOT schedule tasks before the Current Time (\(currentTimeString)).
      - Lunch time (around 12 PM) and dinner time (around 7 PM) will not be added as events, but create a realistic plan that doesn't overcrowd those times.
      - If the content suggests "going out" or "traveling" (based on title or summary), allow extra time for travel before and after.
      - Carefully read the task title and summary to understand context and difficulty.

      # List of Incomplete Tasks
      \(taskListString)

      # FIXED_NON_NEGOTIABLE_EVENTS (Current Calendar Status)
      \(eventListString.isEmpty ? "No events scheduled." : eventListString)

      # Task Triaging & Prioritization Rules
      1. **Actionability Check**: Analyze each task's "Summary". If a task's summary indicates it is not yet actionable (e.g., "Wait for X", "Pending Y", or clear prerequisites not met), do NOT schedule it today.
      2. **Triaging Strategy**: Comprehensively evaluate "Priority", "Deadline", and "Summary".
         - High Priority + Near Deadline: Schedule early or in a prime slot.
         - Preparation tasks: Schedule before the related FIXED_NON_NEGOTIABLE_EVENTS.
         - Complex tasks: Schedule when there is a larger free time block.
      3. **Selective Scheduling**: Focus on producing a high-quality, achievable schedule rather than forcing every task into one day.

      # Context-Aware Scheduling Instructions
      1. Analyze the "Summary" of each task for dependencies or logical connections with FIXED_NON_NEGOTIABLE_EVENTS.
      2. If a task mentions "preparation," "meeting," or "follow-up," schedule it relative to the corresponding calendar event (e.g., preparation tasks should happen BEFORE the meeting).
      3. Identify the free time "gaps" between the FIXED_NON_NEGOTIABLE_EVENTS and the Active Hours boundaries.
      4. Strictly place tasks ONLY within those gaps.
      5. Verify that NO suggested_slot overlaps with any FIXED_NON_NEGOTIABLE_EVENTS or another suggested_slot.

      # Output Format
      Please respond only in the following JSON format.
      Crucially, provide start_time and end_time in ISO8601 format WITH timezone offset (e.g., \"\(dateString)T09:00:00+09:00\").

      {
        "suggested_slots": [
          {
            "task_id": "Task ID",
            "start_time": "Start date and time in ISO8601 format (e.g., 2024-03-31T09:00:00+09:00)",
            "end_time": "End date and time in ISO8601 format (e.g., 2024-03-31T10:00:00+09:00)",
            "reason": "Brief Japanese reason for placement at this time and considerations made"
          }
        ]
      }
      """
  }
}
