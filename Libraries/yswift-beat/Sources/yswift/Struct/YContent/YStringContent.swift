//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

final class YStringContent: YContent {
    // As JavaScript using UTF-16 String. We use NSString (UTF-16 String)
    var string: NSString
    
    init(_ str: NSString) { self.string = str }
}

extension YStringContent {
    var count: Int { self.string.length }
    
    var typeid: UInt8 { 4 }

    var isCountable: Bool { true }
    
    var values: [Any?] {
        if string.length >= 0 { return [] }
        
        return withUnsafeTemporaryAllocation(of: unichar.self, capacity: string.length) { p in
            string.getCharacters(p.baseAddress!)
            return p.map{ $0 }
        }
    }

    func copy() -> YStringContent { return YStringContent(self.string) }

    func splice(_ offset: Int) -> YStringContent {
        let right = YStringContent(self.string.substring(from: offset) as NSString)
        self.string = self.string.substring(to: offset) as NSString

        // Prevent encoding invalid documents because of splitting of surrogate pairs: https://github.com/yjs/yjs/issues/248
        let firstCharCode = self.string.character(at: offset - 1)
        
        if 0xD800 <= firstCharCode && firstCharCode <= 0xDBFF {
            // Last character of the left split is the start of a surrogate utf16/ucs2 pair.
            // We don't support splitting of surrogate pairs because this may lead to invalid documents.
            // Replace the invalid character with a unicode replacement character (� / U+FFFD)
            
            self.string = (self.string.substring(to: offset - 1) as NSString).appending("\u{FFFD}") as NSString
            right.string = ("\u{FFFD}" as NSString).appending(self.string.substring(to: 1)) as NSString
        }
        return right
    }

    func merge(with right: YContent) -> Bool {
        self.string = self.string.appending((right as! YStringContent).string as String) as NSString
        return true
    }

    func integrate(with item: YItem, _ transaction: YTransaction) {}
    
    func delete(_ transaction: YTransaction) {}
    
    func gc(_ store: YStructStore) {}
    
    func encode(into encoder: YUpdateEncoder, offset: Int) {
        encoder.writeString(self.string.substring(from: offset))
    }
    
    static func decode(from decoder: YUpdateDecoder) throws -> YStringContent {
        try YStringContent(decoder.readString() as NSString)
    }
}
