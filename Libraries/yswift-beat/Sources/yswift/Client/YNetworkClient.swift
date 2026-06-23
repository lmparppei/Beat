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
    case error
}

public final class YNetworkClient: NSObject {

    public var userId = UUID().uuidString
    
    // Callbacks — set these before calling connect
    public var onRoomCreated: ((String) -> Void)?   // roomId → share this as the join link
    public var onJoined: ((String) -> Void)?        // roomId
    public var onPeerJoined: ((String, [String]) -> Void)?
    public var onPeerLeft: ((String, [String], Bool) -> Void)?
    public var onUpdates: (([Data]) -> Void)?       // array of binary CRDT chunks from a remote peer
    public var onError: ((String) -> Void)?
    public var onDisconnected: ((YNetworkClientDisconnectReason, Error?) -> Void)?
    public var onConnected: (() -> Void)?
    
    public var isConnected:Bool = false
    
    public var activePeers:Set<String> = [] {
        didSet {
            print("activePeers: \(activePeers)")
        }
    }
    
    private let baseURL: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!

    init(serverURL: URL) {
        self.baseURL = serverURL
                
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public API

    /// Host: create a new room. `onRoomCreated` fires with the roomId on success.
    public func createRoom() {
        connect(path: "/create/\(userId)")
    }

    /// Peer: join an existing room by id.
    public func joinRoom(_ roomId: String) {
        connect(path: "/join/\(roomId)/\(userId)")
    }

    /// Send an array of binary CRDT chunks to all other peers in one frame.
    public func sendUpdates(_ chunks: [Data]) {
        //print("      --> sending",chunks)
        guard !chunks.isEmpty else { return }
        let frame = Framing.encode(chunks)
        let message = URLSessionWebSocketTask.Message.data(frame)
        webSocketTask?.send(message) { [weak self] error in
            if let error {
                self?.onError?("Send failed: \(error.localizedDescription)")
            }
        }
    }

    public func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Private

    private func connect(path: String) {
        let url = baseURL.appendingPathComponent(path)
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveNext()
    }

    private func receiveNext() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.onError?("Receive error: \(error.localizedDescription)")
            case .success(let message):
                self.handle(message)
                self.receiveNext()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            do {
                let chunks = try Framing.decode(data)
                onUpdates?(chunks)
            } catch {
                onError?("Framing decode failed: \(error)")
            }

        case .string(let text):
            guard
                let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                let type = json["type"] as? String
            else { return }

            switch type {
            case "room_created":
                if let roomId = json["roomId"] as? String {
                    onRoomCreated?(roomId)
                }
                
            case "joined":
                if let roomId = json["roomId"] as? String {
                    onJoined?(roomId)
                }
                if let memberIds = json["memberIds"] as? [String] {
                    activePeers.removeAll()
                    activePeers.formUnion(memberIds)
                }
                
            case "peer_joined":
                let userId = json["userId"] as? String
                let memberIds = json["memberIds"] as? [String]
                onPeerJoined?(userId ?? "", memberIds ?? [])
                if let userId { activePeers.insert(userId) }
                
            case "peer_left":
                let userId = json["userId"] as? String
                let memberIds = json["memberIds"] as? [String]
                let isHost = json["isHost"] as? Bool ?? false
                
                onPeerLeft?(userId ?? "", memberIds ?? [], isHost)
                if let userId { activePeers.remove(userId) }
                
            case "error":
                onError?(json["message"] as? String ?? "Unknown error")
                
            default:
                break
            }

        @unknown default:
            break
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension YNetworkClient: URLSessionWebSocketDelegate {
    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        // Connected — waiting for server handshake message
        self.isConnected = true
        onConnected?()
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        self.isConnected = false
        onDisconnected?(.userTriggered, nil)
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
        print("Invalid error")
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        
        var reason:YNetworkClientDisconnectReason = .hostTerminated
        
        if let error = error as? NSError {
            let errorCode = error.code
            let domain = error.domain
            
            switch errorCode {
            case NSURLErrorTimedOut:
                reason = .timedOut
            case NSURLErrorBadURL, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed, NSURLErrorUnsupportedURL, NSURLErrorBadServerResponse:
                reason = .hostNotFound
            case NSURLErrorNetworkConnectionLost:
                reason = .networkLost
            default:
                reason = .error
            }
        }
        
        onDisconnected?(reason, error)
    }
}

