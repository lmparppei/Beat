//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class YOpaqueMap: YOpaqueObject {
    public var count: Int {
        if document != nil { return self.storage.lazy.filter{ _, v in !v.deleted }.count }
        return self._prelimContent.count
    }
    
    public var isEmpty: Bool {
        if document != nil { return self.storage.lazy.filter{ _, v in !v.deleted }.isEmpty }
        return self._prelimContent.isEmpty
    }
    
    private var _prelimContent: [String: Any?]
    
    public init(_ contents: [String: Any?]? = nil) {
        self._prelimContent = contents ?? [:]
        super.init()
    }
    
    public subscript(key: String) -> Any? {
        get { self.get(key) }
        set { self.set(key, value: newValue) }
    }
    
    public func get(_ key: String) -> Any? {
        if document != nil { return mapGet(key) }
        return self._prelimContent[key] ?? nil
    }
    
    public func set(_ key: String, value: Any?) {
        assert(!(value is any YWrapperObject), "You should not put wrapper directory to opaque object.")
        
        if let doc = self.document {
            doc.transact{ self.mapSet($0, key: key, value: value) }
        } else {
            self._prelimContent[key] = value ?? NSNull()
        }
    }
    
    public func keys() -> some Sequence<String> {
        self.innerSequence().map{ key, _ in key }
    }
    
    public func values() -> some Sequence<Any?> {
        self.innerSequence().map{ _, value in value }
    }
    
    public func contains(_ key: String) -> Bool {
        if document != nil { return self.mapHas(key) }
        return self._prelimContent[key] != nil
    }
    
    public func removeValue(forKey key: String) -> Any? {
        let value = (self[key] as? YOpaqueObject).map{ $0.copy() } ?? self[key]
        self.deleteValue(forKey: key)
        return value
    }
    
    public func deleteValue(forKey key: String) {
        if let doc = self.document {
            doc.transact{ self.mapDelete($0, key: key) }
        } else {
            self._prelimContent.removeValue(forKey: key)
        }
    }

    public func removeAll() {
        if let doc = self.document {
            doc.transact{ for key in self.keys() { self.mapDelete($0, key: key) } }
        } else {
            self._prelimContent.removeAll()
        }
    }
    
    public override func copy() -> YOpaqueMap {
        let map = YOpaqueMap()
        for (key, value) in self {
            map.set(key, value: (value as? YOpaqueObject).map{ $0.copy() } ?? value)
        }
        return map
    }

    public override func toJSON() -> Any {
        var map: [String: Any] = [:]
        for (key, value) in self {
            if value == nil {
                map[key] = NSNull()
            } else if let v = value as? YOpaqueObject {
                map[key] = v.toJSON()
            } else {
                map[key] = value
            }
        }
        return map
    }
    
    // ============================================================================== //
    // MARK: - Private -
    override func _write(_ encoder: YUpdateEncoder) {
        encoder.writeTypeRef(YMapRefID)
    }
    
    override func _integrate(_ y: YDocument, item: YItem?) {
        super._integrate(y, item: item)
        
        for (key, value) in self._prelimContent {
            self.set(key, value: value)
        }
        self._prelimContent.removeAll()
    }

    override func _copy() -> YOpaqueMap {
        return YOpaqueMap()
    }

    override func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) {
        self.callObservers(transaction: transaction, event: YOpaqueMapEvent(self, transaction: transaction, keysChanged: _parentSubs))
    }
}


extension YOpaqueMap: Sequence {
    public typealias Element = (key: String, value: Any?)
    
    private func innerSequence() -> AnySequence<Element> {
        if document != nil {
            return AnySequence(self.storage.lazy.filter{ _, v in !v.deleted }
                .map{ ($0, $1.content.values[$1.length - 1]) })
        }
        return AnySequence(self._prelimContent)
    }
    
    public func makeIterator() -> some IteratorProtocol<Element> {
        return self.innerSequence().makeIterator()
    }
}

extension YOpaqueMap: CustomStringConvertible {
    public var description: String { String(describing: self.toJSON()) }
}


func readYMap(_decoder: YUpdateDecoder) -> YOpaqueMap {
    return YOpaqueMap()
}
