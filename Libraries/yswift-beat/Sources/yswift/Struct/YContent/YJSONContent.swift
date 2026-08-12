//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class YJSONContent: YContent {
    var array: [Any?]
    
    init(_ arr: [Any?]) { self.array = arr }
}

extension YJSONContent {
    var count: Int { self.array.count }

    var isCountable: Bool { true }
    
    var typeid: UInt8 { 2 }
    
    var values: [Any?] { self.array }

    func copy() -> YJSONContent { YJSONContent(self.array) }

    func splice(_ offset: Int) -> YJSONContent {
        let right = YJSONContent(self.array[offset...].map{ $0 })
        self.array = self.array[..<offset].map{ $0 }
        return right
    }

    func merge(with right: YContent) -> Bool {
        self.array = self.array + (right as! YJSONContent).array
        return true
    }

    func integrate(with item: YItem, _ transaction: YTransaction) {}
    
    func delete(_ transaction: YTransaction) {}
    
    func gc(_ store: YStructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) {
        let len = self.array.count
        encoder.writeLen(len - offset)
        for i in offset..<len {
            let c = self.array[i]
            if let c = c {
                let jsonData = try! JSONSerialization.data(withJSONObject: c, options: [.fragmentsAllowed])
                encoder.writeBuf(jsonData)
            } else {
                encoder.writeString("undefined")
            }
            if let c = c {
                encoder.writeBuf(try! JSONSerialization.data(withJSONObject: c, options: [.fragmentsAllowed]))
            } else {
                encoder.writeString("undefined")
            }
        }
    }

    static func decode(from decoder: YUpdateDecoder) throws -> YJSONContent {
        let len = try decoder.readLen()
        var cs: [Any?] = []
        for _ in 0..<len {
            let c = try decoder.readString()
            if c == "undefined" {
                cs.append(nil)
            } else {
                try cs.append(JSONSerialization.jsonObject(with: c.data(using: .utf8)!, options: [.fragmentsAllowed]))
            }
        }
        return YJSONContent(cs)
    }
}
