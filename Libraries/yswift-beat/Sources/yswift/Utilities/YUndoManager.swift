//
//  File.swift
//
//
//  Created by yuki on 2023/03/17.
//

import Foundation
import Combine
import lib0

final public class YUndoManager: JSHashable {
    
    public let doc: YDocument
    public let trackedOrigins: TrackOrigins
    
    public private(set) var undoing: Bool = false
    public private(set) var redoing: Bool = false
    
    public var stackCleanred: some Publisher<CleanEvent, Never> { _stackCleanred }
    public var stackItemAdded: some Publisher<YUndoManager.ChangeEvent, Never> { _stackItemAdded }
    public var stackItemPopped: some Publisher<YUndoManager.ChangeEvent, Never> { _stackItemPopped }
    public var stackItemUpdated: some Publisher<YUndoManager.ChangeEvent, Never> { _stackItemUpdated }
    
    private let _stackCleanred = PassthroughSubject<CleanEvent, Never>()
    private let _stackItemAdded = PassthroughSubject<YUndoManager.ChangeEvent, Never>()
    private let _stackItemPopped = PassthroughSubject<YUndoManager.ChangeEvent, Never>()
    private let _stackItemUpdated = PassthroughSubject<YUndoManager.ChangeEvent, Never>()

    let scope: RefArray<YOpaqueObject> = []
    let deleteFilter: (YItem) -> Bool
    let captureTimeout: TimeInterval
    let ignoreRemoteMapChanges: Bool
    
    var captureTransaction: (YTransaction) -> Bool
    var undoStack: RefArray<StackItem> = []
    var redoStack: RefArray<StackItem> = []
    var lastChange: Date = Date.distantPast
    
    private var afterTransactionDisposer: LZObservableObject.Disposer!
    
    public convenience init<T: YWrapperObject>(_ scope: T, options: Options = .make()) {
        self.init([scope.opaque], options: options)
    }
    public convenience init<T: YWrapperObject>(_ scope: [T], options: Options = .make()) {
        self.init(scope.map{ $0.opaque }, options: options)
    }
    public convenience init(_ scope: YOpaqueObject, options: Options = .make()) {
        self.init([scope], options: options)
    }

    public init(_ scope: [YOpaqueObject], options: Options = .make()) {
        assert((options.document ?? scope[0].document) != nil, "You must provide document.")
        
        self.deleteFilter = options.deleteFilter
        self.captureTransaction = options.captureTransaction
        self.doc = options.document ?? scope[0].document!
        self.ignoreRemoteMapChanges = options.ignoreRemoteMapChanges
        self.captureTimeout = options.captureTimeout
        self.trackedOrigins = options.trackedOrigins
                
        self.addToScope(scope)
        self.trackedOrigins.append(self)
        
        self.afterTransactionDisposer = self.doc.on(YDocument.On.afterTransaction) {
            self.afterTransaction($0)
        }
        
        self.doc.on(YDocument.On.destroy) {
            self.destroy()
        }
    }

    public func addToScope<T: YWrapperObject>(_ object: T) {
        self.addToScope([object])
    }
    public func addToScope(_ object: YOpaqueObject) {
        self.addToScope([object])
    }
    public func addToScope<T: YWrapperObject>(_ objects: [T]) {
        self.addToScope(objects.map{ $0.opaque })
    }
    public func addToScope(_ objects: [YOpaqueObject]) {
        for object in objects {
            if self.scope.allSatisfy({ $0 !== object }) {
                self.scope.value.append(object)
            }
        }
    }

    public func addTrackedOrigin(_ origin: Any?) {
        self.trackedOrigins.append(origin)
    }
    public func removeTrackedOrigin(_ origin: Any?) {
        self.trackedOrigins.remove(origin)
    }

    public func clear(clearUndoStack: Bool = true, clearRedoStack: Bool = true) {
        guard (clearUndoStack && self.canUndo()) || (clearRedoStack && self.canRedo()) else { return }
        
        self.doc.transact{ tr in
            if clearUndoStack {
                for item in undoStack { self.clearStackItem(tr, stackItem: item) }
                self.undoStack = []
            }
            if clearRedoStack {
                for item in self.redoStack { self.clearStackItem(tr, stackItem: item) }
                self.redoStack = []
            }
            self._stackCleanred.send(CleanEvent(undoStackCleared: clearUndoStack, redoStackCleared: clearRedoStack))
        }
    }

    public func stopCapturing() {
        self.lastChange = Date.distantPast
    }

    @discardableResult
    public func undo() -> StackItem? {
        self.undoing = true; defer { self.undoing = false }
        return self.popStackItem(self.undoStack, eventType: .undo)
    }

    @discardableResult
    public func redo() -> StackItem? {
        self.redoing = true; defer { self.redoing = false }
        return self.popStackItem(self.redoStack, eventType: .redo)
    }

