//
//  BeatParser.swift
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 13.2.2024.
//

/**
 
 An attempt at translating the parser to Swift. Nothing to see her.
 
 */

import Foundation

struct FountainMarkup {
    var open:String
    var close:String
    var set:String
}

fileprivate let _bold = FountainMarkup(open: "**", close: "**", set: "bold")
fileprivate let _italic = FountainMarkup(open: "*", close: "*", set: "italic")
fileprivate let _underline = FountainMarkup(open: "_", close: "_", set: "underlined")
fileprivate let _macro = FountainMarkup(open: "{{", close: "}}", set: "macro")

fileprivate let formattingTypes:[FountainMarkup] = [_bold, _italic, _underline, _macro]

protocol BeatParserDelegate {
    var disabledTypes:[LineType] { get }
    var selectedRange:NSRange { get }
}

class BeatParser:NSObject {
    var delegate:BeatParserDelegate?
    
    var changedIndices:IndexSet = []
    var lines:[Line] = []
    
    var boneyardSection:Line?
    
    
    func parseFormatting(for line:Line) {
        line.escapeRanges = NSMutableIndexSet()
        
        var excludedRanges:IndexSet = []
        for formatting in formattingTypes {
            var openRange = false
            
            let ranges = line.string.ranges(startString: formatting.open, endString: formatting.close, excludingIndices: &excludedRanges, line: line)
            let setName = formatting.set + "Ranges"
            
            line.setValue(ranges, forKey: setName)
        }
    }
    
    func parseType(for line:Line, at index:Int) -> LineType {
        let previousLine = (index > 0) ? self.lines[index - 1] : nil
        let nextLine = (index < lines.count - 1) ? self.lines[index + 1] : nil
        
        var previousIsEmpty = false
        
        let trimmedString = line.string.trimmingCharacters(in: .whitespaces)
        
        // Handle empty lines first
        if line.length == 0 {
            if let prev = previousLine, (prev.isDialogue() || prev.isDualDialogue()) {
                // If preceded by a character cue, always return dialogue
                if prev.type == .character { return .dialogue }
                else if prev.type == .dualDialogueCharacter { return .dualDialogue }
                
                let selection = (Thread.isMainThread) ? (delegate?.selectedRange.location ?? 0) : 0
                
                // If it's any other dialogue line and we're editing it, return dialogue
                if prev.isAnyDialogue() || prev.isAnyParenthetical(), 
                    prev.length > 0,
                    nextLine?.length ?? 0 == 0,
                    NSLocationInRange(selection, line.range()) {
                    return (prev.isDialogue()) ? .dialogue : .dualDialogue;
                }
            }
        
            return .empty
        }
        
        // Check forced types
        if let forcedType = parseForcedType(for: line) {
            return forcedType
        }
        
        // Normal parsing
        let prefix = line.string.prefix(3).lowercased()
        
        if prefix == "int" || prefix == "ext" || prefix == "i/e" {
            // For convenience's sake, let's return heading for just these prefixes
            if line.length == 3 { return .heading }
            
            // Check next char after prefix: we don't want to make words like "international" a heading
            let fPrefix = line.string.prefix(4)
            if let last = fPrefix.last, (last == " " || last == ".") {
                return .heading
            }
        }
        
        // Check lines that require the previous line to be empty
        if let prev = previousLine, prev.type == .empty {
            if line.visibleContentIsUppercase(), let lastChr = line.string.last, lastChr == ":" {
                return .transitionLine
            }
            
            if line.visibleContentIsUppercase(), line.length > 2 {
                if let lastChr = line.string.last, lastChr == "^" {
                    return .dualDialogueCharacter
                }
                return .character
            }
        }
        
        return .action
    }
    
    func parseForcedType(for line:Line) -> LineType? {
        guard let firstChar = line.string.first, let lastChar = line.string.last else { return nil }
        
        switch firstChar {
        case "!":
            if line.length > 1, line.string.prefix(2) == "!!" { return .shot}
            return .action
        case "@":
            if lastChar == "^" { return .dualDialogueCharacter }
            return .character
        case "~":
            return .lyrics
        case ">":
            if lastChar == "<" { return .centered }
            return .transitionLine
        case "=":
            return .synopse
        case "#":
            return .section
        case ".":
            if line.length > 1, line.string.prefix(2) == ".." { return nil }
            return .heading
        default:
            return nil
        }
    }
}

extension String {
    func ranges(startString: String, endString: String, excludingIndices: inout IndexSet, line: Line) -> IndexSet {
        var indexSet = IndexSet()
        let length = self.utf16.count
        let startLength = startString.utf8.count
        let delimLength = endString.utf8.count

        guard length >= startLength + delimLength else {
            return indexSet
        }

        var index = self.utf16.startIndex
        var range = NSRange(location: -1, length: 0)

        while index <= self.utf16.index(before: self.utf16.endIndex) {
            let i = self.utf16.distance(from: self.utf16.startIndex, to: index)

            // If this index is contained in the omit character indexes, skip
            if excludingIndices.contains(i) {
                index = self.utf16.index(after: index)
                continue
            }

            // First check for escape character
            if i > 0 {
                let prevCharIndex = self.utf16.index(before: index)
                let prevChar = self[prevCharIndex]
                if prevChar == "\\" {
                    line.escapeRanges.add(i - 1)
                    index = self.utf16.index(after: index)
                    continue
                }
            }

            if range.location == -1 {
                // Next, see if we can find the whole start string
                let endIndex = self.utf16.index(index, offsetBy: startLength)
                let startSubstring = self[index..<endIndex]

                if startSubstring != startString {
                    index = self.utf16.index(after: index)
                    continue
                }

                // Success! We found a matching string
                range.location = i

                // Pass the starting string
                index = self.utf16.index(index, offsetBy: startLength - 1)

            } else {
                // We have found a range, let's see if we find a closing string.
                let endIndex = self.utf16.index(index, offsetBy: delimLength)
                let endSubstring = self[index..<endIndex]

                if endSubstring != endString {
                    index = self.utf16.index(after: index)
                    continue
                }

                // Success, we found a closing string.
                range.length = i + delimLength - range.location
                indexSet.insert(integersIn: Range(range)!)

                // Add the current formatting ranges to future excludes

                excludingIndices.insert(integersIn: Range(NSRange(location: range.location, length: startLength))!)
                excludingIndices.insert(integersIn: Range(NSRange(location: i, length: delimLength))!)

                range.location = -1

                // Move past the ending string
                index = self.utf16.index(index, offsetBy: delimLength - 1)
            }

            index = self.utf16.index(after: index)
        }

        return indexSet
    }
}
