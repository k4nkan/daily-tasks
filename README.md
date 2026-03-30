# Daily Tasks

Notion のタスクDBをバックエンドAPI経由で取得・追加する iOS アプリ。

## Requirements

- Xcode 16+
- iOS 18+

## Setup

### 1. Config.plist を作成する

```bash
cp Config.plist.example daily-tasks/Config.plist
```

`daily-tasks/Config.plist` を開いて `API_BASE_URL` に実際のURLを設定してください。

> ⚠️ `daily-tasks/Config.plist` は `.gitignore` に含まれているため、Git にはコミットされません。

### 2. Xcode でビルド

```bash
open daily-tasks.xcodeproj
```

Xcode で開いてビルド・実行（⌘R）してください。

### 3. API Key を設定する

初回起動時に API Key の入力画面が表示されます。
入力した API Key は端末の Keychain に安全に保存されます。

## Architecture

```
daily-tasks/
├── Models/          # データモデル（Codable）
├── Services/        # APIClient, KeychainService
├── ViewModels/      # 画面ごとのロジック（@Observable）
└── Views/           # SwiftUI 画面
```

MVVM をベースにしたシンプルな構成です。

## API

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /api/tasks | X-API-Key | タスク一覧取得 |
| POST | /api/tasks | X-API-Key | タスク追加 |
| GET | /api/health | なし | ヘルスチェック |
