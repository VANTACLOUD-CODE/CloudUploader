import SwiftUI

struct AlbumInputView: View {
    var onCreate: (String) -> Void
    @State private var albumName: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Album")
                .font(.headline)
                .padding()

            TextField("Enter album name", text: $albumName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            HStack {
                Button("Create") {
                    onCreate(albumName)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.green)

                Button("Cancel") {
                    albumName = ""
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.red)
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}
