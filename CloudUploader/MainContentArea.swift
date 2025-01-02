import SwiftUI

struct MainContentArea: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @ObservedObject var consoleManager: ConsoleManager
    @Binding var showAlbumInput: Bool
    @Binding var showLinkConfirmation: Bool
    @Binding var selectedLinkURL: URL?
    @Binding var showQRCodeOverlay: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            HeaderView()
            
            StatusSection(viewModel: viewModel)
            
            if viewModel.showAuthenticateButton {
                AuthButton(viewModel: viewModel)
            }
            
            if viewModel.showAuthenticateButton {
                SelectAlbumButton(viewModel: viewModel)
            }
            
            Divider().padding(.horizontal)
            
            ConsoleView(consoleManager: consoleManager)
        }
    }
}
