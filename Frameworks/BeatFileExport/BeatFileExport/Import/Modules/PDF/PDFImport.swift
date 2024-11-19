//
//  PDFImport.swift
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 14.11.2024.
//
/**
 
 This is a very badly documented PDF import. Results may vary.
 
 */

import Foundation
import PDFKit

@objcMembers
public class PDFImport:NSObject, BeatFileImportModule {
    
    public var fountain: String?
    public var callback:((Any?) -> Void)? = nil
    
    var titlePageFound = false
    // This flag determines whether the upcoming line is not linearly in its correct Y position.
    var nextLineIsOrphaned = false
    // Single character height
    var chrHeight = 0.0
    // Previously found text bounds
    var previousRect:CGRect = .zero
    // Flag for checking if we're in the middle of dialogue
    var dialogue = false
    
    // We store the Fountain text into an attributed string, so each line will have its Y coordinate stored as an attribute (yPosition)
    var currentPage:NSMutableAttributedString = NSMutableAttributedString()

    var progressModal: BeatProgressModalView?
    
    var header = ""
    
    public class func infoTitle() -> String? { return "PDF Import" }
    public class func infoMessage() -> String? { return "Please note that results of PDF import vary. Some screenplays work without a hitch, while others might come out completely garbled. Some pieces of text can be missing, so remember to check twice before trusting the output." }
    
    func showProgressModal() {
        // Initialize and show the modal window
        #if os(macOS)
        let modal = BeatExportProgressModal(windowNibName: BeatExportProgressModal.windowNibName!)
        #else
        let modal = BeatExportProgressModalManager()
        #endif
        
        self.progressModal = modal
        self.progressModal?.show(nil)
    }
    
    public required init(url: URL, options: [AnyHashable : Any]? = nil, completion callback: ((Any?) -> Void)? = nil) {
        super.init()
                
        self.callback = callback
        self.readPDF(url)
    }
    
    func readPDF(_ url:URL) {
        guard let pdf = PDFDocument(url: url) else {
            callback?(nil)
            return
        }
        
        var text = ""
        
        showProgressModal()

        DispatchQueue.global(qos: .userInitiated).async {
            
            for pageNumber in 0..<pdf.pageCount {
                DispatchQueue.main.async {
                    let progress = (Double(pageNumber) / Double(pdf.pageCount))
                    self.progressModal?.updateProgress(progress, label: "\(pageNumber+1) / \(pdf.pageCount)")
                }
                
                guard let page = pdf.page(at: pageNumber) else { break }
                // Reset flags
                self.nextLineIsOrphaned = false
                self.dialogue = false
                self.previousRect = CGRect.zero
                self.currentPage = NSMutableAttributedString()
                
                var line = ""
                var lineX = -1.0
                
                // PDF converted into a string
                let string = page.string ?? ""
                
                // Iterate through characters
                for i in 0..<page.numberOfCharacters {
                    let chr = String(string[i])
                    let chrBounds = page.characterBounds(at: i)
                    
                    // Store line height if needed. We'll be gratitious on the first page because you might have something weird going on in title page, such as images or bigger title text.
                    if self.chrHeight == 0.0 || self.chrHeight < 11.0 || self.chrHeight > 18.0 || pageNumber == 0 { self.chrHeight = chrBounds.height }
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Calculating offset to the previous line is the best way to determine whether this is a new line element.
                    let offset = self.previousRect.origin.y - chrBounds.origin.y
                    let limit = self.chrHeight - 2.0
                    
                    // We've encountered a line break
                    if abs(offset) > limit {
                        // Some elements have to be transformed before they can be used, such as scene headings.
                        // Page numbers will be ignored altogether.
                        if self.shouldSkipLine(trimmedLine) {
                            line = ""
                            continue
                        }
                        
                        // Check for possible page headers
                        /*
                        if self.currentPage.length == 0 {
                            if self.header == "" {
                                self.header = trimmedLine
                            } else if self.header == trimmedLine {
                                print("Are we looking at header:", trimmedLine)
                            }
                        }
                        */
                        
                        self.appendLine(trimmedLine, offset: offset, limit: limit, pageNumber: pageNumber)
                        
                        line = ""
                        lineX = -1
                    }
                    
                    if chr != "\n" && chr != "\r", chr.count > 0 {
                        line += String(chr)
                        if chrBounds.width > 0 {
                            self.previousRect = chrBounds
                            self.previousRect.origin.x = lineX
                        }
                        
                        if chr != " ", chr != "\n", trimmedLine.count > 0 {
                            lineX = chrBounds.origin.x
                        }
                    }
                }
                
                // If something was left over, add it here
                if line.count > 0 {
                    self.appendLine(line.trimmingCharacters(in: .whitespaces), offset: 0.0, limit: self.chrHeight - 2.0, pageNumber: pageNumber)
                }
                
                text += self.currentPage.string
                if self.titlePageFound { text += "\n" }
            }
            
            
            // Why do we need to store the variable here?
            self.fountain = self.cleanOutput(text)
            
            let callback = self.callback
            let modal = self.progressModal
            callback?(self)
            
            self.callback = nil
            
            DispatchQueue.main.async {
                modal?.close()
            }
        }
    }
    
