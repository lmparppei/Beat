//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

func anyMap<K, V>(_ m: [K: V], _ f: (K, V) -> Bool) -> Bool {
    for (key, value) in m {
        if f(key, value) {
            return true
        }
    }
    return false
}

func callAll(_ fs: RefArray<() -> Void>) {
    var i = 0; while i < fs.count {
        fs[i]()
        i += 1
    }
}


final public class YTransaction {

    public let doc: YDocument
    
    public var local: Bool
    
    public let origin: Any?
    
    var deleteSet: YDeleteSet = YDeleteSet()
    
    var beforeState: [Int: Int] = [:]

    var afterState: [Int: Int] = [:]

    var changed: [YOpaqueObject: Set<String?>] = [:] // Map<Object_<YEvent<any>>, Set<String?>>

    var changedParentTypes: [YOpaqueObject: [YEvent]] = [:] //[Object_<YEvent<any>>: YEvent<any][]> = [:]

    public var meta: [AnyHashable: Any] = [:]

    var subdocsAdded: Set<YDocument> = Set()
    var subdocsRemoved: Set<YDocument> = Set()
    var subdocsLoaded: Set<YDocument> = Set()
    
    var _mergeStructs: RefArray<YStructure> = []

    init(_ doc: YDocument, origin: Any?, local: Bool) {
        self.doc = doc
        self.beforeState = doc.store.getStateVector()
        self.origin = origin
        self.local = local
    }

    func encodeUpdateMessage(_ encoder: YUpdateEncoder) -> Bool {
        let hasContent = anyMap(self.afterState, { client, clock in
            self.beforeState[client] != clock
        })
        
        if self.deleteSet.clients.count == 0 && !hasContent {
            return false
        }
        self.deleteSet.sortAndMerge()
        encoder.writeStructs(from: self)
        self.deleteSet.encode(into: encoder)
        return true
    }

    func nextID() -> YIdentifier {
        let y = self.doc
        return YIdentifier(client: y.clientID, clock: y.store.getState(y.clientID))
    }

    func addChangedType(_ type: YOpaqueObject, parentSub: String?) {
        let item = type._objectItem
        if item == nil || (item!.id.clock < (self.beforeState[item!.id.client] ?? 0) && !item!.deleted) {
            var changed = self.changed.setIfUndefined(type, Set())
            changed.insert(parentSub)
            self.changed[type] = changed
        }
    }

