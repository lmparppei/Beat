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
	

	// MARK: - Parsing
	
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
	
	func parseChangeInRange(range:NSRange, withString string:String) {
		if range.location == NSNotFound {
			return
		}
		
		lastEditedLine = nil
		editedIndex = -1
		
		var changedIndices:NSMutableIndexSet = NSMutableIndexSet()
		
		if range.length == 0 {
			// Addition
			//changedIndices.append(parseAddition(string, atPosition:range.location))
		}
		else if string.count == 0 {
			// Removal
			//changedIndices.append(parseRemoval(range))
		} else {
			// Replacement
			//changedIndices.append(parseRemoval(range))
			//changedIndices.append(parseAddition(string, atPosition:range.location))
		}
		
		//correctParsesInLines(changedIndices)
	}
	
	func parseAddition(string:String, atPosition position:Int) {
		var changedIndices:NSMutableIndexSet = NSMutableIndexSet()
		var lineIndex:UInt = lineIndexAtPosition(position: position)
		
		let line:Line = lines[lineIndex]
		
		if (line.type == LineType.heading || line.type == LineType.synopse || line.type == LineType.section) {
			changeInOutline = true
		}
		
		var indexInLine = position - line.position
	
		// If the added string is a multi-line block, we need to optimize the addition.
		// Else, just parse it character-by-character.
		if string.contains("\n") {
			// Split the original line into two
			var head:String = line.string.substring(to: indexInLine)
			var tail:String = (indexInLine + 1 <= line.string.length) ? line.string.substring(from: indexInLine) : ""
			var newLines = string.components(separatedBy: "\n")
			var offset = line.position
			
			changedIndices.append(lineIndex)
			decrementLinePositions(from:lineIndex + 1, amount:tail.count)
			
			for i in 0...<newLines.count {
				var newLine:String = newLines[i]
				
				if i == 0 {
					// First line
					head.append(newLine)
					line.string = head
					
					incrementLinePositions(from: lineIndex + 1, amount: newLine.count + 1)
					offset += head.count + 1
					
				} else {
					var addedLine:Line?
					
					if i == newLines.count - 1 {
						// Handle adding the last line a bit differently
						newLine.append(tail)
						tail = newLine
						addedLine = Line().init(string: tail, position: offset, parser: self)
					}
				}
			}
		}
	}
	
	func parseCharacterRemoved(atPosition position: Int, line: Line!) -> NSIndexSet {
		var changedIndices = NSIndexSet()
		
		var indexInLine = position - line.position
		let lineIndex = editedIndex

		if indexInLine > line.string.length  {
			indexInLine = line.string.length
		}

		if indexInLine == line.string.length {
			if lineIndex == lines.count - 1 {
				return changedIndices
			}
			
			// .......
		}
	}
	
	/*
		  // Go through the new lines
		  for (NSInteger i = 0; i < newLines.count; i++) {
			  NSString *newLine = newLines[i];
		  
			  if (i == 0) {
				  // First line
				  head = [head stringByAppendingString:newLine];
				  line.string = head;
				  [self incrementLinePositionsFromIndex:lineIndex + 1 amount:newLine.length + 1];
				  offset += head.length + 1;
			  } else {
				  Line *addedLine;
				  
				  if (i == newLines.count - 1) {
					  // Handle adding the last line a bit differently
					  tail = [newLine stringByAppendingString:tail];
					  addedLine = [[Line alloc] initWithString:tail position:offset parser:self];

					  [self.lines insertObject:addedLine atIndex:lineIndex + i];
					  [self incrementLinePositionsFromIndex:lineIndex + i + 1 amount:addedLine.string.length];
					  offset += newLine.length + 1;
				  } else {
					  addedLine = [[Line alloc] initWithString:newLine position:offset parser:self];
					  
					  [self.lines insertObject:addedLine atIndex:lineIndex + i];
					  [self incrementLinePositionsFromIndex:lineIndex + i + 1 amount:addedLine.string.length + 1];
					  offset += newLine.length + 1;
				  }
			  }
		  }
		  
		  [changedIndices addIndexesInRange:NSMakeRange(lineIndex, newLines.count)];
	  } else {
		  // Do it character by character...
		  
		  // Set the currently edited line index
		  if (_editedIndex >= self.lines.count || _editedIndex < 0) {
			  _editedIndex = [self lineIndexAtPosition:position];
		  }

		  // Find the current line and cache its previous version
		  Line* line = self.lines[lineIndex];
		  
		  for (int i = 0; i < string.length; i++) {
			  NSString* character = [string substringWithRange:NSMakeRange(i, 1)];
			  [changedIndices addIndexes:[self parseCharacterAdded:character
														atPosition:position+i
															  line:line]];
		  }
		  
		  if ([string isEqualToString:@"\n"]) {
			  // After a line break is added, parse the next line too, because
			  // some elements may have changed their type.
			  [changedIndices addIndex:lineIndex + 2];
		  }
	  }
	  
	  // Log any problems faced during parsing (safety measure for debugging)
	  // [self report];
	  
	  return changedIndices;
  }*/
	
	
	// MARK: Create Outline
	
	
	// MARK: - Line lookup
	
	
	func decrementLinePositions(from index:Int, amount amount:Int) {
		for i in index...<self.lines.count {
			Line* line = self.lines[i];
			line.position -= amount;
		}
	}
	func incrementLinePositions(from index:Int, amount:Int) {
		for i in index...<self.lines.count {
			Line* line = self.lines[i]
			line.position += amount
		}
	}

	
	func lineIndexAtPosition(position:UInt) -> UInt {
		var match:UInt = -1
		
		// Check for cached line
		if (lastEditedLine != nil) {
			if NSLocationInRange(position, line.range) {
				let i = self.lines.index(of: self.lastEditedLine)
				if (i != NSNotFound) {
					return i
				}
			}
		}
		
		for i in 0...<lines.count {
			let line:Line = self.lines[i]
			
			if NSLocationInRange(position, line.range) {
				return i
			}
		}
		
		return lines.count - 1
	}
	
	
}
