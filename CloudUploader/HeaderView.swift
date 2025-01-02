import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack {
            Spacer()
            if let image = NSImage(contentsOfFile: "/Volumes/CloudUploader/CloudUploader/HeaderImage.png") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            } else {
                Text("Image not found").foregroundColor(.red)
            }
            Spacer()
        }
        .padding(.top, 5)
    }
}
