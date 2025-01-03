import SwiftUI
import WebKit
import CoreImage.CIFilterBuiltins
import AppKit

extension Color {
    static let backgroundPrimary = Color(NSColor.windowBackgroundColor)
    static let backgroundSecondary = Color(NSColor.controlBackgroundColor)
    static let textPrimary = Color(NSColor.labelColor)
    static let textSecondary = Color(NSColor.secondaryLabelColor)
}

@MainActor
struct ContentView: View {
    // Focus state and enum for keyboard navigation
    @FocusState private var focusedButton: ButtonFocus?
    
    private enum ButtonFocus {
        case auth
        case selectAlbum
        case startMonitoring
    }
    
    // Existing state objects and properties
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
    @StateObject private var tokenManager = TokenManager()
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                HeaderView()
                
                StatusSection(viewModel: viewModel)
                
                // Auth Button - Always visible
                AuthButton(viewModel: viewModel)
                    .focused($focusedButton, equals: .auth)
                
                Divider().padding(.horizontal)
                
                AlbumInfoSection(
                    viewModel: viewModel,
                    selectedLinkURL: $selectedLinkURL,
                    showLinkConfirmation: $showLinkConfirmation,
                    showQRCodeOverlay: $showQRCodeOverlay
                )
                
                // Select Album Button - Always visible
                SelectAlbumButton(viewModel: viewModel)
                    .focused($focusedButton, equals: .selectAlbum)
                
                Divider().padding(.horizontal)
                
                ConsoleView(consoleManager: consoleManager)
                    .padding(.horizontal)
                
                Button(action: {
                    // First check token validity
                    if !tokenManager.showRefreshButton { // Token is invalid or expired
                        viewModel.showAuthRequiredSheet = true
                        ConsoleManager.shared.log("⚠️ Authentication required before monitoring", color: .orange)
                        return
                    }
                    
                    // Then check album status
                    if viewModel.albumName == "Not Set" || viewModel.albumName == "N/A" {
                        viewModel.showAlbumRequiredSheet = true
                        ConsoleManager.shared.log("⚠️ Please select an album first", color: .orange)
                        return
                    }
                    
                    // If both checks pass, toggle monitoring
                    viewModel.isMonitoring.toggle()
                    if viewModel.isMonitoring {
                        ConsoleManager.shared.log("🔄 Monitoring started...", color: .green)
                    } else {
                        ConsoleManager.shared.log("⏹️ Monitoring stopped", color: .orange)
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
                .focused($focusedButton, equals: .startMonitoring)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            .frame(minWidth: 869, minHeight: 842)
            .background(Color.backgroundPrimary.opacity(0.95))
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .onKeyPress(.tab) {
                if NSEvent.modifierFlags.contains(.shift) {
                    switch focusedButton {
                    case .auth:
                        focusedButton = .startMonitoring
                    case .selectAlbum:
                        focusedButton = .auth
                    case .startMonitoring:
                        focusedButton = .selectAlbum
                    case nil:
                        focusedButton = .startMonitoring
                    }
                } else {
                    switch focusedButton {
                    case .auth:
                        focusedButton = .selectAlbum
                    case .selectAlbum:
                        focusedButton = .startMonitoring
                    case .startMonitoring:
                        focusedButton = .auth
                    case nil:
                        focusedButton = .auth
                    }
                }
                return .handled
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
                NSApp.windows.forEach { window in
                    window.appearance = NSAppearance(named: themeManager.isDarkMode ? .darkAqua : .aqua)
                }
            }
        }
        .onAppear {
            viewModel.initialize()
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
    }
}
#endif
