//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Promise
import Combine
import lib0

public class YDocument: LZObservableObject, JSHashable {
    public let guid: String
    public var gc: Bool
    
    public internal(set) var collectionid: String?
    public internal(set) var clientID: Int
    
    public var subdocs: Set<YDocument> = []
    
    public var shouldLoad: Bool
    public var autoLoad: Bool
    
    public var meta: Any?
    public var isLoaded: Bool = false
    public var isSynced: Bool = false
    
    public internal(set) var whenLoaded: Promise<Void, Never>!
    public internal(set) var whenSynced: Promise<Void, Never>!
    
    var share: [String: YOpaqueObject] = [:]
    let store = YStructStore()
    
    var _gcFilter: (YItem) -> Bool
    var _item: YItem?
    var _transaction: YTransaction?
    var _transactionCleanups: RefArray<YTransaction> = []
    
    var _subdocGuids: Set<String> { Set(self.subdocs.map{ $0.guid }) }

    public init(_ options: Options = Options()) {
        self.gc = options.gc
        self.clientID = options.cliendID ?? YDocument.generateNewClientID()
        self.guid = options.guid ?? YDocument.generateDocGuid()
        self.collectionid = options.collectionid
        self.shouldLoad = options.shouldLoad
        self.autoLoad = options.autoLoad
        self.meta = options.meta
        
        self._gcFilter = options.gcFilter
        
        super.init()
        
        self.whenLoaded = Promise{ resolve, _ in
            self.on(On.load) {
                self.isLoaded = true
                resolve(())
            }
        }
                        
        func provideSyncedPromise() -> Promise<Void, Never> {
            .init{ resolve, _ in
                var disposer: Disposer!
                disposer = self.on(On.sync, { isSynced in
                    if isSynced {
                        self.off(On.sync, disposer)
                        resolve(())
                    }
                })
            }
        }
        
        self.on(On.sync) { isSynced in
            if !isSynced, self.isSynced {
                self.whenSynced = provideSyncedPromise()
            }
            self.isSynced = isSynced
            if !self.isLoaded { self.emit(On.load, ()) }
        }
        self.whenSynced = provideSyncedPromise()
    }

    public func load() {
        if let item = self._item, !self.shouldLoad {
            item.parent?.object?.document?.transact{ transaction in
                transaction.subdocsLoaded.insert(self)
            }
        }
        self.shouldLoad = true
    }

    public func transact(origin: Any? = nil, local: Bool = true, _ body: () throws -> Void) rethrows {
        try self.transact(origin: origin, local: local, {_ in try body() })
    }
        
    public func transact(origin: Any? = nil, local: Bool = true, _ body: (YTransaction) throws -> Void) rethrows {
        try YTransaction.transact(self, origin: origin, local: local, body)
    }

    func get<T: YOpaqueObject>(_ name: String = "", _ make: () -> T) -> T {
        var thisSet = false
        let object = self.share.setIfUndefined(name, {
            let object = make()
            thisSet = true
            return object
        }())
        
        if thisSet {
            object._integrate(self, item: nil)
        }
        
        if T.self != YOpaqueObject.self && !(object is T) {
            guard type(of: object) == YOpaqueObject.self else {
                fatalError("Type with the name '\(name)' has already been defined with a '\(type(of: object).self)'")
            }
            
            let newObject = make()
            newObject.storage = object.storage
            for item in object.storage.values {
                for item in item.leftSequence() {
                    item.parent = .object(newObject)
                }
            }
            newObject._start = object._start
            for item in YItem.RightSequence(start: newObject._start) {
                item.parent = .object(newObject)
            }
            
            newObject._length = object._length
            self.share[name] = newObject
            newObject._integrate(self, item: nil)
            return newObject
        }
        
        return object as! T
    }

    public func getMap<T: YElement>(_: T.Type, _ name: String = "") -> YMap<T> {
        YMap(opaque: self.getOpaqueMap(name))
    }
    public func getOpaqueMap(_ name: String = "") -> YOpaqueMap {
        self.get(name) { YOpaqueMap() }
    }
    
    public func getArray<T: YElement>(_: T.Type, _ name: String = "") -> YArray<T> {
        YArray(opaque: self.getOpaqueArray(name))
    }
    public func getOpaqueArray(_ name: String = "") -> YOpaqueArray {
        self.get(name) { YOpaqueArray() }
    }
    
    public func getText(_ name: String = "") -> YText {
        self.get(name) { YText() }
    }
    
    public func getObject<T: YObject>(_: T.Type, _ name: String = "") -> T {
        self.get(name) { T() }
    }
    
