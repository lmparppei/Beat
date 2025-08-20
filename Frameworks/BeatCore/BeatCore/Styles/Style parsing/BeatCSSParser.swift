//
//  BeatCSSParser.swift
//  Originally based on CssParser gist by jgsamudio
//  https://gist.github.com/jgsamudio/adba6eb7afc96558bb35f18d5f74c16a
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatParsing

public protocol BeatCssParserDelegate {
	func get(key:String)
}

public final class CssParser {
	var styles:[String:RenderStyle] = [:]
    var lineHeight = BeatStyles.lineHeight // default line height
        
    weak var documentSettings:BeatDocumentSettings?
	
	/// Parses the CSS file string into an array of CSS styles.
	/// - Parameter fileContent: CSS file content.
	/// - Returns: Array of CSS styles.
    func parse(fileContent: String, documentSettings:BeatDocumentSettings? = nil) -> [String: RenderStyle] {
        self.documentSettings = documentSettings
		
		var styles:[String: Dictionary<String, String>] = [:]
		
		var pendingStyleName = ""
		var pendingStyleProperties = [String: String]()
		var pendingLine = ""
		
		var omit = false
        var previousOmit = ""
				
		for character in fileContent {
            // Catch omits
            if character == "/" && pendingStyleName == "" {
                if !omit {
                    previousOmit = "/"
                    continue
                }
                else if omit && previousOmit == "*" {
                    omit = false
                    previousOmit = ""
                    continue
                }
            } else if character == "*" {
				if previousOmit == "/" {
					omit = true
					previousOmit = ""
					continue
				}
				else if omit {
					previousOmit = "*"
					continue
				}
			}
			// We're inside an omit block
			if omit { continue }
            			 
			pendingLine.append(character)
			
			if character == "{" {
				pendingStyleName = pendingLine.replacingOccurrences(strings: ["\n", "{"])
				pendingLine = ""
			} else if character == ";" {
				let propertyLine = pendingLine.replacingOccurrences(strings: [";", "\n"])
				
                // Clean up key. If it's a conditional, don't remove unnecessary spaces.
                var key = propertyLine.removeTrailing(startWith: ":").trimmingCharacters(in: .whitespaces)
                if !key.hasPrefix("if"), !key.hasPrefix("skip") {
                    // Remove unnecessary spaces if it's not a conditional
                    key = key.replacingOccurrences(strings: [" "])
                }
                
				let value = propertyLine.removeLeading(startWith: ":").removeLeading(startWith: " ")
				
				pendingStyleProperties[key] = value
				pendingLine = ""
                
			} else if character == "}" {
				pendingStyleName = pendingStyleName.trimmingCharacters(in: .whitespaces)
                
                let styleNames = pendingStyleName.components(separatedBy: ",")
                
                for styleName in styleNames {
                    let key = styleName.trimmingCharacters(in: .whitespaces)
                    
                    if var existingStyles = styles[key] {
                        // Style already exists, let's overwrite rules when needed
                        for ruleKey in pendingStyleProperties.keys {
                            existingStyles[ruleKey] = pendingStyleProperties[ruleKey]
                        }
                        styles[key] = existingStyles // These are not pointers in Swift (?) so we need to add the style back to dictionary.
                    } else {
                        // Style doesn't exist, create new
                        styles[key] = pendingStyleProperties
                    }
                }
				
				pendingStyleProperties.removeAll()
				pendingStyleName = ""
				pendingLine = ""
			}
		}
		
		// Map the rules into actual styles
		for key in styles.keys {
			let dict:[String:String] = styles[key]!
			var rules = [String:Any]()
			
			for ruleKey in dict.keys {
				let value = dict[ruleKey]!
                				
                // Catch conditionals first
                if ruleKey.hasPrefix("if ") {
                    if rules["_conditionals"] == nil {
                        // Create the key if needed
                        rules["_conditionals"] = [ConditionalRenderStyle]()
                    }
                    
                    // Parse conditional and add it to existing rules
                    if var conditionalRules = rules["_conditionals"] as? [ConditionalRenderStyle],
                        let conditionalStyle = parseConditional(ruleKey, value) {
                        conditionalRules.append(conditionalStyle)
                        rules["_conditionals"] = conditionalRules
                    }
                    continue
                } else if ruleKey.hasPrefix("skip ") {
                    if rules["_paginationRules"] == nil {
                        // Create key when needed
                        rules["_paginationRules"] = [PaginationRule]()
                    }
                    
                    // Parse pagination rule and add it to existing rules
                    if var paginationRules = rules["_paginationRules"] as? [PaginationRule],
                       let rule = parsePaginationRule(ruleKey) {
                        paginationRules.append(rule)
                        rules["_paginationRules"] = paginationRules
                    }
                    continue
                }
                
                // Normal style rule
                if let result = readStyleValue(value: value, key: ruleKey) {
                    rules[ruleKey] = result
                }
			}
		
            let style = RenderStyle(rules: rules)
            style.name = key
            
			self.styles[key] = style
		}
		        
		return self.styles
	}
	
	func convertValueToString(_ value:Any) -> String {
		var userSettingValue = ""
		
		if value is Int { userSettingValue = String(value as? Int ?? 0) }
		else if value is Bool { userSettingValue = (value as! Bool) ? "true" : "false" }
		else if value is String { userSettingValue = String(value as? String ?? "") }
        else { userSettingValue = "\(value)" }
        
		return userSettingValue
	}
	