    static func cleanup(_ transactions: RefArray<YTransaction>, i: Int) {
        if i >= transactions.count { return }
    
        let transaction = transactions[i]
        let doc = transaction.doc
        let store = doc.store
        let ds = transaction.deleteSet
        let mergeStructs = transaction._mergeStructs
        
        ds.sortAndMerge()
        transaction.afterState = transaction.doc.store.getStateVector()
        doc.emit(YDocument.On.beforeObserverCalls, transaction)
        
        let fs: RefArray<() -> Void> = []
        
        transaction.changed.forEach{ (itemtype: YOpaqueObject, subs: Set<String?>) in
            fs.append{
                if itemtype._objectItem == nil || !itemtype._objectItem!.deleted {
                    itemtype._callObserver(transaction, _parentSubs: subs)
                }
            }
        }
        
        fs.append({
            // deep observe events
            transaction.changedParentTypes.forEach{ type, events in
                var events = events
                fs.append{ () -> Void in
                    // We need to think about the possibility that the user transforms the
                    // Y.Doc in the event.
                    if type._objectItem == nil || !type._objectItem!.deleted {
                        events = events
                            .filter{ event in event.target._objectItem == nil || !event.target._objectItem!.deleted }
                        events
                            .forEach{ event in event.currentTarget = type }
                        
                        events
                            .sort{ event1, event2 in event1.path.count < event2.path.count }
                        
                        type._deepEventHandler.callListeners((events: events, transaction))
                    }
                }
            }
            
            fs.append{
                doc.emit(YDocument.On.afterTransaction, transaction)
            }
        })

        // callAll
        callAll(fs)
        
        // Replace deleted items with ItemDeleted / GC.
        // This is where content is actually remove from the Yjs Doc.
        if doc.gc {
            ds.tryGCDeleteSet(store, gcFilter: doc._gcFilter)
        }
        ds.tryMerge(store)
        
        
        // on all affected store.clients props, try to merge
        transaction.afterState.forEach({ client, clock in
            let beforeClock = transaction.beforeState[client] ?? 0
            if beforeClock != clock {
                let structs = store.clients[client]!
                // we iterate from right to left so we can safely remove entries
                let firstChangePos = max(YStructStore.findIndexSS(structs: structs, clock: beforeClock), 1)

                for i in (firstChangePos..<structs.count).reversed() {
                    YStructure.tryMerge(withLeft: structs, pos: i)
                }
            }
        })
        
        
        for i in 0..<mergeStructs.count {
            let client = mergeStructs[i].id.client, clock = mergeStructs[i].id.clock
            let structs = store.clients[client]!
            let replacedStructPos = YStructStore.findIndexSS(structs: structs, clock: clock)
            if replacedStructPos + 1 < structs.count {
                YStructure.tryMerge(withLeft: structs, pos: replacedStructPos + 1)
            }
            
            if replacedStructPos > 0 {
                YStructure.tryMerge(withLeft: structs, pos: replacedStructPos)
            }
        }
        if !transaction.local && transaction.afterState[doc.clientID] != transaction.beforeState[doc.clientID] {
            doc.clientID = YDocument.generateNewClientID()
        }
        
        doc.emit(YDocument.On.afterTransactionCleanup, transaction)
        
        if doc.isObserving(YDocument.On.update) {
            let encoder = YUpdateEncoderV1()
            
            let hasContent = transaction.encodeUpdateMessage(encoder)

            if hasContent {
                doc.emit(YDocument.On.update, (encoder.toUpdate(), transaction.origin, transaction))
            }
        }
        if doc.isObserving(YDocument.On.updateV2) {
            let encoder = YUpdateEncoderV2()
            let hasContent = transaction.encodeUpdateMessage(encoder)
            if hasContent {
                doc.emit(YDocument.On.updateV2, (
                    encoder.toUpdate(), transaction.origin, transaction
                ))
            }
        }
        
        let subdocsAdded = transaction.subdocsAdded
        let subdocsLoaded = transaction.subdocsLoaded
        let subdocsRemoved = transaction.subdocsRemoved
        
        if subdocsAdded.count > 0 || subdocsRemoved.count > 0 || subdocsLoaded.count > 0 {
            subdocsAdded.forEach({ subdoc in
                subdoc.clientID = doc.clientID
                if subdoc.collectionid == nil {
                    subdoc.collectionid = doc.collectionid
                }
                doc.subdocs.insert(subdoc)
            })
            subdocsRemoved.forEach{ doc.subdocs.remove($0) }
            let subdocevent = YDocument.On.SubDocEvent(
                loaded: subdocsLoaded, added: subdocsAdded, removed: subdocsRemoved
            )
            doc.emit(YDocument.On.subdocs, (subdocevent, transaction))
            subdocsRemoved.forEach{ $0.destroy() }
        }

        if transactions.count <= i + 1 {
            doc._transactionCleanups = []
            doc.emit(YDocument.On.afterAllTransactions, transactions.map{ $0 })
        } else {
            YTransaction.cleanup(transactions, i: i + 1)
        }
    }
    

    static func transact(_ doc: YDocument, origin: Any? = nil, local: Bool = true, _ body: (YTransaction) throws -> Void) rethrows {
        
        var initialCall = false
        
        if doc._transaction == nil {
            initialCall = true
            doc._transaction = YTransaction(doc, origin: origin, local: local)
            doc._transactionCleanups.value.append(doc._transaction!)
                        
            if doc._transactionCleanups.count == 1 {
                doc.emit(YDocument.On.beforeAllTransactions, ())
            }
            doc.emit(YDocument.On.beforeTransaction, doc._transaction!)
        }
        
        func defering() {
            guard initialCall else { return }
            let finishCleanup = doc._transaction === doc._transactionCleanups[0]
            doc._transaction = nil
            guard finishCleanup else { return }
            YTransaction.cleanup(doc._transactionCleanups, i: 0)
        }
        
        do {
            try body(doc._transaction!)
        } catch {
            defering()
            throw error
        }
        defering()
    }
}

