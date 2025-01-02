import SwiftUI

struct AuthRequiredView: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @Binding var isVisible: Bool // Use a binding to manage visibility

    var body: some View {
        ZStack {
            // Semi-transparent background to dim the underlying content
            Color.black.opacity(0.69)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isVisible = false // Dismiss only the overlay
                }

            // Dialog content
            VStack(spacing: 20) {
                Text("🔐 Token Required 🔐")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You must generate a token before continuing.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    // Cancel Button
                    Button(action: {
                        isVisible = false // Dismiss only the overlay
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .gray))

                    // Authenticate Button
                    Button(action: {
                        viewModel.authenticateInApp()
                        viewModel.showAuthSheet = true
                        isVisible = false
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Generate")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .blue))
                }
            }
            .padding(30)
            .frame(maxWidth: 400) // Constrain dialog width
            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}
