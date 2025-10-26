//
//  NSRange+Clamp.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 1.10.2025.
//

public extension NSRange {
    public func clamped(to length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        
        let safeLocation = max(0, min(location, length))
        let safeLength = max(0, min(length - safeLocation, self.length))
        
        return NSRange(location: safeLocation, length: safeLength)
    }
}
