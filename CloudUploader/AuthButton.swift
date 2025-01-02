import SwiftUI

struct AuthButton: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    
    var body: some View {
        Button(action: {
            viewModel.authenticateInApp()
            viewModel.showAuthSheet = true
        }) {
            HStack {
                Image(systemName: "key.fill")
                Text("Generate Token")
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