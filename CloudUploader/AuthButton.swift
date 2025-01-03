import SwiftUI

struct AuthButton: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    
    var body: some View {
        Button(action: {
            if viewModel.showRefreshButton {
                viewModel.tokenManager.refreshToken()
            } else {
                viewModel.authenticateInApp()
                viewModel.showAuthSheet = true
            }
        }) {
            HStack {
                Image(systemName: viewModel.showRefreshButton ? "arrow.clockwise" : "key.fill")
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
}