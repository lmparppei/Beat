//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation
import lib0

public struct YUpdate {
    public enum Version { case v1, v2 }
    
    #if DEBUG
    public let version: Version
    #endif
    
    public let data: Data
    
    public init(_ data: Data, version: Version) {
        self.data = data
        #if DEBUG
        self.version = version
        #endif
    }
}

extension YUpdate {
    public struct Meta: Equatable {
        public let from: [Int: Int]
        public let to: [Int: Int]
    }
}

extension YUpdate: Equatable, Hashable {}

extension YUpdate: CustomDebugStringConvertible {
    public var debugDescription: String {
        let components = self.data.map{ $0.description }.joined(separator: ", ")
        return "YUpdate[\(self.data.count)](\(components))"
    }
}

extension YUpdate {
    public static func merged(_ updates: [YUpdate]) throws -> YUpdate {
        return try self._mergeUpdates(updates: updates, YDecoder: YUpdateDecoderV1.init, YEncoder: YUpdateEncoderV1.init)
    }
    public static func mergedV2(_ updates: [YUpdate]) throws -> YUpdate {
        return try self._mergeUpdates(updates: updates, YDecoder: YUpdateDecoderV2.init, YEncoder: YUpdateEncoderV2.init)
    }
    
    public func encodeStateVectorFromUpdate() throws -> Data {
        try self._encodeStateVectorFromUpdate(YEncoder: YDeleteSetEncoderV1.init, YDecoder: YUpdateDecoderV1.init)
    }
    public func encodeStateVectorFromUpdateV2() throws -> Data {
        try self._encodeStateVectorFromUpdate(YEncoder: YDeleteSetEncoderV2.init, YDecoder: YUpdateDecoderV2.init)
    }
    
    public func updateMeta() throws -> Meta {
        return try self._parseUpdateMeta(YDecoder: YUpdateDecoderV1.init)
    }
    public func updateMetaV2() throws -> Meta {
        return try self._parseUpdateMeta(YDecoder: YUpdateDecoderV2.init)
    }

    public func diff(to stateVector: Data) throws -> YUpdate {
        return try self._diff(to: stateVector, YDecoder: YUpdateDecoderV1.init, YEncoder: YUpdateEncoderV1.init)
    }
    public func diffV2(to stateVector: Data) throws -> YUpdate {
        return try self._diff(to: stateVector, YDecoder: YUpdateDecoderV2.init, YEncoder: YUpdateEncoderV2.init)
    }
    
    public func toV2() throws -> YUpdate {
        #if DEBUG
        assert(self.version == .v1)
        #endif
        return try self._convertUpdateFormat(YDecoder: YUpdateDecoderV1.init, YEncoder: YUpdateEncoderV2.init)
    }

    public func toV1() throws -> YUpdate {
        #if DEBUG
        assert(self.version == .v2)
        #endif
        return try self._convertUpdateFormat(YDecoder: YUpdateDecoderV2.init, YEncoder: YUpdateEncoderV1.init)
    }
    
    // ======================================================================================================== //
    // MARK: - Implementations -
    
    private func _convertUpdateFormat(
        YDecoder: (LZDecoder) throws -> YUpdateDecoder = YUpdateDecoderV2.init,
        YEncoder: () -> YUpdateEncoder = YUpdateEncoderV2.init
    ) throws -> YUpdate {
        let updateDecoder = try YDecoder(LZDecoder(self.data))
        let lazyDecoder = try YLazyStructReader(updateDecoder, filterSkips: false)
        let updateEncoder = YEncoder()
        let lazyWriter = YLazyStructWriter(updateEncoder)

        var curr = lazyDecoder.curr; while curr != nil {
            try lazyWriter.write(curr!, offset: 0)
            curr = try lazyDecoder.next()
        }
        
        lazyWriter.finish()
        let ds = try YDeleteSet.decode(decoder: updateDecoder)
        ds.encode(into: updateEncoder)
        return updateEncoder.toUpdate()
    }
    
