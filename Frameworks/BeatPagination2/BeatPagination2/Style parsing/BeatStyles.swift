//
//  BeatStyles.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 28.9.2023.
//

import Foundation

public class BeatStyles:NSObject {
    @objc private static var sharedStyles:BeatStyles = {
        return BeatStyles()
    }()
    
    @objc class public func shared() -> BeatStyles {
        return sharedStyles
    }
    
    
}
