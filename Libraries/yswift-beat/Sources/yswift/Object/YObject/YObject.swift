//
//  File.swift
//
//
//  Created by yuki on 2023/03/16.
//

import Foundation
import Combine

open class YObject: YOpaqueObject {
    
    final public let localStorage = NSMutableDictionary()
    
    final public private(set) var objectID: YObjectID!
        
    final var _prelimContent: [String: Any?] = [:]
    final var _propertyTable: [String: any _YObjectProperty] = [:]
    
    public required override init() {
        if case .decode = YObject.initContext {
            self.objectID = nil
        } else {
            self.objectID = .publish()
        }
        
        super.init()
                
        self.observe{[unowned self] event, _ in
            guard let event = event as? YObjectEvent else { return }
            for case let key? in event.keysChanged {
                self._propertyTable[key]?.send(self.mapGet(key))
            }
        }
        
        if case .decode = YObject.initContext { return }
        self._setValue(self.objectID.value, for: YObject.objectIDKey)
        YObjectStore.shared.register(self)
    }
    
    final override func _onStorageUpdated() {
        guard self.objectID == nil, self.storage[YObject.objectIDKey] != nil else { return }
        let id = self.mapGet(YObject.objectIDKey) as! Int
        self.objectID = YObjectID(id)
        YObjectStore.shared.register(self)
    }

    final public override func copy() -> Self {
        let map = Self()
        if case .smartcopy(let context) = YObject.initContext {
            context.table[self.objectID.value] = map.objectID.value
        }
        for (key, value) in self.elementSequence() {
            if case .smartcopy(let context) = YObject.initContext, key == YObject.objectIDKey || key.starts(with: "&") {
                self._copyWithSmartCopy(map: map, value: value, key: key, context: context)
            } else if let value = value as? YOpaqueObject {
                map._setValue(value.copy(), for: key)
            } else {
                map._setValue(value, for: key)
            }
        }
        return map
    }
    
    final func _getValue(for key: String) -> Any? {
        if self.document != nil { return self.mapGet(key) }
        return _prelimContent[key] ?? nil
    }
    
    final func _setValue(_ value: Any?, for key: String) {
        if let doc = self.document {
            doc.transact{ self.mapSet($0, key: key, value: value) }
        } else {
            self._prelimContent[key] = value
            self._propertyTable[key]?.send(value)
        }
    }

    final override func _write(_ encoder: YUpdateEncoder) {
        guard let typeID = YObject.typeIDTable[ObjectIdentifier(type(of: self))] else {
            fatalError("This object is not registerd.")
        }
        encoder.writeTypeRef(typeID)
    }
    
    final override func _integrate(_ y: YDocument, item: YItem?) {
        super._integrate(y, item: item)
                
        for (key, value) in self._prelimContent {
            self._setValue(value, for: key)
        }
        self._prelimContent.removeAll()
    }

    final override func _copy() -> YObject { return Self() }

    final override func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) {
        self.callObservers(
            transaction: transaction,
            event: YObjectEvent(self, transaction: transaction, keysChanged: _parentSubs)
        )
    }
}

extension YObject {
    func elementSequence() -> AnySequence<(String, Any?)> {
        if self.document == nil {
            return AnySequence(self._prelimContent.lazy
                .map{ ($0, $1) })
        } else {
            return AnySequence(self.storage.lazy.filter{ _, v in !v.deleted }
                .map{ ($0, $1.content.values[$1.length - 1]) })
        }
    }
}

extension YObject {
    enum InitContext {
        case unspecified
        case decode
        case smartcopy(SmartCopyContext)
    }
    
    final class SmartCopyContext {
        var table: [YObjectID.RawValue: YObjectID.RawValue] = [:]
        var writers: [YObjectID.RawValue: (YObjectID.RawValue) -> ()] = [:]
    }
    
    static let objectIDKey = "#"
    static var initContext: InitContext = .unspecified
    static var typeIDTable: [ObjectIdentifier: Int] = [:]
}
