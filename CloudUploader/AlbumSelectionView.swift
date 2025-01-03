import SwiftUI

struct AlbumSelectionView: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateSheet = false
    @State private var selectedAlbumName: String?
    
    var body: some View {
        ZStack {
            // Background dismiss
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Text("Album Selection")
                        .font(.headline)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                
                // Album list
                if viewModel.isLoadingAlbums {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading Albums...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.availableAlbums.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Shared Albums Found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create a new album to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.availableAlbums, id: \.id, selection: $selectedAlbumName) { album in
                        Text(album.title)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tag(album.title)
                    }
                    .listStyle(.plain)
                }
                
                // Bottom buttons
                VStack(spacing: 12) {
                    Button(action: {
                        if let albumName = selectedAlbumName {
                            viewModel.selectAlbum(albumName)
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Select Album")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .purple))
                    .disabled(selectedAlbumName == nil)
                    
                    Button(action: { showCreateSheet = true }) {
                        HStack {
                            Image(systemName: "folder.badge.plus.fill")
                            Text("Create New Album")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ModernButtonStyle(backgroundColor: .teal))
                }
                .padding()
            }
            .frame(width: 600, height: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showCreateSheet) {
            AlbumInputView { newAlbumName in
                viewModel.runNewShootScript(albumName: newAlbumName)
                showCreateSheet = false
                dismiss()
            }
        }
        .task {
            await viewModel.fetchAvailableAlbums()
        }
    }
}