    private func _diff(
        to sv: Data,
        YDecoder: (LZDecoder) throws -> YUpdateDecoder = YUpdateDecoderV2.init,
        YEncoder: () -> YUpdateEncoder = YUpdateEncoderV2.init
    ) throws -> YUpdate {
        let state = try YDeleteSetDecoderV1(sv).readStateVector()
        let encoder = YEncoder()
        let lazyStructWriter = YLazyStructWriter(encoder)
        let decoder = try YDecoder(LZDecoder(self.data))
        let reader = try YLazyStructReader(decoder, filterSkips: false)
        while reader.curr != nil {
            let curr = reader.curr
            let currClient = curr!.id.client
            let svClock = state[Int(currClient)] ?? 0
            if reader.curr is YSkip {
                _ = try reader.next()
                continue
            }
            if curr!.id.clock + curr!.length > svClock {
                
                try lazyStructWriter.write(curr!, offset: max(svClock - curr!.id.clock, 0))
                
                _ = try reader.next()
                while (reader.curr != nil && reader.curr!.id.client == currClient) {
                    try lazyStructWriter.write(reader.curr!, offset: 0)
                    _ = try reader.next()
                }
            } else {
                // read until something comes up
                while (reader.curr != nil && reader.curr!.id.client == currClient && reader.curr!.id.clock + reader.curr!.length <= svClock) {
                    _ = try reader.next()
                }
            }
        }
        lazyStructWriter.finish()
        // write ds
        let ds = try YDeleteSet.decode(decoder: decoder)
        ds.encode(into: encoder)
        return encoder.toUpdate()
    }

    private func _parseUpdateMeta(YDecoder: (LZDecoder) throws -> YUpdateDecoder = YUpdateDecoderV2.init) throws -> Meta {
        var from: [Int: Int] = [:]
        var to: [Int: Int] = [:]
        
        let updateDecoder = try YLazyStructReader(YDecoder(LZDecoder(self.data)), filterSkips: false)
        var curr = updateDecoder.curr
        if curr != nil {
            var currClient = curr!.id.client
            var currClock = curr!.id.clock
            // write the beginning to `from`
            from[currClient] = currClock
            
            while curr != nil {
                if currClient != curr!.id.client {
                    to[currClient] = currClock
                    from[curr!.id.client] = curr!.id.clock
                    currClient = curr!.id.client
                }
                currClock = curr!.id.clock + curr!.length
                
                curr = try updateDecoder.next()
            }
            
            to[currClient] = currClock
        }
        return Meta(from: from, to: to)
    }
    
    
    
    private func _encodeStateVectorFromUpdate(YEncoder: () -> YDeleteSetEncoder, YDecoder: (LZDecoder) throws -> YUpdateDecoder) throws -> Data {
        var encoder = YEncoder()
        let updateDecoder = try YLazyStructReader(YDecoder(LZDecoder(self.data)), filterSkips: false)
        var curr = updateDecoder.curr
        if curr != nil {
            var size = 0
            var currClient = curr!.id.client
            var stopCounting = curr!.id.clock != 0 // must start at 0
            var currClock = stopCounting ? 0 : curr!.id.clock + curr!.length
            while curr != nil {
                if currClient != curr!.id.client {
                    if currClock != 0 {
                        size += 1
                        encoder.restEncoder.writeUInt(UInt(currClient))
                        encoder.restEncoder.writeUInt(UInt(currClock))
                    }
                    currClient = curr!.id.client
                    currClock = 0
                    stopCounting = curr!.id.clock != 0
                }
                if curr! is YSkip {
                    stopCounting = true
                }
                if !stopCounting {
                    currClock = curr!.id.clock + curr!.length
                }
                curr = try updateDecoder.next()
            }
            // write what we have
            if currClock != 0 {
                size += 1
                encoder.restEncoder.writeUInt(UInt(currClient))
                encoder.restEncoder.writeUInt(UInt(currClock))
            }
            // prepend the size of the state vector
            let enc = LZEncoder()
            enc.writeUInt(UInt(size))
            enc.writeOpaqueSizeData(encoder.restEncoder.data)
            encoder.restEncoder = enc
            return encoder.toData()
        } else {
            encoder.restEncoder.writeUInt(0)
            return encoder.toData()
        }
    }
    
