//
//  BeatCSSParser.swift
//  Originally based on CssParser gist by jgsamudio
//  https://gist.github.com/jgsamudio/adba6eb7afc96558bb35f18d5f74c16a
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatParsing.Line

public protocol BeatCssParserDelegate {
	func get(key:String)
}

public final class CssParser {
	var styles:[String:RenderStyle] = [:]
    var lineHeight = BeatStyles.lineHeight // default line height
        
	var settings:BeatExportSettings?
	
	/// Parses the CSS file string into an array of CSS styles.
	/// - Parameter fileContent: CSS file content.
	/// - Returns: Array of CSS styles.
	func parse(fileContent: String, settings:BeatExportSettings? = nil) -> [String: RenderStyle] {
        self.settings = settings
		
		var styles:[String: Dictionary<String, String>] = [:]
		
		var pendingStyleName = ""
		var pendingStyleProperties = [String: String]()
		var pendingLine = ""
		
		var omit = false
		var previousOmit = ""
				
		for character in fileContent {
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
			}
			else if character == "*" {
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
			}
			else if character == ";" {
				let propertyLine = pendingLine.replacingOccurrences(strings: [";", "\n"])
				let key = propertyLine.removeTrailing(startWith: ":").replacingOccurrences(strings: [" "]).trimmingCharacters(in: .whitespaces)
				let value = propertyLine.removeLeading(startWith: ":").removeLeading(startWith: " ")
				
				pendingStyleProperties[key] = value
				pendingLine = ""
			}
			else if character == "}" {
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
		// BTW, this is a silly approach -- why not check the type in RenderStyle property before using readValue()?
		for key in styles.keys {
			let dict:[String:String] = styles[key]!
			var rules = [String:Any]()
			
			for ruleKey in dict.keys {
				let value = dict[ruleKey]!
				
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
        if let val = replaceGetter(value: value, getter: "setting", { key in return self.settings?.value(forKey: key) }) {
            value = val
        }
                
        // Check type
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
        }
        
        // This is most likely a number value, so let's calculate
        
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
            print("!!! SET LINE HEIGHT", e)
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
}