    public func toJSON() -> [String: Any] {
        var doc: [String: Any] = [:]
        self.share.forEach{ key, value in
            doc[key] = value.toJSON()
        }
        return doc
    }

    public override func destroy() {
        self.subdocs.forEach{ $0.destroy() }
        let item = self._item
        if item != nil {
            self._item = nil
                        
            let content = item!.content as? YDocumentContent
            
            // swift add
            var copiedOptions = Options()
            copiedOptions.guid = self.guid
            if let gc = content?.options.gc { copiedOptions.gc = gc }
            if let meta = content?.options.meta { copiedOptions.meta = meta }
            if let autoLoad = content?.options.autoLoad { copiedOptions.autoLoad = autoLoad }
            copiedOptions.shouldLoad = false
            
            let subdoc = YDocument(copiedOptions)
            content?.document = subdoc
            content?.document._item = item!
            
            item!.parent!.object!.document?.transact{ transaction in
                let doc = subdoc
                if !item!.deleted { transaction.subdocsAdded.insert(doc) }
                transaction.subdocsRemoved.insert(self)
            }
        }
        self.emit(On.destroyed, true)
        self.emit(On.destroy, ())
        super.destroy()
    }
}

extension YDocument {
    public var updatePublisher: some Publisher<YUpdate, Never> {
        self.publisher(for: On.update).map{ $0.update }
    }
    public var updateV2Publisher: some Publisher<YUpdate, Never> {
        self.publisher(for: On.updateV2).map{ $0.update }
    }
    
    public enum On {
        public static let load = YDocument.EventName<Void>("load")
        public static let sync = YDocument.EventName<Bool>("sync")
        
        public static let destroy = YDocument.EventName<Void>("destroy")
        public static let destroyed = YDocument.EventName<Bool>("destroyed")
        
        public static let update = YDocument.EventName<(update: YUpdate, origin: Any?, YTransaction)>("update")
        public static let updateV2 = YDocument.EventName<(update: YUpdate, origin: Any?, YTransaction)>("updateV2")
        
        public static let subdocs = YDocument.EventName<(SubDocEvent, YTransaction)>("subdocs")
        
        public static let beforeObserverCalls = YDocument.EventName<YTransaction>("beforeObserverCalls")
        
        public static let beforeTransaction = YDocument.EventName<YTransaction>("beforeTransaction")
        public static let afterTransaction = YDocument.EventName<YTransaction>("afterTransaction")
                        
        public static let beforeAllTransactions = YDocument.EventName<Void>("beforeAllTransactions")
        public static let afterAllTransactions = YDocument.EventName<[YTransaction]>("afterAllTransactions")
        
        public static let afterTransactionCleanup = YDocument.EventName<YTransaction>("afterTransactionCleanup")
    
        public struct SubDocEvent {
            public let loaded: Set<YDocument>
            public let added: Set<YDocument>
            public let removed: Set<YDocument>
        }
    }
}

extension YDocument {
    static func generateDocGuid() -> String {
        #if DEBUG // to remove randomness
        enum __ { static var cliendID: UInt = 0 }
        if NSClassFromString("XCTest") != nil {
            __.cliendID += 1
            return String(__.cliendID)
        }
        print("THIS RUN HAS RANDOMNESS")
        #endif
        return UUID().uuidString
    }
    
    static func generateNewClientID() -> Int {
        #if DEBUG // to remove randomness
        enum __ { static var cliendID: Int = 0 }
        if NSClassFromString("XCTest") != nil {
            __.cliendID += 1
            return __.cliendID
        }
        print("THIS RUN HAS RANDOMNESS")
        #endif
        
        return Int(UInt32.random(in: UInt32.min...UInt32.max))
    }
}

extension YDocument {
    public struct Options {
        public var gc: Bool = true
        public var guid: String?
        public var collectionid: String?
        public var meta: Any?
        public var autoLoad: Bool
        public var shouldLoad: Bool
        public var cliendID: Int?
        
        // pending...
        var gcFilter: (YItem) -> Bool = {_ in true }
        
        public init(gc: Bool = true, guid: String? = nil, collectionid: String? = nil, meta: Any? = nil, autoLoad: Bool = false, shouldLoad: Bool = true, cliendID: Int? = nil) {
            self.gc = gc
            self.guid = guid
            self.collectionid = collectionid
            self.meta = meta
            self.autoLoad = autoLoad
            self.shouldLoad = shouldLoad
            self.cliendID = cliendID
        }
    }
}
