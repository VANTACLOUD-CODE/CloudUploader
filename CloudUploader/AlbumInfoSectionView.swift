import SwiftUI

struct AlbumInfoSection: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @Binding var selectedLinkURL: URL?
    @Binding var showLinkConfirmation: Bool
    @Binding var showQRCodeOverlay: Bool
    
    var body: some View {
        VStack {
            Text("📂 Current Album")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
            
            HStack(spacing: 20) {
                albumStatusRow(label: "Album Name:", value: viewModel.albumName, isAlbumLink: true) {
                    if let url = URL(string: viewModel.shareableLink),
                       viewModel.shareableLink != "N/A",
                       viewModel.shareableLink != "Not available" {
                        selectedLinkURL = url
                        showLinkConfirmation = true
                    }
                }
                
                albumStatusRow(label: "Link:", value: viewModel.shareableLink, isAlbumLink: false) {
                    if let url = URL(string: viewModel.shareableLink),
                       viewModel.shareableLink != "N/A",
                       viewModel.shareableLink != "Not available" {
                        selectedLinkURL = url
                        viewModel.copyToClipboard(viewModel.shareableLink)
                        ConsoleManager.shared.logLinkCopied(link: viewModel.shareableLink)
                        ConsoleManager.shared.logQRCodeDisplayed()
                        showQRCodeOverlay = true
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func albumStatusRow(label: String, value: String, isAlbumLink: Bool, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(label).font(.headline)
            Spacer()
            if let action = action {
                Button(action: action) {
                    Text(value)
                        .foregroundColor(value == "N/A" || value == "Not Set" ? .red : .blue)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text(value)
                    .foregroundColor(value == "N/A" || value == "Not Set" ? .red : .blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .shadow(radius: 2)
        )
    }
}
