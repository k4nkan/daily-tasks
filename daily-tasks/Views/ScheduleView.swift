import SwiftUI

/// スケジュール提案画面（開発中のプレースホルダー）
struct ScheduleView: View {
  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label("スケジュール提案", systemImage: "calendar.badge.clock")
      } description: {
        Text("この機能は現在開発中です。\nAIがタスクからスケジュールを自動提案する機能が\nここに追加されます。")
      }
      .navigationTitle("スケジュール提案")
    }
  }
}

#Preview {
  ScheduleView()
}
