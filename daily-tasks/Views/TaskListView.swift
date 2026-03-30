import SwiftUI

/// Task list screen — fetches tasks from the API and displays them as a list
struct TaskListView: View {
  @State private var viewModel = TaskListViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.tasks.isEmpty {
        // Initial loading
        ProgressView("読み込み中...")
      } else if let error = viewModel.errorMessage, viewModel.tasks.isEmpty {
        // Error display (full-screen display only if no tasks exist)
        ContentUnavailableView {
          Label("エラー", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
          Button("再読み込み") {
            Task { await viewModel.fetchTasks() }
          }
          .buttonStyle(.bordered)
        }
      } else {
        // Task list (after sorting and filtering)
        List(viewModel.filteredAndSortedTasks) { task in
          TaskRowView(task: task)
        }
        .refreshable {
          await viewModel.fetchTasks()
        }
        .overlay {
          if viewModel.filteredAndSortedTasks.isEmpty {
            ContentUnavailableView(
              "該当するタスクがありません",
              systemImage: "tray",
              description: Text(viewModel.tasks.isEmpty ? "タスクを追加してください" : "フィルターの設定を変更してください")
            )
          }
        }
      }
    }
    .navigationTitle("タスク一覧")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Picker("ソート", selection: $viewModel.sortOption) {
            ForEach(TaskListViewModel.SortOption.allCases, id: \.self) { option in
              Text(option.rawValue).tag(option)
            }
          }

          Picker("表示状態", selection: $viewModel.displayMode) {
            ForEach(TaskListViewModel.DisplayMode.allCases, id: \.self) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
        } label: {
          Label("絞り込み", systemImage: "line.3.horizontal.decrease.circle")
        }
      }
    }
    .task {
      // Automatically fetch data when screen appears
      await viewModel.fetchTasks()
    }
  }
}

// MARK: - Single Task Row Display

/// Child view that defines the appearance of each row in the list
private struct TaskRowView: View {
  let task: TaskResponse

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // Title
      Text(task.title)
        .font(.headline)

      // Summary
      if let summary = task.summary, !summary.isEmpty {
        Text(summary)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      // Deadline and Estimate
      HStack(spacing: 12) {
        if let deadline = task.deadline {
          Label(deadline, systemImage: "calendar")
        }
        if let estimate = task.estimate_label {
          Label(estimate, systemImage: "clock")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      // Priority and Status Badges
      HStack(spacing: 8) {
        if let priority = task.priority_label {
          BadgeView(text: priority, color: priorityColor(priority))
        }
        if let status = task.status {
          BadgeView(text: status, color: statusColor(status))
        }
        // Task Type
        ForEach(task.task_types, id: \.self) { type in
          BadgeView(text: type, color: .gray)
        }
      }
    }
    .padding(.vertical, 4)
  }

  /// Returns the color based on priority
  private func priorityColor(_ priority: String) -> Color {
    switch priority {
    case "高": return .red
    case "中": return .orange
    case "低": return .blue
    default: return .gray
    }
  }

  /// Returns the color based on status
  private func statusColor(_ status: String) -> Color {
    switch status {
    case "Done": return .green
    case "In progress": return .blue
    case "Not started": return .orange
    case "stop": return .red
    default: return .gray
    }
  }
}

/// Generic view for small badge display
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
  NavigationStack {
    TaskListView()
  }
}
