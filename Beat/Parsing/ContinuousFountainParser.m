//
//  ContinousFountainParser.m
//  Writer / Beat
//
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  Parts copyright © 2019-2020 Lauri-Matti Parppei. All rights reserved.

//  Relased under GPL

/*
 
 This code is still mostly based on Hendrik Noeller's work.
 It is heavily modified for Beat, and is more and more reliable.
 
 Main differences include:
 - double-checking for all-caps actions mistaken for character cues
 - delegation with the editor
 - title page parsing (mostly for preview & export purposes)
 - new data structure called OutlineScene, which contains scene name and length, as well as a reference to the original line
 - overall tweaks to parsing here and there
 - parsing large chunks of text is optimized 	
  
 
 Update 2021-something: COVID is still on, and this class has been improved a lot.
 
 Future considerations:
 - Make it possible to change editor text via text elements. This means making lines aware of their parser, and
   even tighter integration with the editor delegate.
 - Conform to Fountain note syntax
 
 */

#import "ContinuousFountainParser.h"
#import "RegExCategories.h"
#import "Line.h"
#import "NSString+CharacterControl.h"
#import "NSMutableIndexSet+Lowest.h"
#import "NSIndexSet+Subset.h"
#import "OutlineScene.h"
#import "BeatMeasure.h"

@implementation BeatScreenplay

+(instancetype)from:(ContinuousFountainParser*)parser {
	return [self from:parser settings:nil];
}
+(instancetype)from:(ContinuousFountainParser*)parser settings:(BeatExportSettings*)settings {
	BeatScreenplay *screenplay = BeatScreenplay.new;
	screenplay.titlePage = parser.titlePage;
	
	if (settings.printNotes) screenplay.lines = [parser preprocessForPrintingPrintNotes:YES];
	else screenplay.lines = parser.preprocessForPrinting;
	
	return screenplay;
}

@end

@interface ContinuousFountainParser ()
@property (nonatomic) BOOL changeInOutline;
@property (nonatomic) Line *editedLine;
@property (nonatomic) Line *lastEditedLine;
@property (nonatomic) NSUInteger lastLineIndex;
@property (nonatomic) NSUInteger editedIndex;

// Title page parsing
@property (nonatomic) NSString *openTitlePageKey;
@property (nonatomic) NSString *previousTitlePageKey;

// For initial loading
@property (nonatomic) NSInteger indicesToLoad;
@property (nonatomic) bool firstTime;

// For testing
@property (nonatomic) NSDate *executionTime;

@property (nonatomic) bool nonContinuous;

// Line cache
@property (nonatomic, weak) Line *prevLineAtLocation;

@end

@implementation ContinuousFountainParser

static NSDictionary* patterns;

#pragma mark - Parsing

#pragma mark Bulk Parsing

