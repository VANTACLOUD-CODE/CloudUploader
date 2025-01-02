import SwiftUI
import WebKit
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject private var viewModel = CloudUploaderViewModel.shared
    @StateObject private var consoleManager = ConsoleManager.shared
    @State private var copiedMessage: String? = nil
    @State private var showMessage = false
    @State private var showAlbumInput = false
    @State private var showLinkConfirmation = false
    @State private var selectedLinkURL: URL? = nil
    @State private var showQRCodeOverlay = false
    
    @Environment(\.openURL) var openURL
    
    // Move helper functions outside of body
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
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .shadow(radius: 2)
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
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .shadow(radius: 2)
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
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .shadow(radius: 2)
        )
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                // Brand Icon
                HStack {
                    Spacer()
                    if let image = NSImage(contentsOfFile: "/Volumes/CloudUploader/CloudUploader/HeaderImage.png") {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                    } else {
                        Text("Image not found").foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding(.top, 5)
                
                // Status Section Title
                Text("⚙️ System Status")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                
                // Combined Status Row
                HStack(spacing: 10) {
                    // API Status
                    HStack(spacing: 5) {
                        Text("API Status:")
                            .font(.headline)
                            .foregroundColor(.primary)
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
                    
                    // Token Status
                    statusRow(label: "Token Status:", value: viewModel.tokenStatus,
                              isError: viewModel.tokenStatus.contains("❌"))
                    
                    // Time Remaining
                    timeRemainingRow(label: "Time Remaining:", value: viewModel.timeRemaining)
                }
                .padding(.horizontal)
                
                if viewModel.showAuthenticateButton {
                    Button(action: {
                        viewModel.authenticateInApp()
                        viewModel.showAuthSheet = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text(viewModel.showRefreshButton ? "Refresh Token" : "Generate Token")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .blue))
                    .padding(.horizontal)
                    .padding(.top, 5)
                    .padding(.bottom, 5)
                }
                
                Divider().padding(.horizontal)
                
                // Album Status Info Title
                Text("📂 Current Album")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                
                // Album Info
                HStack(spacing: 20) {
                    albumStatusRow(label: "Album Name:", value: viewModel.albumName, isAlbumLink: true) {
                        if let url = URL(string: viewModel.shareableLink), viewModel.shareableLink != "N/A", viewModel.shareableLink != "Not available" {
                            selectedLinkURL = url
                            showLinkConfirmation = true
                        }
                    }
                    
                    albumStatusRow(label: "Link:", value: viewModel.shareableLink, isAlbumLink: false) {
                        if let url = URL(string: viewModel.shareableLink), 
                           viewModel.shareableLink != "N/A", 
                           viewModel.shareableLink != "Not available" {
                            selectedLinkURL = url
                            viewModel.copyToClipboard(viewModel.shareableLink)
                            ConsoleManager.shared.logLinkCopied(link: viewModel.shareableLink)
                            ConsoleManager.shared.logQRCodeDisplayed()
                            showQRCodeOverlay = true
                        }
                    }
                }
                .padding(.horizontal)
                
                if viewModel.showAuthenticateButton {
                    Button(action: {
                        viewModel.checkOrPromptAuth {
                            Task {
                                await viewModel.runSelectAlbumScript()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Select Album")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .purple))
                    .padding(.horizontal)
                    .padding(.top, 5)
                    .padding(.bottom, 5)
                }
                
                Divider().padding(.horizontal)
                
                // Uploader Console Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("☁️ Uploader Console")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(consoleManager.consoleText.indices, id: \.self) { index in
                                    Text(consoleManager.consoleText[index].text)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(consoleManager.consoleText[index].color)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: consoleManager.consoleText.count) { _ in
                                withAnimation {
                                    proxy.scrollTo(consoleManager.consoleText.count - 1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                            .shadow(radius: 3)
                    )
                }
                .padding(.horizontal)
                
                // Start/Stop Button beneath console
                Button(action: {
                    viewModel.toggleMonitoring()
                }) {
                    HStack {
                        Image(systemName: viewModel.isMonitoring ? "stop.circle" : "play.circle")
                        Text(viewModel.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle(backgroundColor: viewModel.isMonitoring ? .red : .green))
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 842, minHeight: 800)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .onAppear {
                viewModel.initialize()
            }
            
            // Overlays
            .overlay(
                Group {
                    if viewModel.showAuthSheet {
                        AuthenticationSheetView(viewModel: viewModel, isVisible: $viewModel.showAuthSheet)
                            .transition(.opacity)
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
                    
                    if viewModel.showQuitConfirmation {
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
                                viewModel.showQuitConfirmation = false
                            },
                            onCancel: {
                                viewModel.showQuitConfirmation = false
                            }
                        )
                    }
                }
            )
            
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
                            ConsoleManager.shared.logLinkOpened(link: url.absoluteString)
                            openURL(url)
                        }
                        showLinkConfirmation = false
                    },
                    onCancel: {
                        showLinkConfirmation = false
                    }
                )
            }
        }
    }
}
