import Foundation
import Observation

/// タスク一覧画面のロジックを管理
@Observable
class TaskListViewModel {
    var tasks: [TaskResponse] = []
    var isLoading = false
    var errorMessage: String?

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