- (ContinuousFountainParser*)initStaticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings {
	return [self initWithString:string delegate:nil settings:settings nonContinuous:YES];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate nonContinuous:(bool)nonContinuous {
	return [self initWithString:string delegate:delegate settings:nil nonContinuous:nonContinuous];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate {
	return [self initWithString:string delegate:delegate settings:nil];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate settings:(BeatDocumentSettings*)settings {
	return [self initWithString:string delegate:delegate settings:settings nonContinuous:NO];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate settings:(BeatDocumentSettings*)settings nonContinuous:(bool)nonContinuous  {
	self = [super init];
	
	if (self) {
		_lines = NSMutableArray.array;
		_outline = NSMutableArray.array;
		_changedIndices = NSMutableIndexSet.indexSet;
		_titlePage = NSMutableArray.array;
		_storylines = NSMutableSet.set;
		_delegate = delegate;
		_nonContinuous = nonContinuous;
		_staticDocumentSettings = settings;
		 
		// Inform that this parser is STATIC and not continuous (wtf, why is this done using dual values?)
		if (_nonContinuous) _staticParser = YES;
		else _staticParser = NO;
		
		[self parseText:string];
	}
	
	return self;
}
- (ContinuousFountainParser*)initWithString:(NSString*)string
{
	return [self initWithString:string delegate:nil];
}

- (NSString*)screenplayForSaving {
	NSArray *lines = [NSArray arrayWithArray:self.lines];
	NSMutableString *content = [NSMutableString string];
	
	Line *previousLine;
	for (Line* line in lines) {
		if (!line) continue;
		
		NSString *string = line.string;
		LineType type = line.type;
		
		// Ensure correct whitespace before elements
		if ((line.type == character || line.type == heading) &&
			previousLine.string.length > 0) {
			[content appendString:@"\n"];
		}
		
		// Make some lines uppercase
		if ((type == heading || type == transitionLine) && line.numberOfPrecedingFormattingCharacters == 0) string = string.uppercaseString;
		
		[content appendString:string];
		if (line != self.lines.lastObject) [content appendString:@"\n"];
		
		previousLine = line;
	}

	return content;
}

- (void)parseText:(NSString*)text
{
	_firstTime = YES;
	
	_lines = [NSMutableArray array];
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
	_indicesToLoad = lines.count;
    
    NSUInteger position = 0; //To track at which position every line begins
	NSUInteger sceneIndex = -1;
	
	Line *previousLine;
	
    for (NSString *rawLine in lines) {
        NSInteger index = [self.lines count];
        Line* line = [[Line alloc] initWithString:rawLine position:position parser:self];
        [self parseTypeAndFormattingForLine:line atIndex:index];
		
		// Quick fix for mistaking an ALL CAPS action to character cue
		if (previousLine.type == character && (line.string.length < 1 || line.type == empty)) {
			previousLine.type = [self parseLineType:previousLine atIndex:index - 1 recursive:NO currentlyEditing:NO];
			if (previousLine.type == character) previousLine.type = action;
		}
		
		if (line.type == heading || line.type == synopse || line.type == section) {
			// A cloned version of the screenplay is used for preview & printing.
			// sceneIndex ensures we know which scene heading is which, even when there are hidden outline items.
			// This is used to jump into corresponding scenes from preview mode. There are smarter ways
			// to do this, but this is how it was done back in the day and still remains so.
			
			sceneIndex++;
			line.sceneIndex = sceneIndex;
		}
		
		// Quick fix for recognizing split paragraphs
        LineType currentType = line.type;
        if (line.type == action || line.type == lyrics || line.type == transitionLine) {
            if (previousLine.type == currentType && previousLine.string.length > 0) line.isSplitParagraph = YES;
        }
		
        //Add to lines array
        [self.lines addObject:line];
        //Mark change in buffered changes
		[self.changedIndices addIndex:index];
        
        position += [rawLine length] + 1; // +1 for newline character
		previousLine = line;
		_indicesToLoad--;
    }
	
	// Initial parse complete
	_indicesToLoad = -1;
	
    _changeInOutline = YES;
	[self createOutline];
	
	_firstTime = NO;
}

// This sets EVERY INDICE as changed.
- (void)resetParsing {
	NSInteger index = 0;
	while (index < self.lines.count) {
		[self.changedIndices addIndex:index];
		index++;
	}
}

#pragma mark - Continuous Parsing

/*
 
 Note for future me:
 
 I have somewhat revised the original parsing system, which parsed changes by
 always removing single characters in a loop, even with longer text blocks.
 
 I optimized the logic so that if the change includes full lines (either removed or added)
 they are removed or added as whole, rather than character-by-character. This is why
 there are two different methods for parsing the changes, and the other one is still used
 for parsing single-character edits. parseAddition/parseRemovalAt methods fall back to
 them when needed.

 Flow:
 parseChangeInRange ->
	parseAddition/parseRemoval
	-> changedIndices
	-> correctParsesInLines
		
 
 */

- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string
{
	if (range.location == NSNotFound) return; // This is for avoiding crashes when plugin developers are doing weird things
	
	_lastEditedLine = nil;
	_editedIndex = -1;

    NSMutableIndexSet *changedIndices = [[NSMutableIndexSet alloc] init];
    if (range.length == 0) { //Addition
		[changedIndices addIndexes:[self parseAddition:string atPosition:range.location]];
    } else if (string.length == 0) { //Removal
		[changedIndices addIndexes:[self parseRemovalAt:range]];
		
    } else { //Replacement
		//First remove
		[changedIndices addIndexes:[self parseRemovalAt:range]];
        // Then add
		[changedIndices addIndexes:[self parseAddition:string atPosition:range.location]];
    }
	    	
    [self correctParsesInLines:changedIndices];
}

- (void)ensurePositions {
	// This is a method to fix anything that might get broken :-)
	// Use only when debugging.

	NSInteger previousPosition = 0;
	NSInteger previousLength = 0;
	NSInteger offset = 0;
	
	bool fixed = NO;
	
	for (Line * line in self.lines) {
		if (line.position > previousPosition + previousLength + offset && !fixed) {
			NSLog(@"🔴 [FIXING] %lu-%lu   %@", line.position, line.string.length, line.string);
			offset -= line.position - (previousPosition + previousLength);
			fixed = YES;
		}
		
		line.position += offset;
				
		previousLength = line.string.length + 1;
		previousPosition = line.position;
	}
}

- (NSIndexSet*)parseAddition:(NSString*)string  atPosition:(NSUInteger)position
{
	NSMutableIndexSet *changedIndices = [NSMutableIndexSet indexSet];
	
	// Get the line where into which we are adding characters
	NSUInteger lineIndex = [self lineIndexAtPosition:position];
	Line* line = self.lines[lineIndex];
	if (line.type == heading || line.type == synopse || line.type == section) _changeInOutline = YES;
	
	NSUInteger indexInLine = position - line.position;
	
	// If the added string is a multi-line block, we need to optimize the addition.
	// Else, just parse it character-by-character.
	if ([string containsString:@"\n"] && string.length > 1) {
		// Split the original line into two
		NSString *head = [line.string substringToIndex:indexInLine];
		NSString *tail = (indexInLine + 1 <= line.string.length) ? [line.string substringFromIndex:indexInLine] : @"";
		 
		// Split the text block into pieces
		NSArray *newLines = [string componentsSeparatedByString:@"\n"];
		
		// Add the first line
		[changedIndices addIndex:lineIndex];

		NSInteger offset = line.position;

		[self decrementLinePositionsFromIndex:lineIndex + 1 amount:tail.length];
				
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
}

- (void)report {
	NSInteger lastPos = 0;
	NSInteger lastLen = 0;
	for (Line* line in self.lines) {
		NSString *error = @"";
		if (lastPos + lastLen != line.position) error = @" 🔴 ERROR";
		
		if (error.length > 0) {
			NSLog(@"   (%lu -> %lu): %@ (%lu) %@ (%lu/%lu)", line.position, line.position + line.string.length + 1, line.string, line.string.length, error, lastPos, lastLen);
		}
		lastLen = line.string.length + 1;
		lastPos = line.position;
	}
}

- (NSIndexSet*)parseCharacterAdded:(NSString*)character atPosition:(NSUInteger)position line:(Line*)line
{
	NSUInteger lineIndex = _editedIndex;

    NSUInteger indexInLine = position - line.position;
	
	if (line.type == heading || line.type == synopse || line.type == section) _changeInOutline = true;
	
    if ([character isEqualToString:@"\n"]) {
        NSString* cutOffString;
        // Split the edited line in two if needed
		if (indexInLine == line.string.length) {
			// Return key was pressed at the end of line
            cutOffString = @"";
        } else {
			// Line break mid-line, split in two
            cutOffString = [line.string substringFromIndex:indexInLine];
            line.string = [line.string substringToIndex:indexInLine];
        }
        
		// Create the new line
		// NOTE TO SELF: It would be preferrable to create one reliable method of adding
		// a string into the parser. This is now a mess with pretty obfuscated code here and there.
        Line* newLine = [[Line alloc] initWithString:cutOffString
                                            position:position+1
											  parser:self];
        
		// Add line into place and increment positions
		[self.lines insertObject:newLine atIndex:lineIndex+1];
        [self incrementLinePositionsFromIndex:lineIndex+2 amount:1];
        
        return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lineIndex, 2)];
    } else {
		// Add characters into the string
        NSArray* pieces = @[[line.string substringToIndex:indexInLine],
                            character,
                            [line.string substringFromIndex:indexInLine]];
		
        line.string = [pieces componentsJoinedByString:@""];
        [self incrementLinePositionsFromIndex:lineIndex+1 amount:1];
        
        return [[NSIndexSet alloc] initWithIndex:lineIndex];
        
    }
}

// Return the whole document as single string
- (NSString*)rawText {
	NSMutableString *string = [NSMutableString string];
	for (Line* line in self.lines) {
		if (line != self.lines.lastObject) [string appendFormat:@"%@\n", line.string];
		else [string appendFormat:@"%@", line.string];
	}
	return string;
}

- (NSIndexSet*)parseRemovalAt:(NSRange)range {
	NSMutableIndexSet *changedIndices = [[NSMutableIndexSet alloc] init];
	
	NSString *stringToRemove = [self.rawText substringWithRange:range];
	NSInteger lineBreaks = [stringToRemove componentsSeparatedByString:@"\n"].count - 1;
	
	if (lineBreaks > 1) {
		// If there are 2+ line breaks, optimize the operation
		NSInteger lineIndex = [self lineIndexAtPosition:range.location];
		Line *firstLine = self.lines[lineIndex];
				
		// Change in outline
		if (firstLine.type == heading || firstLine.type == section || firstLine.type == synopse) _changeInOutline = YES;
		
		NSUInteger indexInLine = range.location - firstLine.position;
		
		NSString *retain = (firstLine.string.length) ? [firstLine.string substringToIndex:indexInLine] : @"";
		NSInteger nextIndex = lineIndex + 1;
				
		// +1 for line break
		NSInteger offset = firstLine.string.length - retain.length + 1;
		
		for (NSInteger i = 1; i <= lineBreaks; i++) {
			Line* nextLine = self.lines[nextIndex];
						
			if (nextLine.type == heading || nextLine.type == section || nextLine.type == synopse) {
				_changeInOutline = YES;
			}
			
			if (i < lineBreaks) {
				[self.lines removeObjectAtIndex:nextIndex];
				offset += nextLine.string.length + 1;
			} else {
				// This is the last line in the array
				NSInteger indexInNextLine = range.location + range.length - nextLine.position;
				
				NSInteger nextLineLength = nextLine.string.length - indexInNextLine;
				
				NSString *nextLineString;
				
				if (indexInNextLine + nextLineLength > 0) {
					nextLineString = [nextLine.string substringWithRange:NSMakeRange(indexInNextLine, nextLineLength)];
				} else {
					nextLineString = @"";
				}
				
				firstLine.string = [retain stringByAppendingString:nextLineString];
				
				// Remove the last line
				[self.lines removeObjectAtIndex:nextIndex];
				offset += indexInNextLine;
			}
		}
		[self decrementLinePositionsFromIndex:nextIndex amount:offset];
										
		[changedIndices addIndex:lineIndex];
	} else {
		// Do it normally...
		
		// Set the currently edited line index
		if (_editedIndex >= self.lines.count || _editedIndex < 0) {
			_editedIndex = [self lineIndexAtPosition:range.location];
		}
		
		// Cache previous version of the string
		Line* line = self.lines[_editedIndex];
		
		// Parse removal character by character
		for (int i = 0; i < range.length; i++) {
			[changedIndices addIndexes:[self parseCharacterRemovedAtPosition:range.location line:line]];
		}
		
		if ([stringToRemove isEqualToString:@"\n"]) {
			// Parse previous line again too, because removing a line break can cause
			// some elements change their type.
			NSInteger lineIndex = [self lineIndexAtPosition:range.location];
			[changedIndices addIndex:lineIndex - 1];
		}
	}
	
	[self report];
	
	return changedIndices;
}
- (NSIndexSet*)parseCharacterRemovedAtPosition:(NSUInteger)position line:(Line*)line
{
	/*
	 
	 When less than one line is removed, we'll parse it character by character
	 in this method.  lineIndex is cached so we don't have to find current
	 line on every call.
	 
	 */
		
	NSUInteger indexInLine = position - line.position;
	NSUInteger lineIndex = _editedIndex;

	if (indexInLine > line.string.length) indexInLine = line.string.length;
	
    if (indexInLine == line.string.length) {
        if (lineIndex == self.lines.count - 1) {
            return nil; //Removed newline at end of document without there being an empty line - should never happen but to be sure...
        }
		
		// Find the next line and join it with current line
        Line* nextLine = self.lines[lineIndex+1];
        line.string = [line.string stringByAppendingString:nextLine.string];
        		
        [self.lines removeObjectAtIndex:lineIndex+1];
        [self decrementLinePositionsFromIndex:lineIndex+1 amount:1];
        		
		if (nextLine.isOutlineElement) _changeInOutline = YES;
		
		if (nextLine.type == empty &&  lineIndex + 1 < self.lines.count) {
			// An empty line was removed, which might affect parsing of follow elements, so
			// let's be sure to parse whatever comes after the deleted line.
			return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lineIndex, 2)];
		} else {
			return [NSIndexSet indexSetWithIndex:lineIndex];
		}
		
    } else {
        NSArray* pieces = @[[line.string substringToIndex:indexInLine],
                            [line.string substringFromIndex:indexInLine + 1]];
        
        line.string = [pieces componentsJoinedByString:@""];
        [self decrementLinePositionsFromIndex:lineIndex+1 amount:1];
        
        return [[NSIndexSet alloc] initWithIndex:lineIndex];
    }
}

- (NSUInteger)outlineIndexAtLineIndex:(NSUInteger)index {
	NSUInteger outlineIndex = -1;
	
	NSArray *lines = self.safeLines;
	
	for (NSInteger i=0; i<lines.count; i++) {
		Line *l = lines[i];
		if (l.isOutlineElement) outlineIndex++;
		if (i == index) return outlineIndex;
	}
	
	return 0;
}

- (NSUInteger)lineIndexAtPosition:(NSUInteger)position
{
	// Hey, past me. I rewrote this in 1.929, because the previous iteration didn't seem to actually work.
	
	// First check if we are still on the cached line
	if (_lastEditedLine) {
		if (NSLocationInRange(position, _lastEditedLine.range)) {
			return _lastLineIndex;
		}
	}
	
	// Else just iterate through lines and cache the result
    for (int i = 0; i < self.lines.count; i++) {
        Line* line = self.lines[i];
        
        if (NSLocationInRange(position, line.range)) {
			_lastEditedLine = line;
			_lastLineIndex = i;
            return i;
        }
    }
	
	// Return last line
    return self.lines.count - 1;
}

- (void)incrementLinePositionsFromIndex:(NSUInteger)index amount:(NSUInteger)amount
{
    for (; index < [self.lines count]; index++) {
        Line* line = self.lines[index];
        
        line.position += amount;
    }
}

- (void)decrementLinePositionsFromIndex:(NSUInteger)index amount:(NSUInteger)amount
{
    for (; index < [self.lines count]; index++) {
        Line* line = self.lines[index];
        line.position -= amount;
    }
}

- (void)correctParsesForLines:(NSArray *)lines
{
	// Intermediate method for getting indices for line objects
	NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
	
	for (Line* line in lines) {
		NSInteger i = [lines indexOfObject:line];
		if (i != NSNotFound) [indices addIndex:i];
	}
	
	[self correctParsesInLines:indices];
}
- (void)correctParsesInLines:(NSMutableIndexSet*)lineIndices
{
    while (lineIndices.count > 0) {
        [self correctParseInLine:lineIndices.lowestIndex indicesToDo:lineIndices];
    }
}

- (NSInteger)indexOfNoteOpen:(Line*)line {
	unichar string[line.string.length];
	[line.string getCharacters:string];
	
	NSInteger lastIndex = 1;
	NSInteger rangeBegin = -1;
	for (int i = (int)line.length;;i--) {
		if (i > lastIndex) break;
		
		if ((string[i] == '[' && string[i-1] == '[')) {
			rangeBegin = i;
			break;
		}
	}
	
	if (rangeBegin >= 0) return rangeBegin;
	else return NSNotFound;
}

- (NSIndexSet*)terminateNoteBlockAt:(Line*)line  {
	NSInteger i = [self.lines indexOfObject:line];
	return [self terminateNoteBlockAt:line index:i];
}
- (NSIndexSet*)terminateNoteBlockAt:(Line*)line index:(NSInteger)idx {
	NSMutableIndexSet *changedIndices = [NSMutableIndexSet indexSetWithIndex:idx];
	if (idx == NSNotFound) return changedIndices;
	
	if (idx == 0) {
		// This is the first line, can't terminate a note block
		return changedIndices;
	} else {
		Line *prevLine = self.lines[idx - 1];
		// This line doesn't have a preceeding note block, ignore
		if (!prevLine.noteOut || prevLine.length == 0) return changedIndices;
	}
	
	[line.noteRanges addIndexes:line.noteInIndices];
		
	for (NSInteger i = idx-1; i >= 0; i--) {
		Line *l = self.lines[i];
		
		if ([l.string containsString:@"[["]) {
			[l.noteRanges addIndexes:l.noteOutIndices];
			[changedIndices addIndex:i];
			break;
		} else {
			[l.noteRanges addIndexesInRange:(NSRange){ 0, l.string.length }];
			[changedIndices addIndex:i];
		}
	}
	
	[_changedIndices addIndexes:changedIndices];
	
	return changedIndices;
}

- (NSIndexSet*)cancelNoteBlockAt:(Line*)line {
	return [self cancelNoteBlockAt:line index:[self.lines indexOfObject:line]];
}

- (NSIndexSet*)cancelNoteBlockAt:(Line*)line index:(NSInteger)idx {
	NSMutableIndexSet *changedIndices = [NSMutableIndexSet indexSet];
	if (idx == NSNotFound) return changedIndices;
	
	//if (!self.staticParser) NSLog(@"   ---> cancel at %@", line);
	
	Line *prevLine = [self previousLine:line];
	
	line.noteOut = NO;
	bool actuallyCancelsBlock = NO; // If the block was previously ACTUALLY formatted as a block
	if (prevLine.noteOut) {
		//NSLog(@"!!! Note out from %@", prevLine);
		actuallyCancelsBlock = YES;
	}
	
	// Look behind for note ranges
	for (NSInteger i = idx-1; i >= 0; i--) {
		Line *l = self.lines[i];
		
		if ([l.string containsString:@"[["]) {
			//if (!self.staticParser) NSLog(@"  ... %@", l);
			[l.noteRanges removeIndexes:l.noteOutIndices];
			[changedIndices addIndex:i];
			break;
		} else {
			[l.noteRanges removeIndexesInRange:(NSRange){ 0, l.string.length }];
			[changedIndices addIndex:i];
		}
	}
		
	// Don't look forward if the current line had no note ranges to begin with.
	if (!line.noteRanges.count && !actuallyCancelsBlock) {
		//if (!self.staticParser) NSLog(@"   ..not looking forward");
		return changedIndices;
	}

	// Look forward for note ranges
	for (NSInteger i = idx; i < self.lines.count; i++) {
		Line *l = self.lines[i];
		//if (!self.staticParser) NSLog(@"looking at %@", l);
		
		if ([l.string containsString:@"]]"] ||
			[l.string containsString:@"[["] // Another note begins, don't look further
			) {
			[l.noteRanges removeIndexes:l.noteInIndices];
			[changedIndices addIndex:i];
			break;
		} else {
			[l.noteRanges removeIndexesInRange:(NSRange){ 0, l.string.length }];
			[changedIndices addIndex:i];
		}
	}

	
	[_changedIndices addIndexes:changedIndices];
	
	return changedIndices;
}

- (void)listLines {
	for (Line* line in _lines) {
		printf("%s\n", line.string.UTF8String);
		printf("	noteIn: %s\n", (line.noteIn) ? "YES" : "NO" );
		printf("	noteOut: %s\n", (line.noteOut) ? "YES" : "NO" );
	}
}

- (void)correctParseInLine:(NSUInteger)index indicesToDo:(NSMutableIndexSet*)indices
{
	// Do nothing if we went out of range.
	// Note: for code convenience and clarity, some methods can ask to reformat lineIndex-2 etc.,
	// so this check is needed. 
	if (index < 0 || index == NSNotFound || index >= self.lines.count) {
		[indices removeIndex:index];
		return;
	}
	
	bool lastToParse = YES;
	if (indices.count) lastToParse = NO;
	  
	Line* currentLine = self.lines[index];
	
    //Remove index as done from array if in array
    if (indices.count) {
        NSUInteger lowestToDo = indices.lowestIndex;
        if (lowestToDo == index) {
            [indices removeIndex:index];
        }
    }
		
	//Correct type on this line
    LineType oldType = currentLine.type;
    bool oldOmitOut = currentLine.omitOut;
	bool oldNoteOut = currentLine.noteOut;
	bool oldEndsNoteBlock = currentLine.endsNoteBlock;
	bool oldNoteTermination = currentLine.cancelsNoteBlock;
	bool notesNeedParsing = NO;
	
    [self parseTypeAndFormattingForLine:currentLine atIndex:index];
    
    if (!self.changeInOutline &&
		(oldType == heading || oldType == section || oldType == synopse || currentLine.type == heading || currentLine.type == section || currentLine.type == synopse || currentLine.beats.count)) {
        self.changeInOutline = YES;
    }
    
    [self.changedIndices addIndex:index];
	
	if (currentLine.type == dialogue && currentLine.string.length == 0 && indices.count > 1 && index > 0) {
		// Check for all-caps action lines mistaken for character cues in a pasted text
		Line *previousLine = self.lines[index - 1];
		previousLine.type = action;
		currentLine.type = empty;
		[_changedIndices addIndex:index - 1];
	}
	
	// Parse multi-line note ranges
	// This is a mess, and written using trial & error. Dread lightly.
		
	if (currentLine.endsNoteBlock != oldEndsNoteBlock) {
		// A note block which was previously terminated, is no longer that
		if (!currentLine.endsNoteBlock && currentLine.noteIn) currentLine.noteOut = YES;
		else if (currentLine.endsNoteBlock && currentLine.noteIn) currentLine.noteOut = NO;
		notesNeedParsing = YES;
	}
	
	if (currentLine.noteIn && (currentLine.type == empty || currentLine == _lines.lastObject)) {
		// Empty (or last) line automatically cancels a note block
		currentLine.cancelsNoteBlock = YES;
		NSIndexSet *noteIndices = [self cancelNoteBlockAt:currentLine];
		[self.changedIndices addIndexes:noteIndices];
	}
	else if (currentLine.noteOut) {
		// Something else was changed and note spills out of the block, so we need to reparse the whole block
		for (NSInteger ni = [self.lines indexOfObject:currentLine]; ni<self.lines.count; ni++) {
			Line *nextLine = self.lines[ni];
			if (nextLine.noteIn && [nextLine.string containsString:@"]]"]) {
				NSIndexSet *noteIndices = [self terminateNoteBlockAt:nextLine];
				[self.changedIndices addIndexes:noteIndices];
				break;
			}
			else if (nextLine.type == empty) {
				[self.changedIndices addIndexes:[self cancelNoteBlockAt:nextLine]];
				break;
			}
		}
		notesNeedParsing = YES;
	}
	else if (currentLine.noteOut != oldNoteOut && !currentLine.noteOut) {
		// Note no longer bleeds out of this line
		for (NSInteger ni = [self.lines indexOfObject:currentLine] + 1; ni < self.lines.count; ni++) {
			Line *nextLine = self.lines[ni];
			if (nextLine.noteIn && [nextLine.string containsString:@"]]"]) {
				NSIndexSet *noteIndices = [self cancelNoteBlockAt:nextLine];
				[self.changedIndices addIndexes:noteIndices];
				break;
			}
			else if (!nextLine.noteIn) break;
		}
	}
	
	if (currentLine.noteIn && [currentLine.string containsString:@"]]"] && [self.lines indexOfObject:currentLine] > 0) {
		// This line potentially terminates a note block
		NSIndexSet *noteIndices = [self terminateNoteBlockAt:currentLine];
		[self.changedIndices addIndexes:noteIndices];
	}
	
	//If there is a next element, check if it might need a reparse because of a change in type or omit out
	if (oldType != currentLine.type || oldOmitOut != currentLine.omitOut || lastToParse) {
        if (index < self.lines.count - 1) {
            Line* nextLine = self.lines[index+1];
			if (currentLine.isTitlePage ||					// if line is a title page, parse next line too
                currentLine.type == section ||
                currentLine.type == synopse ||
				currentLine.type == character ||        					    //if the line became anything to
                currentLine.type == parenthetical ||        					//do with dialogue, it might cause
                (currentLine.type == dialogue && nextLine.type != empty) ||     //the next lines to be dialogue
                currentLine.type == dualDialogueCharacter ||
                currentLine.type == dualDialogueParenthetical ||
                currentLine.type == dualDialogue ||
                currentLine.type == empty ||                //If the line became empty, it might
                                                            //enable the next on to be a heading
                                                            //or character
                
                nextLine.type == titlePageTitle ||          //if the next line is a title page,
                nextLine.type == titlePageCredit ||         //it might not be anymore
                nextLine.type == titlePageAuthor ||
                nextLine.type == titlePageDraftDate ||
                nextLine.type == titlePageContact ||
                nextLine.type == titlePageSource ||
                nextLine.type == titlePageUnknown ||
                nextLine.type == section ||
                nextLine.type == synopse ||
                nextLine.type == heading ||                 //If the next line is a heading or
                nextLine.type == character ||               //character or anything dialogue
                nextLine.type == dualDialogueCharacter || //related, it might not be anymore
                nextLine.type == parenthetical ||
                nextLine.type == dialogue ||
                nextLine.type == dualDialogueParenthetical ||
                nextLine.type == dualDialogue ||
				
				// Look for unterminated omits & notes
				nextLine.omitIn != currentLine.omitOut ||
				nextLine.noteIn != currentLine.noteOut ||
				currentLine.noteOut != oldNoteOut ||
				currentLine.cancelsNoteBlock != oldNoteTermination ||
				notesNeedParsing ||
				currentLine.endsNoteBlock != oldEndsNoteBlock
				) {

                [self correctParseInLine:index+1 indicesToDo:indices];
            }
        }
    }
}


#pragma mark Parsing Core

#define BOLD_PATTERN "**"
#define ITALIC_PATTERN "*"
#define UNDERLINE_PATTERN "_"
#define NOTE_OPEN_PATTERN "[["
#define NOTE_CLOSE_PATTERN "]]"
#define OMIT_OPEN_PATTERN "/*"
#define OMIT_CLOSE_PATTERN "*/"

#define HIGHLIGHT_OPEN_PATTERN "<<"
#define HIGHLIGHT_CLOSE_PATTERN ">>"
#define STRIKEOUT_OPEN_PATTERN "{{"
#define STRIKEOUT_CLOSE_PATTERN "}}"

#define BOLD_PATTERN_LENGTH 2
#define ITALIC_PATTERN_LENGTH 1
#define UNDERLINE_PATTERN_LENGTH 1
#define NOTE_PATTERN_LENGTH 2
#define OMIT_PATTERN_LENGTH 2
#define HIGHLIGHT_PATTERN_LENGTH 2
#define STRIKEOUT_PATTERN_LENGTH 2

#define COLOR_PATTERN "color"
#define STORYLINE_PATTERN "storyline"

- (void)parseTypeAndFormattingForLine:(Line*)line atIndex:(NSUInteger)index
{
	// Type and formatting are parsed by iterating through character arrays.
	// Using regexes would be much easier, but also about 10 times more costly in CPU time.
	
    line.type = [self parseLineType:line atIndex:index];
	
    NSUInteger length = line.string.length;
    unichar charArray[length];
    [line.string getCharacters:charArray];
    
	// Omits have stars in them, which can be mistaken for formatting characters.
	// We store the omit asterisks into the "excluded" index set to avoid this mixup.
    NSMutableIndexSet* excluded = [[NSMutableIndexSet alloc] init];
	
	// First, we handle notes and omits, which can bleed over multiple lines.
	// The cryptically named omitOut and noteOut mean that the line bleeds an omit out,
	// while omitIn and noteIn tell that they are part of a larger omitted/note block.
    if (index == 0) {
        line.omittedRanges = [self rangesOfOmitChars:charArray
											ofLength:length
											  inLine:line
									 lastLineOmitOut:NO
										 saveStarsIn:excluded];
		
		line.noteRanges = [self noteRanges:charArray
										 ofLength:length
										   inLine:line
									  partOfBlock:NO];
    } else {
        Line* previousLine = self.lines[index-1];
		line.omittedRanges = [self rangesOfOmitChars:charArray
											ofLength:length
											  inLine:line
									 lastLineOmitOut:previousLine.omitOut
										 saveStarsIn:excluded];
		
		line.noteRanges = [self noteRanges:charArray
								  ofLength:length
									inLine:line
							   partOfBlock:previousLine.noteOut];
	}
    
	line.escapeRanges = [NSMutableIndexSet indexSet];

    line.boldRanges = [self rangesInChars:charArray
                                 ofLength:length
                                  between:BOLD_PATTERN
                                      and:BOLD_PATTERN
                               withLength:BOLD_PATTERN_LENGTH
                         excludingIndices:excluded
									 line:line];
	
    line.italicRanges = [self rangesInChars:charArray
                                   ofLength:length
                                    between:ITALIC_PATTERN
                                        and:ITALIC_PATTERN
                                 withLength:ITALIC_PATTERN_LENGTH
                           excludingIndices:excluded
									   line:line];
    line.underlinedRanges = [self rangesInChars:charArray
                                       ofLength:length
                                        between:UNDERLINE_PATTERN
                                            and:UNDERLINE_PATTERN
                                     withLength:UNDERLINE_PATTERN_LENGTH
                               excludingIndices:nil
										   line:line];
	
	line.strikeoutRanges = [self rangesInChars:charArray
								 ofLength:length
								  between:STRIKEOUT_OPEN_PATTERN
									  and:STRIKEOUT_CLOSE_PATTERN
							   withLength:STRIKEOUT_PATTERN_LENGTH
						 excludingIndices:nil
										line:line];
	
	// Intersecting indices between bold & italic are boldItalic
	if (line.boldRanges.count && line.italicRanges.count) line.boldItalicRanges = [line.italicRanges indexesIntersectingIndexSet:line.boldRanges].mutableCopy;
	else line.boldItalicRanges = [NSMutableIndexSet indexSet];
	
    if (line.type == heading) {
		line.sceneNumberRange = [self sceneNumberForChars:charArray ofLength:length];
        
		if (line.sceneNumberRange.length == 0) {
            line.sceneNumber = nil;
        } else {
            line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
        }
    }
	
	// set color for outline elements
	if (line.type == heading || line.type == section || line.type == synopse) {
		line.color = [self colorForHeading:line];
	}
	
	// Markers
	line.marker = [self markerForLine:line];
	
	// Beats
	line.beatRanges = NSMutableIndexSet.indexSet;
	NSArray *beats = [self beatsFor:line];
	NSArray *storylines = [self storylinesFor:line]; // Include storylines for backwards-compatibility
	line.beats = [beats arrayByAddingObjectsFromArray:storylines];
	
	
	if (line.isTitlePage) {
		if ([line.string containsString:@":"] && line.string.length > 0) {
			// If the title doesn't begin with \t or space, format it as key name	
			if ([line.string characterAtIndex:0] != ' ' &&
				[line.string characterAtIndex:0] != '\t' ) line.titleRange = NSMakeRange(0, [line.string rangeOfString:@":"].location + 1);
			else line.titleRange = NSMakeRange(0, 0);
		}
	}
	
	// Multiline block parsing
	// There's no index for this line yet, so let's just pass on the count of lines as index
	if (line.noteIn) {
		NSInteger lineIdx = [self.lines indexOfObject:line];
		if (lineIdx == NSNotFound) lineIdx = self.lines.count;
		
		if ([line.string containsString:@"]]"]) {
			[self terminateNoteBlockAt:line index:lineIdx];
		}
		else if (line.type == empty) {
			[self cancelNoteBlockAt:line index:lineIdx];
			line.noteOut = NO;
		}
	}
}

/*

Update 2020-08:
The recursive madness I built should be dismantled and replaced with delegation.

An example of a clean and nice delegate method can be seen when handling scene headings,
and the same logic should apply everywhere: Oh, an empty line: Did we parse the line before
as a character cue, well, let's not, and then send that information to the UI side of things.

It might be slightly less optimal in some cases, but would save us from this terrible, terrible
and incomprehensible system of recursion.

*/


- (LineType)parseLineType:(Line*)line atIndex:(NSUInteger)index
{
	return [self parseLineType:line atIndex:index recursive:NO currentlyEditing:NO];
}

- (LineType)parseLineType:(Line*)line atIndex:(NSUInteger)index recursive:(bool)recursive
{
	return [self parseLineType:line atIndex:index recursive:recursive currentlyEditing:NO];
}

- (LineType)parseLineType:(Line*)line atIndex:(NSUInteger)index currentlyEditing:(bool)currentLine {
	return [self parseLineType:line atIndex:index recursive:NO currentlyEditing:currentLine];
}

- (LineType)parseLineType:(Line*)line atIndex:(NSUInteger)index recursive:(bool)recursive currentlyEditing:(bool)currentLine
{
    NSString* string = line.string;
    NSUInteger length = [string length];
	NSString* trimmedString = [line.string stringByTrimmingTrailingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	Line* precedingLine = (index == 0) ? nil : (Line*) self.lines[index-1];
	
	// So we need to pull all sorts of tricks out of our sleeve here.
	// Usually Fountain files are parsed from bottom to up, but here we are parsing in a linear manner.
	// I have no idea how I got this to work but it does.

	// Check if this line was forced to become a character cue
	if (line.forcedCharacterCue) {
		line.forcedCharacterCue = NO;
		if (line.lastCharacter == '^') return dualDialogueCharacter;
		else return character;
	}
	
	// Check for all-caps actions mistaken for character cues
	if (self.delegate && NSThread.isMainThread) {
		if (precedingLine.string.length == 0 &&
			NSLocationInRange(self.delegate.selectedRange.location + 1, line.range)) {
			// If the preceeding line is empty, we'll check the line before that, too, to be sure.
			// This way we can check for false character cues
			if (index > 1) {
				Line* lineBeforeThat = (Line*)self.lines[index - 2];
				if (lineBeforeThat.type == character) {
					lineBeforeThat.type = action;
					precedingLine.type = action;
					[self.changedIndices addIndex:index - 1];
					[self.changedIndices addIndex:index - 2];
				}
			}
		}
	}
	
    // Check if empty.
    if (length == 0) {
		// If previous line is part of dialogue block, this line becomes dialogue right away
		// Else it's just empty.
		if (precedingLine.type == character || precedingLine.type == parenthetical || precedingLine.type == dialogue) {
			// If preceeding line is formatted as dialogue BUT it's empty, we'll just return empty.
			if (precedingLine.string.length > 0) {
				// If preceeded by character cue, return dialogue
				if (precedingLine.type == character) return dialogue;
				// If its a parenthetical line, return dialogue
				else if (precedingLine.type == parenthetical) return dialogue;
				// AND if its just dialogue, return action.
				else return action;
			} else {
//				precedingLine.type = empty;
//				[self.changedIndices addIndex:index - 1];
				return empty;
			}
		} else {
			return empty;
		}
    }
	
    char firstChar = [string characterAtIndex:0];
    char lastChar = [string characterAtIndex:length-1];
    
    bool containsOnlyWhitespace = string.containsOnlyWhitespace; // Save to use again later
    bool twoSpaces = (firstChar == ' ' && lastChar == ' '); // Contains at least two spaces
    //If not empty, check if contains only whitespace. Exception: two spaces indicate a continued whatever, so keep them
    if (containsOnlyWhitespace && !twoSpaces) {
        return empty;
	}
	// I don't know why this is needed and the previous doesn't catch this?
	if (containsOnlyWhitespace && firstChar == ' ' && line.length == 1) {
		return empty;
	}
	
	// Reset to zero to avoid strange formatting issues
	line.numberOfPrecedingFormattingCharacters = 0;
	
    //Check for forces (the first character can force a line type)
    if (firstChar == '!') {
        line.numberOfPrecedingFormattingCharacters = 1;
        return action;
    }
    if (firstChar == '@') {
        line.numberOfPrecedingFormattingCharacters = 1;
        return character;
    }
    if (firstChar == '~') {
        line.numberOfPrecedingFormattingCharacters = 1;
        return lyrics;
    }
    if (firstChar == '>' && lastChar != '<') {
        line.numberOfPrecedingFormattingCharacters = 1;
        return transitionLine;
    }
	if (firstChar == '>' && lastChar == '<') {
        //line.numberOfPreceedingFormattingCharacters = 1;
        return centered;
    }
    if (firstChar == '#') {
		// Thanks, Jacob Relkin
		NSUInteger len = [string length];
		NSInteger depth = 0;

		char character;
		for (int c = 0; c < len; c++) {
			character = [string characterAtIndex:c];
			if (character == '#') depth++; else break;
		}
		
		line.sectionDepth = depth;
		line.numberOfPrecedingFormattingCharacters = depth;
        return section;
    }
    if (firstChar == '=' && (length >= 2 ? [string characterAtIndex:1] != '=' : YES)) {
        line.numberOfPrecedingFormattingCharacters = 1;
        return synopse;
    }
	
	// '.' forces a heading. Because our American friends love to shoot their guns like we Finnish people love our booze, screenwriters might start dialogue blocks with such "words" as '.44'
	// So, let's NOT return a scene heading IF the previous line is not empty OR is a character OR is a parenthetical AND is not an omit in...
    if (firstChar == '.' && length >= 2 && [string characterAtIndex:1] != '.') {
		if (precedingLine) {
			if (precedingLine.type == character) return dialogue;
			else if (precedingLine.type == parenthetical) return dialogue;
			else if (precedingLine.string.length > 0 && ![precedingLine.trimmed isEqualToString:@"/*"]) return action;
		}
		
		line.numberOfPrecedingFormattingCharacters = 1;
		return heading;
    }
		
    //Check for scene headings (lines beginning with "INT", "EXT", "EST",  "I/E"). "INT./EXT" and "INT/EXT" are also inside the spec, but already covered by "INT".
	if (precedingLine.type == empty ||
		precedingLine.string.length == 0 ||
		line.position == 0 ||
		[precedingLine.trimmed isEqualToString:@"*/"] ||
		[precedingLine.trimmed isEqualToString:@"/*"] ||
		(precedingLine.type == synopse || precedingLine.type == section)) {
        if (length >= 3) {
            NSString* firstChars = [[string substringToIndex:3] lowercaseString];
			
            if ([firstChars isEqualToString:@"int"] ||
                [firstChars isEqualToString:@"ext"] ||
                [firstChars isEqualToString:@"est"] ||
                [firstChars isEqualToString:@"i/e"]) {
				
				// If it's just under 4 characters, return heading
				if (length < 4) return heading;
				else {
					char nextChar = [string characterAtIndex:3];
					if (nextChar == '.' || nextChar == ' ' || nextChar == '/') {
						// Line begins with int. or ext. etc.
						return heading;
					}
				}
            }
        }
    }
	
	//Check for title page elements. A title page element starts with "Title:", "Credit:", "Author:", "Draft date:" or "Contact:"
	//it has to be either the first line or only be preceeded by title page elements.
	if (!precedingLine ||
		precedingLine.type == titlePageTitle ||
		precedingLine.type == titlePageAuthor ||
		precedingLine.type == titlePageCredit ||
		precedingLine.type == titlePageSource ||
		precedingLine.type == titlePageContact ||
		precedingLine.type == titlePageDraftDate ||
		precedingLine.type == titlePageUnknown) {
		
		//Check for title page key: value pairs
		// - search for ":"
		// - extract key
		NSRange firstColonRange = [string rangeOfString:@":"];
		
		if (firstColonRange.length != 0 && firstColonRange.location != 0) {
			NSUInteger firstColonIndex = firstColonRange.location;
			
			NSString* key = [[string substringToIndex:firstColonIndex] lowercaseString];
			
			NSString* value = @"";
			// Trim the value
			if (string.length > firstColonIndex + 1) value = [string substringFromIndex:firstColonIndex + 1];
			value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
			
			// Store title page data
			NSDictionary *titlePageData = @{ key: [NSMutableArray arrayWithObject:value] };
			[_titlePage addObject:titlePageData];
			
			// Set this key as open (in case there are additional title page lines)
			_openTitlePageKey = key;
			
			if ([key isEqualToString:@"title"]) {
				return titlePageTitle;
			} else if ([key isEqualToString:@"author"] || [key isEqualToString:@"authors"]) {
				return titlePageAuthor;
			} else if ([key isEqualToString:@"credit"]) {
				return titlePageCredit;
			} else if ([key isEqualToString:@"source"]) {
				return titlePageSource;
			} else if ([key isEqualToString:@"contact"]) {
				return titlePageContact;
			} else if ([key isEqualToString:@"contacts"]) {
				return titlePageContact;
			} else if ([key isEqualToString:@"contact info"]) {
				return titlePageContact;
			} else if ([key isEqualToString:@"draft date"]) {
				return titlePageDraftDate;
			} else {
				return titlePageUnknown;
			}
		} else {
			// This is an additional line
			/*
			 if (length >= 2 && [[string substringToIndex:2] isEqualToString:@"  "]) {
			 line.numberOfPreceedingFormattingCharacters = 2;
			 return precedingLine.type;
			 } else if (length >= 1 && [[string substringToIndex:1] isEqualToString:@"\t"]) {
			 line.numberOfPreceedingFormattingCharacters = 1;
			 return precedingLine.type;
			 } */
			if (_openTitlePageKey) {
				NSMutableDictionary* dict = [_titlePage lastObject];
				[(NSMutableArray*)dict[_openTitlePageKey] addObject:line.string];
			}
			
			return precedingLine.type;
		}
		
	}
	    
    //Check for transitionLines and page breaks
    if (trimmedString.length >= 3) {
        //transitionLine happens if the last three chars are "TO:"
        NSRange lastThreeRange = NSMakeRange(trimmedString.length - 3, 3);
        NSString *lastThreeChars = [trimmedString substringWithRange:lastThreeRange];

        if ([lastThreeChars isEqualToString:@"TO:"]) {
            return transitionLine;
        }
        
        //Page breaks start with "==="
        NSString *firstChars;
        if (trimmedString.length == 3) {
            firstChars = lastThreeChars;
        } else {
            firstChars = [trimmedString substringToIndex:3];
        }
        if ([firstChars isEqualToString:@"==="]) {
            return pageBreak;
        }
    }
    
    // Check if all uppercase (and at least 3 characters to not indent every capital leter before anything else follows) = character name.
	// Also, note lines never constitute a character cue
    if (precedingLine.type == empty || precedingLine.string.length == 0) {
		if (length >= 3 && string.onlyUppercaseUntilParenthesis && !containsOnlyWhitespace && ![line.noteRanges containsIndex:0]) {
            // A character line ending in ^ is a double dialogue character
            if (lastChar == '^') {
				// PLEASE NOTE:
				// nextElementIsDualDialogue is ONLY used while staticly parsing for printing,
				// and SHOULD NOT be used anywhere else, as it won't be updated.
				NSInteger i = index - 1;
				while (i >= 0) {
					Line *prevLine = [self.lines objectAtIndex:i];

					if (prevLine.type == character) {
						prevLine.nextElementIsDualDialogue = YES;
						break;
					}
					if (prevLine.type == heading) break;
					i--;
				}
				
                return dualDialogueCharacter;
            } else {
				// It is possible that this IS NOT A CHARACTER anyway, so let's see.
				if ([line.noteRanges containsIndex:0]) {
					return action;
				}
				else if (index + 2 < self.lines.count && currentLine) {
					Line* nextLine = (Line*)self.lines[index+1];
					Line* twoLinesOver = (Line*)self.lines[index+2];
					
					if (recursive && nextLine.string.length == 0 && twoLinesOver.string.length > 0) {
						return action;
					}
				}

                return character;
            }
        }
    }
	else if (precedingLine.type == action &&
			 precedingLine.length > 0 &&
			 precedingLine.string.onlyUppercaseUntilParenthesis &&
			 line.length > 0 &&
			 !precedingLine.forced &&
			 [self previousLine:precedingLine].type == empty) {
		// Make all-caps lines with < 2 characters character cues and/or make all-caps actions character cues when the text is changed to have some dialogue follow it.
		if (precedingLine.lastCharacter == '^') precedingLine.type = dualDialogueCharacter;
		else precedingLine.type = character;
		
		[_changedIndices addIndex:index-1];
		return dialogue;
	}
    
    //Check for centered text
    if (firstChar == '>' && lastChar == '<') {
        return centered;
    }

    //If it's just usual text, see if it might be (double) dialogue or a parenthetical, or section/synopsis
    if (precedingLine) {
        if (precedingLine.type == character ||
			precedingLine.type == dialogue ||
			precedingLine.type == parenthetical) {
            //Text in parentheses after character or dialogue is a parenthetical, else its dialogue
			if (firstChar == '(' && [precedingLine.string length] > 0) {
                return parenthetical;
            } else {
				if ([precedingLine.string length] > 0) {
					return dialogue;
				} else {
					return action;
				}
            }
        } else if (precedingLine.type == dualDialogueCharacter || precedingLine.type == dualDialogue || precedingLine.type == dualDialogueParenthetical) {
            //Text in parentheses after character or dialogue is a parenthetical, else its dialogue
            if (firstChar == '(' && lastChar == ')') {
                return dualDialogueParenthetical;
            } else {
                return dualDialogue;
            }
        }
		/*
		// I beg to disagree with this.
		// This is not a part of the Fountain syntax definition, if I'm correct.
		else if (precedingLine.type == section) {
            return section;
        } else if (precedingLine.type == synopse) {
            return synopse;
        }
		*/
    }
    
    return action;
}

- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes line:(Line*)line
{
	// Let's use the asym method here, just put in our symmetric delimiters.
	return [self asymRangesInChars:string ofLength:length between:startString and:startString startLength:delimLength endLength:delimLength excludingIndices:excludes line:line];
	
	/*
    NSMutableIndexSet* indexSet = [[NSMutableIndexSet alloc] init];
    
    NSInteger lastIndex = length - delimLength; //Last index to look at if we are looking for start
    NSInteger rangeBegin = -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
    
    for (int i = 0;; i++) {
		if (i > lastIndex) break;
		
        // If this index is contained in the omit character indexes, skip
		if ([excludes containsIndex:i]) continue;
		
		// No range is currently inspected
        if (rangeBegin == -1) {
            bool match = YES;
            for (int j = 0; j < delimLength; j++) {
				// IF the characters in range are correct, check for an escape character (\)
				if (string[j+i] == startString[j] && i > 0 &&
					string[j + i - 1] == '\\') {
					match = NO;
					[line.escapeRanges addIndex:j+i - 1];
					break;
				}
				
                if (string[j+i] != startString[j]) {
                    match = NO;
                    break;
                }
            }
            if (match) {
                rangeBegin = i;
                i += delimLength - 1;
            }
		// We have found a range
        } else {
            bool match = YES;
            for (int j = 0; j < delimLength; j++) {
                if (string[j+i] != endString[j]) {
                    match = NO;
                    break;
				} else {
					// Check for escape characters again
					if (i > 0 && string[j+i - 1] == '\\') {
						[line.escapeRanges addIndex:j+i - 1];
						match = NO;
					}
				}
            }
            if (match) {
				// Add the current formatting ranges to future excludes
				[excludes addIndexesInRange:(NSRange){ rangeBegin, delimLength }];
				[excludes addIndexesInRange:(NSRange){ i, delimLength }];
				
                [indexSet addIndexesInRange:NSMakeRange(rangeBegin, i - rangeBegin + delimLength)];
                rangeBegin = -1;
                i += delimLength - 1;
            }
        }
    }
	
    return indexSet;
	 */
}

- (NSMutableIndexSet*)asymRangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString startLength:(NSUInteger)startLength endLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes line:(Line*)line
{
	/*
	 
	 NOTE:
	 
	 This is a confusing method name, but only because it is based on the old rangesInChars method. However, it's basically the same code, but I've put in the ability to seek ranges between two delimiters that are **not** the same, and can have asymmetrical length.
	 
	 The original method now just calls this using the symmetrical delimiters.
	 
	 */
	
	NSMutableIndexSet* indexSet = NSMutableIndexSet.new;
	
	NSInteger lastIndex = length - delimLength; //Last index to look at if we are looking for start
	NSInteger rangeBegin = -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
	
	for (int i = 0;; i++) {
		if (i > lastIndex) break;
		
		// If this index is contained in the omit character indexes, skip
		if ([excludes containsIndex:i]) continue;
		
		// No range is currently inspected
		if (rangeBegin == -1) {
			bool match = YES;
			for (int j = 0; j < startLength; j++) {
				// IF the characters in range are correct, check for an escape character (\)
				if (string[j+i] == startString[j] && i > 0 &&
					string[j + i - 1] == '\\') {
					match = NO;
					[line.escapeRanges addIndex:j+i - 1];
					break;
				}
				
				if (string[j+i] != startString[j]) {
					match = NO;
					break;
				}
			}
			if (match) {
				rangeBegin = i;
				i += delimLength - 1;
			}
		// We have found a range
		} else {
			bool match = YES;
			for (int j = 0; j < delimLength; j++) {
				if (string[j+i] != endString[j]) {
					match = NO;
					break;
				} else {
					// Check for escape characters again
					if (i > 0 && string[j+i - 1] == '\\') {
						[line.escapeRanges addIndex:j+i - 1];
						match = NO;
					}
				}
			}
			if (match) {
				// Add the current formatting ranges to future excludes
				[excludes addIndexesInRange:(NSRange){ rangeBegin, delimLength }];
				[excludes addIndexesInRange:(NSRange){ i, delimLength }];
				
				[indexSet addIndexesInRange:NSMakeRange(rangeBegin, i - rangeBegin + delimLength)];
				rangeBegin = -1;
				i += delimLength - 1;
			}
		}
	}
	
	return indexSet;
}

- (NSMutableIndexSet*)rangesOfOmitChars:(unichar*)string ofLength:(NSUInteger)length inLine:(Line*)line lastLineOmitOut:(bool)lastLineOut saveStarsIn:(NSMutableIndexSet*)stars
{
    NSMutableIndexSet* indexSet = [[NSMutableIndexSet alloc] init];
    
    NSInteger lastIndex = length - OMIT_PATTERN_LENGTH; //Last index to look at if we are looking for start
    NSInteger rangeBegin = lastLineOut ? 0 : -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
    line.omitIn = lastLineOut;
    
    for (int i = 0;;i++) {
        if (i > lastIndex) break;
        if (rangeBegin == -1) {
            bool match = YES;
            for (int j = 0; j < OMIT_PATTERN_LENGTH; j++) {
                if (string[j+i] != OMIT_OPEN_PATTERN[j]) {
                    match = NO;
                    break;
                }
            }
            if (match) {
                rangeBegin = i;
                [stars addIndex:i+1];
            }
        } else {
            bool match = YES;
            for (int j = 0; j < OMIT_PATTERN_LENGTH; j++) {
                if (string[j+i] != OMIT_CLOSE_PATTERN[j]) {
                    match = NO;
                    break;
                }
            }
            if (match) {
                [indexSet addIndexesInRange:NSMakeRange(rangeBegin, i - rangeBegin + OMIT_PATTERN_LENGTH)];
                rangeBegin = -1;
                [stars addIndex:i];
            }
        }
    }
    
    //Terminate any open ranges at the end of the line so that this line is omited untill the end
    if (rangeBegin != -1) {
        NSRange rangeToAdd = NSMakeRange(rangeBegin, length - rangeBegin);
        [indexSet addIndexesInRange:rangeToAdd];
        line.omitOut = YES;
    } else {
        line.omitOut = NO;
    }
    
    return indexSet;
}

- (NSMutableIndexSet*)noteRanges:(unichar*)string ofLength:(NSUInteger)length inLine:(Line*)line partOfBlock:(bool)partOfBlock
{
	// If a note block is bleeding into this line, noteIn is true
	line.noteIn = partOfBlock;
		
	// Reset all indices
	NSMutableIndexSet* indexSet = [[NSMutableIndexSet alloc] init];
	
	line.cancelsNoteBlock = NO;
	line.endsNoteBlock = NO;
	
	[line.noteRanges removeAllIndexes];
	[line.noteInIndices removeAllIndexes];
	[line.noteOutIndices removeAllIndexes];
	
	// Empty lines cut off note blocks
	if (line.type == empty && partOfBlock) {
		line.cancelsNoteBlock = YES;
		line.noteOut = NO;
		return indexSet;
	}
	
	// rangeBegin is -1 when a note range is not being inspected
	// and >0 when we have found the index of an open note range
	
	NSInteger lastIndex = length - NOTE_PATTERN_LENGTH; //Last index to look at if we are looking for start
	NSInteger rangeBegin = partOfBlock ? 0 : -1;
	
	bool beginsNoteBlock = NO;
	bool lookForTerminator = NO;
	if (line.noteIn) lookForTerminator = YES;
	
	for (int i = 0;;i++) {
		if (i > lastIndex) break;
		
		bool match = NO;
		if ((string[i] == '[' && string[i+1] == '[')) {
			lookForTerminator = NO;
			match = YES;
			beginsNoteBlock = YES;
			rangeBegin = i;
		}
		else if (string[i] == ']' && string[i+1] == ']') {
			
			if (lookForTerminator && rangeBegin != -1) {
				lookForTerminator = NO;
				line.endsNoteBlock = YES;
				
				beginsNoteBlock = NO;
				
				line.noteInIndices = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(rangeBegin, i - rangeBegin + NOTE_PATTERN_LENGTH)];
				
				rangeBegin = -1;
			}
			else {
				// Make sure there is a range where it all began
				if (rangeBegin != -1) {
					match = YES;
					[indexSet addIndexesInRange:NSMakeRange(rangeBegin, i - rangeBegin + NOTE_PATTERN_LENGTH)];
					rangeBegin = -1;
				}
			}
		}
	}
	
	//Terminate any open ranges at the end of the line so that this line is omited untill the end

	if (rangeBegin != -1) {
			//NSRange rangeToAdd = NSMakeRange(rangeBegin, length - rangeBegin);
			//[indexSet addIndexesInRange:rangeToAdd];

		// Let's take note that this line bleeds out a note range
		if (beginsNoteBlock) line.beginsNoteBlock = YES;
		line.noteOut = YES;
		
		NSRange rangeToAdd = NSMakeRange(rangeBegin, length - rangeBegin);
		NSMutableIndexSet *unterminatedIndices = [NSMutableIndexSet indexSetWithIndexesInRange:rangeToAdd];
		line.noteOutIndices = unterminatedIndices;
	} else {
		line.noteOut = NO;
		[line.noteOutIndices removeAllIndexes];
	}
		
	return indexSet;
}

- (NSRange)sceneNumberForChars:(unichar*)string ofLength:(NSUInteger)length
{
    NSUInteger backNumberIndex = NSNotFound;
	int note = 0;
	
    for(NSInteger i = length - 1; i >= 0; i--) {
        char c = string[i];
		
		// Exclude note ranges: [[ Note ]]
		if (c == ' ') continue;
		if (c == ']' && note < 2) { note++; continue; }
		if (c == '[' && note > 0) { note--; continue; }
		
		// Inside a note range
		if (note == 2) continue;
		
        if (backNumberIndex == NSNotFound) {
            if (c == '#') backNumberIndex = i;
            else break;
        } else {
            if (c == '#') {
                return NSMakeRange(i+1, backNumberIndex-i-1);
            }
        }
    }
	
    return NSMakeRange(0, 0);
}

- (NSString *)markerForLine:(Line*)line {
	__block NSString *markerColor = @"";
	
	line.markerRange = (NSRange){0, 0};
	line.marker = @"";
	line.markerDescription = @"";
	
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSString *note = [line.string substringWithRange:range].lowercaseString;
		if ([note containsString:@"[[marker "] && note.length > @"[[marker ]]".length) {
			NSString *markerInfo = [note substringWithRange:(NSRange){ @"[[marker ".length, note.length - @"[[marker ".length - 2 }];
			if ([markerInfo containsString:@":"]) {
				NSArray *markerComponents = [markerInfo componentsSeparatedByString:@":"];
				line.marker = markerComponents[0];
				if (markerComponents.count > 1) line.markerDescription = markerComponents[1];
			} else {
				line.marker = markerInfo;
			}
			
			line.markerRange = range;
			markerColor = line.marker;
			
			*stop = YES;
		}
	}];

	return markerColor;
}
- (NSString *)colorForHeading:(Line *)line
{
	__block NSString *color = @"";
	
	line.colorRange = NSMakeRange(0, 0);
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSString * note = [line.string substringWithRange:range];

		NSRange noteRange = NSMakeRange(NOTE_PATTERN_LENGTH, [note length] - NOTE_PATTERN_LENGTH * 2);
		note =  [note substringWithRange:noteRange];
        
		if ([note localizedCaseInsensitiveContainsString:@COLOR_PATTERN] == true) {
			if (note.length > @COLOR_PATTERN.length + 1) {
				NSRange colorRange = [note rangeOfString:@COLOR_PATTERN options:NSCaseInsensitiveSearch];
				if (colorRange.length) {
					color = [note substringWithRange:NSMakeRange(colorRange.length, [note length] - colorRange.length)];
					color = [color stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
					
					line.colorRange = range;
				}
			}
		}
	}];

	return color;
}
- (NSArray *)beatsFor:(Line *)line {
	NSUInteger length = line.string.length;
	unichar string[length];
	[line.string.lowercaseString getCharacters:string]; // Make it lowercase for range enumeration
	
	NSMutableIndexSet *set = [self asymRangesInChars:string ofLength:length between:"[[beat" and:"]]" startLength:@"[[beat".length endLength:2 excludingIndices:nil line:line];
	
	NSMutableArray *beats = NSMutableArray.array;
	
	[set enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSString *storylineStr = [line.string substringWithRange:range];
		NSUInteger loc = @"[[beat".length;
		NSString *rawBeats = [storylineStr substringWithRange:(NSRange){ loc, storylineStr.length - loc - 2 }];
		
		NSArray *components = [rawBeats componentsSeparatedByString:@","];
		for (NSString *component in components) {
			Storybeat *beat = [Storybeat line:line scene:nil string:component range:range];
			[beats addObject:beat];
		}
		
		[line.beatRanges addIndexesInRange:range];
	}];
	
	return beats;
}
- (NSArray *)storylinesFor:(Line *)line {
	// This is here for backwards-compatibility with older documents.
	// These are nowadays called BEATS.
	NSUInteger length = line.string.length;
	unichar string[length];
	[line.string.lowercaseString getCharacters:string]; // Make it lowercase for range enumeration
		
	NSMutableIndexSet *set = [self asymRangesInChars:string ofLength:length between:"[[storyline" and:"]]" startLength:@"[[storyline".length endLength:2 excludingIndices:nil line:line];
	
	NSMutableArray *beats = NSMutableArray.array;
	
	[set enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSString *storylineStr = [line.string substringWithRange:range];
		NSUInteger loc = @"[[storyline".length;
		NSString *rawStorylines = [storylineStr substringWithRange:(NSRange){ loc, storylineStr.length - loc - 2 }];
		
		NSArray *components = [rawStorylines componentsSeparatedByString:@","];
		
		for (NSString *component in components) {
			Storybeat *beat = [Storybeat line:line scene:nil string:component range:range];
			[beats addObject:beat];
		}
		
		[line.beatRanges addIndexesInRange:range];
	}];
	
	return beats;
}