    public func canUndo() -> Bool { self.undoStack.count > 0 }

    public func canRedo() -> Bool { self.redoStack.count > 0 }

    public func destroy() {
        self.trackedOrigins.remove(self)
        self.doc.off(YDocument.On.afterTransaction, self.afterTransactionDisposer)
    }
    
    private func clearStackItem(_ tr: YTransaction, stackItem: StackItem) {
        stackItem.deletions.iterate(tr) { item in
            if let item = item as? YItem, self.scope.contains(where: { $0.isParentOf(child: item) }) {
                item.keepRecursive(keep: false)
            }
        }
    }
    
    private func afterTransaction(_ transaction: YTransaction) {
        // Only track certain transactions
        guard self.captureTransaction(transaction) else { return }
        guard self.scope.contains(where: { transaction.changedParentTypes.keys.contains($0) }) else { return }
        guard self.trackedOrigins.contains(transaction.origin) else { return }
        
        let undoing = self.undoing
        let redoing = self.redoing
        let stack = undoing ? self.redoStack : self.undoStack
        if undoing {
            self.stopCapturing() // next undo should not be appended to last stack item
        } else if !redoing {
            // neither undoing nor redoing: delete redoStack
            self.clear(clearUndoStack: false, clearRedoStack: true)
        }
        let insertions = YDeleteSet()
        for (client, endClock) in transaction.afterState {
            let startClock = transaction.beforeState[client] ?? 0
            let len = endClock - startClock
            if len > 0 {
                insertions.add(client: client, clock: startClock, length: len)
            }
        }
        
        let now = Date()
        var didAdd = false
        if self.lastChange > Date.distantPast, now.timeIntervalSince(self.lastChange) < self.captureTimeout, stack.count > 0, !undoing, !redoing {
            // append change to last stack op
            let lastOp = stack[stack.count - 1]
            lastOp.deletions = YDeleteSet.mergeAll([lastOp.deletions, transaction.deleteSet])
            lastOp.insertions = YDeleteSet.mergeAll([lastOp.insertions, insertions])
        } else {
            // create a stack op
            stack.value.append(StackItem(transaction.deleteSet, insertions: insertions))
            didAdd = true
        }
        
        if !undoing, !redoing { self.lastChange = now }
        
        // make sure that deleted structs are not gc'd
        transaction.deleteSet.iterate(transaction) { item in
            if let item = item as? YItem, self.scope.contains(where: { $0.isParentOf(child: item) }) {
                item.keepRecursive(keep: true)
            }
        }

        let changeEvent = ChangeEvent(
            origin: transaction.origin,
            stackItem: stack[stack.count - 1],
            type: undoing ? .redo : .undo,
            undoStackCleared: nil,
            changedParentTypes: transaction.changedParentTypes
        )

        if didAdd {
            self._stackItemAdded.send(changeEvent)
        } else {
            self._stackItemUpdated.send(changeEvent)
        }
    }
    
    private func popStackItem(_ stack: RefArray<StackItem>, eventType: EvnetType) -> StackItem? {
        var result: StackItem? = nil
        var _tr: YTransaction? = nil
        let doc = self.doc
        let scope = self.scope
        
        doc.transact(origin: self) { transaction in
            while (stack.count > 0 && result == nil) {
                let store = doc.store
                let stackItem = stack.value.popLast()!
                var itemsToRedo = Set<YItem>()
                var itemsToDelete: [YItem] = []

                var performedChange = false
                stackItem.insertions.iterate(transaction) { struct_ in
                    var struct_ = struct_
                    if struct_ is YItem {
                        if (struct_ as! YItem).redone != nil {
                            let redone = StructRedone.followRedone(store: store, id: struct_.id)
                            var item = redone.item, diff = redone.diff
                            if diff > 0 {
                                item = YStructStore.getItemCleanStart(transaction, id: YIdentifier(client: item.id.client, clock: item.id.clock + diff))
                            }
                            struct_ = item
                        }
                        if !struct_.deleted && scope.contains(where: { type in type.isParentOf(child: (struct_ as! YItem)) }) {
                            itemsToDelete.append(struct_ as! YItem)
                        }
                    }
                }
                stackItem.deletions.iterate(transaction) { struct_ in
                    if (
                        struct_ is YItem &&
                        scope.contains(where: { type in type.isParentOf(child: (struct_ as! YItem)) }) &&
                        // Never redo structs in stackItem.insertions because they were created and deleted in the same capture interval.
                        !stackItem.insertions.isDeleted(struct_.id)
                    ) {
                        itemsToRedo.insert(struct_ as! YItem)
                    }
                }
                for struct_ in itemsToRedo {
                    let redo = struct_
                        .redo(transaction,
                              redoitems: itemsToRedo,
                              itemsToDelete: stackItem.insertions,
                              ignoreRemoteMapChanges: self.ignoreRemoteMapChanges
                        )
                    performedChange = performedChange || redo != nil
                }
                for i in (0..<itemsToDelete.count).reversed() {
                    let item = itemsToDelete[i]
                    if self.deleteFilter(item) {
                        item.delete(transaction)
                        performedChange = true
                    }
                }
                result = performedChange ? stackItem : nil
            }
            transaction.changed.forEach({ type, subProps in
                // destroy search marker if necessary
                if subProps.contains(nil) && type.serchMarkers != nil {
                    type.serchMarkers!.value.removeAll()
                }
            })
            _tr = transaction
        }
        
        if let result = result {
            let changedParentTypes = _tr!.changedParentTypes
            self._stackItemPopped.send(ChangeEvent(stackItem: result, type: eventType, changedParentTypes: changedParentTypes))
        }
        return result
    }

}


