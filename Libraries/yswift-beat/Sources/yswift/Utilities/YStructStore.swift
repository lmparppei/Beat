//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation


final class PendingStrcut: CustomStringConvertible {
    var missing: [Int: Int]
    var update: YUpdate
    
    init(missing: [Int: Int], update: YUpdate) {
        self.missing = missing
        self.update = update
    }
    
    var description: String { "PendingStrcut(missing: \(missing), update: \(update))" }
}

final class YStructStore {
    var clients: [Int: RefArray<YStructure>] = [:]
    var pendingStructs: PendingStrcut? = nil
    var pendingDs: YUpdate? = nil

    init() {}

    /** Return the states as a Map<client,clock>. Note that clock refers to the next expected clock id. */
    func getStateVector() -> [Int: Int] {
        var sm = [Int: Int]()
        self.clients.forEach({ client, structs in
            let struct_ = structs[structs.count - 1]
            sm[client] = struct_.id.clock + struct_.length
        })
        return sm
    }

    func getState(_ client: Int) -> Int {
        let structs = self.clients[client]
        if structs == nil {
            return 0
        }
        let lastStruct = structs![structs!.count - 1]
        return lastStruct.id.clock + lastStruct.length
    }

    func integretyCheck() throws {
        try self.clients.forEach{ _, structs in
            for i in 1..<structs.count {
                let l = structs[i - 1]
                let r = structs[i]
                if l.id.clock + l.length != r.id.clock {
                    throw YSwiftError.integretyCheckFail
                }
            }
        }
    }

