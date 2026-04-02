import SwiftUI

/// Standard full-screen loading view
struct LoadingView: View {
  let message: String

  var body: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.2)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Standard error display view
struct ErrorView: View {
  let title: String
  let message: String
  let retryAction: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "exclamationmark.triangle")
    } description: {
      Text(message)
    } actions: {
      Button("再試行") {
        retryAction()
      }
      .buttonStyle(.bordered)
    }
  }
}

/// Standard empty state view
struct EmptyStateView: View {
  let title: String
  let message: String
  let systemImage: String

  var body: some View {
    ContentUnavailableView(
      title,
      systemImage: systemImage,
      description: Text(message)
    )
  }
}
