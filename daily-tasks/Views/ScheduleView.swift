import EventKit
import SwiftUI

/// スケジュール提案画面
struct ScheduleView: View {
  @State private var viewModel = ScheduleViewModel()

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.isLoading {
          ProgressView("スケジュールの生成中...")
        } else if !viewModel.hasCalendarAccess {
          ContentUnavailableView(
            "カレンダーへのアクセスが必要です",
            systemImage: "calendar.badge.exclamationmark",
            description: Text(viewModel.errorMessage ?? "設定アプリからアクセスを許可してください")
          )
          Button("再試行") {
            Task { await viewModel.loadAndSchedule() }
          }
          .buttonStyle(.bordered)
        } else if let error = viewModel.errorMessage {
          ContentUnavailableView(
            "エラーが発生しました",
            systemImage: "exclamationmark.triangle",
            description: Text(error)
          )
        } else {
          // スケジュールのタイムライン表示
          List {
            // 日付ごとにセクションを分ける (今回は1日分のみ)
            let sortedDays = viewModel.scheduleSlots.keys.sorted()
            ForEach(sortedDays, id: \.self) { day in
              Section(header: Text(day, style: .date).font(.headline)) {
                let slots = viewModel.scheduleSlots[day] ?? []
                if slots.isEmpty {
                  Text("予定なし")
                    .foregroundStyle(.secondary)
                } else {
                  ForEach(slots) { slot in
                    ScheduleSlotRow(slot: slot)
                  }
                }
              }
            }
          }
          .refreshable {
            await viewModel.loadAndSchedule()
          }
        }
      }
      .navigationTitle("スケジュール提案")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task {
              await viewModel.exportToCalendar()
            }
          } label: {
            if viewModel.isExporting {
              ProgressView()
            } else {
              Label("カレンダーに追加", systemImage: "calendar.badge.plus")
            }
          }
          .disabled(viewModel.scheduleSlots.isEmpty || viewModel.isExporting)
        }
      }
      .alert("カレンダー保存", isPresented: $viewModel.showExportAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.exportAlertMessage ?? "")
      }
      .task {
        // 画面表示時にスケジュールの生成を開始
        await viewModel.loadAndSchedule()
      }
    }
  }
}

// MARK: - タイムラインの1行分

/// スケジュールの1枠を表示するビュー
private struct ScheduleSlotRow: View {
  let slot: ScheduleSlot

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // 時間表示 (左側)
      VStack(alignment: .trailing, spacing: 2) {
        Text(slot.startTime.formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .fontWeight(.semibold)
        Text(slot.endTime.formatted(date: .omitted, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(width: 50, alignment: .trailing)

      // 縦線
      Rectangle()
        .fill(lineColor.opacity(0.3))
        .frame(width: 2)

      // コンテンツ表示 (右側)
      VStack(alignment: .leading, spacing: 4) {
        switch slot.type {
        case .calendarEvent(let event):
          Text(event.title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .strikethrough()  // カレンダーの予定は控えめに表示

        case .task(let task):
          Text(task.title)
            .font(.headline)

          HStack {
            if let priority = task.priority_label {
              BadgeView(text: priority, color: priorityColor(priority))
            }
            if let estimate = task.estimate_label {
              Label(estimate, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          if let reason = slot.reason {
            Text(reason)
              .font(.caption2)
              .italic()
              .foregroundStyle(.secondary)
              .padding(.top, 2)
          }

        case .freeTime:
          Text("空き時間")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)

      Spacer()
    }
    .padding(.vertical, 4)
  }

  // 色設定
  private var lineColor: Color {
    switch slot.type {
    case .calendarEvent: return .gray
    case .task(let task): return priorityColor(task.priority_label)
    case .freeTime: return .clear
    }
  }

  private func priorityColor(_ priority: String?) -> Color {
    switch priority {
    case "高": return .red
    case "中": return .orange
    case "低": return .blue
    default: return .gray
    }
  }
}

/// 小さなバッジ表示用の汎用View
private struct BadgeView: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption2)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.15))
      .foregroundStyle(color)
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}

#Preview {
  ScheduleView()
}
