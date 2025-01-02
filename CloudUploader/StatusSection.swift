import SwiftUI

struct StatusSection: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    
    var body: some View {
        VStack {
            Text("⚙️ System Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
            
            HStack(spacing: 20) {
                HStack {
                    Text("API Status:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.apiStatus)
                        .font(.headline)
                        .foregroundColor(viewModel.apiStatus.contains("✅") ? .green : .red)
                }
                .padding(.vertical)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .shadow(radius: 2)
                )
                .frame(maxWidth: .infinity)
                
                HStack {
                    Text("Token Status:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.tokenStatus)
                        .font(.headline)
                        .foregroundColor(viewModel.tokenStatus.contains("❌") ? .red : .green)
                }
                .padding(.vertical)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .shadow(radius: 2)
                )
                .frame(maxWidth: .infinity)
                
                HStack {
                    Text("Time Remaining:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.timeRemaining)
                        .font(.headline)
                        .foregroundColor(timeColor(for: viewModel.timeRemaining))
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
            .padding(.horizontal)
        }
    }
    
    private func timeColor(for value: String) -> Color {
        if value.contains("expired") {
            return .red
        } else if value.contains("< 1 hour") {
            return .orange
        }
        return .green
    }
}
