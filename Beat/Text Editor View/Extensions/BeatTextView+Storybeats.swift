//
//  BeatTextView+Storybeats.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 4.5.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatParsing

fileprivate var prevBeatButton:NSButton?
fileprivate var nextBeatButton:NSButton?

fileprivate var currentBeat:Storybeat?

extension BeatTextView {
	
	@objc func updateStorybeatButtons() {
		guard self.selectedRange().length == 0,
			  let currentLine = self.editorDelegate?.currentLine,
			  currentLine.beats.count > 0,
			  let doc = self.delegate as? Document,
			  let beat = doc.storybeat(at: self.selectedRange().location)
		else {
			prevBeatButton?.removeFromSuperview()
			nextBeatButton?.removeFromSuperview()
			currentBeat = nil
			return
		}
				
		if prevBeatButton == nil,
		   nextBeatButton == nil,
		   let prevImg = NSImage(named: "chevron.backward"),
		   let nextImg = NSImage(named: "chevron.forward")
		{
			let color = BeatColors.color("cyan").withAlphaComponent(0.8).cgColor
			
			prevBeatButton = NSButton(image: prevImg, target: self, action: #selector(moveToPreviousStorybeatSibling))
			nextBeatButton = NSButton(image: nextImg, target: self, action: #selector(moveToNextStorybeatSibling))
			
			nextBeatButton?.bezelStyle = .circular
			nextBeatButton?.controlSize = .small
			nextBeatButton?.isBordered = false
			
			prevBeatButton?.bezelStyle = .circular
			prevBeatButton?.isBordered = false
			prevBeatButton?.controlSize = .small
			
			nextBeatButton?.wantsLayer = true
			nextBeatButton?.layer?.backgroundColor = color
			
			prevBeatButton?.wantsLayer = true
			prevBeatButton?.layer?.backgroundColor = color
		}
		
		if beat != currentBeat {
			// Check if there are next or previous beats
			let prevBeat = doc.findPreviousStorybeat(from: beat.range.location, storyline: beat.storyline)
			let nextBeat = doc.findNextStorybeat(from: NSMaxRange(beat.range), storyline: beat.storyline)
						
			prevBeatButton?.isHidden = prevBeat == nil
			nextBeatButton?.isHidden = nextBeat == nil
		}
		
		let beatRange = NSMakeRange(beat.line.position + beat.rangeInLine.location, beat.rangeInLine.length)
			
		if let nextBeatButton, let prevBeatButton,
			let gRange = self.layoutManager?.glyphRange(forCharacterRange: beatRange, actualCharacterRange: nil),
			let rects = self.layoutManager?.rectsForGlyphRange(gRange),
			let firstRect = rects.first?.rectValue {
						
			prevBeatButton.frame.size = CGSizeMake(firstRect.height, firstRect.height)
			nextBeatButton.frame.size = CGSizeMake(firstRect.height, firstRect.height)
			
			prevBeatButton.frame.origin = CGPointMake(firstRect.origin.x + self.textContainerInset.width - prevBeatButton.frame.size.width, firstRect.origin.y + self.textContainerInset.height)
			nextBeatButton.frame.origin = CGPointMake(firstRect.origin.x + firstRect.size.width + self.textContainerInset.width, firstRect.origin.y + self.textContainerInset.height)
			
			prevBeatButton.layer?.cornerRadius	= firstRect.size.height / 2
			nextBeatButton.layer?.cornerRadius	= firstRect.size.height / 2
			
			if nextBeatButton.superview == nil, prevBeatButton.superview == nil {
				self.addSubview(nextBeatButton)
				self.addSubview(prevBeatButton)
			}
		}

		currentBeat = beat
	}
	
	@objc func moveToPreviousStorybeatSibling() {
		guard let doc = self.delegate as? Document else { return }
		
		doc.prevBeatOfSelectedStoryline(nil)
	}
	
	@objc func moveToNextStorybeatSibling() {
		guard let doc = self.delegate as? Document else { return }
		
		doc.nextBeatOfSelectedStoryline(nil)
	}	
}
