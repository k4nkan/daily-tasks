import Foundation
import Observation

/// タスク一覧画面のロジックを管理
@Observable
class TaskListViewModel {
  // MARK: - ソートオプション
  enum SortOption: String, CaseIterable {
    case deadlineAsc = "締切が近い順"
    case deadlineDesc = "締切が遠い順"
  }

  // MARK: - 状態管理
  var tasks: [TaskResponse] = []
  var isLoading = false
  var errorMessage: String?

  // MARK: - 表示モード
  enum DisplayMode: String, CaseIterable {
    case all = "all"
    case inProgress = "In progress"
    case notStarted = "Not started"
  }

  // ソート・フィルター用のプロパティ
  var sortOption: SortOption = .deadlineAsc  // デフォルトは締切が近い順
  var displayMode: DisplayMode = .all  // デフォルトはすべて

  /// ソートとフィルターが適用されたタスクリスト
  var filteredAndSortedTasks: [TaskResponse] {
    // 1. フィルター
    var result = tasks

    switch displayMode {
    case .inProgress:
      result = result.filter { $0.status == "In progress" }
    case .notStarted:
      result = result.filter { $0.status == "Not started" }
    case .all:
      break
    }

    // 2. ソート
    switch sortOption {
    case .deadlineAsc:
      result.sort { (task1, task2) -> Bool in
        // 締切がnilのものは後ろへ
        guard let d1 = task1.deadline else { return false }
        guard let d2 = task2.deadline else { return true }
        return d1 < d2
      }

    case .deadlineDesc:
      result.sort { (task1, task2) -> Bool in
        // 締切がnilのものは後ろへ
        guard let d1 = task1.deadline else { return false }
        guard let d2 = task2.deadline else { return true }
        return d1 > d2
      }
    }

    return result
  }

  /// APIからタスク一覧を取得する
  func fetchTasks() async {
    isLoading = true
    errorMessage = nil

    do {
      tasks = try await APIClient.fetchTasks()
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}
