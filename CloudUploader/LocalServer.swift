import Foundation
import Network

class LocalServer {
    private let port: Int
    private let completion: (URL) -> Void
    private var isRunning = false
    private var listener: NWListener?
    
    init(port: Int, completion: @escaping (URL) -> Void) {
        self.port = port
        self.completion = completion
    }
    
    func start() throws {
        let parameters = NWParameters.tcp
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        listener = try NWListener(using: parameters, on: nwPort)
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        
        listener?.start(queue: .main)
        isRunning = true
        print("Local server started on port \(port)")
    }
    
    func stop() {
        listener?.cancel()
        isRunning = false
        print("Local server stopped on port \(port)")
    }
    
    private func handle(connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, let request = String(data: data, encoding: .utf8) {
                print("Received request: \(request)")
                if let url = self.parseRequest(request) {
                    self.completion(url)
                }
                
                // Respond to the browser
                let response = """
                HTTP/1.1 200 OK
                Content-Type: text/html

                <html>
                <body>
                <h1>Authentication Successful</h1>
                <p>You can close this window and return to the application.</p>
                </body>
                </html>
                """
                let responseData = response.data(using: .utf8) ?? Data()
                connection.send(content: responseData, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
            
            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }
    
    private func parseRequest(_ request: String) -> URL? {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else { return nil }
        let path = components[1]
        
        // Reconstruct the full URL
        let urlString = "http://localhost:\(port)\(path)"
        return URL(string: urlString)
    }
}