#pragma mark - Data access

- (NSString*)stringAtLine:(NSUInteger)line
{
    if (line >= [self.lines count]) {
        return @"";
    } else {
        Line* l = self.lines[line];
        return l.string;
    }
}

- (LineType)typeAtLine:(NSUInteger)line
{
    if (line >= [self.lines count]) {
        return NSNotFound;
    } else {
        Line* l = self.lines[line];
        return l.type;
    }
}

- (NSUInteger)positionAtLine:(NSUInteger)line
{
    if (line >= self.lines.count) {
        return NSNotFound;
    } else {
        Line* l = self.lines[line];
        return l.position;
    }
}

- (NSString*)sceneNumberAtLine:(NSUInteger)line
{
    if (line >= self.lines.count) {
        return nil;
    } else {
        Line* l = self.lines[line];
        return l.sceneNumber;
    }
}

- (LineType)lineTypeAt:(NSInteger)index
{
	Line * line = [self lineAtPosition:index];
	
	if (!line) return action;
	else return line.type;
}

#pragma mark - New Outline Data

- (void)updateOutline {
	[self updateOutlineWithLines:self.lines];
}
- (void)updateOutlineWithLines:(NSArray*)lines {
	NSMutableArray *headings = NSMutableArray.array;
	
	// Gather heading, section and synopsis lines
	for (Line* line in self.lines) {
		if (line.isOutlineElement) [headings addObject:line];
	}
	
	// Create the actual outline items
	NSInteger index = 0;
	NSInteger sceneNumber = 1;
	
	for (Line *line in headings) {
		OutlineScene *scene;
		if (index >= _outline.count) {
			scene = [OutlineScene withLine:line delegate:self];
		} else {
			scene = _outline[index];
			scene.line = line;
		}
				
		if (line.sceneNumberRange.length > 0) {
			scene.sceneNumber = line.sceneNumber;
		} else if (!line.omitted) {
			scene.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
			line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
			sceneNumber++;
		} else {
			scene.sceneNumber = @"";
			scene.line.sceneNumber = @"";
		}
		
		//[self updateOutlineItem:scene];
	}
}
- (void)updateOutlineItem:(OutlineScene*)scene {
	
}

