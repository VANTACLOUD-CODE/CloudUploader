import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeOverlayView: View {
    var url: URL
    var onDismiss: () -> Void
    @State private var isQRExpanded = false // State to toggle QR code size

    var body: some View {
        ZStack {
            // Dim background to cover the entire screen
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if isQRExpanded {
                        withAnimation(.spring()) {
                            isQRExpanded.toggle() // Scale back down
                        }
                    } else {
                        onDismiss() // Dismiss the overlay
                    }
                }

            VStack(spacing: 10) {
                // Header
                if !isQRExpanded {
                    Text("🔗 Link Details 🔗")
                        .font(.title)
                        .fontWeight(.bold)
                        .transition(.opacity)
                        .animation(.easeInOut, value: isQRExpanded)
                }

                // Info text
                if !isQRExpanded {
                    Text("This link has been copied to your clipboard.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                        .animation(.easeInOut, value: isQRExpanded)
                }

                // QR Code with animation
                if let qrImage = generateQRCode(from: url.absoluteString) {
                    Image(nsImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .cornerRadius(10) // Rounded corners for the QR code
                        .frame(
                            width: isQRExpanded ? min(800, NSScreen.main?.frame.width ?? 800) : 269,
                            height: isQRExpanded ? min(800, NSScreen.main?.frame.width ?? 800) : 269
                        ) // Dynamically sized QR code with screen constraints
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isQRExpanded.toggle() // Toggle expanded state
                            }
                        }
                        .padding(isQRExpanded ? 0 : 20) // Remove padding in expanded state
                } else {
                    Text("Failed to generate QR Code")
                        .foregroundColor(.red)
                }

                // Cancel button
                if !isQRExpanded {
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Close")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .gray))
                    .padding(.top, 10) // Add a little spacing at the bottom
                }
            }
            .padding(isQRExpanded ? 0 : 30) // Remove padding when expanded
            .frame(
                width: isQRExpanded ? NSScreen.main?.frame.width ?? 800 : 400,
                height: isQRExpanded ? NSScreen.main?.frame.height ?? 600 : 500
            ) // Larger overlay size with screen restrictions
            .background(isQRExpanded ? Color.black : Color(NSColor.windowBackgroundColor))
            .cornerRadius(isQRExpanded ? 0 : 20) // No rounded corners when expanded
            .shadow(radius: isQRExpanded ? 0 : 20)
            .edgesIgnoringSafeArea(isQRExpanded ? .all : .init())
        }
    }

    // Generate a high-resolution QR code
    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            // Scale the QR code to a larger size to prevent pixelation
            let transform = CGAffineTransform(scaleX: 10, y: 10) // Scale factor for high resolution
            let scaledImage = outputImage.transformed(by: transform)

            // Render as an NSImage
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return NSImage(cgImage: cgImage, size: NSSize(width: scaledImage.extent.width, height: scaledImage.extent.height))
            }
        }
        return nil
    }
}
