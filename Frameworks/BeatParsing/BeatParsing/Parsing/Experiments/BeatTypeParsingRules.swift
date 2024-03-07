//
//  BeatParsingRules.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 14.2.2024.
//
/**
 
 An idea for Swift parser. This is unfortunately VERY slow, almost 9 times slower than the messy ObjC counterpart.
 This is probably because of how Swift handles strings and keeps converting them back and forth between `NSString` and `String`.
 
 (Also, unichars are super efficient and I can't get the same performance under Swift)
 
 */

import Foundation

@objcMembers
public class BeatParsingRule:NSObject {
    var resultingType:LineType
    
    var allCapsUntilParentheses = false
    var previousIsEmpty = false
    
    var titlePage = false
    
    var beginsWith:[String] = []
    var endsWith:[String] = []
    
    var requiredAfterPrefix:[String] = []
    var excludedAfterPrefix:[String] = []
    
    var forcedType = false
    
    var length = NSMakeRange(-1,0)
    var allowedWhiteSpace = -1
    
    var previousTypes:IndexSet = []
    
    init(resultingType: LineType, previousIsEmpty: Bool = false, previousTypes:[LineType] = [], allCapsUntilParentheses: Bool = false, beginsWith: [String] = [], endsWith: [String] = [], requiredAfterPrefix: [String] = [], excludedAfterPrefix: [String] = [], length: NSRange = NSMakeRange(-1, 0), allowedWhiteSpace:Int = -1, titlePage:Bool = false) {
        self.resultingType = resultingType
        self.allCapsUntilParentheses = allCapsUntilParentheses
        self.previousIsEmpty = previousIsEmpty

        self.beginsWith = beginsWith
        self.endsWith = endsWith
        self.requiredAfterPrefix = requiredAfterPrefix
        self.excludedAfterPrefix = excludedAfterPrefix
        self.length = length
        self.allowedWhiteSpace = allowedWhiteSpace
        
        self.titlePage = titlePage
        
        var pTypes:IndexSet = []
        previousTypes.forEach { pTypes.insert(Int($0.rawValue)) }
        self.previousTypes = pTypes;
        
        super.init()
    }
    
}

@objc public extension ContinuousFountainParser {
    @objc static var rules:[BeatParsingRule] = [
    
        // Empty
        BeatParsingRule(resultingType: .empty, length: NSMakeRange(0, 1), allowedWhiteSpace: 1),
        // Forced heading
        BeatParsingRule(resultingType: .heading, previousIsEmpty: true, beginsWith: ["."], excludedAfterPrefix: ["."]),
        // Shot
        BeatParsingRule(resultingType: .shot, previousIsEmpty: true, beginsWith: ["!!"]),
        // Action
        BeatParsingRule(resultingType: .action, beginsWith: ["!"]),
        // Lyrics
        BeatParsingRule(resultingType: .lyrics, beginsWith: ["~"]),
        // Character
        BeatParsingRule(resultingType: .character, previousIsEmpty: true, beginsWith: ["@"]),
        // Section
        BeatParsingRule(resultingType: .section, beginsWith: ["#"]),
        // Synopsis
        BeatParsingRule(resultingType: .section, beginsWith: ["="]),
        // Heading
        BeatParsingRule(resultingType: .heading, previousIsEmpty: true, beginsWith: ["int", "ext", "i/e", "i./e", "e/i", "e./i"], requiredAfterPrefix: [".", " "]),
        // Centered
        BeatParsingRule(resultingType: .centered, beginsWith: [">"], endsWith: ["<"]),
        // Transition
        BeatParsingRule(resultingType: .centered, beginsWith: [">"]),
        
        // Dual Dialogue Character
        BeatParsingRule(resultingType: .dualDialogueCharacter, previousIsEmpty: true, allCapsUntilParentheses: true, endsWith: ["^"]),
        // Dual Dialogue Parenthetical
        BeatParsingRule(resultingType: .parenthetical, previousTypes: [.dualDialogueCharacter, .dualDialogueParenthetical, .dualDialogue], beginsWith: ["("]),
        // Dual Dialogue
        BeatParsingRule(resultingType: .dualDialogue, previousTypes: [.dualDialogueCharacter, .dualDialogueParenthetical, .dualDialogue]),
        
        // Character
        BeatParsingRule(resultingType: .character, previousIsEmpty: true, allCapsUntilParentheses: true),
        // Parenthetical
        BeatParsingRule(resultingType: .parenthetical, previousTypes: [.character, .parenthetical, .dialogue], beginsWith: ["("]),
        // Dialogue
        BeatParsingRule(resultingType: .dialogue, previousTypes: [.character, .parenthetical, .dialogue]),
        
        // This is a cheat. Actual title page parsing is done in a separate method.
        BeatParsingRule(resultingType: .titlePageUnknown, titlePage: true)
    ]
    
