import SwiftUI

struct AlbumSelectionView: View {
    let albums: [String]
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    
    @State private var newAlbumName: String = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Existing Albums")) {
                    ForEach(albums, id: \.self) { album in
                        Text(album)
                            .onTapGesture {
                                // Handle album selection if needed
                            }
                    }
                }
                
                Section(header: Text("New Album")) {
                    HStack {
                        TextField("Enter album name", text: $newAlbumName)
                        Button(action: {
                            guard !newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            onCreate(newAlbumName)
                            newAlbumName = ""
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Select Album")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}
