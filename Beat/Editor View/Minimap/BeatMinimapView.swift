//
//  BeatMinimap.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//
/**

 N.B. — This class takes a lot of inspiration from CodeEditor for SwiftUI, but doesn't directly use its code.
 
 */

import AppKit
import BeatCore

class BeatMinimapView: NSTextView {
	weak var editorDelegate:BeatEditorDelegate?
	/// The actual editor text view
	var editorView:NSTextView?
	
	@objc
	class func createMinimap(editorDelegate:BeatEditorDelegate, textStorage:NSTextStorage, editorView:NSTextView) -> BeatMinimapView {
		let layoutManager = BeatMinimapLayoutManager()
		textStorage.addLayoutManager(layoutManager)
		
		let textContainer = NSTextContainer(containerSize: NSSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude))
		layoutManager.addTextContainer(textContainer)
		
		let minimap = BeatMinimapView(frame: NSMakeRect(0.0, 0.0, 0.0, editorView.enclosingScrollView?.frame.height ?? 100.0), textContainer: textContainer)
		
		minimap.editorDelegate = editorDelegate
		minimap.editorView = editorView
		
		minimap.layoutManager?.typesetter = BeatMinimapTypeSetter()
		
		minimap.textContainer?.widthTracksTextView  = true
		minimap.textContainer?.heightTracksTextView = false
		minimap.textContainer?.lineBreakMode        = .byWordWrapping
		
		minimap.translatesAutoresizingMaskIntoConstraints = true
		minimap.autoresizingMask                    = [.height, .maxXMargin]
		
		minimap.isEditable                          = false
		minimap.isSelectable                        = false
		minimap.isHorizontallyResizable             = false
		minimap.isVerticallyResizable               = true
		minimap.textContainerInset                  = CGSize(width: 0, height: 0)
		
		minimap.textContainer?.lineFragmentPadding = BeatMinimapLayoutManager.minimapFontSize()
		minimap.textContainerInset = NSMakeSize(0, BeatMinimapLayoutManager.minimapFontSize())
		minimap.backgroundColor = .clear
		
		return minimap
	}
	
	/// Highlights the current line
	override func drawBackground(in rect: NSRect) {
		super.drawBackground(in: rect)
		
		// Highlight the current line
		guard let range = self.editorDelegate?.currentLine().textRange() else { return }
		if range.location != NSNotFound {
			NSColor.lightGray.setFill()
			layoutManager?.enumerateFragmentRects(forLineContaining: range.location, using: { rect in
				NSBezierPath(rect: rect).fill()
			})
		}
	}
	
	
	// MARK: - View sizing & positioning
	
	/// Returns minimap view width based on page size
	var viewWidth:CGFloat {
		guard let pageSize = editorDelegate?.pageSize else { return 100.0 }
		
		// TODO: Get the values from styles
		let widthInChars = (pageSize == .A4) ? 59 : 61
		let width = CGFloat(widthInChars) * (BeatMinimapLayoutManager.minimapFontSize() / 2.0)
		
		return width
	}
	
	@objc
	func resizeMinimap() {
		guard let scrollView = self.editorView?.enclosingScrollView else { return }
		
		let width = self.viewWidth
		let height = self.frame.height < scrollView.frame.height ? scrollView.frame.height : self.frame.height
		let rect = CGRectMake(0, 0, width, height)
		
		self.textContainer?.size = CGSizeMake(width, CGFloat.greatestFiniteMagnitude)
		
		self.frame = rect
	}
	
	@objc
	func adjustPosition() {
		//guard viewLayout.showMinimap else { return }
		
		guard let layoutManager = self.layoutManager as? BeatMinimapLayoutManager,
			  let textView = self.editorView,
			  let scrollView = self.editorView?.enclosingScrollView
		else { return }
				
		layoutManager.onLayoutFinished { [self] in
			let textViewHeight 		= textView.frame.height,
				textHeight     		= textView.boundingRect()?.height ?? 0,
				minimapHeight  		= self.boundingRect()?.height ?? 0,
				documentVisibleRect = scrollView.documentVisibleRect,
				visibleHeight  		= scrollView.documentVisibleRect.size.height
			
			let factor: CGFloat
			
			if minimapHeight < visibleHeight || textHeight <= visibleHeight {
				factor = 1
			} else {
				factor = 1 - (minimapHeight - visibleHeight) / (textHeight - visibleHeight)
			}
			
			
			// We box the positioning of the minimap at the top and the bottom of the code view (with the `max` and `min`
			// expessions. This is necessary as the minimap will otherwise be partially cut off by the enclosing clip view.
			// To get Xcode-like behaviour, where the minimap sticks to the top, it being a floating view is not sufficient.
			let newOriginY = floor(min(max(documentVisibleRect.origin.y * factor, 0), textViewHeight - minimapHeight))
			
			// Avoid updating the frame if it hasn't changed.
			if self.frame.origin.y != newOriginY {
				self.frame.origin.y = newOriginY
			}
			
			/*
			let minimapVisibleY      = documentVisibleRect.origin.y * minimapHeight / textHeight,
				minimapVisibleHeight = visibleHeight * minimapHeight / textHeight,
				documentVisibleFrame = CGRect(x: 0,
											  y: minimapVisibleY,
											  width: self.bounds.size.width ?? 0,
											  height: minimapVisibleHeight).integral
			
			if documentVisibleBox?.frame != documentVisibleFrame { documentVisibleBox?.frame = documentVisibleFrame }
			 */
		}
	}
	
}

extension NSTextView {
	/// Returns a pointer
	var insertionPoint: Int? {
		if let selection = selectedRanges.first as? NSRange,
			selection.length == 0 {
			return selection.location
		}
		else { return nil }
	}
}

