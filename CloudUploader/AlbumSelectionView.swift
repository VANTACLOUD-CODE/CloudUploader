import SwiftUI

struct AlbumSelectionView: View {
    let albums: [[String: String]]
    var onSelect: (Dictionary<String, String>) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Select an Album")
                .font(.headline)
                .padding()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(albums, id: \.self) { album in
                        HStack {
                            Text(album["name"] ?? "Unknown Album")
                                .font(.subheadline)
                            Spacer()
                            Button(action: {
                                onSelect(album)
                            }) {
                                Text("Select")
                                    .frame(minWidth: 50)
                                    .padding(5)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(5)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()

            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.red)
            .padding()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
