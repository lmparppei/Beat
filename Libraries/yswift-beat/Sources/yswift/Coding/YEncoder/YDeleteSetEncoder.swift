//
//  File.swift
//  
//
//  Created by yuki on 2023/03/25.
//

import Foundation
import lib0

protocol YDeleteSetEncoder {
    var restEncoder: LZEncoder { get set }
    var updateVersion: YUpdate.Version { get }
    
    func resetDeleteSetValue()
    func writeDeleteSetClock(_ clock: Int)
    func writeDeleteSetLen(_ len: Int)
    func toData() -> Data
}

extension YDeleteSetEncoder {
    func toUpdate() -> YUpdate { YUpdate(toData(), version: self.updateVersion) }
}

class YDeleteSetEncoderV1: YDeleteSetEncoder {
    var restEncoder = LZEncoder()
    
    var updateVersion: YUpdate.Version { .v1 }

    init() {}

    func toData() -> Data {
        return self.restEncoder.data
    }

    func resetDeleteSetValue() {}

    func writeDeleteSetClock(_ clock: Int) {
        self.restEncoder.writeUInt(UInt(clock))
    }

    func writeDeleteSetLen(_ len: Int) {
        self.restEncoder.writeUInt(UInt(len))
    }
}

class YDeleteSetEncoderV2: YDeleteSetEncoder {
    var restEncoder = LZEncoder()
    
    var updateVersion: YUpdate.Version { .v2 }
    
    private var dsCurrVal = 0

    init() {}

    func toData() -> Data {
        return self.restEncoder.data
    }

    func resetDeleteSetValue() {
        self.dsCurrVal = 0
    }

    func writeDeleteSetClock(_ clock: Int) {
        let diff = clock - self.dsCurrVal
        self.dsCurrVal = clock
        self.restEncoder.writeUInt(UInt(diff))
    }

    func writeDeleteSetLen(_ len: Int) {
        assert(len != 0, "Unexpected case")
//        if len == 0 {
//            throw YSwiftError.unexpectedCase
//        }
        self.restEncoder.writeUInt(UInt(len - 1))
        self.dsCurrVal += len
    }
}
