import SwiftUI

/// Reusable badge view for priority and status
struct StatusBadge: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption2)
      .fontWeight(.medium)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.12))
      .foregroundStyle(color)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

/// Helper to get consistent priority/status colors
enum StatusColor {
  static func forPriority(_ priority: String?) -> Color {
    switch priority {
    case "高": return .red
    case "中": return .orange
    case "低": return .blue
    default: return .gray
    }
  }

  static func forStatus(_ status: String?) -> Color {
    switch status {
    case "Done": return .green
    case "In progress": return .blue
    case "Not started": return .orange
    case "stop": return .red
    default: return .gray
    }
  }
}

#Preview {
  VStack {
    HStack {
      StatusBadge(text: "高", color: StatusColor.forPriority("高"))
      StatusBadge(text: "中", color: StatusColor.forPriority("中"))
      StatusBadge(text: "低", color: StatusColor.forPriority("低"))
    }
    HStack {
      StatusBadge(text: "Done", color: StatusColor.forStatus("Done"))
      StatusBadge(text: "In progress", color: StatusColor.forStatus("In progress"))
      StatusBadge(text: "Not started", color: StatusColor.forStatus("Not started"))
    }
  }
}
