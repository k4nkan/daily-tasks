import Foundation
import Observation

/// Manages the logic for the task list screen
@Observable
class TaskListViewModel {
  // MARK: - Sort Options
  enum SortOption: String, CaseIterable {
    case deadlineAsc = "締切が近い順"
    case deadlineDesc = "締切が遠い順"
  }

  // MARK: - State Management
  var tasks: [TaskResponse] = []
  var isLoading = false
  var errorMessage: String?

  // MARK: - Display Mode
  enum DisplayMode: String, CaseIterable {
    case all = "all"
    case inProgress = "In progress"
    case notStarted = "Not started"
  }

  // Properties for sorting and filtering
  var sortOption: SortOption = .deadlineAsc  // Default is Nearest Deadline
  var displayMode: DisplayMode = .all  // Default is All

  // MARK: - Computed Properties

  /// Task list with sorting and filtering applied
  var filteredAndSortedTasks: [TaskResponse] {
    // 1. Filter
    var result = tasks

    switch displayMode {
    case .inProgress:
      result = result.filter { $0.status == "In progress" }
    case .notStarted:
      result = result.filter { $0.status == "Not started" }
    case .all:
      break
    }

    // 2. Sort
    switch sortOption {
    case .deadlineAsc:
      result.sort { (task1, task2) -> Bool in
        // Combine logical guard for nil to sort them at the back
        guard let d1 = task1.deadline else { return false }
        guard let d2 = task2.deadline else { return true }
        return d1 < d2
      }

    case .deadlineDesc:
      result.sort { (task1, task2) -> Bool in
        guard let d1 = task1.deadline else { return false }
        guard let d2 = task2.deadline else { return true }
        return d1 > d2
      }
    }

    return result
  }

  // MARK: - Public Methods

  /// Fetches the task list from the API
  func fetchTasks() async {
    isLoading = true
    errorMessage = nil

    do {
      tasks = try await NotionService.fetchTasks()
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}
