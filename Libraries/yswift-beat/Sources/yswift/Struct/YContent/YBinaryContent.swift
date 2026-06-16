//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class YBinaryContent: YContent {
    var data: Data
    
    init(_ content: Data) { self.data = content }
}

extension YBinaryContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { 3 }
    
    var isCountable: Bool { true }

    var values: [Any?] { return [self.data] }

    func copy() -> YBinaryContent { return YBinaryContent(self.data) }

    func splice(_ offset: Int) -> YBinaryContent { fatalError() }

    func merge(with right: YContent) -> Bool { return false }
    
    func integrate(with item: YItem, _ transaction: YTransaction) {}
    
    func delete(_ transaction: YTransaction) {}
    
    func gc(_ store: YStructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) { encoder.writeBuf(self.data) }
    
    static func decode(from decoder: YUpdateDecoder) throws -> YBinaryContent {
        try YBinaryContent(decoder.readBuf())
    }
}
