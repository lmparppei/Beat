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
import BeatParsing

// MARK: - Render style
public enum RenderStyleValueType:Int {
    case boolType
    case stringType
    case enumType
    case lineType
    case additionalSettings
    case integerType
}

enum ConditionalRenderStyleOperator {
    case greater
    case less
    case equal
    case greaterOrEqual
    case lessOrEqual
}

struct ConditionalRenderStyle {
    /// Property key in `Line` object
    var property:String
    /// Comparison operator, like `<` or `>=`
    var comparison:String
    /// The value to compare against (this is string, so basically anything goes, if you are using strings, remember to escape them)
    var value:String
    
    /// Rule name, such as `margin-top`, stored by BeatCSS parser
    var ruleName:String
    /// The value which should be applied to this particular conditional rule
    var ruleValue:Any?
    
    /// A condition key for distincting different rules
    func condition() -> String {
        return property + " " + comparison + " " + value
    }
}

enum PaginationRuleType {
    case none
    case skip
}

struct PaginationRule {
    var precededBy:LineType
    var followedBy:LineType
    var rule:PaginationRuleType
}

@objc public class RenderStyle:NSObject {
    // Map property names to types
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
        "visible-elements": .lineType,
        "disabled-types": .lineType,
        "trim": .boolType,
        "visible": .boolType,
        "additional-settings": .stringType,
        "skip-if-preceded-by": .lineType,
        "reformat-following-paragraph-after-type-change": .boolType,
        "disable-automatic-paragraphs": .boolType,
        "pagination-mode": .integerType,
        "overrideParagraphPaginationMode": .boolType
    ] }

    @objc public var name:String = ""
    /// `true` if this style was created based on conditional styles
    @objc public var dynamicStyle = false
    @objc public var initialStyles:[String:Any]
    
    @objc public var fontType:BeatFontType = .fixed
    
    @objc public var bold:Bool = false
    @objc public var italic:Bool = false
    @objc public var underline:Bool = false
    @objc public var uppercase:Bool = false
    
    @objc public var textAlign:String = "left"
    @objc public var textAlignment:NSTextAlignment {
        switch textAlign {
        case "right":
            return .right
        case "center":
            return .center
        case "justify":
            return .justified
        default:
            return .left
        }
    }
    
    @objc public var visible = true
    
    @objc public var firstPageWithNumber:Int = 2
    
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

    @objc public var lineFragmentMultiplier = 1.0;
    
    @objc public var paginationMode:Int = -1
    @objc public var overrideParagraphPaginationMode:Bool = false
    
    /// Top margin is isually ignored for elements on top of page. If `forcedMargin` is set `true`, the margin applies on an empty page as well.
    @objc public var forcedMargin = false

    /// Line height is automatically multiplied if needed
    @objc public var lineHeight:CGFloat {
        get { return self.actualLineHeight * self.lineHeightMultiplier }
        set { self.actualLineHeight = newValue }
    }
    /// `0` eans automatic line height. Access this value via `.lineHeight`
    var actualLineHeight:CGFloat = 0
    
    @objc public var lineHeightMultiplier:CGFloat = 1.0
    
    @objc public var width:CGFloat = 0
    @objc public var widthA4:CGFloat = 0
    @objc public var widthLetter:CGFloat = 0
    
    @objc public var defaultWidthA4:CGFloat = 0
    @objc public var defaultWidthLetter:CGFloat = 0
    
    @objc public var color:String = ""
    @objc public var font:String = ""
    @objc private var _fontSize:CGFloat = 0
    @objc public var fontSize:CGFloat {
        get {
            return max(_fontSize, minimumFontSize)
        }
        set {
            _fontSize = newValue
        }
    }
    @objc public var minimumFontSize:CGFloat = 0
    
    @objc public var indent:CGFloat = 0
    @objc public var firstLineIndent:CGFloat = 0
    @objc public var indentSplitElements:Bool = true
    @objc public var unindentFreshParagraphs:Bool = false
    
    @objc public var trim:Bool = false
    
    @objc public var additionalSettings:[String] = []
    
    /// If content is set, it should replace existing text content in this particular element
    @objc public var content:String?
    
    /// Whether this object always begins a new page
    @objc public var beginsPage = false
    
    @objc public var reformatFollowingParagraphAfterTypeChange = false
    @objc public var disableAutomaticParagraphs = false
    
    /// A dictionary of sub-rules
    var conditionalRules:[String:[String:Any]] = [:]
    
    /// Pagination rules
    var paginationRules:[PaginationRule] = []
    
    @objc public var visibleElements:[AnyObject] = [] {
        /// Int arrays are not supported in ObjC, so we'll use a shadow array here to provide actual values for Swift
        didSet { self._visibleElements = self.visibleElements as? [LineType] ?? [] }
    }
    public var _visibleElements:[LineType] = []
    
    /// This is a pagination rule. Skips the element in pagination if it's preceded by any of the given line types.
    @objc public var skipIfPrecededBy:NSIndexSet = NSIndexSet() {
        didSet {
            self._skipIfPrecededBy = [];
            self.skipIfPrecededBy.enumerate(using: { idx, stop in
                if let type = LineType(rawValue: UInt(idx)) {
                    self._skipIfPrecededBy.append(type)
                }
            })
        }
    }
    public var _skipIfPrecededBy:[LineType] = []
    
    /// @warning: this type can't be correctly represented in ObjC. You need to use `getDisabledTypes` to get an index set, which in turn is compatible with the parser.
    @objc public var disabledTypes:[Any]?
    @objc public func getDisabledTypes() -> IndexSet? {
        guard let disabledTypes = self.disabledTypes as? [LineType] else { return nil }
        
        let rawValues:[Int] = disabledTypes.map { Int($0.rawValue) }
        let indices = IndexSet(rawValues)
        
        return indices
    }
    
    
    @objc public var sceneNumber:Bool = true
    
    public init(rules:[String:Any]) {
        // Save initial styles and remove any conditionals from that list
        self.initialStyles = rules
        self.initialStyles["_conditionals"] = nil
        
        super.init()

        for key in rules.keys {
            // Create property name based on the rule key
            var value = rules[key]!
            
            let property = styleNameToProperty(name: key)
            if property == "fontType" {
                let fontType = value as? BeatFontType ?? .fixed
                value = fontType.rawValue
            }
                        
            // First catch conditionals
            if key == "_conditionals" {
                // We'll create a specific stylesheet for all conditional values
                if let conditions = value as? [ConditionalRenderStyle] {
                    for condition in conditions {
                        let exp = condition.condition()
                        
                        // Create a new dict for this condition if needed
                        if self.conditionalRules[exp] == nil {
                            // Create empty set of dynamic rules
                            var conditionalRules:[String:Any] = [:]
                            conditionalRules["dynamicStyle"] = true
                            
                            self.conditionalRules[exp] = conditionalRules
                        }
                                                
                        // Store new rules
                        if var rules = self.conditionalRules[exp] {
                            rules[condition.ruleName] = condition.ruleValue
                            self.conditionalRules[exp] = rules
                        }
                    }
                }
                
                continue
            } else if key == "_paginationRules" {
                self.paginationRules = rules[key] as? [PaginationRule] ?? []
                continue
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
        case "line-height-multiplier":
            return "lineHeightMultiplier"
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
        case "disabled-types":
            return "disabledTypes"
        case "additional-settings":
            return "additionalSettings"
        case "skip-if-preceded-by":
            return "skipIfPrecededBy"
        case "reformat-following-paragraph-after-type-change":
            return "reformatFollowingParagraphAfterTypeChange"
        case "disable-automatic-paragraphs":
            return "disableAutomaticParagraphs"
        case "line-fragment-multiplier":
            return "lineFragmentMultiplier"
        case "min-font-size":
            return "minimumFontSize"
        case "pagination-mode":
            return "paginationMode"
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
        
    @objc public func hasConditionalStyles() -> Bool {
        return (self.conditionalRules.count > 0)
    }
    
    
    /// Checks if there are dynamic (conditional) rules to be resolved for given line, and returns a dynamically customized style.
    @objc public func dynamicStyles(for line:Line) -> RenderStyle? {
        // Nothing to check
        if self.conditionalRules.count == 0 { return nil }
        
        var dynamicRules:[String:Any] = [:]
        
        // Iterate through conditional rules and append any fitting dynamic rules
        for conditionalRule in self.conditionalRules.keys.sorted() {            
            // We'll split the rule key back to its components (ie. "sectionDepth > 1" -> "sectionDepth", ">", "1")
            let components = conditionalRule.components(separatedBy: " ")
            if components.count == 0 { print("Warning: No components found in conditional rule", conditionalRule); continue }
        
            // Get the given value from line
            if let val = line.value(forKey: components[0]) {
                // Create an expression based on the newly received value, operator and the expected value
                let expString = "(\(val) \(components[1]) \(components[2]))"
                let exp = NSPredicate(format: expString)
                                
                // Run predicate and if it applies, let's apply new rules
                if exp.evaluate(with: nil),
                    let rules = self.conditionalRules[conditionalRule]
                {
                    dynamicRules.merge(rules) { $1 }
                }
            }
        }
        
        if dynamicRules.count > 0 {
            // Dynamic rules exist.
            // Merge the with initial rules, overriding any new values.
            var fullRules = self.initialStyles
            fullRules.merge(dynamicRules) { $1 }
            
            return RenderStyle(rules: fullRules)
        } else {
            // No dynamic rules
            return nil
        }
    }
}

