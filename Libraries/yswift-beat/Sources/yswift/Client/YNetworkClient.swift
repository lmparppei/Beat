//
//  ConnectionManager.swift
//  CRDTImplementation
//
//  Created by Lauri-Matti Parppei on 11.6.2026.
//

import Foundation
import yswift

// MARK: - Client

import Foundation

// MARK: - Binary framing
//
// A single WebSocket binary frame carries an array of Data chunks:
//
//   [count: UInt32 BE]
//   for each chunk:
//     [length: UInt32 BE] [bytes...]
//
// The server relays the frame opaquely, so framing is purely a client concern.

private enum Framing {
    static func encode(_ chunks: [Data]) -> Data {
        var out = Data()
        var count = UInt32(chunks.count).bigEndian
        out.append(Data(bytes: &count, count: 4))
        for chunk in chunks {
            var length = UInt32(chunk.count).bigEndian
            out.append(Data(bytes: &length, count: 4))
            out.append(chunk)
        }
        return out
    }

    static func decode(_ data: Data) throws -> [Data] {
        var offset = data.startIndex

        func readUInt32() throws -> Int {
            guard data.endIndex - offset >= 4 else { throw FramingError.truncated }
            var raw: UInt32 = 0
            withUnsafeMutableBytes(of: &raw) { dest in
                data[offset ..< offset + 4].withUnsafeBytes { src in
                    dest.copyMemory(from: src)
                }
            }
            offset += 4
            return Int(UInt32(bigEndian: raw))
        }

        let count = try readUInt32()
        var chunks: [Data] = []
        chunks.reserveCapacity(count)

        for _ in 0 ..< count {
            let length = try readUInt32()
            guard data.endIndex - offset >= length else { throw FramingError.truncated }
            chunks.append(data[offset ..< offset + length])
            offset += length
        }
        return chunks
    }

    enum FramingError: Error { case truncated }
}


// MARK: - CRDTRelayClient

public enum YNetworkClientDisconnectReason:Int {
    case userTriggered = 0
    case hostNotFound
    case hostTerminated
    case timedOut
    case networkLost
    case roomNotFound
    case error
}

public enum YServerError:Int {
    case roomNotFound
}

public final class YNetworkClient: NSObject {

    public var userId = UUID().uuidString
    
    public var onRoomCreated: ((String) -> Void)?
    public var onJoined: ((String) -> Void)?
    public var onPeerJoined: ((String, [String]) -> Void)?
    public var onPeerLeft: ((String, [String], Bool) -> Void)?
    public var onUpdates: (([Data]) -> Void)?
    public var onError: ((String, NSError) -> Void)?
    public var onDisconnected: ((YNetworkClientDisconnectReason, Error?) -> Void)?
    public var onConnected: (() -> Void)?
    
    public var ready: Bool = false
    public var isConnected: Bool = false {
        didSet {
            if !isConnected { ready = false }
        }
    }
    public var isReconnecting: Bool = false
    public var activePeers: Set<String> = []
    
    private let baseURL: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    // Tracks intentional disconnects so delegate callbacks
    // don't misfire as errors
    private var disconnectReason: YNetworkClientDisconnectReason?
    // Guards against double-firing from didCloseWith + didCompleteWithError
    private var disconnectCallbackFired = false

