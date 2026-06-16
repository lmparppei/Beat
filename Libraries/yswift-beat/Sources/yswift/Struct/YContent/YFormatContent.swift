//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class YFormatContent: YContent {
    var key: String
    var value: YTextAttributeValue?
    
    init(key: String, value: YTextAttributeValue?) {
        self.key = key
        self.value = value
    }
}

extension YFormatContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { return 6 }
    
    var isCountable: Bool { false }
    
    var values: [Any?] { [] }

    func copy() -> YFormatContent { return YFormatContent(key: self.key, value: self.value) }

    func splice(_ offset: Int) -> YFormatContent { fatalError() }

    func merge(with right: YContent) -> Bool { false }

    func integrate(with item: YItem, _ transaction: YTransaction) {
        item.parent?.object?.serchMarkers = nil
    }

    func delete(_ transaction: YTransaction) {}
    
    func gc(_ store: YStructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) {
        encoder.writeKey(self.key)
        encoder.writeJSON(self.value)
    }

    static func decode(from decoder: YUpdateDecoder) throws -> YFormatContent {
        // TODO: this as? may be wrong
        let key = try decoder.readKey()
        let value = try decoder.readJSON()
        if !(value is YTextAttributeValue?) {
            assertionFailure("'\(value as Any)' (\(type(of: value))) is not YTextAttributeValue")
        }
        return YFormatContent(key: key, value: value as? YTextAttributeValue)
    }
}

extension YFormatContent: CustomStringConvertible {
    var description: String { "ContentFormat(key: \(key), value: \(value as Any?))" }
}
