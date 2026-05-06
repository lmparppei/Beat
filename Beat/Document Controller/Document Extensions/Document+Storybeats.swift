//
//  Document+Storybeats.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 3.5.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import Foundation

extension Document {
	
	func nextBeatOfSelectedStoryline(_ sender: Any?) {
		guard let beat = storybeat(at: self.selectedRange().location) else { return }
				
		if let nextBeat = findNextStorybeat(from: NSMaxRange(beat.range), storyline: beat.storyline) {
			self.setSelectedRange(NSMakeRange(nextBeat.range.location, 0))
		}
	}
	
	func prevBeatOfSelectedStoryline(_ sender: Any?) {
		guard let beat = storybeat(at: self.selectedRange().location) else { return }
				
		if let prevBeat = findPreviousStorybeat(from: beat.range.location, storyline: beat.storyline) {
			self.setSelectedRange(NSMakeRange(prevBeat.range.location, 0))
		}
	}
	
	func storybeat(at:Int) -> Storybeat? {
		guard let currentLine else { return nil }
		
		for beat in currentLine.beats {
			if NSLocationInRange(self.selectedRange().location, beat.range) {
				return beat
			}
		}
		
		return nil
	}
	
	@IBAction func nextStorybeat(_ sender: Any?) {
		guard let beat = findNextStorybeat(from: self.selectedRange().location) else { return }
		
		self.setSelectedRange(NSMakeRange(beat.line.position + NSMaxRange(beat.rangeInLine), 0))
	}
	
	@IBAction func previousStorybeat(_ sender: Any?) {
		guard let beat = findPreviousStorybeat(from: self.selectedRange().location) else { return }
		
		self.setSelectedRange(NSMakeRange(beat.line.position + beat.rangeInLine.location, 0))
	}

	func findNextStorybeat(from location:Int, storyline:String? = nil) -> Storybeat? {
		guard let lines = self.parser.lines(in: NSMakeRange(location, self.text().count - location)) else {
			return nil
		}
		
		for line in lines {
			for beat in line.beats {
				let globalRange = NSMakeRange(line.position + beat.rangeInLine.location, beat.rangeInLine.length)

				if NSMaxRange(globalRange) <= location || NSLocationInRange(location, beat.range) {
					continue
				} else if storyline != nil, beat.storyline != storyline {
					continue
				}
				
				return beat
			}
		}
		
		return nil
	}
	
	func findPreviousStorybeat(from location:Int, storyline:String? = nil) -> Storybeat? {
		guard let lines = self.parser.lines(in: NSMakeRange(0, location)) else {
			return nil
		}
		
		for line in lines.reversed() {
			for beat in line.beats.reversed() {
				let globalRange = NSMakeRange(line.position + beat.rangeInLine.location, beat.rangeInLine.length)
				if NSMaxRange(globalRange) > location || NSLocationInRange(location, beat.range) {
					continue
				} else if storyline != nil, beat.storyline != storyline {
					continue
				}
				
				return beat
			}
		}
		
		return nil
	}
}

