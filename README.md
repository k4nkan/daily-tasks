# Daily Tasks

An iOS application that manages Notion tasks via a backend API, featuring AI-powered scheduling and calendar integration.

## Features

- **Task Management**: Fetch and add tasks to your Notion database through a secure API.
- **AI Scheduling**: Automatically generate an optimized daily schedule using OpenAI's GPT-4o, considering task difficulty and existing calendar events.
- **Calendar Integration**: Seamlessly sync your tasks with the Apple Calendar app.
- **Smart Filtering & Sorting**: Filter tasks by status and sort them by deadline to stay on top of your work.

## Requirements

- Xcode 16.0+
- iOS 18.0+

## Setup

### 1. Create Config.plist

Copy the example configuration file and fill in your details:

```bash
cp Config.plist.example daily-tasks/Config.plist
```

Open `daily-tasks/Config.plist` and set the following:
- `API_BASE_URL`: The URL of your backend API.
- `API_KEY`: Your backend API key.
- `OPEN_AI_API_KEY`: Your OpenAI API key for scheduling features.

> ⚠️ `daily-tasks/Config.plist` is ignored by Git to keep your secrets safe.

### 2. Build in Xcode

```bash
open daily-tasks.xcodeproj
```

Open the project in Xcode and press `⌘R` to build and run.

## Architecture

The project follows the **MVVM (Model-View-ViewModel)** pattern using the latest SwiftUI and Swift features:

```
daily-tasks/
├── Models/          # Codable data models
├── Services/        # Logic for API, OpenAI, and Calendar integration
├── ViewModels/      # Business logic and state management using @Observable
└── Views/           # Declarative SwiftUI views
```

## API Endpoints

The app communicates with the following endpoints:

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /api/tasks | X-API-Key | Fetch all tasks |
| POST | /api/tasks | X-API-Key | Add a new task |
| GET | /api/health | None | API health check |
