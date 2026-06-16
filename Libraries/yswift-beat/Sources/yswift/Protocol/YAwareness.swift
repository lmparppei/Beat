
import Foundation
import Combine
import lib0

private let outdatedTimeout: TimeInterval = 30000 / 1000

final public class YAwareness<State: Codable> {
    public typealias Update = YOpaqueAwareness.Update
    public typealias Origin = YOpaqueAwareness.Origin
    
    public let opaque = YOpaqueAwareness()
    
    public var clientID: Int { opaque.clientID }
    
    public var updatePublisher: some Publisher<(update: Update, origin: Origin), Never> { opaque.updatePublisher }
    public var changePublisher: some Publisher<(update: Update, origin: Origin), Never> { opaque.changePublisher }
    public var errorPublisher: some Publisher<Error, Never> { _errorPublisher }
    
    @LZObservable
    public var states: [Int: State] = [:]
    
    @LZObservable
    public var localState: State? { didSet { self._setState(localState) } }
    
    private var _errorPublisher = PassthroughSubject<Error, Never>()
    
    private let _dictionaryEncoder = DictionaryEncoder(dataEncoding: .base64)
    private let _dictionaryDecoder = DictionaryDecoder()
    
    private var _objectBag = [AnyCancellable]()
    
    public init() {}
        
    public func register(_ document: YDocument) {
        self.opaque.register(document)
        self.opaque.changePublisher
            .sink{[unowned self] in self._handleChange($0.update) }.store(in: &_objectBag)
    }
    
    public func applyUpdate(_ update: Data, origin: Origin) {
        do {
            try self.opaque.applyUpdate(update, origin: origin)
        } catch {
            self._errorPublisher.send(error)
        }
    }
    
    public func encodeUpdate(of clients: [Int]) -> Data? {
        self.opaque.encodeUpdate(of: clients)
    }
    
    public func encodeUpdateAll() -> Data? {
        self.opaque.encodeUpdate(of: self.opaque.states.keys.map{ $0 })
    }
    
    public func removeStates(of clients: [Int], origin: Origin) {
        self.opaque.removeStates(of: clients, origin: origin)
    }
    
    private func _setState(_ state: State?) {
        do {
            let state = try self._dictionaryEncoder.encode(state)
            self.opaque.localState = state
        } catch {
            self._errorPublisher.send(error)
        }
    }
    
    private func _handleChange(_ udpate: YOpaqueAwareness.Update) {
        for client in udpate.changed {
            do {
                let state = try self._dictionaryDecoder.decode(State?.self, from: self.opaque.states[client])
                self.states[client] = state
                if client == self.clientID {
                    self.localState = state
                }
            } catch {
                self._errorPublisher.send(error)
            }
        }
    }
}

final public class YOpaqueAwareness {
    public struct Update {
        public let added: [Int]
        public let updated: [Int]
        public let removed: [Int]
        
        public var changed: Set<Int> { Set(added + updated + removed) }
    }
    
    public enum Origin {
        case unspecified
        case local
        case timeout
        case custom(Any?)
    }
    
    private struct ClientMeta {
        let clock: Int
        let lastUpdated: Double
    }
        
    public private(set) var clientID: Int = -1
    
    @LZObservable
    public var states: [Int: Any] = [:]
    
    public var updatePublisher: some Publisher<(update: YOpaqueAwareness.Update, origin: Origin), Never> { _updatePublisher }
    public var changePublisher: some Publisher<(update: YOpaqueAwareness.Update, origin: Origin), Never> { _changePublisher }
    
    private var meta: [Int: ClientMeta] = [:]

    private let _updatePublisher = PassthroughSubject<(update: YOpaqueAwareness.Update, origin: Origin), Never>()
    private let _changePublisher = PassthroughSubject<(update: YOpaqueAwareness.Update, origin: Origin), Never>()
    private var _checkTimer: Timer!
    
    public init() {}
    
    public func register(_ document: YDocument) {
        assert(clientID == -1, "This awareness already inialized.")
        self.clientID = document.clientID
        
        self._checkTimer = Timer.scheduledTimer(withTimeInterval: outdatedTimeout / 10, repeats: true) {[weak self] timer in
            guard let self = self else { return timer.invalidate() }
            let now = Date().timeIntervalSince1970
            guard let meta = self.meta[self.clientID] else { return }

            if outdatedTimeout / 2 <= now - meta.lastUpdated {
                self.localState = self.localState
            }
            let removedClients = self.meta
                .filter{ (client, meta) in client != self.clientID && outdatedTimeout <= now - meta.lastUpdated && self.states[client] != nil }
                .map{ $0.key }
            
            if removedClients.count > 0 {
                self.removeStates(of: removedClients, origin: .timeout)
            }
        }
        
        document.on(YDocument.On.destroy) {
            self._checkTimer.invalidate()
        }
        
        self.localState = [String: Any]()
    }

