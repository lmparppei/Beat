//
//  NSIndexSet+Array.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 7.8.2024.
//

import Foundation

@objc public extension NSIndexSet {
    
    @objc func toArray() -> [NSNumber] {
        var numbers:[NSNumber] = []
        self.enumerate { idx, stop in
            numbers.append(NSNumber(integerLiteral: idx))
        }
        
        return numbers
    }
    
    @objc class func fromArray(_ numbers:[NSNumber]) -> NSIndexSet {
        var indices:NSMutableIndexSet = NSMutableIndexSet()
        for num in numbers {
            indices.add(num.intValue)
        }
        
        return indices
    }
    
}
