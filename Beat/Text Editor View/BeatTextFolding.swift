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
				
		//self.setSelectedRange(NSMakeRange(section.position, 0))
		self.textStorage?.addAttribute(NSAttributedString.Key("BeatFolded"), value: true, range: range)
		
		// This won't work because adding the attachment makes stuff go out of range.
		/*
		let attachment = NSTextAttachment()
		let cell = FoldAttachmentCell()
		cell.label = section.stringForDisplay()
		attachment.attachmentCell = cell

		let attrString = NSAttributedString(attachment: attachment)
		self.textStorage?.insert(attrString, at: range.location)
		*/
	}
	
}


/// Attachment cell with a disclosure button + label
final class FoldAttachmentCell: NSTextAttachmentCell {
	var label: String = "FOLDED" {
		didSet { controlView?.needsDisplay = true }
	}
	
	private let padding: CGFloat = 4
	private let triangleSize: CGFloat = 8
	
	override func cellSize() -> NSSize {
		let labelSize = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
		return NSSize(width: triangleSize + padding + labelSize.width,
					  height: max(labelSize.height, triangleSize))
	}
	
	override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
		let triangleRect = NSRect(x: cellFrame.minX,
								  y: cellFrame.midY - triangleSize / 2,
								  width: triangleSize,
								  height: triangleSize)
		
		let path = NSBezierPath()
		path.move(to: NSPoint(x: triangleRect.minX, y: triangleRect.minY))
		path.line(to: NSPoint(x: triangleRect.maxX, y: triangleRect.midY))
		path.line(to: NSPoint(x: triangleRect.minX, y: triangleRect.maxY))
		path.close()
		
		NSColor.labelColor.setFill()
		path.fill()
		
		// Draw label
		let labelRect = NSRect(x: triangleRect.maxX + padding,
							   y: cellFrame.minY,
							   width: cellFrame.width - triangleRect.width - padding,
							   height: cellFrame.height)
		
		(label as NSString).draw(in: labelRect,
								 withAttributes: [
									.font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
									.foregroundColor: NSColor.secondaryLabelColor
								 ])
	}
	
	override func trackMouse(with event: NSEvent, in cellFrame: NSRect,
							 of controlView: NSView?, untilMouseUp flag: Bool) -> Bool {
		print("clicked")
		return true
	}
}
