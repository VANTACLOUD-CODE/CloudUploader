import SwiftUI
import WebKit
import CoreImage.CIFilterBuiltins // Required for QR Code generation

struct ContentView: View {
    @ObservedObject private var viewModel = CloudUploaderViewModel()
    @State private var showQuitConfirmation = false
    @State private var copiedMessage: String? = nil
    @State private var showMessage = false
    @State private var showAlbumInput = false // Controls "New Shoot" sheet

    // State variables for link confirmation and QR code overlay
    @State private var showLinkConfirmation = false
    @State private var selectedLinkURL: URL? = nil
    @State private var showQRCodeOverlay = false

    // Environment to handle URL opening
    @Environment(\.openURL) var openURL

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // === Brand Icon ===
                HStack {
                    Spacer()
                    if let image = NSImage(contentsOfFile: "/Volumes/CloudUploader/CloudUploader/HeaderImage.png") {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 111, height: 111) // Adjusted size for better visibility
                    } else {
                        Text("Image not found").foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding(.top, 20)

                // === API Status ===
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Text("API Status:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(viewModel.apiStatus)
                            .font(.headline)
                            .foregroundColor(viewModel.apiStatus.contains("✅") ? .green : .red)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    Spacer()
                }
                .padding(.horizontal)

                // === Token Status and Time Remaining ===
                HStack(spacing: 20) {
                    // Token Status
                    statusRow(label: "Token Status:", value: viewModel.tokenStatus, isError: viewModel.tokenStatus.contains("❌"))
                    
                    // Time Remaining
                    timeRemainingRow(label: "Time Remaining:", value: viewModel.timeRemaining)
                }
                .padding(.horizontal)

                Divider().padding(.horizontal)

                // === Album Info: Album Name and Shareable Link ===
                HStack(spacing: 20) {
                    // Album Name with confirmation prompt
                    albumStatusRow(label: "Album Name:", value: viewModel.albumName, isAlbumLink: true, action: {
                        if let url = URL(string: viewModel.shareableLink), viewModel.shareableLink != "N/A", viewModel.shareableLink != "Not available" {
                            selectedLinkURL = url
                            showLinkConfirmation = true
                        }
                    })

                    // Shareable Link with QR Code overlay
                    albumStatusRow(label: "Link:", value: viewModel.shareableLink, isAlbumLink: false, action: {
                        if let url = URL(string: viewModel.shareableLink), viewModel.shareableLink != "N/A", viewModel.shareableLink != "Not available" {
                            selectedLinkURL = url
                            viewModel.copyToClipboard(viewModel.shareableLink) // Copy to clipboard
                            showQRCodeOverlay = true // Show the QR code overlay
                        }
                    })
                }
                .padding(.horizontal)

                // === Capture One Status ===
                VStack(alignment: .leading, spacing: 10) {
                    Text("Capture One Status:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)

                    ScrollView {
                        Text(viewModel.captureOneStatus)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(viewModel.captureOneStatus.isEmpty || viewModel.captureOneStatus == "Not processing" ? .gray : .blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .padding(.top, 10)
                }
                .padding(.horizontal)

                Spacer()

                // === Action Buttons ===
                VStack(spacing: 20) {
                    // New Shoot and Select Album Buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            // Check token validity
                            viewModel.checkOrPromptAuth {
                                showAlbumInput = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("New Shoot")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(ModernButtonStyle(backgroundColor: .orange))

                        Button(action: {
                            // Check token validity
                            viewModel.checkOrPromptAuth {
                                viewModel.runSelectAlbumScript()
                            }
                        }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Select Album")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(ModernButtonStyle(backgroundColor: .purple))
                    }

                    // Authenticate and Quit Buttons
                    HStack(spacing: 20) {
                        if viewModel.showAuthenticateButton {
                            Button(action: {
                                // Ensure that the WebView loads the authentication URL
                                viewModel.authenticateInApp() // Properly call the method in ViewModel
                                viewModel.showAuthSheet = true // Present the AuthenticationSheetView
                            }) {
                                HStack {
                                    Image(systemName: "lock.shield")
                                    Text("Authenticate")
                                        .font(.headline)
                                }
                            }
                            .buttonStyle(ModernButtonStyle(backgroundColor: .blue))
                        }

                        Button(action: {
                            showQuitConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "power")
                                Text("Quit")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(ModernButtonStyle(backgroundColor: .red))
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(minWidth: 700, minHeight: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .onAppear {
                viewModel.initialize()
            }
            
            // Overlays for QR Code, AuthRequired, and Confirmation
            .overlay(
                Group {
                    if viewModel.showAuthSheet {
                                AuthenticationSheetView(viewModel: viewModel, isVisible: $viewModel.showAuthSheet)
                                    .transition(.opacity)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.showAuthSheet)
                            }
                    if viewModel.showAuthRequiredSheet {
                        AuthRequiredView(viewModel: viewModel, isVisible: $viewModel.showAuthRequiredSheet)
                            .transition(.opacity)
                    }

                    if showQRCodeOverlay, let url = selectedLinkURL {
                        QRCodeOverlayView(url: url) {
                            withAnimation {
                                showQRCodeOverlay = false
                            }
                        }
                        .transition(.opacity)
                    }

                    if showLinkConfirmation {
                        ConfirmationView(
                            title: "🔗 Open Link 🔗",
                            message: "Are you sure you want to open this link?",
                            confirmText: "Open",
                            cancelText: "Cancel",
                            confirmColor: .blue,
                            confirmIcon: "link",
                            cancelIcon: "xmark.circle",
                            onConfirm: {
                                if let url = selectedLinkURL {
                                    openURL(url)
                                }
                                withAnimation {
                                    showLinkConfirmation = false
                                }
                            },
                            onCancel: {
                                withAnimation {
                                    showLinkConfirmation = false
                                }
                            }
                        )
                    }

                    if showQuitConfirmation {
                        ConfirmationView(
                            title: "🚨 Confirm Quit 🚨",
                            message: "Are you sure you want to quit?\nAll processes will be stopped.",
                            confirmText: "Quit",
                            cancelText: "Cancel",
                            confirmColor: .red,
                            confirmIcon: "power",
                            cancelIcon: "xmark.circle",
                            onConfirm: {
                                viewModel.confirmQuit()
                                withAnimation {
                                    showQuitConfirmation = false
                                }
                            },
                            onCancel: {
                                withAnimation {
                                    showQuitConfirmation = false
                                }
                            }
                        )
                    }
                }
            )
            .sheet(isPresented: $showAlbumInput) {
                AlbumInputView { albumName in
                    viewModel.runNewShootScript(albumName: albumName)
                    showAlbumInput = false
                }
            }
        }
    }

    // Helper Views
    private func statusRow(label: String, value: String, isError: Bool = false) -> some View {
        HStack {
            Text(label).font(.headline)
            Spacer()
            Text(value)
                .foregroundColor(isError ? .red : .green)
                .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func timeRemainingRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.headline)
            Spacer()
            Text(value)
                .foregroundColor(viewModel.remainingTimeColor)
                .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func albumStatusRow(label: String, value: String, isAlbumLink: Bool, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(label).font(.headline)
            Spacer()
            if let action = action {
                Button(action: action) {
                    Text(value)
                        .foregroundColor(value == "N/A" || value == "Not Set" ? .red : .blue)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text(value)
                    .foregroundColor(value == "N/A" || value == "Not Set" ? .red : .blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
