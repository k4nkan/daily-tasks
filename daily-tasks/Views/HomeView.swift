import SwiftUI

/// Main tab screen of the application
struct HomeView: View {
  // 0: Tasks, 1: Add Task, 2: Schedule
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      // 1. Task List Tab
      NavigationStack {
        TaskListView()
      }
      .tabItem {
        Label("タスク一覧", systemImage: "list.bullet")
      }
      .tag(0)

      // 2. Add Task Tab
      // Pass `$selectedTab` to return to the list tab (0) after adding
      NavigationStack {
        TaskAddView(selectedTab: $selectedTab)
      }
      .tabItem {
        Label("タスク追加", systemImage: "plus.circle")
      }
      .tag(1)

      // 3. Schedule Proposal Tab
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
