import SwiftUI

/// ホーム画面 — 各機能への導線を提供する
/// 将来的にスケジュール提案などを追加する「ハブ」として機能する
struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                // メイン機能
                Section {
                    NavigationLink {
                        TaskListView()
                    } label: {
                        Label("タスク一覧", systemImage: "list.bullet")
                    }

                    NavigationLink {
                        TaskAddView()
                    } label: {
                        Label("タスク追加", systemImage: "plus.circle")
                    }
                }

                // 将来の拡張エリア
                // スケジュール提案機能はここに NavigationLink を追加する
                Section("Coming Soon") {
                    Label("スケジュール提案", systemImage: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Daily Tasks")
        }
    }
}

#Preview {
    HomeView()
}
