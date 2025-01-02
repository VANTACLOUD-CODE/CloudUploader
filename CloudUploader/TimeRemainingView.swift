import SwiftUI

struct TimeRemainingView: View {
    let label: String
    let value: String
    
    var timeColor: Color {
        if value.contains("expired") {
            return .red
        } else if value.contains("< 1 hour") {
            return .orange
        }
        return .green
    }
    
    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.headline)
                .foregroundColor(.primary)
            Text(value)
                .font(.headline)
                .foregroundColor(timeColor)
        }
        .padding(.vertical)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .shadow(radius: 2)
        )
    }
}
