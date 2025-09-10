//
//  BeatMacros.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 2.10.2023.
//
/**
 
 This is used to parse macros in Fountain content at preprocessing phase.
 Macros are specified as ``{{macro}}``. `Line` objects know the raw ranges of macro content, and will also deliver a list of actual macro strings to this parser.
 
 The code has been cooked up in a day or two, so it's not the cleanest approach, but works :------)
 
 There are three types of macros: `string`, `serial` (which can be `series` for compatibility with Highland) and `date`.
 String macros require a definition, whereas serials start at `1` by default:
 
 __String macros__
 Definition: `{{ macroName = Hello world }}`
 Usage: `{{ macroName }}`
 
 __Serial macro__
 Definition `{{ serial macroName }}` (defaults to 1) or `{{ serial macroName = 100 }}` (starts off at `100`)
 Usage: `{{ macroName }}`
 
 __Date macro__
 Outputs the current date.
 Usage: `{{ date dd.mm.YY }}` or just `{{ date }}` (defaults to current locale)
 
 __Panel macro__
 Reset after highest-level section.
 Usage: `{{panel}}`
 
 */

import Foundation

@objc public class BeatMacroParser:NSObject {
    enum Operation {
        case print, assign
    }
    
    var macros: [String: BeatMacro] = [:]
    var panel = BeatMacro(name: "panel", type: .panel, value: 0)
    var references = BeatMacro(name: "ref", type: .reference, value: [String]())
    
    let typeNames = ["string", "serial", "series", "number", "date", "panel", "ref", "references"]
    
    
    /// Resolves the given macro content and returns the resulting value. At `Line` level, this is called for each macro range, passing the strings in those ranges. `{{` and `}}` are removed automatically. You can also provide pure macro strings to do weird tricks.
    @objc public func parseMacro(_ macro: String) -> AnyObject? {
        // Remove {{, }} and leading/trailing whitespace
        let trimmedMacro = macro.replacingOccurrences(of: "{{", with: "").replacingOccurrences(of: "}}", with: "").trimmingCharacters(in: .whitespaces)
        
        // Separate in two (if applicable)
        let components = trimmedMacro.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Check that macro format is valid
        guard components.count > 0 else { return nil }
        
        var varName = ""
        var typeName = "string"
        var parameters = ""
        var subValue = -1
        
        if let leftSide = components.first?.components(separatedBy: " ") {
            if leftSide.count > 1, let t = leftSide.first?.lowercased().trimmingCharacters(in: .whitespaces) {
                if typeNames.contains(t) { typeName = t }
                
                if typeName == "date" || typeName == "ref" {
                    parameters = leftSide[1..<leftSide.count].joined(separator: " ")
                } else {
                    varName = leftSide[1]
                }
            } else {
                varName = leftSide.first!
            }
        }
        
        // Variable names are case-insensitive
        if typeName != "date" { varName = varName.lowercased() }
        
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
        if varName == "", typeName != "date", typeName != "ref", typeName != "references" { print("Invalid macro"); return nil; }
        
        // Dates and panels don't work as other macros. They can be called just as keywords, {{panel}} or {{date}}, so in these cases we'll make the var name TYPE name and leave actual var name empty.
        if varName == "date" || varName == "panel" || varName == "references" {
            typeName = varName
            varName = ""
        }
                
        // Let's create/fetch the macro now
        let macro:BeatMacro
        var varType = BeatMacro.typeName(for: typeName)
        
        if typeName == "panel" {
            // Panel is a global variable/keyword
            macro = panel
        } else if typeName == "ref" {
            macro = references
        } else if typeName == "references" {
            macro = BeatMacro(name: "references", type: .references, value: references.value)
        } else if varType == .date {
            // Create a date macro
            macro = BeatMacro(name: "date", type: .date, value: parameters)
        } else {
            // If the macro doesn't exist, create it
            if macros[varName] == nil {
                macros[varName] = BeatMacro(name: varName, type: varType, value: nil)
            }
            
            // Retrieve macro type
            macro = macros[varName]!
            varType = macro.type
        }

        // Handle the right side (meaning anything after =)
        if components.count > 1, macro.type != .reference {
            let rightSide = components[1]
            
            if varType == .serial || varType == .number {
                let exp = NSExpression(format: rightSide)
                macro.value = exp.expressionValue(with: nil, context: nil) ?? -1
            } else {
                macro.value = rightSide
            }
        } else if varType == .date {
            // We have handled date parameters earlier, but... uh
            macro.value = parameters
        } else if varType == .reference {
            var items = macro.value as? [String] ?? []
            // We'll support using = just to be friendly
            if components.count > 1 { parameters = components[1] }
            
            items.append(parameters)
            macro.value = items
        } else if varType == .references {
            // do nothing
        } else {
            // If this value is UNDEFINED but printed, we'll assign a value
            if macro.value == nil {
                // Empty string for strings, 0 for any number value
                macro.value = (macro.type == .string || macro.type == .date) ? "" : 0
            }
            
            if macro.type == .serial {
                // serial numbers are incremented every time we encounter them
                macro.incrementValue(subValue: subValue)
            } else if macro.type == .panel {
                // panels are also constantly incremented
                macro.incrementValue()
            }
        }
        
        return macro.resolvedValue(subValue: subValue)
    }
    
    @objc public func resetPanel() {
        self.panel.value = 0
    }
}

@objc enum MacroType:Int {
    case string, serial, number, date, panel, reference, references
}

class BeatMacro {
    var type:MacroType
    var name:String
    var value:Any? {
        didSet {
            // Reset sub value whenever the value is changed
            if self.type == .serial {
                subValues = [:]
            }
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
    
    func resolvedValue(subValue:Int) -> AnyObject? {
        if type == .string {
            return stringValue
        } else if type == .date {
            let df = DateFormatter()
            var format = value as? String ?? ""
            if (format.count == 0) { format = "d.M.Y" }
            
            df.dateFormat = format
            return df.string(from: Date()) as NSString
        } else if type == .reference {
            let items = value as? [String] ?? []
            return "[\(items.count)]" as NSString
        } else if type == .references {
            let items = value as? [String] ?? []
            var text = ""
            
            for i in items.indices {
                let ref = items[i]
                text += "[\(i+1)] \(ref)\n"
            }
            
            return text as NSString
        } else {
            if subValue == -1 {
                return intValue
            } else {
                return NSNumber(integerLiteral: subValues[subValue] ?? -1)
            }
        }
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
        case "panel":
            return .number
        case "ref":
            return .reference
        case "references":
            return .references
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
