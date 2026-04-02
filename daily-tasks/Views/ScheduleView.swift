import EventKit
import SwiftUI

/// Schedule Proposal Screen
struct ScheduleView: View {
  @State private var viewModel = ScheduleViewModel()

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.isLoading {
          LoadingView(message: "スケジュールの生成中...")
        } else if !viewModel.hasCalendarAccess {
          ErrorView(
            title: "カレンダーアクセス不可",
            message: viewModel.errorMessage ?? "設定からカレンダーのアクセスを許可してください",
            retryAction: { Task { await viewModel.loadAndSchedule() } }
          )
        } else if let error = viewModel.errorMessage {
          ErrorView(
            title: "読み込みエラー",
            message: error,
            retryAction: { Task { await viewModel.loadAndSchedule() } }
          )
        } else {
          renderMainList()
        }
      }
      .navigationTitle("スケジュール提案")
      .toolbar(content: renderToolbarItems)
      .alert("カレンダー保存", isPresented: $viewModel.showExportAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.exportAlertMessage ?? "")
      }
      .task {
        viewModel.checkAccessStatus()
      }
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private func renderMainList() -> some View {
    List {
      Section {
        VStack(spacing: 16) {
          DatePicker(
            "対象日",
            selection: Bindable(viewModel).selectedDate,
            displayedComponents: .date
          )
          .datePickerStyle(.compact)

          Button {
            Task { await viewModel.loadAndSchedule() }
          } label: {
            HStack {
              Spacer()
              if viewModel.isLoading {
                ProgressView().padding(.trailing, 8)
              }
              Text("スケジュールを生成").fontWeight(.bold)
              Spacer()
            }
            .padding(.vertical, 8)
          }
          .buttonStyle(.borderedProminent)
          .disabled(viewModel.isLoading)
        }
        .padding(.vertical, 4)
      }

      let sortedDays = viewModel.scheduleSlots.keys.sorted()

      if sortedDays.isEmpty && !viewModel.isLoading {
        EmptyStateView(
          title: "予定がありません",
          message: "日付を選択して生成ボタンを押してください",
          systemImage: "calendar.badge.plus"
        )
      } else {
        ForEach(sortedDays, id: \.self) { day in
          Section(header: Text(day, style: .date).font(.headline)) {
            let slots = viewModel.scheduleSlots[day] ?? []
            if slots.isEmpty {
              Text("予定なし").foregroundStyle(.secondary)
            } else {
              ForEach(slots) { slot in
                ScheduleSlotRow(slot: slot)
              }
            }
          }
        }
      }
    }
    .refreshable {
      await viewModel.loadAndSchedule()
    }
  }

  @ToolbarContentBuilder
  private func renderToolbarItems() -> some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button {
        Task { await viewModel.exportToCalendar() }
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
}

// MARK: - Single Timeline Row

private struct ScheduleSlotRow: View {
  let slot: ScheduleSlot

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .trailing, spacing: 2) {
        Text(slot.startTime.formatted(date: .omitted, time: .shortened))
          .font(.subheadline)
          .fontWeight(.semibold)
        Text(slot.endTime.formatted(date: .omitted, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(width: 50, alignment: .trailing)

      Rectangle()
        .fill(lineColor.opacity(0.3))
        .frame(width: 2)

      VStack(alignment: .leading, spacing: 4) {
        switch slot.type {
        case .calendarEvent(let event):
          Text(event.title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .strikethrough()

        case .task(let task):
          Text(task.title).font(.headline)

          HStack {
            if let priority = task.priority_label {
              StatusBadge(text: priority, color: StatusColor.forPriority(priority))
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
          Text("空き時間").font(.caption).foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)

      Spacer()
    }
    .padding(.vertical, 4)
  }

  private var lineColor: Color {
    switch slot.type {
    case .calendarEvent: return .gray
    case .task(let task): return StatusColor.forPriority(task.priority_label)
    case .freeTime: return .clear
    }
  }
}

#Preview {
  ScheduleView()
}