    private static func _mergeUpdates(updates: [YUpdate], YDecoder: (LZDecoder) throws -> YUpdateDecoder, YEncoder: () -> YUpdateEncoder) throws -> YUpdate {
        struct StructWrite {
            let struct_: YStructure
            let offset: Int
        }
        
        if updates.count == 1 {
            return updates[0]
        }
        let updateDecoders = try updates.map{ try YDecoder(LZDecoder($0.data)) }
        var lazyStructDecoders = try updateDecoders.map{ try YLazyStructReader($0, filterSkips: true) }

        var currWrite: StructWrite? = nil

        let updateEncoder = YEncoder()
        let lazyStructEncoder = YLazyStructWriter(updateEncoder)
        
        while (true) {
            lazyStructDecoders = lazyStructDecoders.filter{
                $0.curr != nil
            }
            lazyStructDecoders.sort(by: { dec1, dec2 in
                if dec1.curr!.id.client == dec2.curr!.id.client {
                    let clockDiff = dec1.curr!.id.clock - dec2.curr!.id.clock
                    if clockDiff == 0 {
                        // @todo remove references to skip since the structDecoders must filter Skips.
                        return type(of: dec1.curr) == type(of: dec2.curr)
                            ? false
                            : dec1.curr is YSkip ? false : true // we are filtering skips anyway.
                    } else {
                        return clockDiff < 0
                    }
                } else {
                    return dec2.curr!.id.client - dec1.curr!.id.client < 0
                }
            })
                            
            if lazyStructDecoders.count == 0 {
                break
            }
            let currDecoder = lazyStructDecoders[0]
            
            let firstClient = currDecoder.curr!.id.client

            if currWrite != nil {
                var curr = currDecoder.curr
                var iterated = false

                // iterate until we find something that we haven't written already
                // remember: first the high client-ids are written
                while (curr != nil
                       && curr!.id.clock + curr!.length <= currWrite!.struct_.id.clock + currWrite!.struct_.length
                       && curr!.id.client >= currWrite!.struct_.id.client
                ) {
                    curr = try currDecoder.next()
                    iterated = true
                }
                if (
                    // current decoder is empty
                    curr == nil
                    // check whether there is another decoder that has has updates from `firstClient`
                    || curr!.id.client != firstClient
                    // the above while loop was used and we are potentially missing updates
                    || (iterated && curr!.id.clock > currWrite!.struct_.id.clock + currWrite!.struct_.length)
                ) {
                    continue
                }

                if firstClient != currWrite!.struct_.id.client {
                    try lazyStructEncoder.write(currWrite!.struct_, offset: currWrite!.offset)
                    currWrite = StructWrite(struct_: curr!, offset: 0)
                    _ = try currDecoder.next()
                } else {
                    if currWrite!.struct_.id.clock + currWrite!.struct_.length < curr!.id.clock {
                        if currWrite!.struct_ is YSkip {
                            currWrite!.struct_.length = curr!.id.clock + curr!.length - currWrite!.struct_.id.clock
                        } else {
                            try lazyStructEncoder.write(currWrite!.struct_, offset: currWrite!.offset)
                            
                            let diff = curr!.id.clock - currWrite!.struct_.id.clock - currWrite!.struct_.length
                            let struct_ = YSkip(id: YIdentifier(client: firstClient, clock: currWrite!.struct_.id.clock + currWrite!.struct_.length), length: diff)
                            currWrite = StructWrite(struct_: struct_, offset: 0)
                        }
                    } else { // if currWrite.struct.id.clock + currWrite.struct.length >= curr.id.clock {
                        let diff = currWrite!.struct_.id.clock + currWrite!.struct_.length - curr!.id.clock
                        if diff > 0 {
                            if currWrite!.struct_ is YSkip {
                                // prefer to slice Skip because the other struct might contain more information
                                currWrite!.struct_.length -= diff
                            } else {
                                curr = curr!.slice(diff: diff)
                            }
                        }
                        if !currWrite!.struct_.merge(with: curr!) {
                            try lazyStructEncoder.write(currWrite!.struct_, offset: currWrite!.offset)
                            currWrite = StructWrite(struct_: curr!, offset: 0)
                            _ = try currDecoder.next()
                        }
                    }
                }
            } else {
                currWrite = StructWrite(struct_: currDecoder.curr!, offset: 0)
                _ = try currDecoder.next()
            }
            var next = currDecoder.curr
            
            while(
                next != nil
                && next!.id.client == firstClient
                && next!.id.clock == currWrite!.struct_.id.clock + currWrite!.struct_.length
                && !(next is YSkip)
            ) {
                try lazyStructEncoder.write(currWrite!.struct_, offset: currWrite!.offset)
                currWrite = StructWrite(struct_: next!, offset: 0)
                
                next = try currDecoder.next()
            }
        }
        
        if currWrite != nil {
            try lazyStructEncoder.write(currWrite!.struct_, offset: currWrite!.offset)
            currWrite = nil
        }
        lazyStructEncoder.finish()

        let dss = try updateDecoders.map{ try YDeleteSet.decode(decoder: $0) }
        let ds = YDeleteSet.mergeAll(dss)
        ds.encode(into: updateEncoder)
        return updateEncoder.toUpdate()
    }

}
