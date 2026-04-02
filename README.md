# Daily Tasks (iOS)

A modern, high-performance iOS application designed to streamline task management. It integrates directly with **Notion** to fetch your to-do lists and uses **OpenAI (GPT-4o)** to generate optimized daily schedules, which are then synced with your **Apple Calendar**.

## Features

- **Direct Notion Integration**: Fetches tasks directly from your Notion database using the latest API.
- **Smart Filtering**: Automatically filters for tasks with status "Not started" or "In progress".
- **AI-Powered Scheduling**: Uses OpenAI's GPT-4o to analyze task difficulty and deadlines, creating a realistic, non-overlapping daily schedule.
- **Calendar Sync**: One-tap export of your generated schedule to the Apple Calendar app.
- **Refined UI**: Built with modern SwiftUI principles, featuring interactive status badges and smooth transitions.

## Requirements

- **Xcode 16.0+**
- **iOS 18.0+**
- **Notion Database**: A database with specific properties (see [Notion Setup](#notion-setup)).

## Setup

### 1. Configure the Project

Copy the example configuration file and fill in your API credentials:

```bash
cp Config.plist.example daily-tasks/Config.plist
```

Open `daily-tasks/Config.plist` and set the following:
- `NOTION_API_KEY`: Your Notion internal integration token.
- `NOTION_DATASORCE_ID`: The ID of your Notion database.
- `OPEN_AI_API_KEY`: Your OpenAI API key for schedule generation.

> [!WARNING]
> `daily-tasks/Config.plist` is ignored by Git to prevent accidental leaks of your secret keys.

### 2. Notion Setup

Your Notion database must include the following properties (Japanese names are supported):

| Property Name | Type | Description |
| :--- | :--- | :--- |
| `Name` | Title | The task name. |
| `ステータス` (Status) | Status | Task progress (Not started, In progress). |
| `締切` (Deadline) | Date | When the task is due. |
| `見積もり` (Estimate) | Select | Expected duration (e.g., "1h", "2h"). |
| `重要度` (Priority) | Select | Task priority level. |

### 3. Build and Run

1. Open `daily-tasks.xcodeproj` in Xcode.
2. Select your target device or simulator (iPhone 16 recommended).
3. Press `⌘ + R` to build and run.

## Architecture

This project follows the **MVVM (Model-View-ViewModel)** architectural pattern, leveraging the latest Swift concurrency (`async/await`) and state management features:

- **Models**: Clean, Codable data structures for Notion and AI responses.
- **ViewModels**: Business logic using the modern `@Observable` macro for reactive UI.
- **Services**: Modularized logic for Networking, Notion API, OpenAI, and Calendar integration.
- **Views**: Declarative SwiftUI views with a focus on performance and rich aesthetics.

---

*Form more technical details on the Notion integration, see [NOTION_FETCH_GUIDE.md](NOTION_FETCH_GUIDE.md).*
