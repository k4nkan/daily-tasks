import Foundation
import Observation

/// タスク追加画面のロジックを管理
@Observable
class TaskAddViewModel {
    // MARK: - フォーム入力値
    var title = ""
    var summary = ""
    var deadline = ""
    var estimateLabel = ""
    var priorityLabel = ""
    var selectedTaskTypes: Set<String> = []
    var status = "Not started"

    // MARK: - 送信状態
    var isSubmitting = false
    var errorMessage: String?
    var didSubmitSuccessfully = false

    // MARK: - 選択肢の定義（ユーザー指定の候補値）
    static let estimateOptions = ["- 0.5h", "- 1h", "- 1.5h", "- 2h", "- 3h", "- 4h", "4h -"]
    static let priorityOptions = ["高", "中", "低"]
    static let statusOptions = ["Not started", "In progress", "Done", "stop"]
    static let taskTypeOptions = ["LiT!", "有志", "大学", "カリキュラム", "友達", "楽天", "生活"]

    /// フォームの入力値を TaskCreateRequest に変換して POST する
    func submit() async {
        // バリデーション: タイトルは必須
        guard !title.isEmpty else {
            errorMessage = "タイトルを入力してください"
            return
        }

        isSubmitting = true
        errorMessage = nil

        // 空文字は nil に変換してリクエストに含めない
        let request = TaskCreateRequest(
            title: title,
            summary: summary.isEmpty ? nil : summary,
            deadline: deadline.isEmpty ? nil : deadline,
            estimate_label: estimateLabel.isEmpty ? nil : estimateLabel,
            priority_label: priorityLabel.isEmpty ? nil : priorityLabel,
            task_types: Array(selectedTaskTypes),
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
}
