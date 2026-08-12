//
//  UpdateDecoder.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import lib0

protocol YUpdateDecoder: YDeleteSetDecoder {
    func readLeftID() throws -> YIdentifier
    func readRightID() throws -> YIdentifier
    func readClient() throws -> Int
    func readInfo() throws -> UInt8
    func readString() throws -> String
    func readParentInfo() throws -> Bool
    func readTypeRef() throws -> Int
    func readLen() throws -> Int
    func readAny() throws -> Any?
    func readBuf() throws -> Data
    func readKey() throws -> String
    func readJSON() throws -> Any?
}

final class YUpdateDecoderV1: YDeleteSetDecoderV1, YUpdateDecoder {
    func readLeftID() throws -> YIdentifier {
        return try YIdentifier(
            client: Int(self.restDecoder.readUInt()),
            clock: Int(self.restDecoder.readUInt())
        )
    }

    func readRightID() throws -> YIdentifier {
        return try YIdentifier(
            client: Int(self.restDecoder.readUInt()),
            clock: Int(self.restDecoder.readUInt())
        )
    }

    func readClient() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    func readInfo() -> UInt8 {
        return self.restDecoder.readUInt8()
    }

    func readString() throws -> String {
        return try self.restDecoder.readString()
    }

    func readParentInfo() throws -> Bool {
        return try self.restDecoder.readUInt() == 1
    }

    func readTypeRef() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    func readLen() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    func readAny() throws -> Any? {
        return try self.restDecoder.readAny()
    }

    func readBuf() throws -> Data {
        return try self.restDecoder.readData()
    }

    func readKey() throws -> String {
        return try self.restDecoder.readString()
    }
    
    func readJSON() throws -> Any? {
        let data = try self.restDecoder.readData()
        return try! JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

class YUpdateDecoderV2: YDeleteSetDecoderV2, YUpdateDecoder {
    var keys: [String] = []
    
    let keyClockDecoder: LZIntDiffOptRleDecoder
    let clientDecoder: LZUIntOptRleDecoder
    let leftClockDecoder: LZIntDiffOptRleDecoder
    let rightClockDecoder: LZIntDiffOptRleDecoder
    let infoDecoder: LZRleDecoder
    let stringDecoder: LZStringDecoder
    let parentInfoDecoder: LZRleDecoder
    let typeRefDecoder: LZUIntOptRleDecoder
    let lenDecoder: LZUIntOptRleDecoder

    required init(_ decoder: LZDecoder) throws {
        _ = try decoder.readUInt() // read feature flag - currently unused
        self.keyClockDecoder = LZIntDiffOptRleDecoder(try decoder.readData())
        self.clientDecoder = LZUIntOptRleDecoder(try decoder.readData())
        self.leftClockDecoder = LZIntDiffOptRleDecoder(try decoder.readData())
        self.rightClockDecoder = LZIntDiffOptRleDecoder(try decoder.readData())
        self.infoDecoder = LZRleDecoder(try decoder.readData())
        self.stringDecoder = try LZStringDecoder(try decoder.readData())
        self.parentInfoDecoder = LZRleDecoder(try decoder.readData())
        self.typeRefDecoder = LZUIntOptRleDecoder(try decoder.readData())
        self.lenDecoder = LZUIntOptRleDecoder(try decoder.readData())
        
        try super.init(decoder)
    }

    func readLeftID() throws -> YIdentifier {
        return try YIdentifier(
            client: Int(self.clientDecoder.read()),
            clock: self.leftClockDecoder.read()
        )
    }

    func readRightID() throws -> YIdentifier {
        return try YIdentifier(
            client: Int(self.clientDecoder.read()),
            clock: self.rightClockDecoder.read()
        )
    }

    func readClient() throws -> Int {
        return try Int(self.clientDecoder.read())
    }

    func readInfo() throws -> UInt8 {
        return try self.infoDecoder.read()
    }

    func readString() throws -> String {
        return try self.stringDecoder.read()
    }

    func readParentInfo() throws -> Bool {
        return try self.parentInfoDecoder.read() == 1
    }

    func readTypeRef() throws -> Int {
        return try Int(self.typeRefDecoder.read())
    }

     func readLen() throws -> Int {
        return try Int(self.lenDecoder.read())
    }

    func readAny() throws -> Any? {
        return try self.restDecoder.readAny()
    }

    func readBuf() throws -> Data {
        return try self.restDecoder.readData()
    }

    func readKey() throws -> String {
        let keyClock = try self.keyClockDecoder.read()
        if keyClock < self.keys.count {
            return self.keys[keyClock]
        } else {
            let key = try self.stringDecoder.read()
            self.keys.append(key)
            return key
        }
    }
    
    func readJSON() throws -> Any? {
        return try self.restDecoder.readAny()
    }
}


