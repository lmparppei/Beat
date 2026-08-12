//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

extension YDocument {
    public func encodeStateAsUpdate(encodedStateVector: Data? = nil) throws -> YUpdate {
        try _encodeStateAsUpdate(encodedStateVector: encodedStateVector, encoder: YUpdateEncoderV1())
    }
    
    public func encodeStateAsUpdateV2(encodedStateVector: Data? = nil) throws -> YUpdate {
        try _encodeStateAsUpdate(encodedStateVector: encodedStateVector, encoder: YUpdateEncoderV2())
    }
    
    private func _encodeStateAsUpdate(encodedStateVector: Data? = nil, encoder: YUpdateEncoder) throws -> YUpdate {
        try encoder.encodeStateAsUpdate(doc: self, encodedStateVector: encodedStateVector)
    }
}

extension YUpdateEncoder {
    func writeStructs(structs: RefArray<YStructure>, client: Int, clock: Int) {
        // write first id
        let clock = max(clock, structs[0].id.clock) // make sure the first id exists
        let startNewStructs = YStructStore.findIndexSS(structs: structs, clock: clock)
            
        // write # encoded structs
        self.restEncoder.writeUInt(UInt(structs.count - startNewStructs))
        self.writeClient(client)
        self.restEncoder.writeUInt(UInt(clock))
            
        let firstStruct = structs[startNewStructs]
        // write first struct with an offset
        firstStruct.encode(into: self, offset: clock - firstStruct.id.clock)
        for i in (startNewStructs + 1)..<structs.count {
            structs[i].encode(into: self, offset: 0)
        }
    }
    
    func writeClientsStructs(store: YStructStore, stateVector: [Int: Int]) {
        // we filter all valid _sm entries into sm
        var _stateVector = [Int: Int]()
        
        for (client, clock) in stateVector where store.getState(client) > clock {
            _stateVector[client] = clock
        }
        for (client, _) in store.getStateVector() where stateVector[client] == nil {
            _stateVector[client] = 0
        }
            
        self.restEncoder.writeUInt(UInt(_stateVector.count))
        
        for (client, clock) in _stateVector.sorted(by: { $0.key > $1.key }) {
            guard let structs = store.clients[client] else { continue }
            self.writeStructs(structs: structs, client: client, clock: clock)
        }
    }
    
    func writeStructs(from transaction: YTransaction) {
        self.writeClientsStructs(store: transaction.doc.store, stateVector: transaction.beforeState)
    }
    
    func writeStateAsUpdate(doc: YDocument, targetStateVector: [Int: Int] = [:]) {
        self.writeClientsStructs(store: doc.store, stateVector: targetStateVector)
        YDeleteSet.createFromStructStore(doc.store).encode(into: self)
    }

    func encodeStateAsUpdate(doc: YDocument, encodedStateVector: Data? = nil) throws -> YUpdate {
        let encoder = self
        
        let encodedStateVector = encodedStateVector ?? Data([0])
        
        let targetStateVector = try YDeleteSetDecoderV1(encodedStateVector).readStateVector()
        
        encoder.writeStateAsUpdate(doc: doc, targetStateVector: targetStateVector)
            
        var updates = [encoder.toUpdate()]
        // also add the pending updates (if there are any)
        
        if doc.store.pendingDs != nil {
            updates.append(doc.store.pendingDs!)
        }
        if doc.store.pendingStructs != nil {
            updates.append(try doc.store.pendingStructs!.update.diffV2(to: encodedStateVector))
        }
        
        
        if updates.count > 1 {
            if encoder is YUpdateEncoderV1 {
                return try YUpdate.merged(updates.enumerated().map{ i, update in
                    try i == 0 ? update : update.toV1()
                })
            } else if encoder is YUpdateEncoderV2 {
                return try YUpdate.mergedV2(updates)
            }
        }

        return updates[0]
    }
}

