//
//  BeatMacros.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 2.10.2023.
//

import Foundation

@objc public class BeatMacroParser:NSObject {
    enum Operation {
        case print, assign
    }
        
    var macros: [String: BeatMacro] = [:]
    let typeNames = ["string", "serial", "number", "date"]
    
    @objc public func parseMacro(_ macro: String) -> AnyObject? {
        // Remove {{, }} and leading/trailing whitespace
        let trimmedMacro = macro.replacingOccurrences(of: "{{", with: "").replacingOccurrences(of: "}}", with: "").trimmingCharacters(in: .whitespaces)
        // Separate in two (if applicable)
        let components = trimmedMacro.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard components.count > 0 else {
            // Invalid macro format
            return nil
        }
        
        var varName = ""
        var varType:MacroType = .string
        
        var typeName = "string"        
        
        if let leftSide = components.first?.components(separatedBy: " ") {
            if leftSide.count > 1, let t = leftSide.first?.lowercased().trimmingCharacters(in: .whitespaces) {
                if typeNames.contains(t) { typeName = t }
                varName = leftSide[1]
            } else {
                varName = leftSide.first!
            }
        }
        
        if varName == "" {
            print("Invalid macro")
            return nil
        }
        else if varName == "date" {
            typeName = "date"
            varName = ""
        }
        
        // Check type
        switch typeName {
        case "serial":
            varType = .serial
        case "number":
            varType = .number
        case "date":
            varType = .date
        default:
            varType = .string
        }
        
        // Variable names are case insensitive
        if varType != .date {
            varName = varName.lowercased()
            
            if macros[varName] == nil{
                // Macro doesn't exist, create it
                macros[varName] = BeatMacro(name: varName, type: varType, value: nil)
            }

        }

        // Get the macro value from dictionary
        let macro = (varType != .date) ? macros[varName]! : BeatMacro(name: "date", type: .date, value: nil)
        
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
            macro.value = varName
        } else {
            // If this value is UNDEFINED but printed, we'll assign a value
            if macro.value == nil {
                // Empty string for strings, 0 for any number value
                macro.value = (macro.type == .string || macro.type == .date) ? "" : 0
            }
            
            if macro.type == .serial {
                // serial numbers are incremented every time we encounter them
                if var n = macro.value as? Int {
                    n += 1
                    macro.value = n
                }
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
            return macro.intValue
        }
    }
}

@objc enum MacroType:Int {
    case string, serial, number, date
}


class BeatMacro {
    var type:MacroType
    var name:String
    var value:Any?
    
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