#pragma mark - Outline Data


- (NSUInteger)numberOfOutlineItems
{
	[self createOutline];
	return _outline.count;
}

- (OutlineScene*)getOutlineForLine: (Line *) line {
	for (OutlineScene * item in _outline) {
		if (item.line == line) {
			return item;
		}
	}
	return nil;
}
- (NSArray*)outlineItems {
	[self createOutline];
	return self.outline;
}

- (void)createOutline {
	if (NSThread.isMainThread) [self createOutlineUsingLines:self.lines];
	else [self createOutlineUsingLines:self.lines.copy];
}
- (void)createOutlineUsingLines:(NSArray<Line*>*)lines
{
	//[_outline removeAllObjects];
	[_storylines removeAllObjects];
	[_storybeats removeAllObjects];
	
	if (!_storybeats) _storybeats = NSMutableDictionary.new;
	
	// Get first scene number
	NSUInteger sceneNumber = 1;
	
	if ([self.documentSettings getInt:DocSettingSceneNumberStart] > 0) {
		sceneNumber = [self.documentSettings getInt:DocSettingSceneNumberStart];
	}
	
	OutlineScene *previousScene;
	NSUInteger sectionDepth = 0; // We will store a section depth to adjust depth for scenes that come after a section
	NSInteger sceneIndex = 0; // Calculate index for scene numbering
	
	OutlineScene *lastFoundSection;
	OutlineScene *lastFoundScene;
	NSMutableArray *sectionTree = NSMutableArray.new;
	
	for (Line* line in lines) {
		if (line.type == section || line.type == synopse || line.type == heading) {
			OutlineScene *scene;
			
			if (sceneIndex >= _outline.count) {
				scene = [OutlineScene withLine:line delegate:self];
			} else {
				scene = _outline[sceneIndex];
				scene.line = line;
			}
			
			// Reset parent
			scene.parent = nil;
			scene.children = NSMutableArray.new;
			
			// Create scene heading (for display)
			if (!scene.omitted) scene.string = line.stripInvisible;
			else scene.string = line.stripNotes;
			
			// Add storylines to the storyline bank
			// scene.storylines = NSMutableArray.array;
			[scene.beats addObjectsFromArray:line.beats];
			[_storylines addObjectsFromArray:line.storylines];
			
			// Remove story beats
			[scene.beats removeAllObjects];
			
			if (scene.type == section) {
				// Check setion depth
				if (sectionDepth < line.sectionDepth) {
					// This is deeper than the previous one
					scene.parent = sectionTree.lastObject;
					[sectionTree addObject:scene];
				} else {
					// This is a higher-level section, so remove anything that's lower-level
					while (sectionTree.count) {
						OutlineScene *pSection = sectionTree.lastObject;
						if (pSection.sectionDepth >= scene.sectionDepth) {
							[sectionTree removeLastObject];
						} else {
							[sectionTree removeLastObject];
							break;
						}
					}
					
					scene.parent = sectionTree.lastObject;
					
					[sectionTree addObject:scene];
				}
				
				// Save section depth
				sectionDepth = line.sectionDepth;
				scene.sectionDepth = sectionDepth;
				
				lastFoundSection = scene;
				lastFoundScene = nil; // Reset last found scene so we won't orphan synopsis lines
			} else {
				scene.sectionDepth = sectionDepth;
			}
			
			if (line.type == heading) {
				// Check if the scene is omitted
				// If the scene is omited, let's not increment scene number for it.
				// However, if the scene has a forced number, we'll maintain it
				if (line.sceneNumberRange.length > 0) {
					scene.sceneNumber = line.sceneNumber;
				}
				else {
					if (!line.omitted) {
						scene.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
						line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
						sceneNumber++;
					} else {
						scene.sceneNumber = @"";
						line.sceneNumber = @"";
					}
				}
				
				// Set parent (NOTE: can be nil)
				scene.parent = lastFoundSection;
				
				// Reset marker array
				scene.markerColors = NSMutableSet.set;
				
				lastFoundScene = scene;
			}
			
			if (line.type == synopse) {
				// For synopsis lines, we set the parent to be either the preceeding scene or latest section
				if (lastFoundScene) scene.parent = lastFoundScene;
				else scene.parent = lastFoundSection;
			}
			
			// This was a new scene
			if (sceneIndex >= _outline.count) [_outline addObject:scene];
			
			// Add this object to the children of its parent
			if (scene.parent) [scene.parent.children addObject:scene];
			
			previousScene = scene;
			sceneIndex++;
		}
		
		if (line.marker.length) {
			[previousScene.markerColors addObject:line.marker];
		}
		
		if (line.beats.count) {
			for (Storybeat *beat in line.beats) {
				if (![previousScene.beats containsObject:beat]) [previousScene.beats addObject:beat];
			}
		}
		
		/*
		if (line.storylines.count) {
			for (NSString *storyline in line.storylines) {
				Storybeat *beat = [Storybeat line:line scene:previousScene beat:@""];
				if (![previousScene.storylines doesContain:storyline]) [previousScene.storylines addObject:storyline];
			}
		}
		
		if (line.hasBeat) {
			NSDictionary *beatData = line.beats;
			for (NSString *storyline in beatData.allKeys) {
				Storybeat *beat = [Storybeat line:line scene:previousScene beat:beatData[storyline]];
				if (!_storybeats[storyline]) _storybeats[storyline] = NSMutableArray.array;
				[_storybeats[storyline] addObject:beat];
				
				if (![previousScene.storylines containsObject:storyline]) [previousScene.storylines addObject:storyline];
				[previousScene.storybeats addObject:beat];
			}
		}
		*/
		
		if (!line.note && !line.omitted && line.type != empty) {
			NSInteger length = line.range.length;
			if (length < 1) length = 1;
			
			if (previousScene) previousScene.printedLength += length;
		}
	}
	
	// Remove excess scene items
	if (sceneIndex - 1 < _outline.count - 1) {
		while (sceneIndex - 1 < _outline.count - 1) {
			[_outline removeLastObject];
		}
	}
	if (sceneIndex == 0) [_outline removeAllObjects];
	
	OutlineScene *lastScene = _outline.lastObject;
	Line *lastLine = _lines.lastObject;
	lastScene.length = lastLine.position + lastLine.string.length - lastScene.position;
}

