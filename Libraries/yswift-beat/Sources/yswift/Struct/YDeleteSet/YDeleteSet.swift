//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class YDeleteSet {
    var clients: [Int: RefArray<YDeleteItem>] = [:]

    func iterate(_ transaction: YTransaction, body: (YStructure) throws -> Void) rethrows {
        
        return try self.clients.forEach{ clientid, deletes in
            for i in 0..<deletes.count {
                let del = deletes[i]
                try YStructStore.iterateStructs(
                    transaction: transaction,
                    structs: transaction.doc.store.clients[clientid]!,
                    clockStart: del.clock, len: del.len, f: body
                )
            }
        }
    }

    func isDeleted(_ id: YIdentifier) -> Bool {
        let dis = self.clients[id.client]
        return dis != nil && YDeleteItem.findIndex(dis!, clock: id.clock) != nil
    }

    func sortAndMerge() {
        self.clients.forEach{ _, dels in
            dels.value.sort(by: { a, b in a.clock < b.clock })
            var i: Int = 1, j: Int = 1
                
            while i < dels.count {
                let left = dels[j - 1]
                let right = dels[i]
                if left.clock + left.len >= right.clock {
                    left.len = max(left.len, right.clock + right.len - left.clock)
                } else {
                    if j < i { dels[j] = right }
                    j += 1
                }
                i += 1
            }
            dels.value = dels[..<j].map{ $0 }
        }
    }

    func add(client: Int, clock: Int, length: Int) {
        if self.clients[client] == nil {
            self.clients[client] = []
        }
        
        self.clients[client]!.value.append(YDeleteItem(clock: clock, len: length))
    }
    
    func encode(into encoder: any YDeleteSetEncoder) {
        encoder.restEncoder.writeUInt(UInt(self.clients.count))
    
        // Ensure that the delete set is written in a deterministic order
        self.clients
            .sorted(by: { $0.key > $1.key })
            .forEach({ client, dsitems in
                encoder.resetDeleteSetValue()
                encoder.restEncoder.writeUInt(UInt(client))
                let len = dsitems.count
                encoder.restEncoder.writeUInt(UInt(len))
                for i in 0..<len {
                    let item = dsitems[i]
                    encoder.writeDeleteSetClock(item.clock)
                    encoder.writeDeleteSetLen(item.len)
                }
            })
    }

    func tryGCDeleteSet(_ store: YStructStore, gcFilter: (YItem) -> Bool) {
        for (client, deleteItems) in self.clients {
            let structs = store.clients[client]!
            
            for di in (0..<deleteItems.count).reversed() {
                let deleteItem = deleteItems[di]
                let endDeleteItemClock = deleteItem.clock + deleteItem.len
                
                var si = YStructStore.findIndexSS(structs: structs, clock: deleteItem.clock)
                var struct_ = structs[si]
                
                while si < structs.count && struct_.id.clock < endDeleteItemClock {
                    let struct__ = structs[si]
                    if deleteItem.clock + deleteItem.len <= struct__.id.clock {
                        break
                    }
                    if type(of: struct__) == YItem.self && struct__.deleted && !(struct__ as! YItem).keep && gcFilter(struct__ as! YItem) {
                        (struct__ as! YItem).gc(store, parentGC: false)
                    }
                    
                    struct_ = structs.value[si]
                    si += 1
                }
            }
        }
    }

    func tryMerge(_ store: YStructStore) {
        self.clients.forEach({ client, deleteItems in
            let structs = store.clients[client]!
            
            for di in (0..<deleteItems.count).reversed() {
                let deleteItem = deleteItems[di]
                // start with merging the item next to the last deleted item
                let mostRightIndexToCheck = min(
                    structs.count - 1,
                    1 + YStructStore.findIndexSS(structs: structs, clock: deleteItem.clock + deleteItem.len - 1)
                )
                var si = mostRightIndexToCheck, struct_ = structs[si];
                
                while si > 0 && struct_.id.clock >= deleteItem.clock {
                    YStructure.tryMerge(withLeft: structs, pos: si)
                    si -= 1
                    struct_ = structs[si]
                }
            }
        })
    }

    func tryGC(_ store: YStructStore, gcFilter: (YItem) -> Bool) {
        self.tryGCDeleteSet(store, gcFilter: gcFilter)
        self.tryMerge(store)
    }
    
    static func mergeAll(_ dss: [YDeleteSet]) -> YDeleteSet {
        let merged = YDeleteSet()
        
        for dssI in 0..<dss.count {
            dss[dssI].clients.forEach({ client, delsLeft in
                if merged.clients[client] == nil {
                    for i in dssI+1..<dss.count {
                        delsLeft.value += dss[i].clients[client] ?? []
                    }
                    merged.clients[client] = delsLeft
                }
            })
        }
        merged.sortAndMerge()
        return merged
    }

    static func decode(decoder: YDeleteSetDecoder) throws -> YDeleteSet {
        let ds = YDeleteSet()
        let numClients = try decoder.restDecoder.readUInt()
        
        for _ in 0..<numClients {
            decoder.resetDeleteSetValue()
            let client = try Int(decoder.restDecoder.readUInt())
            let IntOfDeletes = try decoder.restDecoder.readUInt()
            if IntOfDeletes > 0 {
                if ds.clients[client] == nil { ds.clients[client] = [] }
                
                for _ in 0..<IntOfDeletes {
                    ds.clients[client]!.value.append(YDeleteItem(
                        clock: try decoder.readDeleteSetClock(),
                        len: try decoder.readDeleteSetLen()
                    ))
                }
            }
        }
        return ds
    }
    
    static func createFromStructStore(_ ss: YStructStore) -> YDeleteSet {
        let ds = YDeleteSet()
        
        for (client, structs) in ss.clients {
            let dsitems: RefArray<YDeleteItem> = []
            
            var i = 0; while i < structs.count {
                let struct_ = structs[i]
                if struct_.deleted {
                    let clock = struct_.id.clock
                    var len = struct_.length
                    
                    if i + 1 < structs.count {
                        var next: YStructure? = structs[i+1]
                        
                        while let unext = next, i+1 < structs.count && unext.deleted {
                            len += unext.length
                            i += 1
                            if !(i+1 < structs.count) { break }
                            next = structs.value[i+1]
                        }
                    }
                    
                    dsitems.value.append(YDeleteItem(clock: clock, len: len))
                }
                i += 1
            }
            if dsitems.count > 0 {
                ds.clients[client] = dsitems
            }
        }
        
        return ds
    }

    static func decodeAndApply(_ decoder: YDeleteSetDecoder, transaction: YTransaction, store: YStructStore) throws -> YUpdate? {
        let unappliedDS = YDeleteSet()
        let numClients = try decoder.restDecoder.readUInt()
        
        for _ in 0..<numClients {
            decoder.resetDeleteSetValue()
            let client = try Int(decoder.restDecoder.readUInt())
            let numberOfDeletes = try decoder.restDecoder.readUInt()
            let structs = store.clients[client] ?? []
            let state = store.getState(client)
            
            for _ in 0..<numberOfDeletes {
                let clock = try decoder.readDeleteSetClock()
                let dsLen = try decoder.readDeleteSetLen()
                let clockEnd = clock + dsLen
                
                if clock < state {

                    if state < clockEnd {
                        unappliedDS.add(client: client, clock: state, length: clockEnd - state)
                    }
                    var index = YStructStore.findIndexSS(structs: structs, clock: clock)
                    var struct_ = structs[index]
                    // split the first item if necessary
                    if !struct_.deleted && struct_.id.clock < clock {
                        structs.value
                            .insert((struct_ as! YItem).split(transaction, diff: clock - struct_.id.clock), at: index + 1)
                        index += 1 // increase we now want to use the next struct
                    }
                    while (index < structs.count) {
                        struct_ = structs[index]
                        index += 1
                        
                        if struct_.id.clock < clockEnd {
                            if !struct_.deleted {
                                if clockEnd < struct_.id.clock + struct_.length {
                                    structs.value
                                        .insert((struct_ as! YItem).split(transaction, diff: clockEnd - struct_.id.clock), at: index)
                                }
                                (struct_ as! YItem).delete(transaction)
                            }
                        } else {
                            break
                        }
                    }
                } else {
                    unappliedDS.add(client: client, clock: clock, length: clockEnd - clock)
                }
            }
        }
        
        if unappliedDS.clients.count > 0 {
            let ds = YUpdateEncoderV2()
            ds.restEncoder.writeUInt(0) // encode 0 structs
            unappliedDS.encode(into: ds)
            return ds.toUpdate()
        }
        
        return nil
    }
}
