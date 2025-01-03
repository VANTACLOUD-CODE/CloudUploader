import SwiftUI

struct AlbumInputView: View {
    var onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var albumName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Text("Create New Shared Album")
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
            
            TextField("Enter album name", text: $albumName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isTextFieldFocused)
                .padding(.horizontal)
                .onSubmit {
                    if !albumName.isEmpty {
                        onCreate(albumName)
                        dismiss()
                    }
                }
            
            Button(action: {
                onCreate(albumName)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Create Album")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(backgroundColor: .teal))
            .disabled(albumName.isEmpty)
            .padding(.horizontal)
            
            Spacer().frame(height: 8)
        }
        .padding(.bottom, 8)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}
