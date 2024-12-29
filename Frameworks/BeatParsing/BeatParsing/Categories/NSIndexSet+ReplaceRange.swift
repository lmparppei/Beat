//
//  NSIndexSet+ReplaceRange.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 1.10.2023.
//

import Foundation

public extension NSMutableIndexSet {
    /// Replaces a range in this index set
    @objc func replaceRange(_ range:NSRange, lengthChange length:Int) {
        let startIndex = range.location
        let endIndex = startIndex + range.length
        
        // Create an array of the indices to offset
        let indicesToOffset = self.filter { index in
            return index >= startIndex && index <= endIndex
        }
        
        // Offset the indices based on the length change
        for index in indicesToOffset {
            self.remove(index)
            self.add(index + length)
        }
    }
}

public extension NSIndexSet {
    @objc func arrayRepresentation() -> NSArray {
        let array = NSMutableArray()
        
        enumerateRanges { range, stop in
            if range.length > 0 {
                array.add([ range.location, range.length])
            }
        }
        
        return array as NSArray
    }
}
