import SwiftUI

struct ConfirmationView: View {
    var title: String
    var message: String
    var confirmText: String
    var cancelText: String
    var confirmColor: Color = .red
    var confirmIcon: String? = nil // Optional icon for Confirm button
    var cancelIcon: String? = nil // Optional icon for Cancel button
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background to dim the underlying content
            Color.black.opacity(0.69)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onCancel() // Dismiss the overlay on background tap
                }

            // Confirmation dialog
            VStack(spacing: 20) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    // Cancel Button with optional icon
                    Button(action: onCancel) {
                        HStack {
                            if let cancelIcon = cancelIcon {
                                Image(systemName: cancelIcon)
                            }
                            Text(cancelText)
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .gray))

                    // Confirm Button with optional icon
                    Button(action: onConfirm) {
                        HStack {
                            if let confirmIcon = confirmIcon {
                                Image(systemName: confirmIcon)
                            }
                            Text(confirmText)
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: confirmColor))
                }
            }
            .padding(20)
            .frame(maxWidth: 369) // Constrain dialog width
            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: title)
    }
}
