//
//  File.swift
//
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import Combine
 
open class YOpaqueObject: JSHashable {
        
    // =========================================================================== //
    // MARK: - Property -
    public var document: YDocument? = nil

    var _parentObject: YOpaqueObject? { self._objectItem?.parent?.object }
    
    var _objectItem: YItem? = nil
    
    var storage: [String: YItem] = [:] { didSet { self._onStorageUpdated() } }
    
    var serchMarkers: RefArray<YArraySearchMarker>? = nil

    var _start: YItem? = nil
    var _length: Int = 0
    
    let _eventHandler: YEventHandler<(event: YEvent, YTransaction)> = YEventHandler()
    let _deepEventHandler: YEventHandler<(events: [YEvent], YTransaction)> = YEventHandler()

    var _first: YItem? {
        var item = self._start
        while let uitem = item, uitem.deleted { item = uitem.right as? YItem }
        return item
    }

    // =========================================================================== //
    // MARK: - Abstract Methods -

    public func copy() -> Self { fatalError() }

    func _copy() -> YOpaqueObject { fatalError() }
    
    func _onStorageUpdated() {}

    // =========================================================================== //
    // MARK: - Methods -

    public init() {}

    func getChildren() -> [YItem] {
        var item = self._start
        var arr: [YItem] = []
        while (item != nil) {
            arr.append(item!)
            item = item!.right as? YItem
        }
        return arr
    }

    func isParentOf(child: YItem?) -> Bool {
        var child = child
        while (child != nil) {
            if child!.parent?.object === self { return true }
            child = child?.parent?.object?._objectItem
        }
        return false
    }

    func callObservers(transaction: YTransaction, event: YEvent) {
        var type = self
        let changedType = type
        
        while true {
            if transaction.changedParentTypes[type] == nil { transaction.changedParentTypes[type] = [] }
            transaction.changedParentTypes[type]!.append(event)
            guard let object = type._objectItem?.parent?.object else { break }
            type = object
        }
        
        changedType._eventHandler.callListeners((event, transaction))
    }

    // =========================================================================== //
    // MARK: - Private Methods (Temporally public) -
    
    func _integrate(_ y: YDocument, item: YItem?) {
        self.document = y
        self._objectItem = item
    }

    func _write(_ _encoder: YUpdateEncoder) {}

    func _callObserver(_ transaction: YTransaction, _parentSubs: Set<String?>) {
        if !transaction.local && self.serchMarkers != nil {
            self.serchMarkers!.value.removeAll()
        }
    }

    /** Observe all events that are created on this type. */
    @discardableResult
    public func observe(_ f: @escaping (YEvent, YTransaction) -> Void) -> UUID {
        self._eventHandler.addListener(f)
    }

    /** Observe all events that are created by this type and its children. */
    @discardableResult
    public func observeDeep(_ f: @escaping ([YEvent], YTransaction) -> Void) -> UUID {
        self._deepEventHandler.addListener(f)
    }

    /** Unregister an observer function. */
    public func unobserve(_ disposer: UUID) {
        self._eventHandler.removeListener(disposer)
    }

    /** Unregister an observer function. */
    public func unobserveDeep(_ disposer: UUID) {
        self._deepEventHandler.removeListener(disposer)
    }

    public func toJSON() -> Any {
        fatalError()
    }
}

extension YOpaqueObject {
    func findRootTypeKey() -> String {
        for (key, value) in self.document?.share ?? [:] {
            if value === self { return key }
        }
        fatalError("Key not found. \(self)")
    }
}

extension YOpaqueObject: YElement {
    public static func fromOpaque(_ opaque: Any?) -> Self { opaque as! Self }
    
    public func toOpaque() -> Any? { self }
}
