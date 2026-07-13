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
        let key = try decoder.readKey()
        let raw = try decoder.readJSON()

        let value: YTextAttributeValue? = {
            switch raw {
            case let v as Bool:         return v
            case let v as Int:          return v
            case let v as String:       return v
            case let v as NSString:     return v as String
            case let v as NSNumber:     return v
            case let v as NSDictionary: return v
            case let v as NSArray:      return v
            case is NSNull:             return NSNull()
            case nil:                   return nil
            default:
                assertionFailure("'\(raw as Any)' (\(type(of: raw as Any))) is not YTextAttributeValue")
                return nil
            }
        }()

        return YFormatContent(key: key, value: value as? YTextAttributeValue)
    }
}

extension YFormatContent: CustomStringConvertible {
    var description: String { "ContentFormat(key: \(key), value: \(value as Any?))" }
}