- (BOOL)getAndResetChangeInOutline
{
    if (_changeInOutline) {
        _changeInOutline = NO;
        return YES;
    }
    return NO;
}


#pragma mark - Thread-safety for arrays

/**
 
 safeLines and safeOutline create a copy of the respective array when called from a background thread.
 Because Beat now supports plugins with direct access to the parser, we need to be extra careful with our threads.
 
 An example:
 We want to build a view of all the scenes and update it in the background. While the background
 thread calls something like linesForScene:, the user edits the screenplay. This causes a crash,
 because our .lines array was mutated while being enumerated.
 
 */

- (NSArray*)safeLines {
	if (NSThread.isMainThread) return self.lines;
	else return self.lines.copy;
}
- (NSArray*)safeOutline {
	if (NSThread.isMainThread) return self.outline;
	else return self.outline.copy;
}


#pragma mark - Convenience

- (NSInteger)numberOfScenes {
	NSArray *lines = self.safeLines; // Use thread-safe lines
	NSInteger scenes = 0;
	
	for (Line *line in lines) {
		if (line.type == heading) scenes++;
	}
	
	return scenes;
}
- (NSArray*)scenes {
	NSArray *outline = self.safeOutline; // Use thread-safe lines
	NSMutableArray *scenes = [NSMutableArray array];
	
	for (OutlineScene *scene in outline) {
		if (scene.type == heading) [scenes addObject:scene];
	}
	return scenes;
}

