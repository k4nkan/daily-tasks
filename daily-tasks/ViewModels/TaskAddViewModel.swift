import Foundation
import Observation

/// Manages the logic for the task addition screen
@Observable
class TaskAddViewModel {
  // MARK: - Form Input Values
  var title = ""
  var summary = ""
  var hasDeadline = false
  var deadlineDate = Date()
  var estimateLabel = ""
  var priorityLabel = ""
  var status = "Not started"

  // MARK: - Submission State
  var isSubmitting = false
  var errorMessage: String?
  var didSubmitSuccessfully = false

  // MARK: - Options
  static let estimateOptions = ["- 0.5h", "- 1h", "- 1.5h", "- 2h", "- 3h", "- 4h", "4h -"]
  static let priorityOptions = ["高", "中", "低"]

  /// Resets the form to its initial state
  func resetForm() {
    title = ""
    summary = ""
    hasDeadline = false
    deadlineDate = Date()
    estimateLabel = ""
    priorityLabel = ""
    status = "Not started"
    isSubmitting = false
    errorMessage = nil
    didSubmitSuccessfully = false
  }

  /// Converts form input to TaskCreateRequest and POSTs it
  func submit() async {
    guard !title.isEmpty else {
      errorMessage = "タイトルを入力してください"
      return
    }

    isSubmitting = true
    errorMessage = nil
    didSubmitSuccessfully = false

    let formattedDeadline: String? = hasDeadline ? formatDate(deadlineDate) : nil

    let request = TaskCreateRequest(
      title: title,
      summary: summary.isEmpty ? nil : summary,
      deadline: formattedDeadline,
      estimate_label: estimateLabel.isEmpty ? nil : estimateLabel,
      priority_label: priorityLabel.isEmpty ? nil : priorityLabel,
      task_types: [],
      status: status
    )

    do {
      try await APIClient.createTask(request)
      didSubmitSuccessfully = true
    } catch {
      errorMessage = error.localizedDescription
    }

    isSubmitting = false
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter.string(from: date)
  }
}
