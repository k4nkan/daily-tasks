import EventKit
import Foundation
import Observation

// MARK: - 定数設定
private let activeStartHour = 9
private let activeEndHour = 22
private let defaultEstimateMinutes = 60

// MARK: - タイムスロットモデル
struct ScheduleSlot: Identifiable {
  let id = UUID()
  let startTime: Date
  let endTime: Date
  let type: SlotType
  let reason: String?  // AIによる配置理由

  enum SlotType {
    case calendarEvent(EKEvent)
    case task(TaskResponse)
    case freeTime
  }
}

/// スケジュール（タスクの予定組み込み）のロジックを管理
@Observable
class ScheduleViewModel {
  var scheduleSlots: [Date: [ScheduleSlot]] = [:]
  var isLoading = false
  var errorMessage: String?
  var hasCalendarAccess = false

  // エクスポート用
  var isExporting = false
  var exportAlertMessage: String?
  var showExportAlert = false

  /// カレンダー権限の要求およびデータの取得を開始
  func loadAndSchedule() async {
    isLoading = true
    errorMessage = nil

    do {
      // カレンダー権限の確認
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

  /// カレンダーに予定を一括で書き込む
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

  /// OpenAI API を用いて、現実的で動的なスケジュールを生成する
  private func buildSchedule() async throws {
    // 1. タスクと既存予定の取得
    let allTasks = try await APIClient.fetchTasks()
    let pendingTasks = allTasks.filter { $0.status == "Not started" || $0.status == "In progress" }

    let calendar = Calendar.current
    let now = Date()
    let currentHour = calendar.component(.hour, from: now)

    // 夜18時以降なら翌日、それ以外は今日
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

    // 2. OpenAI へのプロンプト作成
    let prompt = constructAIPrompt(
      targetDate: targetDayDate,
      startHour: activeStartHour,
      endHour: activeEndHour,
      tasks: pendingTasks,
      existingEvents: events
    )

    // 3. OpenAI API 呼び出し
    let openAIResponse = try await OpenAIService.shared.generateSchedule(prompt: prompt)

    // 4. スケジュール枠への反映
    let isoFormatter = ISO8601DateFormatter()
    var newSlots: [ScheduleSlot] = []

    // まず既存のカレンダー予定を追加
    for event in events {
      newSlots.append(
        ScheduleSlot(
          startTime: event.startDate, endTime: event.endDate, type: .calendarEvent(event),
          reason: nil))
    }

    // OpenAI が提案したタスク予定を追加
    for suggested in openAIResponse.suggested_slots {
      guard let task = pendingTasks.first(where: { $0.id == suggested.task_id }),
        let startDate = isoFormatter.date(from: suggested.start_time),
        let endDate = isoFormatter.date(from: suggested.end_time)
      else {
        continue
      }

      newSlots.append(
        ScheduleSlot(
          startTime: startDate, endTime: endDate, type: .task(task), reason: suggested.reason))
    }

    // 開始時間順にソート
    newSlots.sort { $0.startTime < $1.startTime }

    self.scheduleSlots = [dayKey: newSlots]
  }

  /// AI 用のプロンプトを構築する
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

    let taskListString = tasks.map {
      "- ID: \($0.id), Title: \($0.title), Estimate: \($0.estimate_minutes ?? defaultEstimateMinutes)m, Priority: \($0.priority_label ?? "中"), Summary: \($0.summary ?? "")"
    }.joined(separator: "\n")

    let eventListString = existingEvents.map {
      "- Title: \($0.title), Start: \($0.startDate.formatted(date: .omitted, time: .shortened)), End: \($0.endDate.formatted(date: .omitted, time: .shortened))"
    }.joined(separator: "\n")

    return """
      あなたは優秀なタイムマネジメント・アシスタントです。
      ユーザーの未完了タスクを、カレンダーの空き時間に現実的に配置してください。

      # 前提条件
      - 対象日: \(dateString)
      - 活動時間制限: \(startHour):00 〜 \(endHour):00
      - 昼食（12時頃）や夕食（19時頃）の時間は、予定として追加はしませんが、その時間にタスクを詰めすぎない現実的な計画にしてください。
      - タスクの前後には 5〜15分の休憩（バッファ）を、タスクの難易度や長さに応じて挿入してください。
      - 「外出」「移動」が想定される内容（タイトルや概要から判断）の場合、前後に移動時間を考慮した余裕を持たせてください。
      - タスクのタイトルや概要（Summary）を詳しく読み取り、難易度が高そうなものは時間を長めに（見積もり以上でも可）確保してください。

      # 未完了タスク一覧
      \(taskListString)

      # 既に決まっている予定
      \(eventListString.isEmpty ? "なし" : eventListString)

      # 出力フォーマット
      以下のJSON形式のみで回答してください。
      {
        "suggested_slots": [
          {
            "task_id": "タスクのID",
            "start_time": "ISO8601形式の開始日時",
            "end_time": "ISO8601形式の終了日時",
            "reason": "なぜこの時間に配置したか、どう考慮したかの簡潔な理由"
          }
        ]
      }
      """
  }
}
