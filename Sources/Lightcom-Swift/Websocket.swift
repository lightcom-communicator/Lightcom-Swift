import Foundation

public class Websocket: NSObject, URLSessionWebSocketDelegate {
    private var websocket: URLSessionWebSocketTask?
    private var onReceive: (_ data: Data?, _ str: String?) -> ()
    
    init(url: String, onReceive: @escaping (_ data: Data?, _ str: String?) -> ()) {
        self.onReceive = onReceive
        super.init()
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        let url = URL(string: url)!
        self.websocket = session.webSocketTask(with: url)
        self.websocket?.resume()
        self.receive()
    }
    
    func receive() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.websocket?.receive { result in
                do {
                    let message = try result.get()
                    switch message {
                    case .data(let data):
                        self?.onReceive(data, nil)
                    case .string(let str):
                        self?.onReceive(nil, str)
                    }
                    
                    self?.receive()
                } catch {
                    self?.websocket?.cancel()
                }
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now(), execute: workItem)
    }
    
    func send(message: Data) {
        self.websocket?.send(URLSessionWebSocketTask.Message.data(message), completionHandler: {_ in})
    }
    
    func send(message: String) {
        self.websocket?.send(URLSessionWebSocketTask.Message.string(message), completionHandler: {_ in})
    }
    
    @objc public func close() {
        self.websocket?.cancel()
    }
}
