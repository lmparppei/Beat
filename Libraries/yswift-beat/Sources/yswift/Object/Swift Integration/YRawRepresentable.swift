//
//  File.swift
//  
//
//  Created by yuki on 2023/04/02.
//

import Foundation

public protocol YRawRepresentable: YValue {
    associatedtype RawValue: YValue

    var rawValue: RawValue { get }

    init?(rawValue: RawValue)
}

extension YRawRepresentable {
    public func toOpaque() -> Any? { self.rawValue }
    
    public static func fromOpaque(_ opaque: Any?) -> Self {
        Self.init(rawValue: opaque as! Self.RawValue)!
    }
    
    public func toPropertyList() -> Any? { self.rawValue }
    
    public static func fromPropertyList(_ content: Any?) -> Self? {
        guard let rawValue = content as? RawValue else { return nil }
        return Self.init(rawValue: rawValue)
    }
}
