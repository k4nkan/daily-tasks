import SwiftUI

/// Task addition screen — form input to send POST /api/tasks
struct TaskAddView: View {
  /// Binding to return to the "Tasks (0)" tab after completion
  @Binding var selectedTab: Int
  @State private var viewModel = TaskAddViewModel()

  var body: some View {
    Form {
      // Basic Info Section
      Section("基本情報") {
        TextField("タイトル（必須）", text: $viewModel.title)
        TextField("概要", text: $viewModel.summary)
      }

      // Deadline Setting (Calendar)
      Section("締切") {
        Toggle("締切日を設定する", isOn: $viewModel.hasDeadline)

        if viewModel.hasDeadline {
          DatePicker("締切日を選択", selection: $viewModel.deadlineDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
        }
      }

      // Estimate
      Section("見積もり") {
        Picker("見積もり時間", selection: $viewModel.estimateLabel) {
          Text("未選択").tag("")
          ForEach(TaskAddViewModel.estimateOptions, id: \.self) { option in
            Text(option).tag(option)
          }
        }
      }

      // Priority
      Section("重要度") {
        Picker("重要度", selection: $viewModel.priorityLabel) {
          Text("未選択").tag("")
          ForEach(TaskAddViewModel.priorityOptions, id: \.self) { option in
            Text(option).tag(option)
          }
        }
      }

      // Submit Button
      if let error = viewModel.errorMessage {
        Section {
          Text(error)
            .foregroundStyle(.red)
        }
      }

      // Submit Button
      Section {
        Button {
          Task {
            await viewModel.submit()
            // Reset form and return to the task list tab on success
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