    @objc func parseType(line:Line, index:Int) -> LineType {
        let previousLine:Line? = (index > 0) ? self.lines[index - 1] as? Line : nil
        
        var previousIsEmpty = true
        
        // Check if previous line is empty or not
        if let prev = previousLine, prev.type != .empty {
            previousIsEmpty = false
        }
        
        let string = line.string ?? ""
        
        for rule in ContinuousFountainParser.rules {
            // Basic rules
            if (rule.previousIsEmpty && !previousIsEmpty) ||                                                                 // Previous is empty
                (rule.allCapsUntilParentheses && !string.isUppercaseUntilParentheses()) ||                                   // All caps
                ((string as NSString).containsOnlyWhitespace() && string.count > rule.allowedWhiteSpace) ||                  // Only whitespace
                (rule.length.length > 0 && line.length > rule.length.length)                                                 // Length
            {
                continue
            }
            
            // Check previous line type
            if let prev = previousLine, rule.previousTypes.count > 0, !rule.previousTypes.contains(Int(prev.type.rawValue)) {
                continue
            }
            
            // Check required prefixes etc.
            if !matchesPrefix(line: line, rule: rule) ||
                !matchesSuffix(line: line, rule: rule) {
                continue
            }
            
            // Check for title page
            if rule.titlePage {
                // The previous line can be either title page or null
                if previousLine == nil || previousLine?.isTitlePage() ?? false {
                    let titlePageType = parseTitlePageLine(line, index: index)
                    
                    if titlePageType != .empty { return titlePageType }
                }
                
                continue
            }
            
            // We've passed all rules
            return rule.resultingType
        }
        
        // Return action by default
        if line.length == 0 {
            return .empty
        } else {
            return .action
        }
    }
    
    func matchesSuffix(line:Line, rule:BeatParsingRule) -> Bool {
        if rule.endsWith.count == 0 { return true }
        
        let string = line.string.lowercased()
        for suffix in rule.endsWith {
            if string.hasSuffix(suffix) { return true }
        }
        return false
    }
    
    func matchesPrefix(line:Line, rule:BeatParsingRule) -> Bool {
        if rule.beginsWith.count == 0 { return true }
        
        let lowerCasedString = line.string.lowercased()
        var match = false
        
        for begins in rule.beginsWith {
            // No prefix
            if !lowerCasedString.hasPrefix(begins) { continue }
            
            match = true
            
            // Excluded items
            if lowerCasedString.count > begins.count && rule.excludedAfterPrefix.count > 0 {
                var hasForbiddenItem = false
                for ex in rule.excludedAfterPrefix {
                    if line.string.hasPrefix(begins + ex) {
                        hasForbiddenItem = true
                        break
                    }
                }
                // A forbidden item was found
                if hasForbiddenItem { continue }
            }
            
            // If it's longer than just the single starting component and we have additional rules, check those as well
            if lowerCasedString.count > begins.count && rule.requiredAfterPrefix.count > 0 {
                var matchesFullPrefix = false
                for rq in rule.requiredAfterPrefix {
                    // Combine components
                    let fullPrefix = begins + rq
                    if lowerCasedString.hasPrefix(fullPrefix) {
                        matchesFullPrefix = true
                        break
                    }
                }
                
                match = matchesFullPrefix
            }
            
            if match { return true }
        }
        
        return false
    }
    
    func parseTitlePageLine(_ line:Line, index:Int) -> LineType {
        if let _ = line.string.range(of: ":") {
            let key = line.titlePageKey().lowercased()
            if key.count == 0 { return .empty }
            
            switch key {
            case "title":
                return .titlePageTitle
            case "author":
                return .titlePageAuthor
            case "authors":
                return .titlePageAuthor
            case "credit":
                return .titlePageCredit
            case "source":
                return .titlePageSource
            case "contact":
                return .titlePageContact
            case "draft date":
                return .titlePageDraftDate
            case "date":
                return .titlePageDraftDate
            default:
                return .titlePageUnknown
            }
        } else {
            // This is a continuation of another line
            let prevLine = (index > 0) ? (self.lines[index - 1] as? Line ?? nil) : nil
            if prevLine != nil {
                return prevLine!.type
            }
        }
        
        return .empty
    }
}



extension String {
    func isUppercaseUntilParentheses() -> Bool {
        var isUppercase = true
        var withinParentheses = false

        for char in self {
            if char == "(" {
                withinParentheses = true
            } else if char == ")" {
                withinParentheses = false
            } else if !withinParentheses && char.isLowercase {
                isUppercase = false
                break
            }
        }

        return isUppercase
    }
}
