//
//  File.swift
//  
//
//  Created by yuki on 2023/03/25.
//

import lib0
import Foundation

protocol YDeleteSetDecoder {
    var restDecoder: LZDecoder { get }

    init(_ decoder: LZDecoder) throws
    
    func resetDeleteSetValue()
    func readDeleteSetClock() throws -> Int
    func readDeleteSetLen() throws -> Int
}

extension YDeleteSetDecoder {
    init(_ update: YUpdate) throws { try self.init(update.data) }
    init(_ data: Data) throws { try self.init(LZDecoder(data)) }
}

class YDeleteSetDecoderV1 {
    let restDecoder: LZDecoder

    required init(_ decoder: LZDecoder) { self.restDecoder = decoder }
}

extension YDeleteSetDecoderV1: YDeleteSetDecoder {
    func resetDeleteSetValue() {}
    func readDeleteSetClock() throws -> Int { try Int(self.restDecoder.readUInt()) }
    func readDeleteSetLen() throws -> Int { try Int(self.restDecoder.readUInt()) }
}

class YDeleteSetDecoderV2 {
    let restDecoder: LZDecoder
    
    private var deleteSetCurrentValue = 0

    required init(_ decoder: LZDecoder) throws { self.restDecoder = decoder }
}

extension YDeleteSetDecoderV2: YDeleteSetDecoder {
    func resetDeleteSetValue() { self.deleteSetCurrentValue = 0 }

    func readDeleteSetClock() throws -> Int {
        self.deleteSetCurrentValue += try Int(self.restDecoder.readUInt())
        return self.deleteSetCurrentValue
    }

    func readDeleteSetLen() throws -> Int {
        let diff = try Int(self.restDecoder.readUInt()) + 1
        self.deleteSetCurrentValue += diff
        return diff
    }
}
