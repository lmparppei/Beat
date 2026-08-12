//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import lib0

final class YLazyStructWriter {
    private struct ClientStruct {
        var written: Int
        var restEncoder: Data
    }
    
    private var currClient: Int
    private var startClock: Int
    private var written: Int
    private var encoder: YUpdateEncoder
    private var clientStructs: [ClientStruct]
    
    init(_ encoder: YUpdateEncoder) {
        self.currClient = 0
        self.startClock = 0
        self.written = 0
        self.encoder = encoder
        self.clientStructs = []
    }
}

extension YLazyStructWriter {
    func flush() {
        if self.written > 0 {
            let clientStruct = ClientStruct(written: self.written, restEncoder: self.encoder.restEncoder.data)
            self.clientStructs.append(clientStruct)
            self.encoder.restEncoder = LZEncoder()
            self.written = 0
        }
    }

    func write(_ struct_: YStructure /* not Skip */, offset: Int) throws {
        // flush curr if we start another client
        if self.written > 0 && self.currClient != struct_.id.client {
            self.flush()
        }
        if self.written == 0 {
            self.currClient = Int(struct_.id.client)
            // write next client
            self.encoder.writeClient(struct_.id.client)
            // write startClock
            self.encoder.restEncoder.writeUInt(UInt(struct_.id.clock + offset))
        }
        struct_.encode(into: self.encoder, offset: offset)
        self.written += 1
    }

    func finish() {
        self.flush()

        // this is a fresh encoder because we called flushCurr
        let restEncoder = self.encoder.restEncoder

        restEncoder.writeUInt(UInt(self.clientStructs.count))

        for i in 0..<self.clientStructs.count {
            let partStructs = self.clientStructs[i]
            restEncoder.writeUInt(UInt(partStructs.written))
            restEncoder.writeOpaqueSizeData(partStructs.restEncoder)
        }
    }

}
