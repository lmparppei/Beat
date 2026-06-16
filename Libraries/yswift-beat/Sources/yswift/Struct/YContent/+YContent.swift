//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

protocol YContent: AnyObject, CustomStringConvertible {
    var count: Int { get }
    
    var typeid: UInt8 { get }
    
    var isCountable: Bool { get }
    
    var values: [Any?] { get }
    
    func copy() -> Self
    
    func splice(_ offset: Int) -> Self

    func merge(with right: any YContent) -> Bool

    func integrate(with item: YItem, _ transaction: YTransaction) -> Void

    func delete(_ transaction: YTransaction) -> Void

    func gc(_ store: YStructStore) -> Void

    func encode(into encoder: YUpdateEncoder, offset: Int) -> Void
    
    static func decode(from decoder: YUpdateDecoder) throws -> Self
}

extension YContent {
    public var description: String {
        var components = [String]()
        for child in Mirror(reflecting: self).children {
            components.append("\(child.label ?? ""): \(child.value)")
        }
        return "\(Self.self)(\(components.joined(separator: ", ")))"
    }
}

func decodeContent(from decoder: YUpdateDecoder, info: UInt8) throws -> any YContent {
    return try contentDecoders_[Int(info & 0b0001_1111)](decoder)
}

/** A lookup map for reading Item content. */
fileprivate let contentDecoders_: [(YUpdateDecoder) throws -> any YContent] = [
    {_ in throw YSwiftError.unexpectedCase }, // GC is not ItemContent
    YDeletedContent.decode(from:), // 1
    YJSONContent.decode(from:), // 2
    YBinaryContent.decode(from:), // 3
    YStringContent.decode(from:), // 4
    YEmbedContent.decode(from:), // 5
    YFormatContent.decode(from:), // 6
    YObjectContent.decode(from:), // 7
    YAnyContent.decode(from:), // 8
    YDocumentContent.decode(from:), // 9
    {_ in throw YSwiftError.unexpectedCase }, // 10 - Skip is not ItemContent
]
