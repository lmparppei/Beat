//
//  BeatSwiftExtensions.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.1.2024.
//

import Foundation

/**
Makes sure no other thread reenters the closure before the one running has not returned
*/
@discardableResult
public func synchronized<T>(_ lock: AnyObject, closure:() -> T) -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return closure()
}
