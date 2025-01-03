import SwiftUI

struct TimeRemainingView: View {
    @ObservedObject var tokenManager: TokenManager
    
    var body: some View {
        HStack {
            Text("Time Remaining:")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(tokenManager.countdownDisplay)
                .font(.headline)
                .foregroundColor(tokenManager.remainingTimeColor)
        }
        .padding(.vertical)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .shadow(radius: 2)
        )
        .frame(maxWidth: .infinity)
    }
}
