//
//  File.swift
//  
//
//  Created by yuki on 2023/04/07.
//

import Foundation

struct WeakBox<Value: AnyObject> {
    weak var value: Value!
}

struct UnownedBox<Value: AnyObject> {
    unowned var value: Value
}
