//
//  BeatTextFolding.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 27.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatParsing

@objc public extension BeatTextView {
	@IBAction func foldCurrentSection(_ sender:Any?) {
		guard let delegate = self.editorDelegate
		else { print("No delegate for text folding"); return; }
		
		let idx = delegate.parser.lineIndex(atPosition: UInt(delegate.selectedRange.location))
		var section:Line?
		
		for i in stride(from: Int(idx), to: 0, by: -1) {
			if let line = delegate.parser.lines[i] as? Line {
				if line.type == .section {
					section = line
					break
				}
			}
		}
		
		if section != nil {
			foldSection(section!)
		}
	}
	
	@objc func foldSection(_ section:Line) {
		guard let delegate = self.editorDelegate else { print("No delegate for text folding"); return; }
	
		let i = delegate.parser.lines.index(of: section)
		if i == NSNotFound { return }
		
		// Find next section
		var nextSection:Line?
		for idx in i+1..<delegate.parser.lines.count {
			if let line = delegate.parser.lines[idx] as? Line {
				if line.sectionDepth >= section.sectionDepth {
					nextSection = line
					break
				}
			}
		}
		
		var range = NSMakeRange(0, 0)
		let headingRange = section.range()
		
		if nextSection == nil {
			// No next section found, let's just fold everything until the end
			range = NSMakeRange(NSMaxRange(headingRange), delegate.text().count - NSMaxRange(headingRange) - 1)
		} else {
			range = NSMakeRange(NSMaxRange(headingRange), nextSection!.position - NSMaxRange(headingRange))
		}
		
		print("Range", range, "max range", NSMaxRange(range), "length", self.text.count)
		
		//self.setSelectedRange(NSMakeRange(section.position, 0))
		self.textStorage?.addAttribute(NSAttributedString.Key("BeatFolded"), value: true, range: range)
		
	}
	
}
