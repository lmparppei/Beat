//
//  BeatScreenplayElements.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 1.5.2023.
//

import Foundation

@objc public class BeatScreenplayElements:NSObject {
    @objc public static let shared = BeatScreenplayElements()
    
    private override init() {
        super.init()
    }
    
    @objc
    public var more:String {
        let string = BeatUserDefaults.shared().get(BeatSettingScreenplayItemMore) as? String ?? ""
        return "(" + string + ")"
    }
    
    @objc
    public var contd:String {
        let string = BeatUserDefaults.shared().get(BeatSettingScreenplayItemContd) as? String ?? ""
        return " (" + string + ")"
    }
    
    @objc 
    public var spaceBeforeHeading:Int {
        return BeatUserDefaults.shared().getInteger(BeatSettingSceneHeadingSpacing)
    }
}