    func addStruct(_ struct_: YStructure) {
        var structs = self.clients[struct_.id.client]
        if structs == nil {
            structs = []
            self.clients[struct_.id.client] = structs
        } else {
            let lastStruct = structs![structs!.count - 1]
            if lastStruct.id.clock + lastStruct.length != struct_.id.clock {
                fatalError("Unexpected case")
//                throw YSwiftError.unexpectedCase
            }
        }
            
        structs!.value.append(struct_)
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    func find(_ id: YIdentifier) -> YStructure {
        let structs = self.clients[id.client]!
        return structs.value[YStructStore.findIndexSS(structs: structs, clock: id.clock)]
    }


    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    func getItem(_ id: YIdentifier) -> YItem {
        return self.find(id) as! YItem
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    @discardableResult
    static func getItemCleanStart(_ transaction: YTransaction, id: YIdentifier) -> YItem {
        let index = self.findIndexCleanStart(
            transaction: transaction,
            structs: transaction.doc.store.clients[id.client]!,
            clock: id.clock
        )

        return transaction.doc.store.clients[id.client]![index] as! YItem
    }

    /** Expects that id is actually in store. This function throws or is an infinite loop otherwise. */
    func getItemCleanEnd(_ transaction: YTransaction, id: YIdentifier) -> YStructure {
        let structs = self.clients[id.client]!
        
        let index = YStructStore.findIndexSS(structs: structs, clock: id.clock)
        let struct_ = structs[index]
        if id.clock != struct_.id.clock + struct_.length - 1 && !(struct_ is YGC) {            
            structs.value
                .insert((struct_ as! YItem).split(transaction, diff: id.clock - struct_.id.clock + 1), at: index + 1)
        }
        return struct_
    }

    /** Replace `item` with `newitem` in store */
    func replaceStruct(_ struct_: YStructure, newStruct: YStructure) {
        self.clients[struct_.id.client]![
            YStructStore.findIndexSS(structs: self.clients[struct_.id.client]!, clock: struct_.id.clock)
        ] = newStruct
    }

    /** Iterate over a range of structs */
    static func iterateStructs(transaction: YTransaction, structs: RefArray<YStructure>, clockStart: Int, len: Int, f: (YStructure) throws -> Void) rethrows {
        if len == 0 { return }
        let clockEnd = clockStart + len
        var index = self.findIndexCleanStart(transaction: transaction, structs: structs, clock: clockStart)
        var struct_: YStructure
        repeat {
            struct_ = structs.value[index]
            index += 1
            if clockEnd < struct_.id.clock + struct_.length {
                _ = self.findIndexCleanStart(transaction: transaction, structs: structs, clock: clockEnd)
            }
            try f(struct_)
        } while (index < structs.count && structs[index].id.clock < clockEnd)
    }


    /** Perform a binary search on a sorted array */
    static func findIndexSS(structs: RefArray<YStructure>, clock: Int) -> Int {
        var left = 0
        var right = structs.count - 1
        var mid = structs[right]
        var midclock = mid.id.clock
        if midclock == clock {
            return right
        }
        // @todo does it even make sense to pivot the search?
        // If a good split misses, it might actually increase the time to find the correct item.
        // Currently, the only advantage is that search with pivoting might find the item on the first try.
        var midindex = (clock / (midclock + mid.length - 1)) * right
        while (left <= right) {
            mid = structs[midindex]
            midclock = mid.id.clock
            if midclock <= clock {
                if clock < midclock + mid.length {
                    return midindex
                }
                left = midindex + 1
            } else {
                right = midindex - 1
            }
            midindex = (left + right) / 2
        }
        fatalError("unexpectedCase")
        // Always check state before looking for a struct in StructStore
        // Therefore the case of not finding a struct is unexpected
//        throw YSwiftError.unexpectedCase
    }

    static func findIndexCleanStart(transaction: YTransaction, structs: RefArray<YStructure>, clock: Int) -> Int {
        let index = YStructStore.findIndexSS(structs: structs, clock: clock)
        let struct_ = structs[index]
        if struct_.id.clock < clock && struct_ is YItem {
            structs.value
                .insert(((struct_ as! YItem).split(transaction, diff: clock - (struct_ as! YItem).id.clock)), at: index + 1)
            return index + 1
        }
        return index
    }
}

extension YStructStore {
    func integrateStructs(transaction: YTransaction, clientsStructRefs: RefDictionary<Int, StructRef>) throws -> PendingStrcut? {
        let store = self
        
        var stack: [YStructure] = []
        var clientsStructRefsIds = clientsStructRefs.value.keys.sorted(by: <)
        if clientsStructRefsIds.count == 0 {
            return nil
        }
        
        func getNextStructTarget() -> StructRef? {
            if clientsStructRefsIds.count == 0 {
                return nil
            }
            var nextStructsTarget = clientsStructRefs.value[clientsStructRefsIds.last!]!
                
            while nextStructsTarget.refs.count == nextStructsTarget.i {
                clientsStructRefsIds.removeLast()
                if clientsStructRefsIds.count > 0 {
                    nextStructsTarget = clientsStructRefs.value[clientsStructRefsIds.last!]!
                } else {
                    return nil
                }
            }
            return nextStructsTarget
        }
        var curStructsTarget = getNextStructTarget()
        if curStructsTarget == nil && stack.count == 0 {
            return nil
        }

        let restStructs: YStructStore = YStructStore()
        var missingSV = [Int: Int]()
        func updateMissingSv(client: Int, clock: Int) {
            let mclock = missingSV[client]
            if mclock == nil || mclock! > clock {
                missingSV[client] = clock
            }
        }

        var stackHead: YStructure = curStructsTarget!.refs[curStructsTarget!.i]!
        curStructsTarget!.i += 1
        var state = [Int: Int]()

        func addStackToRestSS() {
            for item in stack {
                let client = item.id.client
                let unapplicableItems = clientsStructRefs.value[client]
                if unapplicableItems != nil {
                    // decrement because we weren't able to apply previous operation
                    unapplicableItems!.i -= 1
                    restStructs.clients[client] = .init(unapplicableItems!.refs[unapplicableItems!.i...].map{ $0! })
                    clientsStructRefs.value.removeValue(forKey: client)
                    unapplicableItems!.i = 0
                    unapplicableItems!.refs = []
                } else {
                    // item was the last item on clientsStructRefs and the field was already cleared. Add item to restStructs and continue
                    restStructs.clients[client] = .init([item])
                }
                // remove client from clientsStructRefsIds to prevent users from applying the same update again
                clientsStructRefsIds = clientsStructRefsIds.filter{ $0 != client }
            }
            stack.removeAll()
        }

        // iterate over all struct readers until we are done
        while (true) {
            if type(of: stackHead) != YSkip.self {
                let localClock = state.setIfUndefined(stackHead.id.client, store.getState(stackHead.id.client))
                let offset = localClock - stackHead.id.clock
                if offset < 0 {
                    stack.append(stackHead)
                    updateMissingSv(client: stackHead.id.client, clock: stackHead.id.clock - 1)
                    // hid a dead wall, add all items from stack to restSS
                    addStackToRestSS()
                } else {
                    let missing = stackHead.getMissing(transaction, store: store)
                    if missing != nil {
                        stack.append(stackHead)
                        
                        let structRefs: StructRef = clientsStructRefs.value[missing!] ?? StructRef(i: 0, refs: [])
                        
                        if structRefs.refs.count == structRefs.i {
                            updateMissingSv(client: missing!, clock: store.getState(missing!))
                            addStackToRestSS()
                        } else {
                            stackHead = structRefs.refs[structRefs.i]!
                            structRefs.i += 1
                            continue
                        }
                    } else if offset == 0 || offset < stackHead.length {
                        // all fine, apply the stackhead
                        try stackHead.integrate(transaction: transaction, offset: offset)
                        state[stackHead.id.client] = stackHead.id.clock + stackHead.length
                    }
                }
            }
            // iterate to next stackHead
            if stack.count > 0 {
                stackHead = stack.removeLast()
            } else if curStructsTarget != nil && curStructsTarget!.i < curStructsTarget!.refs.count {
                stackHead = curStructsTarget!.refs[curStructsTarget!.i]!
                curStructsTarget!.i += 1
            } else {
                curStructsTarget = getNextStructTarget()
                            
                if curStructsTarget == nil {
                    // we are done!
                    break
                } else {
                    stackHead = curStructsTarget!.refs[curStructsTarget!.i]!
                    curStructsTarget!.i += 1
                }
            }
        }
        
        if restStructs.clients.count > 0 {
            let encoder = YUpdateEncoderV2()
            encoder.writeClientsStructs(store: restStructs, stateVector: [:])
            // write empty deleteset
            // writeDeleteSet(encoder, DeleteSet())
            encoder.restEncoder.writeUInt(0) // -> no need for an extra function call, just write 0 deletes
            return PendingStrcut(missing: missingSV, update: encoder.toUpdate())
        }
        return nil
    }


}
