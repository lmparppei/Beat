//
//  NSDictionary+Inverse.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.12.2024.
//

import Foundation

public extension NSDictionary {
    
    @objc func inverted() -> NSDictionary {
        var dict = NSMutableDictionary()
        
        for key in self.allKeys {
            if let value = self[key] {
                dict[value] = key
            }
        }
        
        return dict
    }
    
}
