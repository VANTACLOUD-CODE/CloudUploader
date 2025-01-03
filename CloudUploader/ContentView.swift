import SwiftUI
import WebKit
import CoreImage.CIFilterBuiltins

extension Color {
    static let backgroundPrimary = Color(NSColor.windowBackgroundColor)
    static let backgroundSecondary = Color(NSColor.controlBackgroundColor)
    static let textPrimary = Color(NSColor.labelColor)
    static let textSecondary = Color(NSColor.secondaryLabelColor)
}

struct ContentView: View {
    @StateObject private var viewModel = CloudUploaderViewModel.shared
    @StateObject private var consoleManager = ConsoleManager.shared
    @State private var copiedMessage: String? = nil
    @State private var showMessage = false
    @State private var showAlbumInput = false
    @State private var showLinkConfirmation = false
    @State private var selectedLinkURL: URL? = nil
    @State private var showQRCodeOverlay = false
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(\.openURL) var openURL
    
    @State private var showQuitConfirmation = false
    @StateObject private var quitHandler = QuitConfirmationHandler.shared
    
    @StateObject private var windowDelegate = AppWindowDelegate()
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                HeaderView()
                
                StatusSection(viewModel: viewModel)
                
                // Auth Button - Always visible
                AuthButton(viewModel: viewModel)
                
                Divider().padding(.horizontal)
                
                AlbumInfoSection(
                    viewModel: viewModel,
                    selectedLinkURL: $selectedLinkURL,
                    showLinkConfirmation: $showLinkConfirmation,
                    showQRCodeOverlay: $showQRCodeOverlay
                )
                
                // Select Album Button - Always visible
                SelectAlbumButton(viewModel: viewModel)
                
                Divider().padding(.horizontal)
                
                ConsoleView(consoleManager: consoleManager)
                    .padding(.horizontal)
                
                Button(action: {
                    viewModel.checkOrPromptAlbum {
                        if viewModel.albumName == "Not Set" || viewModel.albumName == "N/A" {
                            ConsoleManager.shared.log("⚠️ Please select an album first", color: .orange)
                            return
                        }
                        viewModel.isMonitoring.toggle()
                        if viewModel.isMonitoring {
                            ConsoleManager.shared.log("🔄 Monitoring started...", color: .green)
                        } else {
                            ConsoleManager.shared.log("⏹️ Monitoring stopped", color: .orange)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                        Text(viewModel.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle(backgroundColor: viewModel.isMonitoring ? .red : .green))
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding()
            .frame(minWidth: 869 , minHeight: 842)
            .background(Color.backgroundPrimary.opacity(0.95))
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .sheet(isPresented: $viewModel.showAlbumSelection) {
                AlbumSelectionView(viewModel: viewModel)
            }
            
            // Overlays
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
            }
            
            if showLinkConfirmation, let url = selectedLinkURL {
                ConfirmationView(
                    title: "🔗 Open Album 🔗",
                    message: "Would you like to open the album in your browser?",
                    confirmText: "Open Link",
                    cancelText: "Cancel",
                    confirmColor: .blue,
                    confirmIcon: "safari",
                    cancelIcon: "xmark.circle",
                    onConfirm: {
                        openURL(url)
                        viewModel.handleLinkOpened(link: url.absoluteString)
                        showLinkConfirmation = false
                    },
                    onCancel: {
                        showLinkConfirmation = false
                    }
                )
            }
            
            if quitHandler.showQuitConfirmation {
                ConfirmationView(
                    title: "🚨 Confirm Quit 🚨",
                    message: "Are you sure you want to quit?\nAll processes will be stopped.",
                    confirmText: "Quit",
                    cancelText: "Cancel",
                    confirmColor: .red,
                    confirmIcon: "power",
                    cancelIcon: "xmark.circle",
                    onConfirm: {
                        quitHandler.confirmQuit()
                    },
                    onCancel: {
                        quitHandler.cancelQuit()
                    }
                )
            }
            
            if viewModel.showAlbumRequiredSheet {
                AlbumRequiredView(viewModel: viewModel, isVisible: $viewModel.showAlbumRequiredSheet)
                    .transition(.opacity)
            }
        }
        .onChange(of: themeManager.isDarkMode) { oldValue, newValue in
            withAnimation {
                // Force window update
                NSApp.windows.forEach { window in
                    window.appearance = NSAppearance(named: themeManager.isDarkMode ? .darkAqua : .aqua)
                }
            }
        }
        .onAppear {
            viewModel.initialize()
            
            // Set window delegate
            if let window = NSApp.windows.first {
                window.delegate = windowDelegate
            }
        }
        .onExitCommand {
            if viewModel.isMonitoring {
                withAnimation {
                    showQuitConfirmation = true
                }
            } else {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDisplayName("Main Window - Empty")
            .previewLayout(.fixed(width: 869, height: 842))
            .preferredColorScheme(.light)
            .background(
                Image("DesktopBackground")
                    .resizable()
                    .edgesIgnoringSafeArea(.all)
            )

        ContentView()
            .previewDisplayName("Auth Required")
            .previewLayout(.fixed(width: 842, height: 800))
            .preferredColorScheme(.light)
            .onAppear {
                CloudUploaderViewModel.shared.showAuthRequiredSheet = true
            }

        ContentView()
            .previewDisplayName("Active Monitoring")
            .previewLayout(.fixed(width: 842, height: 800))
            .preferredColorScheme(.light)
            .onAppear {
                CloudUploaderViewModel.shared.isMonitoring = true
                ConsoleManager.shared.log("🔄 Monitoring started...", color: .green)
                ConsoleManager.shared.log("📸 Found new image: photo001.jpg", color: .blue)
            }

        ContentView()
            .previewDisplayName("QR Code Overlay")
            .previewLayout(.fixed(width: 842, height: 800))
            .preferredColorScheme(.light)
            .onAppear {
                let viewModel = CloudUploaderViewModel.shared
                viewModel.shareableLink = "https://photos.google.com/share/example"
                viewModel.albumName = "Test Album"
            }
    }
}
#endif
