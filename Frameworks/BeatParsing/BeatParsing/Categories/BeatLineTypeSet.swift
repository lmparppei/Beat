//
//  BeatLineTypeSet.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 19.1.2024.
//

import Foundation

@objc public class BeatLineTypeSet:NSObject {
    var types:[UInt]
    
    @objc public init(types:[UInt]) {
        self.types = types
        super.init()
    }
    
    @objc public func contains(_ lineType:LineType) -> Bool {
        return types.contains(lineType.rawValue) 
    }
    
    @objc public func containsTypes(_ lineTypes:[UInt]) -> Bool {
        if lineTypes.count == 0 { return false }
        
        for type in lineTypes {
            if !self.types.contains(type) {
                return false
            }
        }
        
        return true
    }
}
