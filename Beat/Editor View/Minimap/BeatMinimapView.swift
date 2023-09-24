//
//  BeatMinimap.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.9.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import AppKit
import BeatCore

class BeatMinimapView: NSTextView {
	//@IBOutlet weak var textView: NSTextView?
	weak var editorDelegate:BeatEditorDelegate?
	
	/// The actual editor text view
	var editorView:NSTextView?
	
	@objc
	class func createMinimap(editorDelegate:BeatEditorDelegate, textStorage:NSTextStorage, editorView:NSTextView) -> BeatMinimapView {
		let layoutManager = BeatMinimapLayoutManager()
		textStorage.addLayoutManager(layoutManager)
		
		let textContainer = NSTextContainer(containerSize: NSSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude))
		layoutManager.addTextContainer(textContainer)
		
		let minimapView = BeatMinimapView(frame: NSMakeRect(0.0, 0.0, 0.0, editorView.enclosingScrollView?.frame.height ?? 100.0), textContainer: textContainer)
		
		minimapView.editorDelegate = editorDelegate
		minimapView.editorView = editorView
		
		minimapView.autoresizingMask                    = [.height]
		minimapView.isEditable                          = false
		minimapView.isSelectable                        = false
		minimapView.isHorizontallyResizable             = false
		minimapView.isVerticallyResizable               = true
		minimapView.textContainerInset                  = CGSize(width: 0, height: 0)
		minimapView.textContainer?.widthTracksTextView  = true
		minimapView.textContainer?.heightTracksTextView = false
		minimapView.textContainer?.lineBreakMode        = .byWordWrapping
		
		minimapView.layoutManager?.typesetter = BeatMinimapTypeSetter()
		minimapView.textContainer?.lineFragmentPadding = BeatMinimapLayoutManager.minimapFontSize()
		
		minimapView.textContainerInset = NSMakeSize(0, BeatMinimapLayoutManager.minimapFontSize())
		minimapView.backgroundColor = .clear
		
		return minimapView
	}
	
	// Highlight the current line.
	override func drawBackground(in rect: NSRect) {
		super.drawBackground(in: rect)
		
		// Highlight the current line
		// UPDATE THIS TO SUPPORT PARSER
		/*
		guard let layoutManager = layoutManager, let textView = self.textView else { return }
		 
		NSColor.lightGray.setFill()
		if let location = textView.insertionPoint {
			layoutManager.enumerateFragmentRects(forLineContaining: location) { rect in
				NSBezierPath(rect: rect).fill()
			}
		}
		 */
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
	func adjustScrollPositionOfMinimap() {
		//guard viewLayout.showMinimap else { return }
		
		guard let layoutManager = self.layoutManager as? BeatMinimapLayoutManager,
			  let textView = self.editorView,
			  let scrollView = self.editorView?.enclosingScrollView
		else { return }
				
		layoutManager.layoutFinished { [self] in
			let textViewHeight 		= textView.frame.height,
				textHeight     		= textView.boundingRect()?.height ?? 0,
				minimapHeight  		= self.boundingRect()?.height ?? 0,
				documentVisibleRect = scrollView.documentVisibleRect,
				visibleHeight  		= scrollView.documentVisibleRect.size.height
			
			let scrollFactor: CGFloat
			
			if minimapHeight < visibleHeight || textHeight <= visibleHeight {
				scrollFactor = 1
			} else {
				scrollFactor = 1 - (minimapHeight - visibleHeight) / (textHeight - visibleHeight)
			}
			
			
			// We box the positioning of the minimap at the top and the bottom of the code view (with the `max` and `min`
			// expessions. This is necessary as the minimap will otherwise be partially cut off by the enclosing clip view.
			// To get Xcode-like behaviour, where the minimap sticks to the top, it being a floating view is not sufficient.
			let newOriginY = floor(min(max(documentVisibleRect.origin.y * scrollFactor, 0), textViewHeight - minimapHeight))
			
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

