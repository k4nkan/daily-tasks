import SwiftUI

/// Task list screen — fetches tasks and displays them
struct TaskListView: View {
  @State private var viewModel = TaskListViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.tasks.isEmpty {
        LoadingView(message: "タスクを読み込み中...")
      } else if let error = viewModel.errorMessage, viewModel.tasks.isEmpty {
        ErrorView(
          title: "読み込みエラー",
          message: error,
          retryAction: { Task { await viewModel.fetchTasks() } }
        )
      } else {
        renderTaskList()
      }
    }
    .navigationTitle("タスク一覧")
    .toolbar(content: renderToolbarItems)
    .task {
      await viewModel.fetchTasks()
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private func renderTaskList() -> some View {
    List(viewModel.filteredAndSortedTasks) { task in
      TaskRowView(task: task)
    }
    .refreshable {
      await viewModel.fetchTasks()
    }
    .overlay {
      if viewModel.filteredAndSortedTasks.isEmpty && !viewModel.isLoading {
        EmptyStateView(
          title: "該当するタスクがありません",
          message: viewModel.tasks.isEmpty ? "新しいタスクを追加してください" : "別のフィルターを試してください",
          systemImage: "tray"
        )
      }
    }
  }

  @ToolbarContentBuilder
  private func renderToolbarItems() -> some ToolbarContent {
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
}

// MARK: - Single Task Row

private struct TaskRowView: View {
  let task: TaskResponse

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(task.title)
        .font(.headline)
        .foregroundColor(.primary)

      if let summary = task.summary, !summary.isEmpty {
        Text(summary)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      HStack(spacing: 16) {
        if let deadline = task.deadline {
          Label(deadline, systemImage: "calendar")
        }
        if let estimate = task.estimate_label {
          Label(estimate, systemImage: "clock")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        if let priority = task.priority_label {
          StatusBadge(text: priority, color: StatusColor.forPriority(priority))
        }
        if let status = task.status {
          StatusBadge(text: status, color: StatusColor.forStatus(status))
        }
        ForEach(task.task_types, id: \.self) { type in
          StatusBadge(text: type, color: .gray)
        }
      }
    }
    .padding(.vertical, 8)
  }
}

#Preview {
  NavigationStack {
    TaskListView()
  }
}
