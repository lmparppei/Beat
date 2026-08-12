//
//  File.swift
//  
//
//  Created by yuki on 2023/04/08.
//

import Combine

public protocol YWrapperObject: YElement {
    associatedtype Opaque: YOpaqueObject
    associatedtype Publisher: Combine.Publisher<Self, Never>
    
    var opaque: Opaque { get }
    
    var publisher: Publisher { get }
    
    static var isWrappingReference: Bool { get }
    
    init(opaque: Opaque)
}

