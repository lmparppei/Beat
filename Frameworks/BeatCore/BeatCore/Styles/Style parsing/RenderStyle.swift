//
//  BeatStyleRules.swift
//  BeatPagination2
//
//  Created by Lauri-Matti Parppei on 29.9.2023.
//
/**
 
 This class presents a single set of rules for an element.
 
 */

import Foundation


// MARK: - Render style
public enum RenderStyleValueType:Int {
    case boolType
    case stringType
    case enumType
    case lineType
}

@objc public class RenderStyle:NSObject {
    // Map property names to types
    class var stringTypes:Set<String> { return  ["textAlign", "text-align", "color", "font", "content"] }
    class var boolTypes:Set<String> { return ["bold", "italic", "underline", "uppercase", "indentSplitElements", "indent-split-elements", "sceneNumber", "scene-number", "unindent-fresh-paragraph"] }
    class var enumTypes:Set<String> { return ["font-type"] }
    
    public class var types:[String:RenderStyleValueType] { return [
        "text-align": .stringType,
        "color": .stringType,
        "font": .stringType,
        "content": .stringType,
        "bold": .boolType,
        "italic": .boolType,
        "underline": .boolType,
        "uppercase": .boolType,
        "indent-split-elements": .boolType,
        "scene-number": .boolType,
        "unindent-fresh-paragraph": .boolType,
        "font-type": .enumType,
        "visible-elements": .lineType
    ] }

    @objc public var name:String = ""
    
    @objc public var fontType:BeatFontType = .fixed
    
    @objc public var bold:Bool = false
    @objc public var italic:Bool = false
    @objc public var underline:Bool = false
    @objc public var uppercase:Bool = false
    
    @objc public var textAlign:String = "left"
    
    @objc public var marginTop:CGFloat = 0
    
    @objc public var marginLeft:CGFloat = 0
    
    @objc public var marginLeftA4:CGFloat = 0
    @objc public var marginLeftLetter:CGFloat = 0
    
    @objc public var firstPageWithNumber:Int = 2
    
    @objc public var marginBottom:CGFloat = 0
    @objc public var marginBottomA4:CGFloat = 0
    @objc public var marginBottomLetter:CGFloat = 0
    @objc public var forcedMargin = false
    
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
    @objc public var unindentFreshParagraphs:Bool = false
    
    @objc public var content:String?
    
    @objc public var beginsPage = false
    
    @objc public var visibleElements:[AnyObject] = [] {
        /// Int arrays are not supported in ObjC, so we'll use a shadow array here to provide actual values for Swift
        didSet { self._visibleElements = self.visibleElements as? [LineType] ?? [] }
    }
    public var _visibleElements:[LineType] = []
    
    @objc public var sceneNumber:Bool = true
    
    public init(rules:[String:Any]) {
        super.init()

        for key in rules.keys {
            // Create property name based on the rule key
            var value = rules[key]!
            let property = styleNameToProperty(name: key)
            
            if property == "fontType" {
                let fontType = value as? BeatFontType ?? .fixed
                value = fontType.rawValue
            }
            
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
        case "font-type":
            return "fontType"
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
        case "unindent-fresh-paragraphs":
            return "unindentFreshParagraphs"
        case "visible-elements":
            return "visibleElements"
        case "begins-page":
            return "beginsPage"
        case "forced-margin":
            return "forcedMargin"
        case "first-page-with-number":
            return "firstPageWithNumber"
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

