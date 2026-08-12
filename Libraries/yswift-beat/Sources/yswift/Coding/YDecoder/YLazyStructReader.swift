//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

// Swift has no generator. So just providing API.
final class YLazyStructReader {
    private(set) var curr: YStructure?
    private(set) var done: Bool
    
    private var gen: Array<YStructure>.Iterator
    private let filterSkips: Bool
    
    init(_ decoder: YUpdateDecoder, filterSkips: Bool) throws {
        
        // TODO: lazy!
        var array = [YStructure]()
        try lazyStructReaderGenerator(decoder, yield: {
            array.append($0)
        })
        
        self.gen = array.makeIterator()
        self.curr = nil
        self.done = false
        self.filterSkips = filterSkips
        _ = try self.next()
    }

    func next() throws -> YStructure? {
        repeat {
            self.curr = self.gen.next()
        } while (self.filterSkips && self.curr != nil && self.curr is YSkip)
        return self.curr
    }
}

fileprivate func lazyStructReaderGenerator(_ decoder: YUpdateDecoder, yield: (YStructure) -> ()) throws {

    let numOfStateUpdates = try decoder.restDecoder.readUInt()
    
    for _ in 0..<numOfStateUpdates {
        let numberOfStructs = try decoder.restDecoder.readUInt()
        let client = try decoder.readClient()
        var clock = try Int(decoder.restDecoder.readUInt())
        
        for _ in 0..<numberOfStructs {
            let info = try decoder.readInfo()
            if info == 10 {
                let len = try Int(decoder.restDecoder.readUInt())
                yield(
                    YSkip(id: YIdentifier(client: client, clock: clock), length: len)
                )
                clock += len
            } else if (info & 0b0001_1111) != 0 {
                let cantCopyParentInfo = (info & (0b0100_0000 | 0b1000_0000)) == 0
                let struct_ = try YItem(
                    id: YIdentifier(client: client, clock: clock),
                    left: nil,
                    origin: (info & 0b1000_0000) == 0b1000_0000 ? decoder.readLeftID() : nil, // origin
                    right: nil,
                    rightOrigin: (info & 0b0100_0000) == 0b0100_0000 ? decoder.readRightID() : nil, // right origin
                    parent: cantCopyParentInfo ? (decoder.readParentInfo() ? .string(decoder.readString()) : .id(decoder.readLeftID())) : nil,
                    parentSub: cantCopyParentInfo && (info & 0b0010_0000) == 0b0010_0000 ? decoder.readString() : nil, // parentSub
                    content: try decodeContent(from: decoder, info: info) // item content
                )
                yield(struct_)
                clock += struct_.length
            } else {
                let len = try decoder.readLen()
                yield(YGC(id: YIdentifier(client: client, clock: clock), length: len))
                clock += len
            }
        }
    }
}

