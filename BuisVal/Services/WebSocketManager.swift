import Foundation

class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    private var isConnected = false
    private var subscribedSymbols: Set<String> = []
    private var isReconnecting = false
    private var pingTimer: Timer?
    var onPriceUpdate: ((String, Double) -> Void)?
    
    override init() {
        session = URLSession(configuration: .default)
        super.init()
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.ping()
        }
    }
    
    private func ping() {
        webSocket?.sendPing { error in
            if let error = error {
                print("Ping failed: \(error)")
                self.handleDisconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "trade",
              let payload = json["data"] as? [[String: Any]] else {
            return
        }
        
        for trade in payload {
            if let symbol = trade["s"] as? String,
               let price = trade["p"] as? Double {
                DispatchQueue.main.async {
                    self.onPriceUpdate?(symbol, price)
                }
            }
        }
    }
    
    private func send(message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocket?.send(message) { error in
            if let error = error {
                print("WebSocket sending error: \(error)")
                self.handleDisconnect()
            }
        }
    }
    
    func connect() {
        guard !isConnected && !isReconnecting else { return }
        
        guard let url = URL(string: "\(APIConfig.finnhubWSURL)?token=\(APIConfig.finnhubKey)") else { 
            print("Invalid WebSocket URL")
            return 
        }
        
        disconnect() // Ensure clean state
        
        webSocket = session.webSocketTask(with: url)
        webSocket?.delegate = self
        webSocket?.resume()
        receiveMessage()
    }
    
    private func receiveMessage() {
        guard isConnected else { return }
        
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Only continue receiving if still connected
                if self.isConnected {
                    self.receiveMessage()
                }
            case .failure(let error):
                print("WebSocket receiving error: \(error)")
                self.handleDisconnect()
            }
        }
    }
    
    private func handleDisconnect() {
        guard !isReconnecting else { return }
        
        isConnected = false
        isReconnecting = true
        
        // Attempt to reconnect after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isReconnecting = false
            self?.connect()
            // Resubscribe to symbols
            self?.resubscribeToSymbols()
        }
    }
    
    private func resubscribeToSymbols() {
        let symbols = subscribedSymbols // Create local copy
        subscribedSymbols.removeAll()
        
        // Resubscribe to all previous symbols
        symbols.forEach { symbol in
            subscribe(to: symbol)
        }
    }
    
    func subscribe(to symbol: String) {
        guard isConnected else {
            subscribedSymbols.insert(symbol)
            return
        }
        
        subscribedSymbols.insert(symbol)
        let message = """
            {"type":"subscribe","symbol":"\(symbol)"}
            """
        send(message: message)
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        isConnected = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
    
    // URLSessionWebSocketDelegate methods
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        isConnected = true
        startPingTimer()
        resubscribeToSymbols()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected with code: \(closeCode)")
        handleDisconnect()
    }
} 