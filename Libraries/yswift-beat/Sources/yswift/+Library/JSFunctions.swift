//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

func optionalEqual<T>(_ a: T?, _ b: T?, compare: (T, T) -> Bool) -> Bool {
    if a == nil && b == nil { return true }
    guard let a = a, let b = b else { return false }
    return compare(a, b)
}

// not complete copy of ===
func jsStrictEqual(_ a: Any?, _ b: Any?) -> Bool {
    if a == nil && b == nil {
        return true
    }
    // this may check JS object and array content
    if let a = a as? AnyHashable, let b = b as? AnyHashable {
        return a == b
    }
    return false
}

func removeDualOptional<T>(_ value: T??) -> T? {
    switch value {
    case .none: return nil
    case .some(let value):
        switch value {
        case .none: return nil
        case .some(let value): return value
        }
    }
}

extension Array {
    func at(_ index: Int) -> Element? {
        self.indices.contains(index) ? self[index] : nil
    }
}

extension Dictionary {
    mutating func setIfUndefined(_ key: Key, _ make: @autoclosure () throws -> Value) rethrows -> Value {
        if let value = self[key] { return value }
        let newValue = try make()
        self[key] = newValue
        return newValue
    }
}

extension Array {
    func jsReduce(_ body: (Element, Element) -> Element) -> Element {
        if self.isEmpty { fatalError() }
        if self.count == 1 { return self[0] }
        
        return self[1...].reduce(self[0], body)
    }
}

func equalJSON(_ a: Any?, _ b: Any?) -> Bool {
    if a == nil && b == nil { return true }
    if a is NSNull && b is NSNull { return true }
    if let a = a as? AnyObject, let b = b as? AnyObject, a === b { return true }
    if let a = a as? NSDictionary, let b = b as? NSDictionary { return a == b }
    if let a = a as? NSArray, let b = b as? NSArray { return a == b }
    if let a = a as? NSNumber, let b = b as? NSNumber { return a == b }
    if let a = a as? NSString, let b = b as? NSString { return a == b }
    return false
}

func equalAttributes(_ a: Any?, _ b: Any?) -> Bool {
    var a = a, b = b
    if a is NSNull { a = nil }
    if b is NSNull { b = nil }
    return equalJSON(a, b)
}
