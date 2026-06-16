//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

final public class YMap<Value: YElement> {
    public let opaque: YOpaqueMap
        
    public init(opaque: YOpaqueMap) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueMap()) }
    
    public convenience init(_ dictionary: [String: Value]) { self.init(opaque: YOpaqueMap(dictionary)) }
}

extension YMap {
    public var count: Int { self.opaque.count }
    
    public var isEmpty: Bool { self.opaque.isEmpty }
    
    public subscript(key: String) -> Value? {
        get { self.opaque[key].map{ Value.fromOpaque($0) } }
        set { self.opaque[key] = newValue?.toOpaque() }
    }

    public func set(_ key: String, value: Value?) throws {
        self.opaque.set(key, value: value)
    }
    
    public func keys() -> some Sequence<String> {
        self.opaque.keys()
    }
    
    public func values() -> some Sequence<Value> {
        self.opaque.values().lazy.map{ Value.fromOpaque($0)  }
    }
    
    public func removeValue(forKey key: String) throws -> Value? {
        self.opaque.removeValue(forKey: key).map{ Value.fromOpaque($0) }
    }
    
    public func deleteValue(forKey key: String) throws {
        self.opaque.deleteValue(forKey: key)
    }
    
    public func contains(_ key: String) -> Bool {
        return self.opaque.contains(key)
    }

    public func removeAll() throws {
        self.opaque.removeAll()
    }
    
    public func copy() -> YMap<Value> {
        YMap(opaque: self.opaque.copy())
    }
    
    public func toJSON() -> Any {
        self.opaque.toJSON()
    }
    
    public func toDictionary() -> [String: Value] {
        Dictionary(uniqueKeysWithValues: self)
    }
}

extension YMap: YWrapperObject {
    public static var isWrappingReference: Bool { Value.isReference }
}

extension YMap: YElement {
    public static var isReference: Bool { false }
    public func toOpaque() -> Any? { self.opaque }
    public static func fromOpaque(_ opaque: Any?) -> Self { self.init(opaque: opaque as! YOpaqueMap) }
}

extension YMap: ExpressibleByDictionaryLiteral {
    public convenience init(dictionaryLiteral elements: Element...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension YMap: CustomStringConvertible {
    public var description: String { self.toDictionary().description }
}

extension YMap: Equatable where Value: Equatable {
    public static func == (lhs: YMap<Value>, rhs: YMap<Value>) -> Bool {
        lhs.toDictionary() == rhs.toDictionary()
    }
}

extension YMap: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(toDictionary())
    }
}

extension YMap: Sequence {
    public typealias Element = (String, Value)
    
    public func makeIterator() -> some IteratorProtocol<Element> {
        self.opaque.lazy.map{ (key: $0, value: Value.fromOpaque($1)) }.makeIterator()
    }
}

extension YMap {
    public var publisher: some Combine.Publisher<YMap<Value>, Never> {
        self.opaque._eventHandler.publisher.map{_ in self }
    }
    
    public var deepPublisher: some Combine.Publisher<Void, Never> {
        self.opaque._deepEventHandler.publisher.map{_ in () }
    }
}
