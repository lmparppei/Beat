//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

final class RefDictionary<Key: Hashable, Value> {
    typealias Element = (key: Key, value: Value)

    var value: [Key: Value]
    
    var count: Int { value.count }

    var isEmpty: Bool { value.isEmpty }

    init() { self.value = [:] }
    
    init(_ value: [Key: Value]) { self.value = value }
    
    subscript(key: Key) -> Value? {
        get { self.value[key] } set { self.value[key] = newValue }
    }
    
    func copy() -> RefDictionary<Key, Value> {
        RefDictionary(self.value)
    }
}

extension RefDictionary: ExpressibleByDictionaryLiteral {
    convenience init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension RefDictionary: Sequence {
    func makeIterator() -> some IteratorProtocol<Element> {
        self.value.makeIterator()
    }
}

extension RefDictionary: CustomStringConvertible {
    var description: String { self.value.description }
}
