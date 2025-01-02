import SwiftUI

struct StatusRowView: View {
    let label: String
    let value: String
    let isError: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.headline)
                .foregroundColor(.primary)
            Text(value)
                .font(.headline)
                .foregroundColor(isError ? .red : .green)
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
