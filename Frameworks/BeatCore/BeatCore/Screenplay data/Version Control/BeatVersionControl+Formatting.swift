//
//  BeatVersionControl+Formatting.swift
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 17.4.2026.
//

import Foundation

public extension BeatVersionControl {
    
    // MARK: - Attribute key
    
    static var diffAttributeKey: NSAttributedString.Key {
        return .init("BeatDiffAttributeKey")
    }
    
    // MARK: - Text Formatting
    
    class func formatDiffedText(_ diffs: [Diff], isOriginal: Bool) -> NSAttributedString {
        let string = NSMutableString()
        
        let redColor = BeatColors.color("red").withAlphaComponent(0.2)
        let greenColor = BeatColors.color("green").withAlphaComponent(0.2)
        
        let indices: [String: NSMutableIndexSet] = [
            "delete": NSMutableIndexSet(),
            "insert": NSMutableIndexSet()
        ]
        
        // Create an attributed string from diffs
        for diff in diffs {
            let text = diff.text ?? ""
            let range = NSMakeRange(string.length, text.count)
                    
            switch diff.operation.rawValue {
            case 1: // Delete
                indices["delete"]?.add(in: range)
            case 2: // Insert
                indices["insert"]?.add(in: range)
            default: // Equal
                break
            }

            string.append(text)
        }
        
        // Create a string, parse content and load document settings
        let attributedString = BeatVersionControl.formatFountain(string as String)
        
        // Apply diff colors
        indices["delete"]?.enumerateRanges(using: { range, stop in
            guard NSMaxRange(range) <= attributedString.length else { return }
            
            attributedString.addAttribute(.backgroundColor, value: redColor, range: range)
            attributedString.addAttribute(.strikethroughColor, value: BXColor.red, range: range)
            attributedString.addAttribute(.strikethroughStyle, value: 1, range: range)
            attributedString.addAttribute(BeatVersionControl.diffAttributeKey, value: "delete", range: range)
        })
        indices["insert"]?.enumerateRanges(using: { range, stop in
            guard NSMaxRange(range) <= attributedString.length else { return }
            
            attributedString.addAttribute(.backgroundColor, value: greenColor, range: range)
            attributedString.addAttribute(BeatVersionControl.diffAttributeKey, value: "add", range: range)
        })
        
        return attributedString
    }
    
    class func formatFountain(_ string: String) -> NSMutableAttributedString {
        let settings = BeatDocumentSettings()
        
        let settingRange = settings.readAndReturnRange(string)
        
        var content = string
        if settingRange.location != NSNotFound && settingRange.length != 0 {
            content = String(string.prefix(settingRange.location))
        }

        let attributedString = NSMutableAttributedString(string: content)
        let formatting = BeatEditorFormatting(textStorage: attributedString)

        formatting.staticParser = ContinuousFountainParser(staticParsingWith: attributedString.string, settings: settings)
        formatting.formatAllLines()
        
        return attributedString
    }
}
