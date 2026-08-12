//
//  File.swift
//  
//
//  Created by yuki on 2023/04/08.
//

import Foundation

public protocol YValue: YElement, YPasteboardCopy {}

protocol _YPrimitiveValue: YValue {}
extension _YPrimitiveValue {
    public static var isReference: Bool { false }
    
    public func toOpaque() -> Any? { self }
    public static func fromOpaque(_ opaque: Any?) -> Self { opaque as! Self }
    
    public func toPropertyList() -> Any? { self }
    public static func fromPropertyList(_ content: Any?) -> Self? { content as? Self }
}

extension Int: _YPrimitiveValue {}
extension Int8: _YPrimitiveValue {}
extension Int16: _YPrimitiveValue {}
extension Int32: _YPrimitiveValue {}
extension Int64: _YPrimitiveValue {}

extension UInt: _YPrimitiveValue {}
extension UInt8: _YPrimitiveValue {}
extension UInt16: _YPrimitiveValue {}
extension UInt32: _YPrimitiveValue {}
extension UInt64: _YPrimitiveValue {}

extension Float: _YPrimitiveValue {}
extension CGFloat: _YPrimitiveValue {}
extension Double: _YPrimitiveValue {}

extension String: _YPrimitiveValue {}
extension Data: _YPrimitiveValue {}

extension NSArray: _YPrimitiveValue {}
extension NSDictionary: _YPrimitiveValue {}

extension Array: YPasteboardCopy where Element: YPasteboardCopy {
    public func toPropertyList() -> Any? {
        self.map{ $0.toPropertyList() }
    }
    public static func fromPropertyList(_ content: Any?) -> Array<Element>? {
        (content as? [NSDictionary?]).map{ $0.compactMap{ Element.fromPropertyList($0) } }
    }
}
extension Array: YElement, YValue where Element: YValue {
    public static var isReference: Bool { Element.isReference }
    
    public func toOpaque() -> Any? { self.map{ $0.toOpaque() } }
    
    public static func fromOpaque(_ opaque: Any?) -> [Element] {
        (opaque as! [Any?]).map{ Element.fromOpaque($0) }
    }
}

extension Dictionary: YPasteboardCopy where Key == String, Value: YValue {
    public func toPropertyList() -> Any? {
        self.mapValues{ $0.toPropertyList() } as NSDictionary
    }
    public static func fromPropertyList(_ content: Any?) -> Dictionary<String, Value>? {
        (content as? [String: NSDictionary])?.compactMapValues{ Value.fromPropertyList($0) }
    }
}
extension Dictionary: YElement, YValue where Key == String, Value: YValue {
    public static var isReference: Bool { Value.isReference }
    
    public func toOpaque() -> Any? { self.mapValues{ $0.toOpaque() } }
    
    public static func fromOpaque(_ opaque: Any?) -> Dictionary<String, Value> {
        (opaque as! [String: Any?]).mapValues{ Value.fromOpaque($0) }
    }
}

extension Optional: YPasteboardCopy where Wrapped: YPasteboardCopy {
    public func toPropertyList() -> Any? { self?.toPropertyList() }
 
    public static func fromPropertyList(_ content: Any?) -> Optional<Wrapped>? { content as? Wrapped }
}
extension Optional: YElement where Wrapped: YElement {
    public static var isReference: Bool { Wrapped.isReference }
    
    public func toOpaque() -> Any? {
        switch self {
        case .none: return NSNull()
        case .some(let element): return element.toOpaque()
        }
    }
    public static func fromOpaque(_ opaque: Any?) -> Self {
        if opaque == nil || opaque is NSNull {
            return .none
        } else {
            return .some(Wrapped.fromOpaque(opaque))
        }
    }
}

