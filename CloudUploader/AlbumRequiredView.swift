import SwiftUI

struct AlbumRequiredView: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @Binding var isVisible: Bool
    @State private var showCreateSheet = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isVisible = false
                }
            
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: { isVisible = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("📸 Album Required 📸")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("A valid shared album is required before monitoring can begin.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Button(action: {
                        showCreateSheet = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus.fill")
                            Text("Create")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .teal))
                    
                    Button(action: {
                        viewModel.checkOrPromptAuth {
                            Task {
                                await viewModel.runSelectAlbumScript()
                            }
                        }
                        viewModel.showAlbumRequiredSheet = false
                        isVisible = false
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Select")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .purple))
                }
            }
            .padding(30)
            .frame(maxWidth: 400)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .sheet(isPresented: $showCreateSheet) {
            AlbumInputView { newAlbumName in
                viewModel.runNewShootScript(albumName: newAlbumName)
                showCreateSheet = false
                isVisible = false
                viewModel.showAlbumRequiredSheet = false
            }
        }
    }
}
