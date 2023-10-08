//
//  BeatStyleRules.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 29.9.2023.
//

import Foundation

// MARK: - Render style

@objc public class RenderStyle:NSObject {
    @objc public var name:String = ""
    
    @objc public var bold:Bool = false
    @objc public var italic:Bool = false
    @objc public var underline:Bool = false
    @objc public var uppercase:Bool = false
    
    @objc public var textAlign:String = "left"
    
    @objc public var marginTop:CGFloat = 0
    
    @objc public var marginLeft:CGFloat = 0
    
    @objc public var marginLeftA4:CGFloat = 0
    @objc public var marginLeftLetter:CGFloat = 0
    
    @objc public var marginBottom:CGFloat = 0
    @objc public var marginBottomA4:CGFloat = 0
    @objc public var marginBottomLetter:CGFloat = 0
    
    @objc public var marginRight:CGFloat = 0
    @objc public var paddingLeft:CGFloat = 0
    
    @objc public var contentPadding:CGFloat = 0

    @objc public var lineHeight:CGFloat = 0
    
    @objc public var width:CGFloat = 0
    @objc public var widthA4:CGFloat = 0
    @objc public var widthLetter:CGFloat = 0
    
    @objc public var defaultWidthA4:CGFloat = 0
    @objc public var defaultWidthLetter:CGFloat = 0
    
    @objc public var color:String = ""
    @objc public var font:String = ""
    @objc public var fontSize:CGFloat = 0
    
    @objc public var indent:CGFloat = 0
    @objc public var firstLineIndent:CGFloat = 0
    @objc public var indentSplitElements:Bool = true
    
    @objc public var content:String?
    
    @objc public var sceneNumber:Bool = true
    
    public init(rules:[String:Any]) {
        super.init()

        for key in rules.keys {
            // Create property name based on the rule key
            let value = rules[key]!
            let property = styleNameToProperty(name: key)
            
            // Check that the property exists to avoid any unnecessary crashes
            if (self.responds(to: Selector(property))) {
                self.setValue(value, forKey: property)
            } else {
                print("Warning: Unrecognized BeatCSS key: ", property)
            }
        }
    }
    
    public func styleNameToProperty (name:String) -> String {
        switch name.lowercased() {
        case "width-a4":
            return "widthA4"
        case "width-us":
            return "widthLetter"
        case "text-align":
            return "textAlign"
        case "margin-top":
            return "marginTop"
        case "margin-bottom":
            return "marginBottom"
        case "margin-bottom-us":
            return "marginBottomLetter"
        case "margin-bottom-a4":
            return "marginBottomA4"
        case "margin-left":
            return "marginLeft"
        case "margin-right":
            return "marginRight"
        case "padding-left":
            return "paddingLeft"
        case "line-height":
            return "lineHeight"
        case "default-width-a4":
            return "defaultWidthA4"
        case "default-width-us":
            return "defaultWidthLetter"
        case "content-padding":
            return "contentPadding"
        case "margin-left-us":
            return "marginLeftLetter"
        case "margin-left-a4":
            return "marginLeftA4"
        case "font-size":
            return "fontSize"
        case "first-line-indent":
            return "firstLineIndent"
        case "indent-split-elements":
            return "indentSplitElements"
        case "scene-number":
            return "sceneNumber"
        default:
            return name
        }
    }
    
    override public class func setValue(_ value: Any?, forUndefinedKey key: String) {
        print("RenderStyle: Unknown key: ", key)
    }

    /// Returns the default width based on page size
    @objc public func defaultWidth(pageSize:BeatPaperSize) -> CGFloat {
        return (pageSize == .A4) ? self.defaultWidthA4 : self.defaultWidthLetter
    }
    
    /// Returns the correct element size based on page width.
    @objc public func width(pageSize:BeatPaperSize) -> CGFloat {
        // Prefer page-size-based rules
        if (pageSize == .A4 && widthA4 > 0) {
            return widthA4
        } else if (pageSize == .usLetter && widthLetter > 0) {
            return widthLetter
        } else {
            return width
        }
    }
}
