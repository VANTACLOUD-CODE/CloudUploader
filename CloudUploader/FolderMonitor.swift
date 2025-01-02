import Foundation

class FolderMonitor {
    private let folderURL: URL
    private var fileDescriptor: CInt = -1
    private let source: DispatchSourceFileSystemObject
    var onFileAdded: ((URL) -> Void)?
    
    init(folderPath: String) {
        self.folderURL = URL(fileURLWithPath: folderPath)
        let path = folderURL.path
        fileDescriptor = open(path, O_EVTONLY)
        
        if fileDescriptor == -1 {
            print("❌ Unable to open folder at path: \(path)")
        }
        
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: DispatchQueue.global())
        
        source.setEventHandler { [weak self] in
            self?.directoryDidChange()
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
    }
    
    deinit {
        stop()
    }
    
    func start() {
        source.resume()
    }
    
    func stop() {
        source.cancel()
    }
    
    private func directoryDidChange() {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            for file in contents {
                let isRegularFile = (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                if isRegularFile && isImageFile(url: file) {
                    onFileAdded?(file)
                }
            }
        } catch {
            print("FolderMonitor error: \(error.localizedDescription)")
        }
    }
    
    private func isImageFile(url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

