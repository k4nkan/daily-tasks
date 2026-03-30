import SwiftUI

/// タスク一覧画面 — APIからタスクを取得してリスト表示する
struct TaskListView: View {
    @State private var viewModel = TaskListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                // 初回読み込み中
                ProgressView("読み込み中...")
            } else if let error = viewModel.errorMessage, viewModel.tasks.isEmpty {
                // エラー表示（タスクがない場合のみ全画面表示）
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
                // タスク一覧
                List(viewModel.tasks) { task in
                    TaskRowView(task: task)
                }
                .refreshable {
                    await viewModel.fetchTasks()
                }
                .overlay {
                    if viewModel.tasks.isEmpty {
                        ContentUnavailableView(
                            "タスクがありません",
                            systemImage: "tray",
                            description: Text("タスクを追加してください")
                        )
                    }
                }
            }
        }
        .navigationTitle("タスク一覧")
        .task {
            // 画面表示時に自動でデータ取得
            await viewModel.fetchTasks()
        }
    }
}

// MARK: - タスク1行分の表示

/// リストの各行の見た目を定義する子View
private struct TaskRowView: View {
    let task: TaskResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // タイトル
            Text(task.title)
                .font(.headline)

            // 締切と見積もり
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

            // 重要度とステータスのバッジ
            HStack(spacing: 8) {
                if let priority = task.priority_label {
                    BadgeView(text: priority, color: priorityColor(priority))
                }
                if let status = task.status {
                    BadgeView(text: status, color: statusColor(status))
                }
                // タスクタイプ
                ForEach(task.task_types, id: \.self) { type in
                    BadgeView(text: type, color: .gray)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 重要度に応じた色を返す
    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "高": return .red
        case "中": return .orange
        case "低": return .blue
        default: return .gray
        }
    }

    /// ステータスに応じた色を返す
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
    NavigationStack {
        TaskListView()
    }
}