    init(serverURL: URL) {
        self.baseURL = serverURL
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public API

    public func createRoom() {
        connect(path: "/create/\(userId)")
    }

    public func joinRoom(_ roomId: String) {
        connect(path: "/join/\(roomId)/\(userId)")
    }

    public func sendUpdates(_ chunks: [Data]) {
        guard !chunks.isEmpty else { return }
        let frame = Framing.encode(chunks)
        webSocketTask?.send(.data(frame)) { [weak self] error in
            if let error {
                self?.onError?("Send failed: \(error.localizedDescription)", error as NSError)
            }
        }
    }

    /// Clean disconnect — will not trigger error UI.
    public func disconnect() {
        cancelCurrentTask(reason: .userTriggered)
    }
    
    /// Reconnect to an existing room — replaces the socket without
    /// triggering disconnect UI.
    public func reconnect(roomId: String) {
        cancelCurrentTask(reason: nil) // nil = suppress the callback entirely
        isReconnecting = true
        connect(path: "/join/\(roomId)/\(userId)")
    }

    // MARK: - Private

    private func cancelCurrentTask(reason: YNetworkClientDisconnectReason?) {
        disconnectReason = reason
        disconnectCallbackFired = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    private func connect(path: String) {
        disconnectReason = nil
        disconnectCallbackFired = false
        
        let url = baseURL.appendingPathComponent(path)
        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        
        task.resume()
        receiveNext(for: task)
    }

    // Pass the task explicitly so a replaced task's receive loop
    // doesn't call back into a newer socket
    private func receiveNext(for task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self, self.webSocketTask === task else { return }
            switch result {
            case .failure(let error):
                self.onError?("Receive error: \(error.localizedDescription)", error as NSError)
            case .success(let message):
                self.handle(message)
                self.receiveNext(for: task)
            }
        }
    }

    private func disconnectEvent(reason: YNetworkClientDisconnectReason, error: Error?) {
        // Only fire once per disconnection event
        guard !disconnectCallbackFired else { return }
        disconnectCallbackFired = true
        isConnected = false
        
        // Suppress callback entirely during reconnects
        guard !isReconnecting else { return }
        
        onDisconnected?(reason, error)
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            do {
                let chunks = try Framing.decode(data)
                onUpdates?(chunks)
            } catch {
                onError?("Framing decode failed: \(error)", error as NSError)
            }

        case .string(let text):
            guard
                let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                let type = json["type"] as? String
            else { return }

            switch type {
            case "room_created":
                ready = true
                isReconnecting = false
                if let roomId = json["roomId"] as? String { onRoomCreated?(roomId) }
                
            case "joined":
                ready = true
                isReconnecting = false
                if let roomId = json["roomId"] as? String { onJoined?(roomId) }
                if let memberIds = json["memberIds"] as? [String] {
                    activePeers.removeAll()
                    activePeers.formUnion(memberIds)
                }
                
            case "peer_joined":
                let userId = json["userId"] as? String ?? ""
                let memberIds = json["memberIds"] as? [String] ?? []
                activePeers.insert(userId)
                onPeerJoined?(userId, memberIds)
                
            case "peer_left":
                let userId = json["userId"] as? String ?? ""
                let memberIds = json["memberIds"] as? [String] ?? []
                let isHost = json["isHost"] as? Bool ?? false
                activePeers.remove(userId)
                onPeerLeft?(userId, memberIds, isHost)
                
            case "peer_reconnected":
                let userId = json["userId"] as? String ?? ""
                activePeers.insert(userId)
                
            case "error":
                let message = json["message"] as? String ?? "Unknown error"
                handleServerError(message: message)
                
            default:
                break
            }

        @unknown default:
            break
        }
    }
    
    private func handleServerError(message:String) {
        var disconnect = false
        var code = -9999
        
        if message == "Room not found" {
            code = YServerError.roomNotFound.rawValue
            disconnect = true
        }
        onError?(message, NSError(domain: "YServer", code: code, userInfo: [NSLocalizedDescriptionKey: message]))
        
        if disconnect {
            self.disconnect()
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension YNetworkClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol protocol: String?) {
        isConnected = true
        onConnected?()
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        // If we set an explicit reason, use it; otherwise treat as host termination
        let reason = disconnectReason ?? .hostTerminated
        disconnectEvent(reason: reason, error: nil)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        guard let error = error as? NSError else { return }
        
        // NSURLErrorCancelled (-999) fires when we cancel intentionally —
        // didCloseWith already handled (or will handle) that case
        if error.code == NSURLErrorCancelled { return }
        
        let reason: YNetworkClientDisconnectReason
        switch error.code {
        case NSURLErrorTimedOut:              reason = .timedOut
        case NSURLErrorNetworkConnectionLost: reason = .networkLost
        case NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorBadServerResponse:     reason = .hostNotFound
        default:                              reason = .error
        }
        
        disconnectEvent(reason: reason, error: error)
    }
}