extension YUndoManager {
    public enum EvnetType { case undo, redo }
    
    final public class TrackOrigins: ExpressibleByArrayLiteral {
        var storage: Set<AnyHashable?> = []
        
        public init() {}
        
        public convenience init(arrayLiteral elements: Any?...) {
            self.init()
            for element in elements { self.append(element) }
        }
        
        public func append(_ value: Any?) {
            guard let value = value else { self.storage.insert(nil); return }
            if let value = value as? AnyHashable { self.storage.insert(value) }
            if let value = value as? Any.Type { self.storage.insert(ObjectIdentifier(value)) }
            self.storage.insert(ObjectIdentifier(value as AnyObject))
        }
        
        public func remove(_ value: Any?) {
            guard let value = value else { self.storage.remove(nil); return }
            if let value = value as? AnyHashable { self.storage.remove(value) }
            if let value = value as? Any.Type { self.storage.remove(ObjectIdentifier(value)) }
            self.storage.remove(ObjectIdentifier(value as AnyObject))
        }
        
        public func contains(_ value: Any?) -> Bool {
            guard let value = value else { return storage.contains(nil) }
            if let value = value as? AnyHashable, storage.contains(value) { return true }
            if storage.contains(ObjectIdentifier(type(of: value))) { return true }
            return storage.contains(ObjectIdentifier(value as AnyObject))
        }
        
    }
    
    final public class StackItem {
        var deletions: YDeleteSet
        var insertions: YDeleteSet

        public var meta: [String: Any]

        init(_ deletions: YDeleteSet, insertions: YDeleteSet) {
            self.insertions = insertions
            self.deletions = deletions
            self.meta = [:]
        }
    }

    public class ChangeEvent {
        public var origin: Any?
        public var stackItem: StackItem
        public var type: EvnetType
        public var undoStackCleared: Bool?
        public var changedParentTypes: [YOpaqueObject: [YEvent]]
        
        init(origin: Any? = nil, stackItem: StackItem, type: EvnetType, undoStackCleared: Bool? = nil , changedParentTypes: [YOpaqueObject : [YEvent]]) {
            self.origin = origin
            self.stackItem = stackItem
            self.type = type
            self.undoStackCleared = undoStackCleared
            self.changedParentTypes = changedParentTypes
        }
    }
    
    public class CleanEvent {
        public var undoStackCleared: Bool
        public var redoStackCleared: Bool
        
        init(undoStackCleared: Bool, redoStackCleared: Bool) {
            self.undoStackCleared = undoStackCleared
            self.redoStackCleared = redoStackCleared
        }
    }
    
    public struct Options {
        let captureTimeout: TimeInterval
        let captureTransaction: ((YTransaction) -> Bool)
        let deleteFilter: ((YItem) -> Bool) = {_ in true }
        let trackedOrigins: TrackOrigins
        let ignoreRemoteMapChanges: Bool
        let document: YDocument?
        
        public static func make(
            captureTimeout: TimeInterval = 500,
            captureTransaction: @escaping ((YTransaction) -> Bool) = {_ in true },
            trackedOrigins: TrackOrigins = [nil],
            ignoreRemoteMapChanges: Bool = false,
            document: YDocument? = nil
        ) -> Options {
            self.init(
                captureTimeout: captureTimeout,
                captureTransaction: captureTransaction,
                trackedOrigins: trackedOrigins,
                ignoreRemoteMapChanges: ignoreRemoteMapChanges,
                document: document
            )
        }
    }
    
    public enum Event {
        public static let stackCleanred = LZObservableObject.EventName<CleanEvent>("stack-cleared")
        public static let stackItemAdded = LZObservableObject.EventName<YUndoManager.ChangeEvent>("stack-item-added")
        public static let stackItemPopped = LZObservableObject.EventName<YUndoManager.ChangeEvent>("stack-item-popped")
        public static let stackItemUpdated = LZObservableObject.EventName<YUndoManager.ChangeEvent>("stack-item-updated")
    }
    