    func handleHeadings(_ string:String, location:Int) -> String{
        var result = string
        if let heading = parseSceneHeading(result) {
            result = heading.heading.trimmingCharacters(in: .whitespaces)
            if heading.number.count > 0 { result += " #\(heading.number)#" }
            if characterOnCurrentPage(location) != "\n" { result = "\n" + result }
            
            result += "\n\n"
        }
        
        return result
    }
    
    func handleDialogue(_ string:String, location:Int) -> (string:String, lineBreaks:Int) {
        var result = string
        var lineBreaks = 0
        
        if mightBeCharacter(string) {
            if characterOnCurrentPage(location) != "\n" {
                result = "\n" + result
            }
            dialogue = true
            lineBreaks = 1
        } else if dialogue, string.first == "(" {
            if characterOnCurrentPage(location) != "\n" { result = "\n" + result }
            if string.last == ")" { lineBreaks = 1 }
        } else if dialogue, string.last == ")" {
            lineBreaks = 1
        }
        
        return (result, lineBreaks)
    }
    
    func characterOnCurrentPage(_ location:Int) -> String {
        if location - 1 >= 0 && currentPage.length > location - 1 {
            return currentPage.attributedSubstring(from: NSMakeRange(location - 1, 1)).string
        }
        
        return ""
    }
    
    func shouldSkipLine(_ string:String) -> Bool {
        return isPageNumber(string) || string == "(MORE)"
    }
    
    func parseSceneHeading(_ input: String) -> (heading: String, number: String)? {
        let pattern = #"^(\d+)?\s*(INT|EXT)\. (.+?)(\s*\d+)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: input.utf16.count)
        
        if let match = regex.firstMatch(in: input, options: [], range: range) {
            // Extract the optional starting number
            let numberStartRange = match.range(at: 1)
            let numberStart = numberStartRange.location != NSNotFound ? (input as NSString).substring(with: numberStartRange) : nil
            
            // Extract the scene type (INT or EXT)
            let sceneType = (input as NSString).substring(with: match.range(at: 2))
            
            // Extract the description part
            let description = (input as NSString).substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
            
            // Extract the optional ending number
            let numberEndRange = match.range(at: 4)
            let numberEnd = numberEndRange.location != NSNotFound ? (input as NSString).substring(with: numberEndRange).trimmingCharacters(in: .whitespaces) : nil
            
            // Check if there's a matching starting and ending number, or if either is nil
            if numberStart == numberEnd || numberEnd == nil {
                let heading = "\(sceneType). \(description)"
                return (heading, numberStart ?? "")
            }
        }
        
        return nil
    }
    
    func isPageNumber(_ input: String) -> Bool {
        let pattern = #"^\d+\.$|^pg\.\s*\d+$"#
        guard let regex = NSRegularExpression(pattern: pattern) else { return false }
        
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.firstMatch(in: input, options: [], range: range) != nil
    }
    
    func mightBeCharacter(_ input:String) -> Bool {
        var parentheses = false
        if input.count == 0 || input.first == "(" {
            return false
        }
        
        return input.allSatisfy({ char in
            if parentheses || char.isUppercase || char.isWhitespace {
                return true
            } else if char == "(", input.first != "(" {
                parentheses = true
                return true
            } else if char == ")" {
                parentheses = false
                return true
            } else if char.isPunctuation, char != ",", char != ":", char != "!" {
                return true
            } else {
                return false
            }
        })
    }
    
