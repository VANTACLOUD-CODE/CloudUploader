import SwiftUI

struct AuthRequiredView: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @Binding var isVisible: Bool // Use a binding to manage visibility

    var body: some View {
        ZStack {
            // Semi-transparent background to dim the underlying content
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isVisible = false // Dismiss only the overlay
                }

            // Dialog content
            VStack(spacing: 20) {
                Text("🔐 Authentication Required 🔐")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You must authenticate before continuing.\nPlease log in or cancel to return.")
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
                        isVisible = false // Dismiss only the overlay
                    }) {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Authenticate")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .blue))
                }
            }
            .padding(30)
            .frame(maxWidth: 400) // Constrain dialog width
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}
