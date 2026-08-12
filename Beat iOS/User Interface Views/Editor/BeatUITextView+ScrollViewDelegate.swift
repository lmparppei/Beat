//
//  BeatUITextView+ScrollViewDelegate.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 6.8.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

extension BeatUITextView:UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return pageView
	}
		
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		//
	}
	
	func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
		guard let pageView else { return }
		var x = (scrollView.frame.width - pageView.frame.width) / 2
		if (x < 0) { x = 0; }
				
		var frame = pageView.frame
		frame.origin.x = x
		
		var zoom = scrollView.zoomScale
		
		// Page view will always be at least the height of the screen
		if (frame.height < scrollView.frame.height) {
			let factor = frame.height / scrollView.frame.height
			zoom = scrollView.zoomScale / factor
		}
		
		// Set content scale factor (see UIView+Scale extension)
		// We'll multiply the value with screen native scale. Not sure if this is wise or not.
		let scale = scrollView.zoomScale * UIScreen.main.nativeScale
		
		scrollView.scaleViewTree(to: scale)
		self.scaleView(scale: scale)

		UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveLinear) { [weak self] in
			self?.pageView?.frame.origin.x = frame.origin.x
			
			self?.enclosingScrollView?.zoomScale = zoom
			self?.resizeScrollViewContent()
		} completion: { _ in
			
		}
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		guard let key = presses.first?.key else { return }
		
		// First check possible assistant view status and move highlight if needed
		// Normal tab presses are caught later
		if let assistantView, assistantView.numberOfSuggestions > 0,
		   key.modifierFlags.rawValue == 0 || key.modifierFlags == .shift {
			var preventSuper = false
			
			if key.keyCode == .keyboardTab && key.modifierFlags == .shift {
				assistantView.highlightPreviousSuggestion()
				preventSuper = true
			} else if key.keyCode == .keyboardTab {
				assistantView.highlightNextSuggestion()
				preventSuper = true
			} else if assistantView.highlightedSuggestion >= 0, key.keyCode == .keyboardReturnOrEnter {
				// Select the highlighted item
				assistantView.selectHighlightedItem()
				preventSuper = true
			} else if assistantView.highlightedSuggestion >= 0, key.keyCode == .keyboardEscape  {
				// De-select highlights
				assistantView.deselectHighlightedItem()
				preventSuper = true
			}
			
			if preventSuper { return }
		}
		
		if key.keyCode == .keyboardTab {
			handleTabPress()
			return
		}
		
		if key.keyCode == .keyboardReturnOrEnter, key.modifierFlags == .shift {
			self.modifierFlags = key.modifierFlags
		} else if key.keyCode == .keyboardDeleteOrBackspace, self.shouldCancelCharacterInput() {
			// Check if we should cancel character input
			self.cancelCharacterInput()
			return
		}
		
		super.pressesBegan(presses, with: event)
	}
	
	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		// Reset modifier flags first
		self.modifierFlags = []
		
		guard let key = presses.first?.key else { return }

		switch key.keyCode {
		case .keyboardTab:
			return
			
		default:
			super.pressesEnded(presses, with: event)
		}
	}
	
	func handleTabPress() {
		guard let line = self.editorDelegate?.currentLine else { return }
					
		if line.isAnyCharacter(), line.length > 0 {
			self.editorDelegate?.formattingActions.addOrEditCharacterExtension()
		} else if line.isAnyDialogue() && line.length == 0 {
			self.editorDelegate?.textActions.add("()", at: UInt(line.position), skipAutomaticLineBreaks: true)
			self.setSelectedRange(NSMakeRange(line.position+1, 0))
		} else {
			forceCharacterInput()
		}
	}
	
	func forceCharacterInput() {
		if self.editorDelegate?.lineForNewCue != nil { return }
		self.editorDelegate?.formattingActions.addCue()
	}
	
	
	//Delegate Methods
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView){
		lastOffsetY = scrollView.contentOffset.y
	}
	
	func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView){
		/*
		let hide = scrollView.contentOffset.y > self.lastOffsetY
		if let vc = self.getViewController() {
			let nc = vc.navigationController
			vc.navigationController?.setToolbarHidden(hide, animated: true)
		}
		*/
	}
}