    func readStyleValue(value:String, key:String) -> Any? {       
        if value.contains("[") {
            // An array
            if let elements = value.slice(from: "[", to: "]") {
                let components = elements.commaSeparated()
                let values = components.map { readSingleValue(string: $0, key: key) }
                return values
            }
        }
        
        return readSingleValue(string: value, key: key)
    }
    
    func readSingleValue(string:String, key:String) -> Any? {
        var value = string
        var type = RenderStyle.types[key]
        
        // We'll infer some types
        if string == "true" || string == "false" { type = .boolType }
        
        // First replace any setting getters
        if let val = replaceGetter(value: value, getter: "userSetting", { key in return BeatUserDefaults.shared().get(key) }) {
            value = val
        }
        //if let val = replaceGetter(value: value, getter: "setting", { key in return self.settings?.value(forKey: key) }) {
        //    value = val
        //}
        
        // Document settings are a bit tricky. If a document setting block is not provided, we need to inquire the actual default value.
        if let val = replaceGetter(value: value, getter: "documentSetting", { key in
            let documentSettings = documentSettings ?? BeatDocumentSettings()
            var v:Any? = documentSettings.get(key)
            
            // Try to get default value if it wasn't applied already
            if v == nil { v = documentSettings.defaultValues()[key] }
            
            return v
        }) {
            value = val
        }
                
        // First check return valuetype and handle it elsewhere if needed.
        if type == .stringType {
            // This is a string, no processing required
            return value
        } else if type == .boolType {
            // true/false
            return (value == "true" || value == "1")
        } else if type == .lineType {
            // Line type
            return Line.type(fromName: value)
        } else if type == .enumType {
            // Enum value
            return enumValue(value: value, key: key)
        } else if type == .integerType {
            return Int(value)
        } else {
            // This is most likely a float value, so let's calculate. The & reference is here just out of lazinesss.
            return floatValue(value: &value, key: key)
        }
    }
    
    func floatValue(value: inout String, key: String) -> Any? {
        // Calculate different units based on *fixed values*
        value = value.replacingOccurrences(of: "ch", with: "* 7.25")
        value = value.replacingOccurrences(of: "l", with: "* \(self.lineHeight)")
        value = value.replacingOccurrences(of: "px", with: "")
        value = value.replacingOccurrences(of: " ", with: "")
        
        // ... and to be even more *safe* and *transparent*, let's use NSExpression 🍄
        let exp = NSExpression(format: value)
        
        // Line height can be set DYNAMICALLY, and will affect other value calculations
        if key == "page" && (key == "lineHeight" || key == "line-height") {
            let e = exp.expressionValue(with: nil, context: nil) as? CGFloat ?? BeatStyles.lineHeight
            self.lineHeight = e
        }
        
        return exp.expressionValue(with: nil, context: nil) ?? 0
    }
    
    func replaceGetter(value:String, getter:String, _ handler:(_ key:String) -> Any?) -> String? {
        if !value.contains(getter + "(") { return nil }
        
        if let key = value.slice(from: getter + "(", to: ")"), let val = handler(key) {
            let result = convertValueToString(val)
            return value.replacingOccurrences(of: getter + "(" + key + ")", with: result)
        }
        
        return nil
    }
    
    func enumValue(value:String, key: String) -> Any? {
        var t:Any?
        
        if key == "font-type" {
            t = BeatFontType.fixed
            
            if value == "fixed" { t = BeatFontType.fixed }
            else if value == "variable" { t = BeatFontType.variableSerif }
            else if value == "variable-sans-serif" { t = BeatFontType.variableSansSerif }
            else if value == "fixed-sans-serif" { t = BeatFontType.fixedSansSerif }
        }
        
        return t
    }
    
    func parseConditional(_ key:String, _ value:String) -> ConditionalRenderStyle? {
        let conditional = key.slice(from: "if ", to: " then")
        
        guard let components = conditional?.components(separatedBy: " "),
              components.count == 3,
              let ruleEnd = key.range(of: " then ")?.upperBound
        else {
            return nil
        }
        
        let ruleName = String(key.suffix(from: ruleEnd))
        //let keyName = self.styleNameToProperty(name: ruleName)
        
        let p = components[0] // property
        let o = components[1] // operator
        let v = components[2] // value
        
        let actualValue = readStyleValue(value: value, key: key)
        return ConditionalRenderStyle(property: p, comparison: o, value: v, ruleName: ruleName, ruleValue:actualValue)
    }
    
    /// A highly experimental way to add pagination rules to styles. Not used for now.
    func parsePaginationRule(_ key:String) -> PaginationRule? {
        let components = key.components(separatedBy: " ")
        guard components.count == 4 else { return PaginationRule(precededBy: .empty, followedBy: .empty, rule: .none) }
        
        var rule:PaginationRuleType
        //if components[0] == "skip" { rule = .skip } ...
        rule = .skip
        
        let precededBy:LineType
        let followedBy:LineType
        
        // operator is either "after" or "before"
        if components[2] == "after" {
            precededBy = Line.type(fromName: components[3])
            followedBy = Line.type(fromName: components[1])
        } else {
            precededBy = Line.type(fromName: components[1])
            followedBy = Line.type(fromName: components[3])
        }

        return PaginationRule(precededBy: precededBy, followedBy: followedBy, rule: rule)
    }
}
