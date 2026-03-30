import SwiftUI

/// アプリのメインとなるタブ画面
struct HomeView: View {
  // 0: タスク一覧, 1: タスク追加, 2: スケジュール提案
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      // 1. タスク一覧タブ
      NavigationStack {
        TaskListView()
      }
      .tabItem {
        Label("タスク一覧", systemImage: "list.bullet")
      }
      .tag(0)

      // 2. タスク追加タブ
      // 追加完了時に一覧タブ(0)に戻れるよう `$selectedTab` を渡す
      NavigationStack {
        TaskAddView(selectedTab: $selectedTab)
      }
      .tabItem {
        Label("タスク追加", systemImage: "plus.circle")
      }
      .tag(1)

      // 3. スケジュール提案タブ（プレースホルダー）
      ScheduleView()
        .tabItem {
          Label("スケジュール", systemImage: "calendar.badge.clock")
        }
        .tag(2)
    }
  }
}

#Preview {
  HomeView()
}