- (NSArray*)linesForScene:(OutlineScene*)scene {
	// Return minimal results for non-scene elements
	if (scene == nil) return @[];
	if (scene.type == synopse) return @[scene.line];
	
	// Make a copy of the lines array IF we are not in the main thread.
	NSArray *lines = self.safeLines;
		
	NSInteger lineIndex = [lines indexOfObject:scene.line];
	if (lineIndex == NSNotFound) return @[];
	
	// Automatically add the heading line and increment the index
	NSMutableArray *linesInScene = [NSMutableArray array];
	[linesInScene addObject:scene.line];
	lineIndex++;
	
	// Iterate through scenes and find the next terminating outline element.
	@try {
		while (lineIndex < lines.count) {
			Line *line = lines[lineIndex];

			if (line.type == heading || line.type == section) break;
			[linesInScene addObject:line];
			
			lineIndex++;
		}
	}
	@catch (NSException *e) {
		NSLog(@"No lines found");
	}
	
	return linesInScene;
}

- (Line*)previousLine:(Line*)line {
	NSArray *lines = self.safeLines; // Use thread-safe lines
	NSInteger lineIndex = [lines indexOfObject:line];
	
	if (line == lines.firstObject || lineIndex == 0 || lineIndex == NSNotFound) return nil;
	
	return lines[lineIndex - 1];
}

