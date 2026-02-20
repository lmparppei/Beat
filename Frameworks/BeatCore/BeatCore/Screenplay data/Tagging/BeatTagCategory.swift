//
//  BeatTagCategory.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 9.2.2026.
//

import Foundation
import UXKit

@objcMembers
public class BeatTagCategory:NSObject {
    public var type:BeatTagType
    public var keyName:String
    public var colorName:String
    public var icon:UXImage?
    public var fdxCategories:[String]
    
    private var color:UXColor?
    
    public init(type: BeatTagType, keyName: String, iconName:String?, colorName: String, fdxCategories: [String]) {
        self.type = type
        self.keyName = keyName
        self.colorName = colorName
        self.fdxCategories = fdxCategories
        
        if let iconName {
            #if os(macOS)
            if #available(macOS 11.0, *) {
                self.icon = NSImage.init(systemSymbolName: iconName, accessibilityDescription: nil)
            }
            #else
            self.icon = UXImage(systemName: iconName)
            #endif
        }
        
        self.color = BeatColors.color(colorName.lowercased())
    }
}
 
