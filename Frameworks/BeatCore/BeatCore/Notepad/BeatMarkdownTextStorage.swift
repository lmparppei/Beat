//
//  BeatMarkdownTextStorage.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.11.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This class provides VERY simple Markdown-style parsing.
 
 */

import Foundation
import UXKit

@objc public class BeatMarkdownTextStorageDelegate:NSObject, NSTextStorageDelegate {
	
	enum BeatMarkdownLineType {
		case normal
		case heading
	}
	
	struct BeatMdLine {
		var string = ""
		var position = NSNotFound
		var length:Int { return self.string.count }
		var range:NSRange { return NSMakeRange(position, length + 1) }
	}
	
	@objc public weak var textStorage:NSTextStorage?
    @objc public var fontSize:CGFloat = 12.0
    
    var stylization:[String:Any]
    
    @objc public init(fontSize:CGFloat = 12.0) {
        self.fontSize = fontSize
        self.stylization = [
            "*": [NSAttributedString.Key.font: UXFont.systemFont(ofSize: fontSize).italics()],
            "**": [NSAttributedString.Key.font: UXFont.systemFont(ofSize: fontSize).bold()],
            "_": [NSAttributedString.Key.underlineStyle: 1]
        ]
        
        super.init()
    }
    
    func setupStyles() {
        
    }

	var lines:[BeatMdLine] {
		guard let textStorage = self.textStorage else { return [] }
		
		let lines = textStorage.string.components(separatedBy: "\n")
		var i = 0
		
		// Create simple line elements for each
		let mdLines:[BeatMdLine] = lines.map { str in
			let l = BeatMdLine(string: str, position: i)
			i += str.count + 1
			return l
		}
		
		return mdLines
	}
    	
	public func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        self.formatMarkup(range: editedRange)
	}
	
	public func formatMarkup(range:NSRange) {
		for line in self.lines {
			if NSIntersectionRange(range, line.range).length > 0 || NSLocationInRange(range.location, line.range) {
				parse(line.range)
			}
		}
	}
	
	public func parse(_ range:NSRange) {
		guard let textStorage = self.textStorage else { return }
		
		var r = range
		if NSMaxRange(r) > textStorage.string.count {
			r.length -= NSMaxRange(r) - textStorage.string.count
		}
		
		let string = textStorage.string.substring(range: r)
		if string.count == 0 { return }
		
		let type = parseLineType(string)
		
        var newAttrs:[NSAttributedString.Key:Any] = [:]
		
		if type == .heading {
			// A heading. Calculate its level and set font.
			var level = 1
			for i in 1..<string.count {
				if string[i] == "#" { level += 1 }
				else { break }
			}
			
			if level > 4 { level = 4 }
            let size = 1.6 * fontSize - 2 * CGFloat(level)
			let newFont = BXFont.boldSystemFont(ofSize: size)

			newAttrs[NSAttributedString.Key.font] = newFont
		} else {
			// Something else
			newAttrs[NSAttributedString.Key.font] = BXFont.systemFont(ofSize: fontSize)
		}
		
		// Reset underline
		newAttrs[NSAttributedString.Key.underlineStyle] = 0
		// Apply full font style first
		self.textStorage?.addAttributes(newAttrs, range: r)
        
		// Inline stylization
		if type == .normal {
			for key in stylization.keys {
				let dict = stylization[key] as? [NSAttributedString.Key: Any]
				let indices = parseInlineStyles(string: string, markdown: key)
				
				indices.enumerateRanges { localRange, stop in
					if (dict != nil) {
						self.textStorage?.addAttributes(dict!, range: NSMakeRange(range.location + localRange.location, localRange.length))
					}
				}
			}
		}
	}
	
	func parseLineType(_ string:String) -> BeatMarkdownLineType {
		if string.count == 0 {
			return .normal
		} else if string[0] == "#" {
			return .heading
		}
		
		return .normal
	}
	
	public func parseInlineStyles(string:String, markdown:String) -> NSIndexSet {
		let indices = NSMutableIndexSet()
		let lim = string.count - markdown.count + 1
		
		var range = NSMakeRange(NSNotFound, 0)
		
		for i in 0..<lim {
			var match = true
			for n in 0..<markdown.count {
				let c = string[i+n]
				if c != markdown[n] {
					match = false
					break
				}
			}
			
			if match {
				if range.location == NSNotFound {
					// Starts a range
					range.location = i
					continue
				} else {
					// Terminates a range
					range.length = i - range.location
					indices.add(in: range)
				}
			}
		}
		
		return indices
	}
	
}