- (Line*)nextLine:(Line*)line {
	NSArray *lines = self.safeLines; // Use thread-safe lines
	NSInteger lineIndex = [lines indexOfObject:line];
	
	if (line == lines.lastObject || lines.count < 2 || lineIndex == NSNotFound) return nil;
	
	return lines[lineIndex + 1];
}


#pragma mark - Utility

- (NSString *)description
{
    NSString *result = @"";
    NSInteger index = 0;
	
    for (Line *l in self.lines) {
        //For whatever reason, %lu doesn't work with a zero
        result = [result stringByAppendingFormat:@"%lu ", index];
		
        result = [[result stringByAppendingString:[NSString stringWithFormat:@"%@", l]] stringByAppendingString:@"\n"];
        index++;
    }
	
    //Cut off the last newline
    result = [result substringToIndex:result.length - 1];
    return result;
}

// This returns a pure string with no comments or invisible elements
- (NSString *)cleanedString {
	NSString * result = @"";
	
	for (Line* line in self.lines) {
		// Skip invisible elements
		if (line.type == section || line.type == synopse || line.omitted || line.isTitlePage) continue;
		
		result = [result stringByAppendingFormat:@"%@\n", line.cleanedString];
	}
	
	return result;
}

- (Line*)lineAtIndex:(NSInteger)position {
	return [self lineAtPosition:position];
}

