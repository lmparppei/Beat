//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class YAnyContent: YContent {
    var array: [Any?]
    
    init(_ array: [Any?]) { self.array = array }
}

extension YAnyContent {
    var count: Int { return self.array.count }
    
    var typeid: UInt8 { 8 }
    
    var isCountable: Bool { true }

    var values: [Any?] { self.array }
    
    func copy() -> YAnyContent { return YAnyContent(self.array) }

    func splice(_ offset: Int) -> YAnyContent {
        let right = YAnyContent(self.array[offset...].map{ $0 })
        self.array = self.array[0..<offset].map{ $0 }
        return right
    }

    func merge(with right: YContent) -> Bool {
        self.array = self.array + (right as! YAnyContent).array
        return true
    }

    func integrate(with item: YItem, _ transaction: YTransaction) {}
    
    func delete(_ transaction: YTransaction) {}
    
    func gc(_ store: YStructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) {
        let count = self.array.count
        encoder.writeLen(count - offset)
        for i in offset..<count {
            encoder.writeAny(self.array[i])
        }
    }
    
    static func decode(from decoder: YUpdateDecoder) throws -> YAnyContent {
        let len = try decoder.readLen()
        var cs = [Any?]()
        for _ in 0..<len {
            try cs.append(decoder.readAny())
        }
        return YAnyContent(cs)
    }
}
