//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

extension YDocument {
    public func encodeStateVector() throws -> Data {
        try YDeleteSetEncoderV1().encodeStateVector(from: self)
    }
    public func encodeStateVectorV2() throws -> Data {
        try YDeleteSetEncoderV2().encodeStateVector(from: self)
    }
}

extension YDeleteSetEncoder {
    
    func writeStateVector(from stateVector: [Int: Int]) throws {
        self.restEncoder.writeUInt(UInt(stateVector.count))
        
        for (client, clock) in stateVector.sorted(by: { $0.key > $1.key }) {
            self.restEncoder.writeUInt(UInt(client))
            self.restEncoder.writeUInt(UInt(clock))
        }
    }
    func writeStateVector(from doc: YDocument) throws {
        try self.writeStateVector(from: doc.store.getStateVector())
    }

    func encodeStateVector(from stateVector: [Int: Int]) throws -> Data {
        try self.writeStateVector(from: stateVector)
        return self.toData()
    }

    func encodeStateVector(from doc: YDocument) throws -> Data {
        try self.writeStateVector(from: doc)
        return self.toData()
    }

}

