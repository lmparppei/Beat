//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation
import Combine

final public class YArray<Element: YElement> {
    public let opaque: YOpaqueArray
    
    public var count: Int { self.opaque.count }
    
    public var isEmpty: Bool { self.opaque.count == 0 }
    
    public init(opaque: YOpaqueArray) { self.opaque = opaque }
    
    public convenience init() { self.init(opaque: YOpaqueArray()) }
    
    public convenience init<S: Sequence>(_ contents: S) where S.Element == Element {
        self.init(opaque: YOpaqueArray(contents.lazy.map{ $0.toOpaque() }))
    }
    
    public subscript(index: Int) -> Element {
        Element.fromOpaque(self.opaque[index])
    }
    public subscript<R: _RangeExpression>(range: R) -> [Element] {
        self.opaque[range].map{ Element.fromOpaque($0) }
    }
    
    public func append(_ content: Element) {
        self.opaque.append(content.toOpaque())
    }
    public func append<S: Sequence>(contentsOf contents: S) where S.Element == Element {
        self.opaque.append(contentsOf: contents.map{ $0.toOpaque() })
    }
    
    public func insert(_ content: Element, at index: Int) {
        self.opaque.insert(content.toOpaque(), at: index)
    }
    public func insert<S: Sequence>(contentsOf contents: S, at index: Int) where S.Element == Element {
        self.opaque.insert(contentsOf: contents.map{ $0.toOpaque() }, at: index)
    }

    public func delete(at index: Int) {
        opaque.delete(at: index)
    }
    public func delete<R: _RangeExpression>(in range: R) {
        opaque.delete(in: range)
    }
    public func deleteAll() {
        opaque.deleteAll()
    }
    
    public func remove(at index: Int) -> Element {
        Element.fromOpaque(opaque.remove(at: index))
    }
    
    public func assign(_ other: [Element]) {
        opaque.assign(other.map{ $0.toOpaque() })
    }
    
    public func copy() -> YArray<Element> {
        YArray(opaque: self.opaque.copy())
    }
    
    public func toJSON() -> Any { self.opaque.toJSON() }
    
    public func toArray() -> [Element] { Array(self) }
}

extension YArray: Equatable where Element: Equatable {
    public static func == (lhs: YArray<Element>, rhs: YArray<Element>) -> Bool {
        lhs.toArray() == rhs.toArray()
    }
}

extension YArray: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.toArray())
    }
}

extension YArray: YWrapperObject {
    public static var isWrappingReference: Bool { Element.isReference }
}

extension YArray: YElement {
    public static var isReference: Bool { false }
    
    public func toOpaque() -> Any? { self.opaque }
    public static func fromOpaque(_ opaque: Any?) -> Self { self.init(opaque: opaque as! YOpaqueArray) }
}

extension YArray: CustomStringConvertible {
    public var description: String { self.toArray().description }
}

extension YArray: Sequence {
    public var first: Element? { self.isEmpty ? nil : self[0] }
    
    public var last: Element? { self.isEmpty ? nil : self[self.count-1] }
    
    public func makeIterator() -> some IteratorProtocol<Element> {
        return self.opaque.lazy.map{ Element.fromOpaque($0) }.makeIterator()
    }
}

extension YArray: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Element
    
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension YArray {
    public var publisher: some Combine.Publisher<YArray<Element>, Never> {
        let eventPublisher = self.eventPublisher.map{_ in self }
        return Just(self).merge(with: eventPublisher)
    }
    
    public var opaqueEventPublisher: some Combine.Publisher<YEvent, Never> {
        self.opaque._eventHandler.publisher.map{ event, _ in event }
    }
    
    public var opaqueDeepPublisher: some Combine.Publisher<[YEvent], Never> {
        self.opaque._deepEventHandler.publisher.map{ event, _ in event }
    }
}

extension YArray {
    public var eventPublisher: some Combine.Publisher<Event, Never> {
        self.opaqueEventPublisher.map{ try! Event($0) }
    }
    
    public struct Event {
        let retain: Int
        let delete: Int
        let insert: [Element]
        
        public init(retain: Int = 0, delete: Int = 0, insert: [Element] = []) {
            self.retain = retain
            self.delete = delete
            self.insert = insert
        }
        
        init(_ event: YEvent) throws {
            var retain = 0
            var delete = 0
            var insert = [Element]()
            
            for delta in event.changes().delta {
                if let v = delta.retain { retain += v }
                if let v = delta.delete { delete += v }
                if let v = delta.insert { insert.append(contentsOf: v as! [Element]) }
            }
            
            self.retain = retain
            self.delete = delete
            self.insert = insert
        }
    }
}

extension YArray.Event: Equatable where Element: Equatable {}
extension YArray.Event: CustomStringConvertible {
    public var description: String {
        var components = [String]()
        if retain != 0 { components.append("retain: \(retain)") }
        if delete != 0 { components.append("delete: \(delete)") }
        if insert.count != 0 { components.append("insert: \(insert)") }
        return "YArray.Event(\(components.joined(separator: ", ")))"
    }
}
