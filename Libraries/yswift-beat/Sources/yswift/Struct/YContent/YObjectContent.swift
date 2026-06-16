//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final class YObjectContent: YContent {
    var object: YOpaqueObject
    
    init(_ object: YOpaqueObject) { self.object = object }
}

extension YObjectContent {
    var count: Int { 1 }
    
    var typeid: UInt8 { 7 }
    
    var isCountable: Bool { true }

    var values: [Any?] { [self.object] }

    func copy() -> YObjectContent { YObjectContent(self.object._copy()) }

    func splice(_ offset: Int) -> YObjectContent { fatalError() }

    func merge(with right: YContent) -> Bool { false }

    func integrate(with item: YItem, _ transaction: YTransaction) {
        self.object._integrate(transaction.doc, item: item)
    }

    func delete(_ transaction: YTransaction) {
        var item = self.object._start
        while let uitem = item {
            if !uitem.deleted {
                uitem.delete(transaction)
            } else {
                transaction._mergeStructs.value.append(uitem)
            }
            item = uitem.right as? YItem
        }
        for (_, item) in self.object.storage {
            if !item.deleted {
                item.delete(transaction)
            } else {
                transaction._mergeStructs.value.append(item)
            }
        }
        transaction.changed.removeValue(forKey: self.object)
    }

    func gc(_ store: YStructStore) {
        var item = self.object._start
        while let uitem = item {
            uitem.gc(store, parentGC: true)
            item = uitem.right as? YItem
        }
        
        self.object._start = nil
        for (_, item) in self.object.storage {
            var item: YItem? = item
            while let uitem = item {
                uitem.gc(store, parentGC: true)
                item = uitem.left as? YItem
            }
        }
        self.object.storage = [:]
    }

    func encode(into encoder: YUpdateEncoder, offset: Int) {
        self.object._write(encoder)
    }
    
    static func decode(from decoder: YUpdateDecoder) throws -> YObjectContent {
        let typeID = try decoder.readTypeRef()
        
        if typeID <= 6 {
            let object = YObjectContent.objectDecoder[typeID](decoder)
            return YObjectContent(object)
        }
        
        guard let objectDecoder = customObjectDecoder[typeID] else { throw YSwiftError.unexpectedCase }
        let object = objectDecoder(decoder)
        return YObjectContent(object)
    }
}

extension YObjectContent {
    static func register(for typeID: Int, _ decoder: @escaping (YUpdateDecoder) -> (YObject)) {
        assert(typeID > 6)
        assert(customObjectDecoder[typeID] == nil)
        
        customObjectDecoder[typeID] = decoder
    }
    
    static func unregister(for typeID: Int) {
        assert(typeID > 6)
        assert(customObjectDecoder[typeID] != nil)
        
        customObjectDecoder.removeValue(forKey: typeID)
    }
    
    static private var objectDecoder: [(YUpdateDecoder) -> YOpaqueObject] = [
        readYArray,
        readYMap,
        readYText,
        {_ in fatalError() }, // XMLElement
        {_ in fatalError() }, // XMLFragment
        {_ in fatalError() }, // XMLHook
        {_ in fatalError() }, // XMLText
        // customs...
    ]
    
    static private var customObjectDecoder: [Int: (YUpdateDecoder) -> YObject] = [:]
}

let YArrayRefID: Int = 0
let YMapRefID: Int = 1
let YTextRefID: Int = 2
//let YXmlElementRefID: UInt8 = 3
//let YXmlFragmentRefID: UInt8 = 4
//let YXmlHookRefID: UInt8 = 5
//let YXmlTextRefID: UInt8 = 6
