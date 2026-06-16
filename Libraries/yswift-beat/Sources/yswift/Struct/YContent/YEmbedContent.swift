//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class YEmbedContent: YContent {
    let embed: Any?
    
    init(_ embed: Any?) { self.embed = embed }
}

extension YEmbedContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { 5 }
    
    var isCountable: Bool { true }

    var values: [Any?] { [self.embed] }

    func copy() -> YEmbedContent { YEmbedContent(self.embed) }

    func splice(_ offset: Int) -> YEmbedContent { fatalError() }

    func merge(with right: YContent) -> Bool { false }

    func integrate(with item: YItem, _ transaction: YTransaction) {}
    
    func delete(_ transaction: YTransaction) {}
    
    func gc(_ store: YStructStore) {}

    func encode(into encoder: YUpdateEncoder, offset: Int) { encoder.writeJSON(self.embed) }
    
    static func decode(from decoder: YUpdateDecoder) throws -> YEmbedContent {
        try YEmbedContent(decoder.readJSON())
    }
}
