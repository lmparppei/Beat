//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

/**
 Since `YArray` and `YMap` create a new instance for every get operation except for objects inheriting from `YObject`,
 the implementation of `YElement` must be light weight.
 
 (This problem does not occur in `YObject` because `YObject.Property` cache data.)
 */
public protocol YElement {
    /// Whether this type requires a reference to be updated during SmartCopy
    static var isReference: Bool { get }
    
    /// Make opaque data concrete.
    static func fromOpaque(_ opaque: Any?) -> Self
    
    /// Make concrete data opaque.
    func toOpaque() -> Any?
}

extension YElement {
    /// In almost all cases isReference will be false, so a default implementation is provided.
    public static var isReference: Bool { false } 
}


