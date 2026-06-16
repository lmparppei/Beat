//
//  File.swift
//  
//
//  Created by yuki on 2023/03/23.
//

final class RefArray<Element> {
    var value: [Element]
    
    var count: Int { self.value.count }
    
    var isEmpty: Bool { self.value.isEmpty }
    
    init(_ value: [Element]) { self.value = value }
    
    init(repeating element: Element, count: Int) { self.value = [Element](repeating: element, count: count) }
    
    subscript(_ index: Int) -> Element {
        get { self.value[index] }
        set { self.value[index] = newValue }
    }
    
    subscript<R: RangeExpression>(_ range: R) -> RefArray where R.Bound == Int {
        RefArray(self.value[range].map{ $0 })
    }
    
    func append(_ newElement: Element) {
        self.value.append(newElement)
    }
    
    func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element {
        self.value.append(contentsOf: newElements)
    }
    
    func insert(_ newElement: Element, at index: Int) {
        self.value.insert(newElement, at: index)
    }
    
    func insert<S: Collection>(contentsOf newElements: S, at index: Int) where S.Element == Element {
        self.value.insert(contentsOf: newElements, at: index)
    }
    
    func remove(at index: Int) -> Element {
        self.value.remove(at: index)
    }
    
    func popFirst() -> Element? {
        if self.value.isEmpty { return nil }
        return self.value.remove(at: 0)
    }
    
    func popLast() -> Element? {
        if self.value.isEmpty { return nil }
        return self.value.removeLast()
    }
}

extension RefArray {
    func map<T>(_ transform: (Element) throws -> T) rethrows -> RefArray<T> {
        try RefArray<T>(self.value.map(transform))
    }
    func filter(_ condition: (Element) throws -> Bool) rethrows -> RefArray<Element> {
        try RefArray(self.value.filter(condition))
    }
}

extension RefArray: Sequence {
    func makeIterator() -> some IteratorProtocol<Element> {
        self.value.makeIterator()
    }
}

extension RefArray: ExpressibleByArrayLiteral {
    typealias ArrayLiteralElement = Element
    
    convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension RefArray: CustomStringConvertible {
    var description: String { self.value.description }
}

extension RefArray: CustomDebugStringConvertible {
    var debugDescription: String { self.value.debugDescription }
}

 
