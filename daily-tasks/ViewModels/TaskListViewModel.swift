import Foundation
import Observation

/// タスク一覧画面のロジックを管理
@Observable
class TaskListViewModel {
  // MARK: - ソートオプション
  enum SortOption: String, CaseIterable {
    case original = "デフォルト"
    case deadlineAsc = "締切が近い順"
    case priorityDesc = "重要度が高い順"
  }

  // MARK: - 状態管理
  var tasks: [TaskResponse] = []
  var isLoading = false
  var errorMessage: String?

  // MARK: - 表示モード
  enum DisplayMode: String, CaseIterable {
    case active = "進行中・未着手"
    case completed = "完了"
    case stopped = "停止"
    case all = "すべて"
  }

  // ソート・フィルター用のプロパティ
  var sortOption: SortOption = .deadlineAsc  // デフォルトは締切が近い順
  var displayMode: DisplayMode = .active  // デフォルトは進行中・未着手

  /// ソートとフィルターが適用されたタスクリスト
  var filteredAndSortedTasks: [TaskResponse] {
    // 1. フィルター
    var result = tasks

    switch displayMode {
    case .active:
      // Not started と In progress のみ
      result = result.filter { $0.status == "Not started" || $0.status == "In progress" }
    case .completed:
      // Done のみ
      result = result.filter { $0.status == "Done" }
    case .stopped:
      // stop のみ
      result = result.filter { $0.status == "stop" }
    case .all:
      break
    }

    // 2. ソート
    switch sortOption {
    case .original:
      break  // APIの返却順を維持

    case .deadlineAsc:
      result.sort { (task1, task2) -> Bool in
        // 締切がnilのものは後ろへ
        guard let d1 = task1.deadline else { return false }
        guard let d2 = task2.deadline else { return true }
        return d1 < d2
      }

    case .priorityDesc:
      result.sort { (task1, task2) -> Bool in
        // "高", "中", "低" に数値を割り当てて比較
        let p1 = priorityValue(task1.priority_label)
        let p2 = priorityValue(task2.priority_label)
        return p1 > p2
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

  // MARK: - ヘルパー関数

  /// 重要度のラベルを数値に変換（ソート用）
  private func priorityValue(_ label: String?) -> Int {
    switch label {
    case "高": return 3
    case "中": return 2
    case "低": return 1
    default: return 0  // nilやその他の値は一番下へ
    }
  }
}
