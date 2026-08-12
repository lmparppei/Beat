//
//  File.swift
//
//
//  Created by yuki on 2023/04/07.
//

import Foundation


public protocol YCodable: YValue, Codable {}

private let opaqueEncoder = DictionaryEncoder(dataEncoding: .nsdata)
private let opaqueDecoder = DictionaryDecoder()

private let propertyListEncoder = DictionaryEncoder(dataEncoding: .base64)
private let propertyListDecoder = DictionaryDecoder()

extension YCodable {
    public func toOpaque() -> Any? { try! opaqueEncoder.encode(self) }
    public func toPropertyList() -> Any? { try! propertyListEncoder.encode(self) }
}

extension YCodable {
    public static func fromOpaque(_ opaque: Any?) -> Self {
        try! opaqueDecoder.decode(Self.self, from: opaque)
    }
    public static func fromPropertyList(_ content: Any?) -> Self? {
        try! propertyListDecoder.decode(Self.self, from: content)
    }
}

