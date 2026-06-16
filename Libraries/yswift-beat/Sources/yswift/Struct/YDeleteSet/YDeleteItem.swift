//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation


final class YDeleteItem {
    let clock: Int
    var len: Int
    
    init(clock: Int, len: Int) {
        self.clock = clock
        self.len = len
    }
}

extension YDeleteItem: CustomStringConvertible {
    public var description: String { "YDeleteItem(clock: \(clock), len: \(len))" }
}

extension YDeleteItem {
    static func findIndex(_ dis: RefArray<YDeleteItem>, clock: Int) -> Int? {
        var left = 0
        var right = dis.count - 1
        
        while (left <= right) {
            let midindex = (left+right) / 2
            let mid = dis[midindex]
            let midclock = mid.clock
            if midclock <= clock {
                if clock < midclock + mid.len {
                    return midindex
                }
                left = midindex + 1
            } else {
                right = midindex - 1
            }
        }
        return nil
    }
}
