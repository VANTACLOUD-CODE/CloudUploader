import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeOverlayView: View {
    var url: URL
    var onDismiss: () -> Void
    @State private var isQRExpanded = false

    var body: some View {
        ZStack {
            // Background with tap gesture
            Color.black.opacity(0.69)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        if isQRExpanded {
                            onDismiss()
                        } else {
                            onDismiss()
                        }
                    }
                }
            
            if let qrImage = generateQRCode(from: url.absoluteString) {
                if isQRExpanded {
                    // When expanded, just show the QR code
                    Image(nsImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 600, height: 600)
                        .cornerRadius(10)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isQRExpanded.toggle()
                            }
                        }
                } else {
                    // Normal overlay view
                    VStack(spacing: 10) {
                        Text("🔗 Link Details 🔗")
                            .font(.title)
                            .fontWeight(.bold)
                            .transition(.opacity)
                        
                        Text("This link has been copied to your clipboard.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                        
                        Image(nsImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 269, height: 269)
                            .cornerRadius(10)
                            .padding(20)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    isQRExpanded.toggle()
                                }
                            }
                        
                        Button(action: onDismiss) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Close")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(ModernButtonStyle(backgroundColor: .gray))
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .frame(maxWidth: 400, maxHeight: 500)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
            }
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