    func appendLine(_ string:String, offset:CGFloat, limit:CGFloat, pageNumber:Int) {
        var trimmedLine = string
        var lineBreaks = 0
        
        // If this line is not orphaned, just add it. Otherwise we need to find a place for it.
        let location = (!nextLineIsOrphaned && trimmedLine.count > 0) ?  currentPage.length : findPositionFor(string)
        if location == NSNotFound { return }
        
        // Handle headings
        trimmedLine = handleHeadings(trimmedLine, location: location)
        
        // Check offset amount. If it's > 2 line heights, it's a full paragraph change. Otherwise we'll determine if it's a character cue or parenthetical line.
        if offset > 2 * limit {
            // Paragraph break
            dialogue = false
            lineBreaks = 2
        } else if offset > limit {
            // Normal, single line break. We won't add these unless it's a dialogue block of some sorts.
            let dialogueResult = handleDialogue(trimmedLine, location: location)
            trimmedLine = dialogueResult.string
            lineBreaks = dialogueResult.lineBreaks
        }
        
        // Handle title page separately
        if pageNumber == 0 {
            if !titlePageFound, currentPage.string.trimmingCharacters(in: .whitespaces).count == 0, trimmedLine.count > 0, trimmedLine.isAllUppercase, parseSceneHeading(trimmedLine) == nil {
                titlePageFound = true
                trimmedLine = "Title: " + trimmedLine
            } else if titlePageFound {
                let lines = currentPage.string.split(separator: "\n")
                if lines.count > 0 {
                    if trimmedLine.lowercased().contains("written by") || trimmedLine.lowercased() == "by" {
                        trimmedLine = "Credit: " + trimmedLine
                    } else if trimmedLine.contains("@"), !currentPage.string.contains("Contact:") {
                        trimmedLine = "Contact: " + trimmedLine
                    } else if lines.count > 0, lines.count < 3, !currentPage.string.contains("Author:") {
                        trimmedLine = "Author: " + trimmedLine
                    }
                }
            }
            if titlePageFound { lineBreaks = 1 }
        }
        
        // If there are no line breaks, join the lines with spaces (unless there's already a space or a hyphen)
        if lineBreaks == 0, trimmedLine.count > 0, trimmedLine.last != " ", trimmedLine.last != "-" {
            trimmedLine += " "
        }
        
        if trimmedLine.count > 0 {
            currentPage.insert(NSAttributedString(string: trimmedLine, attributes: [
                NSAttributedString.Key("position"): previousRect.origin
            ]), at: location)
        }
            
        // If the offset is NEGATIVE, we have now encountered a line which is supposed to be somewhere much higher on the page.
        // On the next iteration, we'll try to find a place for it.
        nextLineIsOrphaned = (offset < 0 && previousRect.origin.y > 0)
                            
        // Reset current line and add line breaks to page text
        if trimmedLine.count > 0 {
            for _ in 0..<lineBreaks { currentPage.appendString("\n") }
        }
    }
    
    func findPositionFor(_ string:String) -> Int {
        // In some cases we might have ended up with an orphaned element. We'll now investigate where it should actually lie.
        var location = NSNotFound
        if string.count == 0 || isPageNumber(string) { return location }
        
        let attrStr = NSAttributedString(attributedString: currentPage)
        var previousRange = NSMakeRange(NSNotFound, 0)
        attrStr.enumerateAttribute(NSAttributedString.Key("position"), in: NSMakeRange(0, attrStr.length), options: .reverse) { value, range, stop in
            guard value != nil, let position = value as? CGPoint else  { return }
            
            if position.y == previousRect.origin.y {
                location = (previousRect.origin.x > position.x) ? NSMaxRange(range) : range.location
                stop.pointee = true
            } else if position.y > previousRect.origin.y {
                location = (previousRect.origin.x > position.x) ? NSMaxRange(previousRange) : previousRange.location
                stop.pointee = true
            }
            
            previousRange = range
        }
        
        return (location != NSNotFound) ? location : currentPage.length
    }
    
    func cleanOutput(_ string: String) -> String {
        // Clear double spaces and triple line breaks
        var cleanedText = string.replacingOccurrences(of: #"[ ]{2,}"#, with: " ", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: #"(?:\n\s\r*){3,}"#, with: "\n\n", options: .regularExpression)
        // Some brute forcing in case the regex doesn't work, he he
        cleanedText = cleanedText.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        cleanedText = cleanedText.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        
        return cleanedText
    }
}

extension NSMutableAttributedString {
    func appendString(_ string:String) {
        append(NSAttributedString(string: string))
    }
}

private extension String {
    var isAllUppercase:Bool {
        self.allSatisfy { chr in
            return !chr.isLowercase
        }
    }

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
