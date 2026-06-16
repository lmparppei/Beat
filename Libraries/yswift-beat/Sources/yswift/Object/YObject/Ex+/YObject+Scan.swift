//
//  File.swift
//  
//
//  Created by yuki on 2023/04/07.
//

import Foundation

extension YObject {
    public func scanRecursive(_ body: (YObject) -> ()) {
        body(self)
        
        for (_, value) in self.elementSequence() {
            if let value = value as? YObject {
                value.scanRecursive(body)
            }
            if let value = value as? YOpaqueArray {
                value.forEach{ ($0 as? YObject)?.scanRecursive(body) }
            }
            if let value = value as? YOpaqueMap {
                value.values().forEach{ ($0 as? YObject)?.scanRecursive(body) }
            }
        }
    }
}