    final class StructRedone {
        let item: YItem
        let diff: Int
        
        init(item: YItem, diff: Int) {
            self.item = item
            self.diff = diff
        }
        
        static func followRedone(store: YStructStore, id: YIdentifier) -> StructRedone {
            var nextID: YIdentifier? = id
            var diff = 0
            var item: YStructure? = nil
            repeat {
                if diff > 0 {
                    nextID = YIdentifier(client: nextID!.client, clock: nextID!.clock + diff)
                }
                item = store.find(nextID!)
                diff = nextID!.clock - item!.id.clock
                nextID = (item as? YItem)?.redone
            } while (nextID != nil && item is YItem)
            
            return StructRedone(item: item as! YItem, diff: diff)
        }
    }

}


// TODO: implement this type of contains...
// trackedOriginsの判定にconstructorを使っている部分がSwiftで実装できない。
// || (transaction.origin != nil && self.trackedOrigins.contains(type(of: transaction.origin)))


extension YItem {
    func redo(_ transaction: YTransaction, redoitems: Set<YItem>, itemsToDelete: YDeleteSet, ignoreRemoteMapChanges: Bool) -> YItem? {
        if let redone = self.redone { return YStructStore.getItemCleanStart(transaction, id: redone) }
        
        let doc = transaction.doc
        let store = doc.store
        let ownClientID = doc.clientID
        
        var parentItem = self.parent!.object!._objectItem
        var left: YStructure? = nil
        var right: YStructure? = nil

        if let uparentItem = parentItem, uparentItem.deleted {
            
            if uparentItem.redone == nil {
                if !redoitems.contains(uparentItem) { return nil }
                let redo = uparentItem
                    .redo(transaction, redoitems: redoitems, itemsToDelete: itemsToDelete, ignoreRemoteMapChanges: ignoreRemoteMapChanges)
                if redo == nil { return nil }
            }
            
            while let redone = parentItem?.redone {
                parentItem = YStructStore.getItemCleanStart(transaction, id: redone)
            }
        }
        
        let parentType: YOpaqueObject
        
        if let parentContent = parentItem?.content as? YObjectContent {
            parentType = parentContent.object
        } else if let parentObject = self.parent?.object {
            parentType = parentObject
        } else {
            return nil
        }
        
        if self.parentKey == nil {
            left = self.left
            right = self
            
            while let uleft = left as? YItem {
                var leftTrace: YItem? = uleft
                
                while let uleftTrace = leftTrace, uleftTrace.parent?.object?._objectItem !== parentItem {
                    guard let redone = uleftTrace.redone else { leftTrace = nil; break }
                    leftTrace = YStructStore.getItemCleanStart(transaction, id: redone)
                }
                if let uleftTrace = leftTrace, uleftTrace.parent?.object?._objectItem === parentItem {
                    left = uleftTrace; break
                }
                
                left = uleft.left
            }
            
            while let uright = right as? YItem {
                var rightTrace: YItem? = uright
                
                while let urightTrace = rightTrace, urightTrace.parent?.object?._objectItem !== parentItem {
                    if let redone = urightTrace.redone {
                        rightTrace = YStructStore.getItemCleanStart(transaction, id: redone)
                    } else {
                        rightTrace = nil
                        break
                    }
                }
                if let urightTrace = rightTrace, urightTrace.parent?.object?._objectItem === parentItem {
                    right = urightTrace
                    break
                }
                right = uright.right
            }
        } else {
            right = nil
            if self.right != nil && !ignoreRemoteMapChanges {
                left = self
                
                while let uleft = left as? YItem, let leftRight = uleft.right, itemsToDelete.isDeleted(leftRight.id) {
                    left = uleft.right
                }
                while let redone = (left as? YItem)?.redone {
                    left = YStructStore.getItemCleanStart(transaction, id: redone)
                }
                if let uleft = left as? YItem, uleft.right != nil {
                    return nil
                }
            } else if let parentKey = self.parentKey {
                left = parentType.storage[parentKey]
            } else {
                assertionFailure()
            }
        }
        let nextClock = store.getState(ownClientID)
        let nextId = YIdentifier(client: ownClientID, clock: nextClock)
        let redoneItem = YItem(
            id: nextId,
            left: left,
            origin: (left as? YItem)?.lastID,
            right: right,
            rightOrigin: right?.id,
            parent: .object(parentType),
            parentSub: self.parentKey,
            content: self.content.copy()
        )
        self.redone = nextId
        redoneItem.keepRecursive(keep: true)
        redoneItem.integrate(transaction: transaction, offset: 0)
        return redoneItem
    }
}