- (id)findNeighbourIn:(NSArray*)array origin:(NSUInteger)searchOrigin descending:(bool)descending cacheIndex:(NSUInteger*)cacheIndex block:(BOOL (^)(id item))compare  {
	
	// Don't go out of range
	if (NSLocationInRange(searchOrigin, NSMakeRange(-1, array.count))) {
		return nil;
	}
		
	NSInteger i = searchOrigin;
	NSInteger origin = i - 1;
		
	bool stop = NO;
	bool looped = NO;
	
	do {
		if (!descending) {
			i++;
			if (i >= array.count) {
				i = 0;
				looped = YES;
			}
		} else {
			i--;
			if (i < 0) {
				i = array.count - 1;
				looped = YES;
			}
		}
				
		id item = array[i];
		
		if (compare(item)) {
			*cacheIndex = i;
			return item;
		}
		
		if (i == origin && looped) {
			break;
		}
		
	} while (stop != YES);
		
	return nil;
}

// Cached line
NSUInteger prevLineAtLocationIndex = 0;
- (Line*)lineAtPosition:(NSInteger)position {
	// Let's check the cached line first
	if (NSLocationInRange(position, _prevLineAtLocation.range) && _prevLineAtLocation != nil) {
		return _prevLineAtLocation;
	}
		
	NSArray *lines = self.safeLines; // Use thread safe lines for this lookup
	if (prevLineAtLocationIndex >= lines.count) prevLineAtLocationIndex = 0;
	
	
	// Quick lookups for first object
	if (position == 0) return lines.firstObject;
	
	// We'll use a circular lookup here.
	// It's HIGHLY possible that we are not just randomly looking for lines,
	// but that we're looking for close neighbours in a for loop.
	// That's why we'll either loop the array forward or backward to avoid
	// unnecessary looping from beginning, which soon becomes VERY inefficient.
	
	NSUInteger cachedIndex;
	
	bool descending = NO;
	if (_prevLineAtLocation && position < _prevLineAtLocation.position) {
		descending = YES;
	}
		
	Line *line = [self findNeighbourIn:lines origin:prevLineAtLocationIndex descending:descending cacheIndex:&cachedIndex block:^BOOL(id item) {
		Line *l = item;
		if (NSLocationInRange(position, l.range)) return YES;
		else return NO;
	}];
	
	if (line) {
		_prevLineAtLocation = line;
		prevLineAtLocationIndex = cachedIndex;
		return line;
	}
	
	return nil;
}


- (NSArray*)linesInRange:(NSRange)range {
	NSArray *lines = self.safeLines;
	NSMutableArray *linesInRange = NSMutableArray.array;
	
	for (Line* line in lines) {
		if ((NSLocationInRange(line.position, range) ||
			NSLocationInRange(range.location, line.textRange) ||
			NSLocationInRange(range.location + range.length, line.textRange)) &&
			NSIntersectionRange(range, line.textRange).length > 0) {
			[linesInRange addObject:line];
		}
	}
	
	return linesInRange;
}

- (NSArray*)scenesInRange:(NSRange)range {
	NSMutableArray *scenes = NSMutableArray.new;
	
	[self createOutline];
	NSArray *outline = self.safeOutline; // Thread-safe outline
	
	// When length is zero, return just the scene at the beginning of range
	if (range.length == 0) return @[ [self sceneAtPosition:range.location] ];
	
	for (OutlineScene* scene in outline) {
		NSRange intersection = NSIntersectionRange(range, scene.range);
		if (intersection.length > 0) [scenes addObject:scene];
	}
	
	return scenes;
}
- (OutlineScene*)sceneAtIndex:(NSInteger)index {
	return [self sceneAtPosition:index];
}
- (OutlineScene*)sceneAtPosition:(NSInteger)index {
	for (OutlineScene *scene in self.safeOutline) {
		if (NSLocationInRange(index, scene.range) && scene.line) return scene;
	}
	return nil;
}

- (NSArray*)scenesInSection:(OutlineScene*)topSection {
	if (topSection.type != section) return @[];
	
	NSArray *outline = self.safeOutline;
	NSMutableArray *scenes = NSMutableArray.new;
	NSInteger idx = [outline indexOfObject:topSection];
	
	[scenes addObject:topSection];
	
	for (NSInteger i=idx+1; i<outline.count; i++) {
		OutlineScene* scene = outline[i];
		if (scene.type == section && scene.sectionDepth <= topSection.sectionDepth) break;
		
		[scenes addObject:scene];
	}
	
	return scenes;
}

- (NSArray*)preprocessForPrintingPrintNotes:(bool)printNotes {
	[self createOutline];
	
	return [self preprocessForPrintingWithLines:self.safeLines printNotes:printNotes];
}

- (NSArray*)preprocessForPrinting {
	[self createOutline];
	return [self preprocessForPrintingWithLines:self.safeLines printNotes:NO];
}
- (NSArray*)preprocessWithBlock:(NSArray* (^)(NSArray* lines))preprocessBlock {
	// This could one day be used to create custom preprocessing through a plugin.
	
	NSArray *lines = self.safeLines;
	NSMutableArray *preprocessed = NSMutableArray.new;
	for (Line* line in lines) {
		if (line.type == empty || line.isTitlePage) continue;
		[preprocessed addObject:line.clone];
	}
	
	return preprocessBlock(lines);
}
- (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines printNotes:(bool)printNotes {
	if (!lines) {
		NSLog(@"WARNING: No lines issued for preprocessing, using all parsed lines");
		lines = self.safeLines;
	}
	
	NSMutableArray *linesForPrinting = [NSMutableArray array];
	for (Line* line in lines) {
		[linesForPrinting addObject:line.clone];
	}
	
	// Get scene number offset from the delegate/document settings
	NSInteger sceneNumber = 1;
	if ([self.documentSettings getInt:DocSettingSceneNumberStart] > 1) {
		sceneNumber = [self.documentSettings getInt:DocSettingSceneNumberStart];
		if (sceneNumber < 1) sceneNumber = 1;
	}
	
	// Printable elements
	NSMutableArray *elements = [NSMutableArray array];
	
	Line *previousLine;
	
	// Check for split paragraphs
	NSInteger i = 0;
	for (Line* line in linesForPrinting) {
		if (i > 0 && line.type == action) {
			Line *precedingLine = lines[i - 1];
			if (precedingLine.type == action && precedingLine.string.length > 0) line.isSplitParagraph = YES;
		}
		i++;
	}
	
	for (Line *line in linesForPrinting) {
		// Fix a weird bug for first line
		if (line.type == empty && line.string.length && !line.string.containsOnlyWhitespace) line.type = action;
		
		// Skip over certain elements. Leave notes if needed.
		if (line.type == synopse || line.type == section || (line.omitted && !line.note)  || line.isTitlePage) continue;
		if (!printNotes && line.note) continue;
		
		// Add scene numbers
		if (line.type == heading) {
			if (line.sceneNumberRange.length > 0) {
				line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
			}
			else if (!line.sceneNumber) {
				line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
				sceneNumber += 1;
			}
		} else {
			line.sceneNumber = @"";
		}
		
		// Eliminate faux empty lines with only single space (let's use two)
		if ([line.string isEqualToString:@" "]) {
			line.type = empty;
			continue;
		}
		
		/**
		 This is a paragraph with a line break, so append the line to the previous one.
		
		 A quick explanation for this practice:
		 The pagination skips empty lines and instead calculates margins before elements.
		 This is a legacy of the old Fountain parser, but is actually somewhat sensitive approach,
		 because extraneous newlines should be ignored anyway. The caveat is that it requires
		 an extra sttep of joining action lines with no empty line between them into one element.
		*/
		
		if (line.isSplitParagraph && [lines indexOfObject:line] > 0 && elements.count > 0) {
			Line *precedingLine = [elements objectAtIndex:elements.count - 1];

			[precedingLine joinWithLine:line];
			continue;
		}
		
		// Remove misinterpreted dialogue
		if (line.type == dialogue && line.string.length < 1) {
			line.type = empty;
			previousLine = line;
			continue;
		}
				
		[elements addObject:line];
		
		// If this is dual dialogue character cue,
		// we need to search for the previous one too, just in cae
		if (line.isDualDialogueElement) {
			NSInteger i = elements.count - 2; // Go for previous element
			while (i > 0) {
				Line *precedingLine = [elements objectAtIndex:i];
				
				if (!(precedingLine.isDialogueElement || precedingLine.isDualDialogueElement)) break;
				
				if (precedingLine.type == character ) {
					precedingLine.nextElementIsDualDialogue = YES;
					break;
				}
				i--;
			}
		}
		
		previousLine = line;
	}
	
	return elements;
}

#pragma mark - Document settings

- (BeatDocumentSettings*)documentSettings {
	if (self.delegate) return self.delegate.documentSettings;
	else if (self.staticDocumentSettings) return self.staticDocumentSettings;
	else return nil;
}

#pragma mark - Separate title page & content for printing

- (BeatScreenplay*)forPrinting {
	return [BeatScreenplay from:self];
}

- (NSDictionary*)scriptForPrinting {
	// NOTE: Use ONLY for static parsing
	return @{
		@"title page": self.titlePage,
		@"script": [self preprocessForPrinting]
	};
}

#pragma mark - String result for saving the screenplay

- (NSString*)scriptForSaving {
	NSMutableString *string = [NSMutableString string];
	
	Line *previousLine;
	for (Line* line in self.lines) {
		// Ensure we have correct amount of line breaks before elements
		if ((line.type == character || line.type == heading) &&
			previousLine.string.length > 0) {
			[string appendString:@"\n"];
		}
		
		[string appendString:line.string];
		[string appendString:@"\n"];
		
		previousLine = line;
	}
	
	return string;
}

@end
/*
 
 Thank you, Hendrik Noeller, for making Beat possible.
 Without your massive original work, any of this had never happened.
 
 */
