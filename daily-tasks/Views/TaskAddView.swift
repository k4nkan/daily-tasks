import SwiftUI

/// タスク追加画面 — フォーム入力して POST /api/tasks に送信する
struct TaskAddView: View {
  /// 完了後にタブを「タスク一覧(0)」に戻すための Binding
  @Binding var selectedTab: Int
  @State private var viewModel = TaskAddViewModel()

  var body: some View {
    Form {
      // 基本情報セクション
      Section("基本情報") {
        TextField("タイトル（必須）", text: $viewModel.title)
        TextField("概要", text: $viewModel.summary)
      }

      // 締切設定（カレンダー）
      Section("締切") {
        Toggle("締切日を設定する", isOn: $viewModel.hasDeadline)

        if viewModel.hasDeadline {
          DatePicker("締切日を選択", selection: $viewModel.deadlineDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
        }
      }

      // 見積もり
      Section("見積もり") {
        Picker("見積もり時間", selection: $viewModel.estimateLabel) {
          Text("未選択").tag("")
          ForEach(TaskAddViewModel.estimateOptions, id: \.self) { option in
            Text(option).tag(option)
          }
        }
      }

      // 重要度
      Section("重要度") {
        Picker("重要度", selection: $viewModel.priorityLabel) {
          Text("未選択").tag("")
          ForEach(TaskAddViewModel.priorityOptions, id: \.self) { option in
            Text(option).tag(option)
          }
        }
      }

      // ステータス
      Section("ステータス") {
        Picker("ステータス", selection: $viewModel.status) {
          ForEach(TaskAddViewModel.statusOptions, id: \.self) { option in
            Text(option).tag(option)
          }
        }
      }

      // エラーメッセージ
      if let error = viewModel.errorMessage {
        Section {
          Text(error)
            .foregroundStyle(.red)
        }
      }

      // 送信ボタン
      Section {
        Button {
          Task {
            await viewModel.submit()
            // 成功したらフォームをリセットし、タスク一覧タブに戻る
            if viewModel.didSubmitSuccessfully {
              viewModel.resetForm()
              selectedTab = 0
            }
          }
        } label: {
          HStack {
            Spacer()
            if viewModel.isSubmitting {
              ProgressView()
            } else {
              Text("タスクを追加")
            }
            Spacer()
          }
        }
        .disabled(viewModel.title.isEmpty || viewModel.isSubmitting)
      }
    }
    .navigationTitle("タスク追加")
  }
}

#Preview {
  NavigationStack {
    TaskAddView(selectedTab: .constant(1))
  }
}
