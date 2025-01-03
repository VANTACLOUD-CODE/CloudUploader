import SwiftUI

struct SelectAlbumButton: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    
    var body: some View {
        Button(action: {
            if viewModel.showRefreshButton { // Token is valid
                viewModel.showAlbumSheet = true
            } else {
                viewModel.showAuthRequiredSheet = true
                ConsoleManager.shared.log("⚠️ Authentication required before selecting album", color: .orange)
            }
        }) {
            HStack {
                Image(systemName: "list.bullet")
                Text("Select Album")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ModernButtonStyle(backgroundColor: .purple))
        .padding(.horizontal)
        .padding(.top, 5)
        .padding(.bottom, 5)
        .sheet(isPresented: $viewModel.showAlbumSheet) {
            AlbumSelectionView(viewModel: viewModel)
        }
    }
}
