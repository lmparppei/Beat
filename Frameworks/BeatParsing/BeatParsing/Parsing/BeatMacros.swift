//
//  BeatMacros.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 2.10.2023.
//
/**
 
 This is used to parse macros in Fountain content.
 Macros are specified as ``{{macro}}``. `Line` objects know the raw ranges of macro content, and will also deliver a list of actual macro strings to this parser.
 
 There are three types of macros: `string`, `serial` (which can be `series` for compatibility with Highland) and `date`.
 String macros require a definition, whereas serials start at `1 ` by default:
 
 __String macros__
 Definition: `{{ macroName = Hello world }}`
 Usage: `{{ macroName }}`
 
 __Serial macro__
 Definition `{{ serial macroName }}` (defaults to 1) or `{{ serial macroName = 100 }}` (starts off at `100`)
 Usage: `{{ macroName }}`
 
 __Date macro__
 Outputs the current date.
 Usage: `{{ date dd.mm.YY }}` or just `{{ date }}` (defaults to current locale)
 
 */

import Foundation

@objc public class BeatMacroParser:NSObject {
    enum Operation {
        case print, assign
    }
        
    var macros: [String: BeatMacro] = [:]
    let typeNames = ["string", "serial", "series", "number", "date"]
    
    
    /// Resolves the given macro content and returns the resulting value. `{{` and `}}` are removed automatically, so you can also provide a generic macro for weird tricks, not just the macro range from a line.
    @objc public func parseMacro(_ macro: String) -> AnyObject? {
        // Remove {{, }} and leading/trailing whitespace
        let trimmedMacro = macro.replacingOccurrences(of: "{{", with: "").replacingOccurrences(of: "}}", with: "").trimmingCharacters(in: .whitespaces)
        // Separate in two (if applicable)
        let components = trimmedMacro.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Check that macro format is valid
        guard components.count > 0 else { return nil }
        
        var varName = ""
        var typeName = "string"
        var subValue = -1
        
        if let leftSide = components.first?.components(separatedBy: " ") {
            if leftSide.count > 1, let t = leftSide.first?.lowercased().trimmingCharacters(in: .whitespaces) {
                if typeNames.contains(t) { typeName = t }
                varName = leftSide[1]
            } else {
                varName = leftSide.first!
            }
        }
        
        // Variable names are case-insensitive
        varName = varName.lowercased()
        
        // Check for sub-values for serials
        if varName.contains(".") && typeName != "date" {
            // A sub value is something like {{page.sub}} or {{page.sub.sub.sub}}. We get the sub value index by calculating the amount of components called "sub".
            let components = varName.components(separatedBy: ".")
            varName = components[0]
            
            for i in 1..<components.count {
                if components[i] == "sub" { subValue += 1 }
                else { break }
            }
        }
        
        // Don't let empty macro names through
        if varName == "" { print("Invalid macro"); return nil; }
        
        // Dates don't work as other macros
        if varName == "date" {
            typeName = "date"
            varName = ""
        }
        
        var varType = BeatMacro.typeName(for: typeName)
        let macro:BeatMacro
        
        if varType != .date {
            // If the macro doesn't exist, create it
            if macros[varName] == nil {
                macros[varName] = BeatMacro(name: varName, type: varType, value: nil)
            }
            
            // Retrieve macro type
            macro = macros[varName]!
            varType = macro.type
        } else {
            // Create a date macro
            macro = BeatMacro(name: "date", type: .date, value: nil)
        }

        if components.count > 1 {
            let rightSide = components[1]
            
            if varType == .serial || varType == .number {
                let exp = NSExpression(format: rightSide)
                macro.value = exp.expressionValue(with: nil, context: nil) ?? -1
            } else {
                macro.value = rightSide
            }
        } else if varType == .date {
            // When defining a date, the type/name convention doesn't work as usual
            print("-> date value", varName)
            macro.value = varName
        } else {
            // If this value is UNDEFINED but printed, we'll assign a value
            if macro.value == nil {
                // Empty string for strings, 0 for any number value
                macro.value = (macro.type == .string || macro.type == .date) ? "" : 0
            }
            
            if macro.type == .serial {
                // serial numbers are incremented every time we encounter them
                macro.incrementValue(subValue: subValue)
            }
        }
        
        if macro.type == .string {
            return macro.stringValue
        } else if macro.type == .date {
            let df = DateFormatter()
            var format = macro.value as? String ?? ""
            if (format.count == 0) { format = "d.M.Y" }
            
            df.dateFormat = format
            return df.string(from: Date()) as NSString
        } else {
            if subValue == -1 {
                return macro.intValue
            } else {
                return NSNumber(integerLiteral: macro.subValues[subValue] ?? -1)
            }
            
        }
    }
}

@objc enum MacroType:Int {
    case string, serial, number, date
}


class BeatMacro {
    var type:MacroType
    var name:String
    var value:Any? {
        didSet {
            // Reset sub value whenever the value is changed
            if self.type == .serial { subValues = [:] }
        }
    }
    
    var subValues:[Int:Int] = [:]
    
    var intValue:NSNumber {
        guard let num = value as? NSNumber else { return NSNumber(integerLiteral: -1) }
        return num
    }
    
    var stringValue:NSString? {
        guard let string = value as? NSString else { return nil }
        return string
    }
    
    init(name: String, type: MacroType, value:Any?) {
        self.value = value
        self.type = type
        self.name = name
    }
    
    func incrementValue(subValue:Int = -1) {
        if var n = value as? Int, subValue == -1 {
            n += 1
            value = n
        } else {
            // Increment sub value
            if let val = self.subValues[subValue] {
                self.subValues[subValue] = val + 1
            } else {
                self.subValues[subValue] = 1
            }
        }
    }

    
    class func typeName(for string:String) -> MacroType {
        // Check type
        switch string {
        case "serial", "series":
            return .serial
        case "number":
            return .number
        case "date":
            return .date
        default:
            return .string
        }
    }
}

@objc public extension Line {
    @objc var macros:[NSRange:String] {
        guard self.string.count > 0 else { return [:] }
        var macros:[NSRange:String] = [:]
        
        var currentRange:NSRange?
        
        for i in 0 ..< string.count - 1 {
            let c = string[i]
            let c2 = string[i+1]
            
            if c == "{" && c2 == "{" {
                currentRange = NSMakeRange(i, 0)
            }
            else if c == "}" && c2 == "}" && currentRange != nil {
                let loc = currentRange!.location
                currentRange?.length = i - loc
                
                macros[NSMakeRange(loc, currentRange!.length + 2)] = String(string.prefix(i).suffix(currentRange!.length - 2))
                
                currentRange = nil
            }
        }
        
        return macros
    }
}