    public var localState: Any? {
        get {
            assert(clientID != -1, "Use of uninitialized awareness.")
            return self.states[self.clientID]
        }
        set { self._updateLocalState(newValue) }
    }

    public func applyUpdate(_ update: Data, origin: Origin = .unspecified) throws {
        assert(clientID != -1, "Use of uninitialized awareness.")
        
        let decoder = LZDecoder(update)
        let timestamp = Date().timeIntervalSince1970
        var added = [Int](), updated = [Int](), removed = [Int](), filteredUpdated = [Int]()
        
        for _ in 0..<(try decoder.readUInt()) {
            let clientID = Int(try decoder.readUInt())
            var clock = Int(try decoder.readUInt())
            var state = try JSONSerialization.jsonObject(with: decoder.readData(), options: [.fragmentsAllowed]) as Any?
            if state is NSNull { state = nil }
            let clientMeta = self.meta[clientID]
            let prevState = self.states[clientID]
            let currentClock = clientMeta.map{ $0.clock } ?? 0

            if currentClock < clock || (currentClock == clock && state == nil && self.states[clientID] != nil) {
                if state == nil {
                    if clientID == self.clientID {
                        clock += 1
                    } else {
                        self.states.removeValue(forKey: clientID)
                    }
                } else {
                    self.states[clientID] = state
                }
                self.meta[clientID] = ClientMeta(clock: clock, lastUpdated: timestamp)
                
                if clientMeta == nil && state != nil {
                    added.append(clientID)
                } else if clientMeta != nil && state == nil {
                    removed.append(clientID)
                } else if state != nil {
                    if !equalJSON(state, prevState) { filteredUpdated.append(clientID) }
                    updated.append(clientID)
                }
            }
        }
        
        if added.count > 0 || filteredUpdated.count > 0 || removed.count > 0 {
            self._changePublisher.send((Update(added: added, updated: filteredUpdated, removed: removed), origin))
        }
        if added.count > 0 || updated.count > 0 || removed.count > 0 {
            self._updatePublisher.send((Update(added: added, updated: updated, removed: removed), origin))
        }
    }

    public func encodeUpdate(of clients: [Int]) -> Data? {
        assert(clientID != -1, "Use of uninitialized awareness.")
        
        let encoder = LZEncoder()
        encoder.writeUInt(UInt(clients.count))
        
        for clientID in clients {
            let state = states[clientID]
            guard let clock = self.meta[clientID]?.clock else { return nil }
            encoder.writeUInt(UInt(clientID))
            encoder.writeUInt(UInt(clock))
            let data = try! JSONSerialization.data(withJSONObject: state ?? NSNull(), options: [.fragmentsAllowed])
            encoder.writeData(data)
        }
        return encoder.data
    }
    
    public func removeStates(of clients: [Int], origin: Origin = .unspecified) {
        assert(clientID != -1, "Use of uninitialized awareness.")
        
        var removed: [Int] = []
        for clientID in clients where self.states[clientID] != nil {
            self.states.removeValue(forKey: clientID)
            
            if clientID == self.clientID {
                guard let meta = self.meta[clientID] else { continue }
                self.meta[clientID] = ClientMeta(clock: meta.clock + 1, lastUpdated: Date().timeIntervalSince1970)
            }
            removed.append(clientID)
        }
        if removed.count > 0 {
            self._changePublisher.send((update: Update(added: [], updated: [], removed: removed), origin: origin))
            self._updatePublisher.send((update: Update(added: [], updated: [], removed: removed), origin: origin))
        }
    }
    
    private func _updateLocalState(_ newValue: Any?) {
        assert(clientID != -1, "Use of uninitialized awareness.")
        
        let clock = self.meta[clientID].map{ $0.clock + 1 } ?? 0
        let prevState = self.states[clientID]

        if newValue == nil {
            self.states.removeValue(forKey: clientID)
        } else {
            self.states[clientID] = newValue
        }
        self.meta[clientID] = ClientMeta(clock: clock, lastUpdated: Date().timeIntervalSince1970)

        var added = [Int](), updated = [Int](), removed = [Int](), filteredUpdated = [Int]()
        
        if newValue == nil {
            removed.append(clientID)
        } else if prevState == nil {
            if newValue != nil { added.append(clientID) }
        } else {
            updated.append(clientID)
            if !equalJSON(prevState, newValue) { filteredUpdated.append(clientID) }
        }
        if added.count > 0 || filteredUpdated.count > 0 || removed.count > 0 {
            self._changePublisher.send((Update(added: added, updated: filteredUpdated, removed: removed), .local))
        }
        self._updatePublisher.send((Update(added: added, updated: updated, removed: removed), .local))
    }
}

