import SwiftUI

struct SelectAlbumButton: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    
    var body: some View {
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
}
