//
//  BeatParser.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This is an initial draft for converting the parser to Swift.
 Nothing to see here unless you want to contribute.
 
 */

import Foundation

class BeatParser: NSObject <LineDelegate> {
	
	var lines = []
	var changedIndices = []
	var outline = []
	var titlePage = []
	var storylines = []
	
	var changeInOutline:Bool = false
	var editedLine:Line?
	var lastEditedLine:Line?
	var editedIndex:NSUInteger = 1
	
	// Title page parsing
	var hasTitlePage:bool = false
	var openTitlePageKey:String?
	var previousTitlePageKey:String?
	
	// Initial loading
	var indicesToLoad:NSInteger = 0
	var firstTime:Bool
	
	// Cache for previously requested line
	var prevLineAtLocation:Line?
	var nonContinuous:Bool
	
	// For STATIC parsing (no editable document)
	var staticDocumentSettings:BeatDocumentSettings?
	var staticPaser:Bool = false
	
	var previousLine:Line?
	
	var content:String = ""
	
	func screenplayForSaving() {
		let lines = self.lines
		
		for line:Line in lines {
			if (line == nil) {
				continue
			}
			
			var string:String = line.string
			var type:LineType = line.type
			
			// Ensure correct whitespace before elements
			if (type == LineType.character || type == LineType.heading) && previousLine?.string.count > 0 {
				string.append("\n")
			}
			
			if (type == LineType.heading || type == LineType.transitionLine) && line.numberOfPrecedingFormattingCharacters == 0 {
				string = string.uppercased()
			}
			
			content.append(string)
			if (line != lines.last) {
				content.append("\n")
			}
			
			previousLine = line
		}
		
		return content
	}
	
	func parseText(text:String) {
		firstTime = true
		
		self.lines = []
		
		var lines = text.components(separatedBy: "\n")
		indicesToLoad = lines.count
		
		var position = 0
		var sceneIndex = -1
		
		var previousLine:Line?
		
		for rawLine in lines {
			var index = self.lines.count
			var line:Line = Line().init(string: rawLine, position: position, parser: self)
			// parseTypeAndFormattingForLine(line, atIndex:index)
			
			// Quick fix for mistaking an ALL CAPS action to character cue
			if (previousLine?.type == LineType.character && (line.string.count < 1 || line.type == LineType.empty)) {
				// previousLine?.type = parseLineType(previousLine, atIndex:index - 1 recursive:false currentlyEditing:false)
				if (previousLine?.type == LineType.character) {
					previousLine?.type = LineType.action
				}
			}
			
			if (line.type == LineType.heading || line.type == LineType.synopse || line.type == LineType.section) {
				// A cloned version of the screenplay is used for preview & printing.
				// sceneIndex ensures we know which scene heading is which, even when there are hidden outline items.
				// This is used to jump into corresponding scenes from preview mode. There are smarter ways
				// to do this, but this is how it was done back in the day and still remains so.
				sceneIndex++
				line.sceneIndex = sceneIndex
			}
			
			// Quick fix for recognizing split paragraphs
			var currentType = line.type;
			if (line.type == LineType.action || line.type == LineType.lyrics || line.type == LineType.transitionLine) {
				if (previousLine.type == currentType && previousLine.string.count > 0) {
					line.isSplitParagraph = true
				}
			}
			
			self.lines.append(line)
			self.changedIndices.append(index)
			
			position += rawLine.count + 1 // +1 for newline character
			previousLine = line
			self.indicesToLoad--
		}
		
		// Initial parse complete
		self.indicesToLoad = -1
		
		self.changeInOutline = false
		self.firstTime = false;
		
		//self.createOutline()
	}
	
	
}
