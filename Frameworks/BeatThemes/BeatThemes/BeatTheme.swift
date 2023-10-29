//
//  BeatTheme.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import BeatDynamicColor

@objc public class BeatTheme: NSObject, NSCopying {
    @objc public var backgroundColor: DynamicColor!
    @objc public var selectionColor: DynamicColor!
    @objc public var textColor: DynamicColor!
    @objc public var invisibleTextColor: DynamicColor!
    @objc public var caretColor: DynamicColor!
    @objc public var commentColor: DynamicColor!
    @objc public var marginColor: DynamicColor!
    @objc public var outlineBackground: DynamicColor!
    @objc public var outlineHighlight: DynamicColor!
    @objc public var sectionTextColor: DynamicColor!
    @objc public var synopsisTextColor: DynamicColor!
    @objc public var pageNumberColor: DynamicColor!
    @objc public var highlightColor: DynamicColor!

    @objc public var macroColor: DynamicColor!
    
    @objc public var genderWomanColor: DynamicColor!
    @objc public var genderManColor: DynamicColor!
    @objc public var genderOtherColor: DynamicColor!
    @objc public var genderUnspecifiedColor: DynamicColor!
    
    @objc public var outlineItem: DynamicColor!
    @objc public var outlineItemOmitted: DynamicColor!
    @objc public var outlineSceneNumber: DynamicColor!
    @objc public var outlineSection: DynamicColor!
    @objc public var outlineSynopsis: DynamicColor!
    @objc public var outlineNote: DynamicColor!
        
    @objc public var name:String? = ""
    
    /// For background-compatibility reasons, we have to do this sort of trickery
    override public init() {
        super.init()
    }
    
    @objc public class func propertyValues() -> [String:String] {
        return [
            "backgroundColor": "Background",
            "marginColor": "Margin",
            "selectionColor": "Selection",
            "textColor": "Text",
            "commentColor": "Comment",
            "invisibleTextColor": "InvisibleText",
            "caretColor": "Caret",
            "pageNumberColor": "PageNumber",
            "synopsisTextColor": "SynopsisText",
            "sectionTextColor": "SectionText",
            "highlightColor": "Highlight",
            "macroColor": "Macro",
            "genderWomanColor": "Woman",
            "genderManColor": "Man",
            "genderOtherColor": "Other",
            "genderUnspecifiedColor": "Unspecified",
            
            "outlineBackground": "OutlineBackground",
            "outlineHighlight": "OutlineHighlight",
            "outlineItem": "OutlineItem",
            "outlineItemOmitted": "OutlineItemOmitted",
            "outlineSceneNumber": "OutlineSceneNumber",
            "outlineSection": "OutlineSection",
            "outlineSynopsis": "OutlineSynopsis",
            "outlineNote": "OutlineNote"
        ]
    }
    
    @objc public func themeAsDictionary(withName name: String!) -> [AnyHashable : Any]! {
        var themeName = name
        if (themeName == "") {
            themeName = self.name
        }
        
        let light = NSMutableDictionary()
        let dark = NSMutableDictionary()
        
        let propertyToValue = BeatTheme.propertyValues()
        
        for property:String in propertyToValue.keys {
            // Skip empty values
            if (self.value(forKey: property) == nil) {
                continue
            }
            
            let color:DynamicColor = self.value(forKey: property) as! DynamicColor
            let key = propertyToValue[property]!
            light[key] = color.valuesAsRGB()[0]
            dark[key] = color.valuesAsRGB()[1]
        }
        
        let result:Dictionary<AnyHashable, Any> = [
            "Name": themeName ?? "",
            "Light": light,
            "Dark": dark
        ]
                
        return result
    }
    
    override public func copy() -> Any {
        let theme = BeatTheme()
        let propertyToValue = BeatTheme.propertyValues()
        
        for key:String in propertyToValue.keys {
            let color:DynamicColor = self.value(forKey: key) as! DynamicColor
            theme.setValue(color.copy(), forKey: key)
        }
        
        return theme
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let theme = BeatTheme()
        let propertyToValue = BeatTheme.propertyValues()

        for key:String in propertyToValue.keys {
            let color:DynamicColor = self.value(forKey: key) as! DynamicColor
            theme.setValue(color.copy(), forKey: key)
        }
        
        return theme
    }
    
    public override class func setValue(_ value: Any?, forUndefinedKey key: String) {
        print("BeatTheme: Trying to set value for unknown key", key)
    }
}

