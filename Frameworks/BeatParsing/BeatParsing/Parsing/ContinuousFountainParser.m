//
//  ContinousFountainParser.m
//  Beat
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
 
 */

#import "ContinuousFountainParser.h"
#import "RegExCategories.h"
#import "Line.h"
#import "NSString+CharacterControl.h"
#import "NSMutableIndexSet+Lowest.h"
#import "NSIndexSet+Subset.h"
#import "OutlineScene.h"
#import "BeatMeasure.h"

#define NEW_OUTLINE YES

#pragma mark - Parser

@implementation OutlineChanges
- (instancetype)init
{
    self = [super init];
    
    self.updated = NSMutableSet.new;
    self.removed = NSMutableSet.new;
    self.added = NSMutableSet.new;
    
    return self;
}
- (bool)hasChanges
{
    return (self.updated.count > 0 || self.removed.count > 0 || self.added.count > 0 || self.needsFullUpdate);
}
- (id)copy
{
    OutlineChanges* changes = OutlineChanges.new;
    changes.updated = self.updated;
    changes.removed = self.removed;
    changes.added = self.added;
    changes.needsFullUpdate = self.needsFullUpdate;
    
    return changes;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return self.copy;
}

@end

@interface ContinuousFountainParser () {
	// Line cache. I don't know why this is an iVar.
	__weak Line * _prevLineAtLocation;
}

@property (nonatomic) BOOL changeInOutline;
@property (nonatomic) OutlineChanges* outlineChanges;
@property (nonatomic) NSMutableSet *changedOutlineElements;
@property (nonatomic) Line *editedLine;
@property (nonatomic, weak) Line *lastEditedLine;
@property (nonatomic) NSUInteger lastLineIndex;
@property (nonatomic) NSUInteger editedIndex;
@property (nonatomic) NSRange editedRange;

// Title page parsing
@property (nonatomic) NSString *openTitlePageKey;
@property (nonatomic) NSString *previousTitlePageKey;

// For initial loading
@property (nonatomic) NSInteger indicesToLoad;
@property (nonatomic) bool firstTime;

// For testing
@property (nonatomic) NSDate *executionTime;

// Static parser flag
@property (nonatomic) bool nonContinuous;

// Cached line set for UUID creation
@property (nonatomic) NSArray* cachedLines;

@property (atomic) bool preprocessing;

@end

@implementation ContinuousFountainParser

static NSDictionary* patterns;

#pragma mark - Initializers

/// Extracts the title page from given string
+ (NSArray*)titlePageForString:(NSString*)string {
	NSArray <NSString*>*rawLines = [string componentsSeparatedByString:@"\n"];
	
	if (rawLines.count == 0) return @[];
	else if (![rawLines.firstObject containsString:@":"]) return @[];
	
	NSMutableString *text = NSMutableString.new;
	
	for (NSString *l in rawLines) {
		// Break at empty line
		[text appendFormat:@"%@\n", l];
		if ([l isEqualToString:@""]) break;
	}
	[text appendString:@"\n"];
	
	ContinuousFountainParser *parser = [ContinuousFountainParser.alloc initWithString:text];
	return parser.titlePage;
}

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

#pragma mark - Saved file processing

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

/// Returns the whole document as single string
- (NSString*)rawText {
	NSMutableString *string = [NSMutableString string];
	for (Line* line in self.lines) {
		if (line != self.lines.lastObject) [string appendFormat:@"%@\n", line.string];
		else [string appendFormat:@"%@", line.string];
	}
	return string;
}


#pragma mark - Parsing

#pragma mark Bulk parsing

- (void)parseText:(NSString*)text {
    [self parseText:text outlineUUIDs:@[]];
}

- (void)parseText:(NSString*)text outlineUUIDs:(NSArray*)outlineUUIDs
{
	_firstTime = YES;
	_lines = NSMutableArray.new;
	
	// Replace MS Word line breaks with macOS ones
	text = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
	
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
	_indicesToLoad = lines.count;
    
    NSUInteger position = 0; //To track at which position every line begins
	NSUInteger sceneIndex = -1;
	
	Line *previousLine;
    
    for (NSString *rawLine in lines) {
        NSInteger index = _lines.count;
        Line* line = [[Line alloc] initWithString:rawLine position:position parser:self];
        [self parseTypeAndFormattingForLine:line atIndex:index];
        
		// Quick fix for mistaking an ALL CAPS action to character cue
		if (previousLine.type == character && (line.string.length < 1 || line.type == empty)) {
			previousLine.type = [self parseLineTypeFor:line atIndex:index - 1];
			if (previousLine.type == character) previousLine.type = action;
		}
		
		if (line.isOutlineElement) {
			// A cloned version of the screenplay is used for preview & printing.
			// sceneIndex ensures we know which scene heading is which, even when there are hidden outline items.
			// This is used to jump into corresponding scenes from preview mode. There are smarter ways
			// to do this, but this is how it was done back in the day and still remains so.
			// Update 2022-11: I think this is not used anymore?
			sceneIndex++;
			line.sceneIndex = sceneIndex;
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
	
    // Reset outline
    _changeInOutline = YES;
	[self createOutline];
    self.outlineChanges = OutlineChanges.new;
	
    // Set identifiers
    if (outlineUUIDs.count) [self setIdentifiersForOutlineElements:outlineUUIDs];
    
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
 
 Note to future me:
 
 I have somewhat revised the original parsing system, which parsed changes by
 always removing single characters in a loop, even with longer text blocks.
 
 I optimized the logic so that if the change includes full lines (either removed or added)
 they are removed or added as whole, rather than character-by-character. This is why
 there are two different methods for parsing the changes, and the other one is still used
 for parsing single-character edits. parseAddition/parseRemovalAt methods fall back to
 them when needed.

 Flow:
 parseChangeInRange ->
	parseAddition/parseRemoval methods write changedIndices
	-> correctParsesInLines processes changedIndices
 
 */

- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string
{
	if (range.location == NSNotFound) return; // This is for avoiding crashes when plugin developers are doing weird things
	
	_lastEditedLine = nil;
	_editedIndex = -1;
    _editedRange = range;

	NSMutableIndexSet *changedIndices = NSMutableIndexSet.new;
    if (range.length == 0) { // Addition
		[changedIndices addIndexes:[self parseAddition:string atPosition:range.location]];
		
    } else if (string.length == 0) { // Removal
		[changedIndices addIndexes:[self parseRemovalAt:range]];
		
    } else { //Replacement
		[changedIndices addIndexes:[self parseRemovalAt:range]]; // First remove
		[changedIndices addIndexes:[self parseAddition:string atPosition:range.location]]; // Then add
    }
	    	
    [self correctParsesInLines:changedIndices];
}

/// Ensures that the given line is parsed correctly. Continuous parsing only. A bit confusing to use.
- (void)ensureDialogueParsingFor:(Line*)line {
	if (!line.isAnyCharacter) return;
	
	NSInteger i = [self indexOfLine:line];
    if (i == NSNotFound) return;
    
	NSArray *lines = self.lines;

	Line *nextLine;
	
	// Get the neighboring lines
	if (i < self.lines.count - 1) nextLine = lines[i + 1];
	
	// Let's not do anything, if we are currently editing these lines.
	if (nextLine != nil && nextLine.string.length == 0 &&
		!NSLocationInRange(_delegate.selectedRange.location, nextLine.range) &&
		!NSLocationInRange(_delegate.selectedRange.location, line.range) &&
        line.numberOfPrecedingFormattingCharacters == 0
        ) {

		line.type = action;
		[self.changedIndices addIndex:i];
		[_delegate applyFormatChanges];
	}
}

/// This is a method to fix anything that might get broken. Use only when debugging.
- (void)ensurePositions {
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

#pragma mark Parsing additions

- (NSIndexSet*)parseAddition:(NSString*)string atPosition:(NSUInteger)position
{
    NSMutableIndexSet *changedIndices = NSMutableIndexSet.new;
    
	// Get the line where into which we are adding characters
	NSUInteger lineIndex = [self lineIndexAtPosition:position];
    Line* line = self.lines[lineIndex];
    
    [changedIndices addIndex:lineIndex];
	
    NSUInteger indexInLine = position - line.position;
            
    // Cut the string in half
    NSString* tail = [line.string substringFromIndex:indexInLine];
    line.string = [line.string substringToIndex:indexInLine];
    
    NSInteger currentRange = -1;
    
    for (NSInteger i=0; i<string.length; i++) {
        if (currentRange < 0) currentRange = i;
        
        unichar chr = [string characterAtIndex:i];
        
        if (chr == '\n') {
            NSString* addedString = [string substringWithRange:NSMakeRange(currentRange, i - currentRange)];
            line.string = [line.string stringByAppendingString:addedString];
            
            if (lineIndex < self.lines.count - 1) {
                Line* nextLine = self.lines[lineIndex+1];
                NSInteger delta = ABS(NSMaxRange(line.range) - nextLine.position);
                [self decrementLinePositionsFromIndex:lineIndex+1 amount:delta];
            }
            
            [self addLineWithString:@"" atPosition:NSMaxRange(line.range) lineIndex:lineIndex+1];
            
            // Increment current line index and reset inspected range
            lineIndex++;
            currentRange = -1;
            
            // Set current line
            line = self.lines[lineIndex];
        }
    }

    // Get the remaining string (if applicable)
    NSString* remainder = (currentRange >= 0) ? [string substringFromIndex:currentRange] : @"";
    line.string = [line.string stringByAppendingString:remainder];
    line.string = [line.string stringByAppendingString:tail];
    
    [self adjustLinePositionsFrom:lineIndex];
    
    //[self report];
    [changedIndices addIndexesInRange:NSMakeRange(changedIndices.firstIndex + 1, lineIndex - changedIndices.firstIndex)];
    
    return changedIndices;
}


#pragma mark Parsing removal

- (NSIndexSet*)parseRemovalAt:(NSRange)range {
    NSMutableIndexSet *changedIndices = NSMutableIndexSet.new;
    
    // Note: First and last index can be the same, if we are parsing on the same line
    NSInteger firstIndex = [self lineIndexAtPosition:range.location];
    NSInteger lastIndex = [self lineIndexAtPosition:NSMaxRange(range)];
    
    Line* firstLine = self.lines[firstIndex];
    Line* lastLine = self.lines[lastIndex];
    
    bool originalLineWasEmpty = (firstLine.string.length == 0);
    bool lastLineWasEmpty = (lastLine.string.length == 0);
    
    bool omitOut = false;
    bool omitIn = false;
    
    NSInteger i = firstIndex;
    while (i < self.lines.count) {
        Line* line = self.lines[i];
        
        // Store a flag if last handled line previously terminated an omission
        omitOut = line.omitOut;
        omitIn = line.omitIn;
        
        NSRange intersection = NSIntersectionRange(line.range, range);
        NSRange localRange = NSMakeRange(intersection.location - line.position, intersection.length);
        
        if (range.length <= 0) {
            break;
        }
        else if (intersection.length == line.range.length) {
            // The range covers this whole line, remove it altogether.
            [self removeLineAtIndex:i];
            range.length -= line.range.length; // Subtract from full range
        }
        else {
            // This line is partly covered by the range
            line.string = [line.string stringByRemovingRange:localRange];
            [self decrementLinePositionsFromIndex:i+1 amount:localRange.length];
            range.length -= localRange.length; // Subtract from full range
            
            // Move on to next line (even if we only wanted to remove one character)
            i++;
        }
    }
    
    // Join the two lines if the original line didn't get removed in the process
    if (firstIndex != lastIndex && firstLine == self.lines[firstIndex] &&
        self.lines.count > firstIndex + 1 && self.lines[firstIndex+1] == lastLine) {
        firstLine.string = [firstLine.string stringByAppendingString:lastLine.string];
        [self removeLineAtIndex:firstIndex+1];
        
        NSInteger diff = NSMaxRange(firstLine.range) - lastLine.position;
        [self incrementLinePositionsFromIndex:firstIndex+1 amount:diff];
    }
    
    [self report];
    
    // Add necessary indices
    [changedIndices addIndex:firstIndex];
    
    // If the line terminated or bleeded out an omit, check surrounding indices, too.
    // Also removing a line break can cause some elements change their type.
    if ((omitOut || lastLineWasEmpty) && firstIndex < self.lines.count+1) [changedIndices addIndex:firstIndex+1];
    if ((omitIn || originalLineWasEmpty) && firstIndex > 0) [changedIndices addIndex:firstIndex-1];
    
    _editedIndex = firstIndex;
    
    return changedIndices;
}


#pragma mark Add / remove lines

- (void)removeLineAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.lines.count) return;
    
    Line* line = self.lines[index];
    
    if (line.isOutlineElement) [self removeOutlineElementForLine:line];
    
    [self.lines removeObjectAtIndex:index];
    [self decrementLinePositionsFromIndex:index amount:line.range.length];
}

- (void)addLineWithString:(NSString*)string atPosition:(NSInteger)position lineIndex:(NSInteger)index {
    // Add a new line into place and increment positions
    Line *newLine = [Line.alloc initWithString:string position:position parser:self];
        
    [self.lines insertObject:newLine atIndex:index];
    [self incrementLinePositionsFromIndex:index+1 amount:1];
}


#pragma mark - Correcting parsed content for existing lines

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
	
	// Remove index as done from array if in array
	if (indices.count) {
		NSUInteger lowestToDo = indices.lowestIndex;
		if (lowestToDo == index) {
			[indices removeIndex:index];
		}
	}
    		
	// Save the original line type
	LineType oldType = currentLine.type;
	bool oldOmitOut = currentLine.omitOut;
	bool oldNoteOut = currentLine.noteOut;
	bool oldEndsNoteBlock = currentLine.endsNoteBlock;
	bool oldNoteTermination = currentLine.cancelsNoteBlock;
	bool notesNeedParsing = NO;
	
    // Parse correct type
	[self parseTypeAndFormattingForLine:currentLine atIndex:index];
    
    // Add, remove or update outline elements
    if ((oldType == section || oldType == heading) && !currentLine.isOutlineElement) {
        // This line is no longer an outline element
        [self removeOutlineElementForLine:currentLine];
    }
    else if (currentLine.isOutlineElement && !(oldType == section || oldType == heading)) {
        // This line became outline element
        [self addOutlineElement:currentLine];
    }
    else if (currentLine.isOutlineElement && (oldType == section || oldType == heading)) {
        // The heading / section was changed
        [self addUpdateToOutlineAtLine:currentLine];
    } else {
        // In other case, let's see if we should update the scene
        [self addUpdateToOutlineIfNeededAt:index];
    }
    
    // Mark the current index as changed
	[self.changedIndices addIndex:index];
	
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
	
	if (index > 0) {
        // Parse faulty and orphaned dialogue (this can happen, because... well, there are *reasons*)
		
        Line *prevLine = self.lines[index - 1]; // Get previous line
        NSInteger selection = (NSThread.isMainThread) ? self.delegate.selectedRange.location : 0; // Get selection
        
        // If previous line is NOT EMPTY, has content and the selection is not at the preceding position, go through preceding lines
		if (prevLine.type != empty && prevLine.length == 0 && selection != prevLine.position - 1) {
            NSInteger i = index - 1;
            
            while (i >= 0) {
                Line *l = self.lines[i];
                if (l.length > 0) {
                    // Not a forced character cue, not the preceding line to selection
                    if (l.type == character && selection != NSMaxRange(l.textRange) && l.numberOfPrecedingFormattingCharacters == 0  &&
                        l != self.delegate.characterInputForLine) {
                        l.type = action;
                        [self.changedIndices addIndex:i];
                    }
                    break;
                }
                else if (l.type != empty && l.length == 0) {
                    l.type = empty;
                    [self.changedIndices addIndex:i];
                }
                
                i -= 1;
            }
 		}
	}
	
	//If there is a next element, check if it might need a reparse because of a change in type or omit out
	if (oldType != currentLine.type || oldOmitOut != currentLine.omitOut || lastToParse ||
		currentLine.isDialogueElement || currentLine.isDualDialogueElement || currentLine.type == empty) {
        
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
				nextLine.type == dualDialogueCharacter ||   //related, it might not be anymore
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
				currentLine.endsNoteBlock != oldEndsNoteBlock ||
				((currentLine.isDialogueElement || currentLine.isDualDialogueElement) && nextLine.string.length > 0)
				) {
				[self correctParseInLine:index+1 indicesToDo:indices];
			}
		}
	}
}


#pragma mark - Incrementing / decrementing line positions

/// A replacement for the old, clunky `incrementLinePositions` and `decrementLinePositions`. Automatically adjusts line positions based on line content.
/// You still have to make sure that you are parsing correct stuff, though.
- (void)adjustLinePositionsFrom:(NSInteger)index {
    Line* line = self.lines[index];
    NSInteger delta = NSMaxRange(line.range);
    index++;
    
    for (;index<self.lines.count; index++) {
        Line* l = self.lines[index];
        l.position = delta;
        
        delta = NSMaxRange(l.range);
    }
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
	for (; index < self.lines.count; index++) {
		Line* line = self.lines[index];
		line.position -= amount;
	}
}



#pragma mark - Parsing Core

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
	
    line.type = [self parseLineTypeFor:line atIndex:index];
        
    NSUInteger length = line.string.length;
    unichar charArray[length];
    [line.string getCharacters:charArray];
        
	// Omits have stars in them, which can be mistaken for formatting characters.
	// We store the omit asterisks into the "excluded" index set to avoid this mixup.
    NSMutableIndexSet* excluded = NSMutableIndexSet.new;
	
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
    
    line.escapeRanges = NSMutableIndexSet.new;

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
    else line.boldItalicRanges = NSMutableIndexSet.new;
	
    if (line.type == heading) {
		line.sceneNumberRange = [self sceneNumberForChars:charArray ofLength:length];
        
		if (line.sceneNumberRange.length == 0) {
            line.sceneNumber = @"";
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

- (LineType)parseLineTypeFor:(Line*)line atIndex:(NSUInteger)index {
    Line *previousLine = (index > 0) ? self.lines[index - 1] : nil;
    Line *nextLine = (index < self.lines.count - 1 && self.lines.count > 0) ? self.lines[index+1] : nil;

    bool previousIsEmpty = false;
    
    NSString *trimmedString = (line.string.length > 0) ? [line.string stringByTrimmingTrailingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] : @"";

    // Check for everything that is considered as empty
    if (previousLine.effectivelyEmpty || index == 0) previousIsEmpty = true;
    
    // Check if this line was forced to become a character cue in editor (by pressing tab)
    if (line.forcedCharacterCue) {
        line.forcedCharacterCue = NO;
        // 94 = ^ (this is here to avoid issues with Turkish alphabet
        if (line.lastCharacter == 94) return dualDialogueCharacter;
        else return character;
    }
    
    // Handle empty lines first
    if (line.length == 0) {
        if (previousLine.isDialogue || previousLine.isDualDialogue) {
            // If preceding line is formatted as dialogue BUT it's empty, we'll just return empty.
            if (previousLine.string.length == 0) return empty;

            // If preceeded by a character cue, always return dialogue
            if (previousLine.type == character) return dialogue;
            if (previousLine.type == dualDialogueCharacter) return dualDialogue;
            
            // If it's any other dialogue line, return dialogue
            if ((previousLine.isAnyDialogue || previousLine.isAnyParenthetical) && previousLine.length > 0 && (nextLine.length == 0 || nextLine == nil)) {
                return (previousLine.isDialogue) ? dialogue : dualDialogue;
            }
        }
        
        return empty;
    }
        
    // Check forced elements
    unichar firstChar = [line.string characterAtIndex:0];
    unichar lastChar = line.lastCharacter;
    
    // Forced whitespace
    bool containsOnlyWhitespace = line.string.containsOnlyWhitespace; // Save to use again later
    bool twoSpaces = (firstChar == ' ' && lastChar == ' ' && line.length > 1); // Contains at least two spaces
    
    if (containsOnlyWhitespace && !twoSpaces) return empty;
        
    if ([trimmedString isEqualToString:@"==="]) return pageBreak;
    else if (firstChar == '!') {
        // Action or shot
        if (line.length > 1) {
            unichar secondChar = [line.string characterAtIndex:1];
            if (secondChar == '!') return shot;
        }
        return action;
    }
    else if (firstChar == '.' && previousIsEmpty) {
        // '.' forces a heading. Because our American friends love to shoot their guns like we Finnish people love our booze, screenwriters might start dialogue blocks with such "words" as '.44'
        if (line.length > 1) {
            unichar secondChar = [line.string characterAtIndex:1];
            if (secondChar != '.') return heading;
        } else {
            return heading;
        }
    }
    // ... and then the rest.
    else if (firstChar == '@') return character;
    else if (firstChar == '>' && lastChar == '<') return centered;
    else if (firstChar == '>') return transitionLine;
    else if (firstChar == '~') return lyrics;
    else if (firstChar == '=') return synopse;
    else if (firstChar == '#') return section;
    else if (firstChar == '@' && lastChar == 94 && previousIsEmpty) return dualDialogueCharacter;
    else if (firstChar == '.' && previousIsEmpty) return heading;
    else if ([trimmedString isEqualToString:@"==="]) return pageBreak;

    // Title page
    // TODO: Rewrite this
    if (previousLine == nil || previousLine.isTitlePage) {
        NSString *key = line.titlePageKey;
        
        if (key.length > 0) {
            NSString* value = line.titlePageValue;
            if (value == nil) value = @"";
            
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
        }
        else if (previousLine.isTitlePage) {
            NSString *key = @"";
            NSInteger i = index - 1;
            while (i >= 0) {
                Line *pl = self.lines[i];
                if (pl.titlePageKey.length > 0) {
                    key = pl.titlePageKey;
                    break;
                }
                i -= 1;
            }
            if (key.length > 0) {
                NSMutableDictionary* dict = _titlePage.lastObject;
                [(NSMutableArray*)dict[key] addObject:line.string];
            }
            
            return previousLine.type;
        }
    }
    
    // Handle items which require an empty line before them
    if (previousIsEmpty && line.string.length >= 3 && line != self.delegate.characterInputForLine) {
        
        // Heading
        NSString* firstChars = [line.string substringToIndex:3].lowercaseString;
        
        if ([firstChars isEqualToString:@"int"] ||
            [firstChars isEqualToString:@"ext"] ||
            [firstChars isEqualToString:@"est"] ||
            [firstChars isEqualToString:@"i/e"]) {
            
            // If it's just under 4 characters, return heading
            if (line.length == 3) return heading;
            else {
                // To avoid words like "international" from becoming headings, the extension HAS to end with either dot, space or slash
                unichar nextChar = [line.string characterAtIndex:3];
                if (nextChar == '.' || nextChar == ' ' || nextChar == '/')  return heading;
            }
        }
        
        // Check for transitions
        NSRange transitionRange = [trimmedString rangeOfString:@"TO:"];
        if (transitionRange.location != NSNotFound && transitionRange.location == trimmedString.length - 3) {
            return transitionLine;
        }
        
        // Character
        if (line.string.onlyUppercaseUntilParenthesis && !containsOnlyWhitespace && line.noteRanges.firstIndex != 0) {
            // A character line ending in ^ is a dual dialogue character
            // (94 = ^, we'll compare the numerical value to avoid mistaking Tuskic alphabet character Ş as ^)
            if (lastChar == 94)
            {
                // Note the previous character cue that it's followed by dual dialogue
                [self makeCharacterAwareOfItsDualSiblingFrom:index];
                return dualDialogueCharacter;
            } else {
                // It is possible that this IS NOT A CHARACTER but an all-caps action line
                if (index + 2 < self.lines.count) {
                    Line* twoLinesOver = (Line*)self.lines[index+2];
                    
                    // Next line is empty, line after that isn't - and we're not on that particular line
                    if ((nextLine.string.length == 0 && twoLinesOver.string.length > 0) ||
                        (nextLine.string.length == 0 && NSLocationInRange(self.delegate.selectedRange.location, nextLine.range))
                        ) {
                        return action;
                    }
                }

                return character;
            }
        }
    }
    
    if ((previousLine.isDialogue || previousLine.isDualDialogue) && previousLine.length > 0) {
        if (firstChar == '(') return (previousLine.isDialogue) ? parenthetical : dualDialogueParenthetical;
        return (previousLine.isDialogue) ? dialogue : dualDialogue;
    }
    
    // Fix some parsing mistakes
    if (previousLine.type == action && previousLine.length > 0 && previousLine.string.onlyUppercaseUntilParenthesis &&
             line.length > 0 &&
             !previousLine.forced &&
             [self previousLine:previousLine].type == empty) {
        // Make all-caps lines with < 2 characters character cues and/or make all-caps actions character cues when the text is changed to have some dialogue follow it.
        // (94 = ^, we'll use the numerical value to avoid mistaking Turkish alphabet letter 'Ş' as '^')
        if (previousLine.lastCharacter == 94) previousLine.type = dualDialogueCharacter;
        else previousLine.type = character;
        
        [_changedIndices addIndex:index-1];
        
        if (line.length > 0 && [line.string characterAtIndex:0] == '(') return parenthetical;
        else return dialogue;
    }
        
    return action;
}

- (void)makeCharacterAwareOfItsDualSiblingFrom:(NSInteger)index {
    NSInteger i = index - 1;
    while (i >= 0) {
        Line *prevLine = [self.lines objectAtIndex:i];

        if (prevLine.type == character) {
            prevLine.nextElementIsDualDialogue = YES;
            break;
        }
        if (!prevLine.isDialogueElement && !prevLine.isDualDialogueElement) break;
        i--;
    }
}

- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes line:(Line*)line
{
	// Let's use the asym method here, just put in our symmetric delimiters.
	return [self asymRangesInChars:string ofLength:length between:startString and:startString startLength:delimLength endLength:delimLength excludingIndices:excludes line:line];
}

- (NSMutableIndexSet*)asymRangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString startLength:(NSUInteger)startLength endLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes line:(Line*)line
{
	/*
	 NOTE: This is a confusing method name, but only because it is based on the old rangesInChars method.
	 However, it's basically the same code, but I've put in the ability to seek ranges between two
	 delimiters that are **not** the same, and can have asymmetrical length.
	 
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
		
		if ((string[i] == '[' && string[i+1] == '[')) {
			lookForTerminator = NO;
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
        unichar c = string[i];
		
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
    line.markerRange = (NSRange){0, 0};
    line.marker = @"";
    line.markerDescription = @"";

    NSString *markerColor = @"";
    NSString *markerContent = @"";

    // Get the last marker. If none is found, just return ""
    NSArray* marker = [line contentAndRangeForLastNoteWithPrefix:@"marker"];
    if (marker == nil) return @"";

    // The correct way to add a marker is to write [[marker color:Content]], but we'll be gratitious here.
    NSRange range = ((NSNumber*)marker[0]).rangeValue;
    NSString* string = marker[1];
    
    if (![string containsString:@":"] && [string containsString:@" "]) {
        // No colon, let's separate components.
        // First words will always be "marker", so get the second word and see if it's a color
        NSArray<NSString*>* words = [string componentsSeparatedByString:@" "];
        NSInteger descriptionStart = @"marker ".length;
        
        if (words.count > 1) {
            NSString* potentialColor = words[1].lowercaseString;
            if ([[self colors] containsObject:potentialColor]) {
                markerColor = potentialColor;
            }
        }
        
        // Get the content after we've checked for potential color for this marker
        markerContent = [string substringFromIndex:descriptionStart + markerColor.length];
    }
    else if ([string containsString:@":"]) {
        NSInteger l = [string rangeOfString:@":"].location;
        markerContent = [string substringFromIndex:l+1];
        
        NSString* left = [string substringToIndex:l];
        NSArray* words = [left componentsSeparatedByString:@" "];
        
        if (words.count > 1) markerColor = words[1];
    }
    
    // Use default as marker color if no applicable color found
    line.marker = (markerColor.length > 0) ? markerColor.lowercaseString : @"default";
    line.markerDescription = [markerContent stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    line.markerRange = range;
    
	return markerColor;
}

- (NSArray<NSString*>*)colors {
    static NSArray* colors;
    if (colors == nil) colors = @[@"red", @"blue", @"green", @"pink", @"magenta", @"gray", @"purple", @"cyan", @"teal", @"yellow", @"orange", @"brown"];
    return colors;
}

/// Finds and sets the color for given outline-level line. Only the last one is used, preceding color notes are ignored.
- (NSString *)colorForHeading:(Line *)line
{
    NSArray *colors = @[@"red", @"blue", @"green", @"pink", @"magenta", @"gray", @"purple", @"cyan", @"teal", @"yellow", @"orange", @"brown"];
    
    __block NSString* headingColor = @"";
	line.colorRange = NSMakeRange(0, 0);
    
    NSDictionary<NSValue*, NSString*>* noteContents = line.noteContentsAndRanges;
    for (NSNumber* key in noteContents.allKeys) {
        NSRange range = key.rangeValue;
        NSString* content = noteContents[key].lowercaseString;
        
        // We only want the last color on the line. The values come from a dictionary, so we can't be sure, so just skip it if it's an earlier one.
        if (line.colorRange.location > range.location) continue;
        
        // We can define a color using both [[color red]] or just [[red]], or #ffffff
        if ([content containsString:@"color "]) {
            // "color red"
            headingColor = [content substringFromIndex:@"color ".length];
            line.colorRange = range;
        }
        else if ([colors containsObject:content] ||
                 (content.length == 7 && [content characterAtIndex:0] == '#')) {
            // pure "red" or "#ff0000"
            headingColor = content;
            line.colorRange = range;
        }
    }

	return headingColor;
}

- (NSArray *)beatsFor:(Line *)line {
    if (line.length == 0) return @[];
    
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


#pragma mark - Parsing notes

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
		// This line doesn't have a preceding note block, ignore
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
	
	Line *prevLine = [self previousLine:line];
	
	line.noteOut = NO;
	bool actuallyCancelsBlock = NO; // If the block was previously ACTUALLY formatted as a block
	if (prevLine.noteOut) {
		actuallyCancelsBlock = YES;
	}
	
	// Look behind for note ranges
	for (NSInteger i = idx-1; i >= 0; i--) {
		Line *l = self.lines[i];
		
		if ([l.string containsString:@"[["]) {
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
		return changedIndices;
	}

	// Look forward for note ranges
	for (NSInteger i = idx; i < self.lines.count; i++) {
		Line *l = self.lines[i];
		
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



#pragma mark - Accessing lines based on some other value

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

/**
 This method returns the line index at given position in document. It uses a cyclical lookup, so the method won't iterate through all the lines every time.
 Instead, it first checks the line it returned the last time, and after that, starts to iterate through
 */
- (NSUInteger)lineIndexAtPosition:(NSUInteger)position
{
    NSArray* lines = self.safeLines;
    NSUInteger actualIndex = NSNotFound;
    NSInteger lastFoundPosition = 0;
    
    // First check if we are still on the same line as before
	if (NSLocationInRange(_lastLineIndex, NSMakeRange(0, lines.count))) {
        Line* lastEdited = lines[_lastLineIndex];
        lastFoundPosition = lastEdited.position;
        
		if (NSLocationInRange(position, lastEdited.range)) {
			return _lastLineIndex;
		}
	}
    
    // Cyclical array lookup from the last found position
    Line* result = [self findNeighbourIn:lines origin:_lastLineIndex descending:(position < lastFoundPosition) cacheIndex:&actualIndex block:^BOOL(id item) {
        Line* l = item;
        return NSLocationInRange(position, l.range);
    }];
    
    if (result != nil) {
        _lastLineIndex = actualIndex;
        _lastEditedLine = result;
        
        return actualIndex;
    } else {
        return self.lines.count - 1;
    }
}

/// Returns line type at given full string index 
- (LineType)lineTypeAt:(NSInteger)index
{
	Line * line = [self lineAtPosition:index];
	
	if (!line) return action;
	else return line.type;
}

#pragma mark - Title page

- (NSString*)titlePageAsString {
    NSMutableString *string = NSMutableString.new;
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        [string appendFormat:@"%@\n", line.string];
    }
    return string;
}

- (NSArray<Line*>*)titlePageLines {
    NSMutableArray *lines = NSMutableArray.new;
    
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        [lines addObject:line];
    }
    
    return lines;
}

- (NSArray< NSDictionary<NSString*,NSArray<Line*>*>*>*)parseTitlePage {
    [self.titlePage removeAllObjects];
    
    // Store the latest key
    NSString *key = @"";
    
    // Iterate through lines and break when we encounter a non- title page line
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        
        // See if there is a key present on the line ("Title: ..." -> "Title")
        if (line.titlePageKey.length > 0) {
            key = line.titlePageKey.lowercaseString;
            if ([key isEqualToString:@"author"]) key = @"authors";
            
            NSMutableDictionary* titlePageValue = [NSMutableDictionary dictionaryWithDictionary:@{ key: NSMutableArray.new }];
            [self.titlePage addObject:titlePageValue];
        }
        
        // Find the correct item in an array of dictionaries
        // [ { "title": [Line] } , { ... }, ... ]
        NSMutableArray *items = [self titlePageArrayForKey:key];
        if (items == nil) continue;
        
        // Add the line into the items of the current line
        [items addObject:line];
    }
    
    return self.titlePage;
}

- (NSMutableArray<Line*>*)titlePageArrayForKey:(NSString*)key {
    for (NSMutableDictionary* d in self.titlePage) {
        if ([d.allKeys.firstObject isEqualToString:key]) return d[d.allKeys.firstObject];
    }
    return nil;
}

/*
- (NSDictionary<NSString*,NSArray<Line*>*>*)titlePageDictionary {
    
}
*/


#pragma mark - Outline Data

/// Returns a tree structure for the outline. Only top-level elements are included, get the rest using `element.chilren`.
- (NSArray*)outlineTree {
    NSMutableArray* tree = NSMutableArray.new;
    
    NSInteger topLevelDepth = 0;
    
    for (OutlineScene* scene in self.outline) {
        if (scene.type == section) {
            // First define top level depth
            if (scene.sectionDepth > topLevelDepth && topLevelDepth == 0) {
                topLevelDepth = scene.sectionDepth;
            }
            else if (scene.sectionDepth < topLevelDepth) {
                topLevelDepth = scene.sectionDepth;
            }
            
            // Add section to tree if applicable
            if (scene.sectionDepth == topLevelDepth) {
                [tree addObject:scene];
            }

        } else if (scene.sectionDepth == 0) {
            // Add bottom-level objects (scenes) by default
            [tree addObject:scene];
        }
    }
    
    return tree;
}

/// Returns the first outline element which contains at least a part of the given range.
- (OutlineScene*)outlineElementInRange:(NSRange)range {
    for (OutlineScene *scene in self.safeOutline) {
        if (NSIntersectionRange(range, scene.range).length > 0) {
            return scene;
        }
    }
    return nil;
}

/// Updates scene numbers for scenes. Autonumbered will get incremented automatically.
/// - note: the arrays can contain __both__ `OutlineScene` or `Line` items to be able to update line content individually without building an outline.
- (void)updateSceneNumbers:(NSArray*)autoNumbered forcedNumbers:(NSSet*)forcedNumbers {
    static NSArray* postfixes;
    if (postfixes == nil) postfixes = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G"];

    NSInteger sceneNumber = [self sceneNumberOrigin];
    for (id item in autoNumbered) {
        Line* line; OutlineScene* scene;
        
        if ([item isKindOfClass:OutlineScene.class]) {
            // This was a scene
            line = ((OutlineScene*)item).line;
            scene = item;
        }
        else {
            // This was a plain Line object
            line = item;
        }
        
        if (line.omitted) {
            line.sceneNumber = @"";
            continue;
        }
        
        NSString* oldSceneNumber = line.sceneNumber;
        NSString* s = [NSString stringWithFormat:@"%lu", sceneNumber];
                
        if ([forcedNumbers containsObject:s]) {
            for (NSInteger i=0; i<postfixes.count; i++) {
                s = [NSString stringWithFormat:@"%lu%@", sceneNumber, postfixes[i]];
                if (![forcedNumbers containsObject:s]) break;
            }
        }
        
        if (![oldSceneNumber isEqualToString:s]) {
            if (scene != nil) [self.outlineChanges.updated addObject:scene];
        }

        line.sceneNumber = s;
        sceneNumber++;
    }
}

/// Returns a set of all scene numbers in the outline
- (NSSet*)sceneNumbersInOutline {
    NSMutableSet<NSString*>* sceneNumbers = NSMutableSet.new;
    for (OutlineScene* scene in self.outline) {
        [sceneNumbers addObject:scene.sceneNumber];
    }
    return sceneNumbers;
}

/// Returns the number from which automatic scene numbering should start from
- (NSInteger)sceneNumberOrigin {
    NSInteger i = [self.documentSettings getInt:DocSettingSceneNumberStart];
    if (i > 0) return i;
    else return 1;
}

/// Gets and resets the changes to outline
- (OutlineChanges*)changesInOutline {
    // Refresh the changed outline elements
    for (OutlineScene* scene in self.outlineChanges.updated) {
        [self updateScene:scene at:NSNotFound lineIndex:NSNotFound];
    }
    for (OutlineScene* scene in self.outlineChanges.added) {
        [self updateScene:scene at:NSNotFound lineIndex:NSNotFound];
    }
    
    // If any changes were made to the outline, rebuild the hierarchy.
    if (self.outlineChanges.hasChanges) [self updateOutlineHierarchy];
    
    OutlineChanges* changes = self.outlineChanges.copy;
    self.outlineChanges = OutlineChanges.new;
    
    return changes;
}


#pragma mark - Handling changes to outline

/// Updates the current outline from scratch (alias of `updateOutline`, here for legacy reasons)
- (void)createOutline {
    [self updateOutlineWithLines:self.safeLines];
}

/// Updates the current outline from scratch.
- (void)updateOutline
{
    [self updateOutlineWithLines:self.safeLines];
}

/// Updates the whole outline from scratch with given lines.
- (void)updateOutlineWithLines:(NSArray<Line*>*)lines
{
    self.outline = NSMutableArray.new;
        
    for (NSInteger i=0; i<lines.count; i++) {
        Line* line = self.lines[i];
        if (!line.isOutlineElement) continue;
        
        [self updateSceneForLine:line at:self.outline.count lineIndex:i];
    }
    
    [self updateOutlineHierarchy];
}

/// Adds an update to this line, but only if needed
- (void)addUpdateToOutlineIfNeededAt:(NSInteger)lineIndex
{
    Line* line = self.safeLines[lineIndex];

    // Nothing to update
    if (line.type != synopse && !line.isOutlineElement && line.noteRanges.count == 0 && line.markerRange.length == 0) return;

    // Find the containing outline element and add an update to it
    NSArray* lines = self.safeLines;
    
    for (NSInteger i = lineIndex; i >= 0; i--) {
        Line* line = lines[i];
        
        if (line.isOutlineElement) {
            [self addUpdateToOutlineAtLine:line];
            return;
        }
    }
}


- (void)addUpdateToOutlineAtLine:(Line*)line {
    OutlineScene* scene = [self outlineElementInRange:line.textRange];
    if (scene) [_outlineChanges.updated addObject:scene];
}


/// Updates the outline element for given line. If you don't know the index for the outline element or line, pass `NSNotFound`.
- (void)updateSceneForLine:(Line*)line at:(NSInteger)index lineIndex:(NSInteger)lineIndex
{
    if (index == NSNotFound) {
        OutlineScene* scene = [self outlineElementInRange:line.textRange];
        index = [self.outline indexOfObject:scene];
    }
    if (lineIndex == NSNotFound) lineIndex = [self indexOfLine:line];
    
    OutlineScene* scene;
    if (index >= self.outline.count || index == NSNotFound) {
        scene = [OutlineScene withLine:line delegate:self];
        [self.outline addObject:scene];
    } else {
        scene = self.outline[index];
    }
    
    [self updateScene:scene at:index lineIndex:lineIndex];
}

/// Updates the given scene and gathers its notes and synopsis lines. If you don't know the line/scene index pass them as `NSNotFound` .
- (void)updateScene:(OutlineScene*)scene at:(NSInteger)index lineIndex:(NSInteger)lineIndex
{
    // We can call this method without specifying the indices
    if (index == NSNotFound) index = [self.outline indexOfObject:scene];
    if (lineIndex == NSNotFound) lineIndex = [self.lines indexOfObject:scene.line];
    
    // Reset everything
    scene.synopsis = NSMutableArray.new;
    scene.beats = NSMutableArray.new;
    scene.notes = NSMutableArray.new;
    scene.markers = NSMutableArray.new;
        
    for (NSInteger i=lineIndex; i<self.lines.count; i++) {
        Line* line = self.lines[i];
        
        if (line != scene.line && line.isOutlineElement) break;
        
        if (line.type == synopse) {
            [scene.synopsis addObject:line];
        }
        
        if (line.noteRanges) {
            [scene.notes addObjectsFromArray:line.noteData];
        }
        
        if (line.markerRange.length > 0) {
            [scene.markers addObject:@{
                @"description": (line.markerDescription) ? line.markerDescription : @"",
                @"color": (line.marker) ? line.marker : @"",
            }];
        }
    }
}

/// Insert an outline element
- (void)addOutlineElement:(Line*)line
{
    NSInteger index = NSNotFound;

    for (NSInteger i=0; i<self.outline.count; i++) {
        OutlineScene* scene = self.outline[i];

        if (line.position <= scene.position) {
            index = i;
            break;
        }
    }

    _changeInOutline = YES;

    OutlineScene* scene = [OutlineScene withLine:line delegate:self];
    if (index == NSNotFound) [self.outline addObject:scene];
    else [self.outline insertObject:scene atIndex:index];

    // Add the scene
    [_outlineChanges.added addObject:scene];
    // We also need to update the previous scene
    if (index > 0 && index != NSNotFound) [_outlineChanges.updated addObject:self.outline[index - 1]];
}

/// Remove given outline elements
- (void)removeOutlineElementForLine:(Line*)line
{
    OutlineScene* scene;
    NSInteger index = NSNotFound;
    for (NSInteger i=0; i<self.outline.count; i++) {
        scene = self.outline[i];
        if (scene.line == line) {
            index = i;
            break;
        }
    }
    
    if (index == NSNotFound) return;
        
    _changeInOutline = YES;
    [_outlineChanges.removed addObject:scene];
    
    [self.outline removeObjectAtIndex:index];

    // We also need to update the previous scene
    if (index > 0) [_outlineChanges.updated addObject:self.outline[index - 1]];
}

/// Rebuilds the outline hierarchy (section depths) and calculates scene numbers.
- (void)updateOutlineHierarchy
{
    NSUInteger sectionDepth = 0;
    NSMutableArray *sectionPath = NSMutableArray.new;
    OutlineScene* currentSection;
    
    NSMutableArray* autoNumbered = NSMutableArray.new;
    NSMutableSet<NSString*>* forcedNumbers = NSMutableSet.new;
        
    for (OutlineScene* scene in self.outline) {
        scene.children = NSMutableArray.new;
        scene.parent = nil;
        
        if (scene.type == section) {
            if (sectionDepth < scene.line.sectionDepth) {
                scene.parent = sectionPath.lastObject;
                [sectionPath addObject:scene];
            } else {
                while (sectionPath.count > 0) {
                    OutlineScene* prevSection = sectionPath.lastObject;
                    [sectionPath removeLastObject];
                    
                    // Break at higher/equal level section
                    if (prevSection.sectionDepth <= scene.sectionDepth) break;
                }
                
                scene.parent = sectionPath.lastObject;
                [sectionPath addObject:scene];
            }
            
            // Any time section depth has changed, we need probably need to update the whole outline structure in UI
            if (scene.sectionDepth != scene.line.sectionDepth) {
                self.outlineChanges.needsFullUpdate = true;
            }
            
            sectionDepth = scene.line.sectionDepth;
            scene.sectionDepth = sectionDepth;
            
            currentSection = scene;
        } else {
            // Manage scene numbers
            if (scene.line.sceneNumberRange.length > 0) [forcedNumbers addObject:scene.sceneNumber];
            else [autoNumbered addObject:scene];
            
            // Update section depth for scene
            scene.sectionDepth = sectionDepth;
            if (currentSection != nil) scene.parent = currentSection;
        }
        
        // Add this object to the children of its parent
        if (scene.parent) {
            [scene.parent.children addObject:scene];
        }
    }
    
    // Do the actual scene number update.
    [self updateSceneNumbers:autoNumbered forcedNumbers:forcedNumbers];
}

/// NOTE: This method is used by line preprocessing to avoid recreating the outline. It has some overlapping functionality with `updateOutlineHierarchy` and `updateSceneNumbers:forcedNumbers:`.
- (void)updateSceneNumbersInLines
{
    NSMutableArray* autoNumbered = NSMutableArray.new;
    NSMutableSet<NSString*>* forcedNumbers = NSMutableSet.new;
    for (Line* line in self.safeLines) {
        if (line.type == heading && !line.omitted) {
            if (line.sceneNumberRange.length > 0) [forcedNumbers addObject:line.sceneNumber];
            else [autoNumbered addObject:line];
        }
    }
    
    [self updateSceneNumbers:autoNumbered forcedNumbers:forcedNumbers];
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

- (NSArray*)safeLines
{
	if (NSThread.isMainThread) return self.lines;
	else return self.lines.copy;
}
- (NSArray*)safeOutline
{
	if (NSThread.isMainThread) return self.outline;
	else return self.outline.copy;
}

- (NSDictionary<NSUUID*, Line*>*)uuidsToLines
{
    // Return the cached version when possible
    if ([self.cachedLines isEqualToArray:self.lines]) {
        return _uuidsToLines;
    }

    // Store the current state of lines
    self.cachedLines = self.lines.copy;
    
    // Create UUID array. This method is usually used by background methods, so we'll need to create a copy of the line array.
    NSArray* lines = self.lines.copy;
    NSMutableDictionary* uuids = NSMutableDictionary.new;
    
    for (Line* line in lines) {
        uuids[line.uuid] = line;
    }
    
    _uuidsToLines = uuids;
    return _uuidsToLines;
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
    NSInteger i = [self lineIndexAtPosition:line.position];
    
    if (i > 0 && i != NSNotFound) return self.safeLines[i - 1];
    else return nil;
}


- (Line*)nextLine:(Line*)line {
    NSArray* lines = self.safeLines;
    NSInteger i = [self lineIndexAtPosition:line.position];
    
    if (i != NSNotFound && i < lines.count - 1) return lines[i + 1];
    else return nil;
}

- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position {
    return [self nextOutlineItemOfType:type from:position depth:NSNotFound];
}
- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth {
    NSInteger idx = [self lineIndexAtPosition:position] + 1;
    NSArray* lines = self.safeLines;
    
    for (NSInteger i=idx; i<lines.count; i++) {
        Line* line = lines[i];
        
        // If no depth was specified, we'll just pass this check.
        NSInteger wantedDepth = (depth == NSNotFound) ? line.sectionDepth : depth;
        
        if (line.type == type && wantedDepth == line.sectionDepth) {
            return line;
        }
    }
    
    return nil;
}

- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position {
    return [self previousOutlineItemOfType:type from:position depth:NSNotFound];
}
- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth {
    NSInteger idx = [self lineIndexAtPosition:position] - 1;
    if (idx == NSNotFound || idx < 0) return nil;
    
    NSArray* lines = self.safeLines;
    
    for (NSInteger i=idx; i>=0; i--) {
        Line* line = lines[i];

        // If no depth was specified, we'll just pass this check.
        NSInteger wantedDepth = (depth == NSNotFound) ? line.sectionDepth : depth;
        
        if (line.type == type && wantedDepth == line.sectionDepth) {
            return line;
        }
    }
    
    return nil;
}


#pragma mark - Element blocks

- (NSArray<NSArray<Line*>*>*)dualDialogueFor:(Line*)line isDualDialogue:(bool*)isDualDialogue {
    if (!line.isDialogue && !line.isDualDialogue) return @[];
    
    NSMutableArray<Line*>* left = NSMutableArray.new;
    NSMutableArray<Line*>* right = NSMutableArray.new;
    
    NSInteger i = [self indexOfLine:line];
    if (i == NSNotFound) return @[];
    
    NSArray* lines = self.safeLines;
    
    while (i >= 0) {
        Line* l = lines[i];
        
        // Break at first normal character
        if (l.type == character) break;
        
        i--;
    }
    
    // Iterate forward
    for (NSInteger j = i; j < lines.count; j++) {
        Line* l = lines[j];
        
        // Break when encountering a character cue (which is not the first line), and whenever seeing anything else than dialogue.
        if (j > i && l.type == character) break;
        else if (!l.isDialogue && !l.isDualDialogue && l.type != empty) break;
        
        if (l.isDialogue) [left addObject:l];
        else [right addObject:l];
    }
    
    // Trim left & right
    while (left.firstObject.type == empty && left.count > 0) [left removeObjectAtIndex:0];
    while (right.lastObject.length == 0 && right.count > 0) [right removeObjectAtIndex:right.count-1];
    
    *isDualDialogue = (left.count > 0 && right.count > 0);
    
    return @[left, right];
}

- (NSArray<Line*>*)blockForRange:(NSRange)range {
	NSMutableArray *blockLines = NSMutableArray.new;
	NSArray *lines;
	
	if (range.length > 0) lines = [self linesInRange:range];
	else lines = @[ [self lineAtPosition:range.location] ];

	for (Line *line in lines) {
		if ([blockLines containsObject:line]) continue;
		
		NSArray *block = [self blockFor:line];
		[blockLines addObjectsFromArray:block];
	}
	
	return blockLines;
}

- (NSArray<Line*>*)blockFor:(Line*)line {
	// The "block" includes the empty line at the end
	
	NSArray *lines = self.lines;
	NSMutableArray *block = NSMutableArray.new;
	NSInteger blockBegin = [lines indexOfObject:line];
	
	// At an empty line, iterate upwards and find out where the block begins
	if (line.type == empty) {
		NSInteger h = blockBegin - 1;
		while (h >= 0) {
			Line *l = lines[h];
			if (l.type == empty) {
				blockBegin = h + 1;
				break;
			}
			h--;
		}
	}
	
	if (line.isDialogueElement || line.isDualDialogueElement) {
		if (!line.isAnyCharacter) {
			NSInteger i = blockBegin - 1;
			while (i >= 0) {
				Line *precedingLine = lines[i];
				if (!(precedingLine.isDualDialogueElement || precedingLine.isDialogueElement) || precedingLine.length == 0) {
					blockBegin = i;
					break;
				}
				
				i--;
			}
		}
	}
	
	NSInteger i = blockBegin;
	while (i < lines.count) {
		Line *l = lines[i];
		[block addObject:l];
		if (l.type == empty || l.length == 0) break;
		
		i++;
	}
	
	return block;
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
		
		result = [result stringByAppendingFormat:@"%@\n", line.stripFormatting];
	}
	
	return result;
}


#pragma mark - Line position lookup

// Cached line for lookup
NSUInteger prevLineAtLocationIndex = 0;

/// Returns line at given POSITION, not index.
- (Line*)lineAtIndex:(NSInteger)position {
	return [self lineAtPosition:position];
}

/// Returns the index in lines array for given line. This method might be probed multiple times, so we'll cache the result. This is a *very* small optimization, we're talking about `0.000001` vs `0.000007`. It's many times faster, but doesn't actually have too big of an effect.
- (NSUInteger)indexOfLine:(Line*)line {
	NSArray *lines = self.safeLines;
	
	static NSInteger previousIndex = NSNotFound;
	if (previousIndex < lines.count && previousIndex >= 0) {
		if (line == (Line*)lines[previousIndex]) {
			return previousIndex;
		}
	}
	
	NSInteger index = [lines indexOfObject:line];
	previousIndex = index;
	return index;
}

/**
 This method finds an element in array that statisfies a certain condition, compared in the block. To optimize the search, you should provide `searchOrigin`  and the direction.
 @returns Returns either the found element or nil if none was found.
 @param array The array to be searched.
 @param searchOrigin Starting index of the search, preferrably the latest result you got from this same method.
 @param descending Set the direction of the search: true for descending, false for ascending.
 @param cacheIndex Pointer for retrieving the index of the found element. Set to NSNotFound if the result is nil.
 @param compare The block for comparison, with the inspected element as argument. If the element statisfies your conditions, return true.
 */
- (id _Nullable)findNeighbourIn:(NSArray*)array origin:(NSUInteger)searchOrigin descending:(bool)descending cacheIndex:(NSUInteger*)cacheIndex block:(BOOL (^)(id item))compare  {
	// Don't go out of range
	if (NSLocationInRange(searchOrigin, NSMakeRange(-1, array.count))) {
		/** Uh, wtf, how does this work?
			We are checking if the search origin is in range from -1 to the full array count,
			so I don't understand how and why this could actually work, and why are we getting
			the correct behavior. The magician surprised themself, too.
		 */
		return nil;
	}
    else if (array.count == 0) return nil;
    
	NSInteger i = searchOrigin;
	NSInteger origin = (descending) ? i - 1 : i + 1;
	if (origin == -1) origin = array.count - 1;
	
	bool stop = NO;
	
	do {
		if (!descending) {
			i++;
			if (i >= array.count) {
				i = 0;
			}
		} else {
			i--;
			if (i < 0) {
				i = array.count - 1;
			}
		}
				
		id item = array[i];
		
		if (compare(item)) {
			*cacheIndex = i;
			return item;
		}
		
		// We have looped around the array (unsuccessfuly)
		if (i == searchOrigin || origin == -1) {
			NSLog(@"Failed to find match for %@ - origin: %lu / searchorigin: %lu  -- %@", self.lines[searchOrigin], origin, searchOrigin, compare);
			break;
		}
		
	} while (stop != YES);
    
    *cacheIndex = NSNotFound;
	return nil;
}

- (Line*)closestPrintableLineFor:(Line*)line {
	NSArray <Line*>* lines = self.lines;
	
	NSInteger i = [lines indexOfObject:line];
	if (i == NSNotFound) return nil;
	
	while (i >= 0) {
		Line *l = lines[i];
		
		if (l.type == action && i > 0) {
			// This might be part of a joined action paragraph block
			Line *prev = lines[i-1];
			if (prev.type == empty && !l.isInvisible) {
				return l;
			}
		}
		else {
			if (!l.isInvisible && !l.isSplitParagraph) return l;
		}
		i--;
	}
	
	return nil;
}

/// Rerturns the line object at given position
- (Line*)lineAtPosition:(NSInteger)position {
	// Let's check the cached line first
	if (NSLocationInRange(position, _prevLineAtLocation.range) && _prevLineAtLocation != nil) {
		return _prevLineAtLocation;
	}
		
	NSArray *lines = self.safeLines; // Use thread safe lines for this lookup
	if (prevLineAtLocationIndex >= lines.count) prevLineAtLocationIndex = 0;
	
	// Quick lookup for first object
	if (position == 0) return lines.firstObject;
	
	// We'll use a circular lookup here.
	// It's HIGHLY possible that we are not just randomly looking for lines,
	// but that we're looking for close neighbours in a for loop.
	// That's why we'll either loop the array forward or backward to avoid
	// unnecessary looping from beginning, which soon becomes very inefficient.
	
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
    if (range.length == 0) {
        OutlineScene* scene = [self sceneAtPosition:range.location];
        return (scene != nil) ? @[scene] : @[];
    }
	
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
		if (NSLocationInRange(index, scene.range) && scene.line != nil) return scene;
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

- (OutlineScene*)sceneWithNumber:(NSString*)sceneNumber {
	for (OutlineScene *scene in self.outline) {
		if ([scene.sceneNumber.lowercaseString isEqualToString:sceneNumber.lowercaseString]) {
			return scene;
		}
	}
	return nil;
}

#pragma mark - Preprocessing for printing

- (NSArray*)preprocessForPrinting {
    return [self preprocessForPrintingWithLines:self.safeLines printNotes:NO];
}

- (NSArray*)preprocessForPrintingPrintNotes:(bool)printNotes
{
	return [self preprocessForPrintingWithLines:self.safeLines printNotes:printNotes];
}


/*
- (NSArray*)preprocessWithBlock:(NSArray* (^)(NSArray* lines))preprocessBlock {
	// This could one day be used to create custom preprocessing through a plugin.
	
	NSArray *lines = self.safeLines;
	NSMutableArray *preprocessed = NSMutableArray.new;
	for (Line* line in lines) {
		if (line.type == empty) continue;
		[preprocessed addObject:line.clone];
	}
	
	return preprocessBlock(lines);
}
 */

- (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines printNotes:(bool)printNotes {
	if (!lines) lines = self.safeLines;
	return [ContinuousFountainParser preprocessForPrintingWithLines:lines printNotes:printNotes settings:self.documentSettings];
}

+ (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines printNotes:(bool)printNotes settings:(BeatDocumentSettings*)documentSettings {
    // The array for printable elements
    NSMutableArray *elements = NSMutableArray.new;
    
    // Create a copy of parsed lines
    NSMutableArray *linesForPrinting = NSMutableArray.array;
    Line *precedingLine;
    
	for (Line* line in lines) {
		[linesForPrinting addObject:line.clone];
                
        // Preprocess split paragraphs
        Line *l = linesForPrinting.lastObject;
        
        if (l.note && !printNotes) continue;
        
        // Reset dual dialogue
        else if (l.type == character) l.nextElementIsDualDialogue = false;
        
        else if (l.type == action || l.type == lyrics || l.type == centered) {
            l.beginsNewParagraph = true;
            
            // BUT in some cases, they don't.
            if (!precedingLine.effectivelyEmpty && precedingLine.type == l.type) {
                l.beginsNewParagraph = false;
                // This is here for backwards compatibility
                // if (precedingLine.type == action) l.isSplitParagraph = true;
            }
        } else {
            l.beginsNewParagraph = true;
        }
        
        precedingLine = l;
	}
	
	// Get scene number offset from the delegate/document settings
	NSInteger sceneNumber = 1;
	if ([documentSettings getInt:DocSettingSceneNumberStart] > 1) {
		sceneNumber = [documentSettings getInt:DocSettingSceneNumberStart];
		if (sceneNumber < 1) sceneNumber = 1;
	}
	
    //
    Line *previousLine;
	for (Line *line in linesForPrinting) {
		// Fix a weird bug for first line
		if (line.type == empty && line.string.length && !line.string.containsOnlyWhitespace) line.type = action;
		
		// Skip over certain elements. Leave notes if needed.
		if (line.type == synopse || line.type == section || (line.omitted && !line.note)) continue;
		else if (!printNotes && line.note) continue;
        else if (line.effectivelyEmpty) {
            previousLine = line;
            continue;
        }
		
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
		
		// Eliminate faux empty lines with only single space. To force whitespace you have to use two spaces.
		if ([line.string isEqualToString:@" "]) {
			line.type = empty;
			continue;
		}
		         
		// Remove misinterpreted dialogue
		if (line.isAnyDialogue && line.string.length == 0) {
			line.type = empty;
			previousLine = line;
			continue;
		}
            		
		// If this is a dual dialogue character cue, we'll need to search for the previous one
        // and make it aware of being a part of a dual dialogue block.
		if (line.type == dualDialogueCharacter) {
			NSInteger i = elements.count - 1;
			while (i >= 0) {
				Line *precedingLine = [elements objectAtIndex:i];
								
				if (precedingLine.type == character) {
					precedingLine.nextElementIsDualDialogue = YES;
					break;
				}
                
                // Break the loop if this is not a dialogue element OR it's another dual dialogue element.
                if (!(precedingLine.isDialogueElement || precedingLine.isDualDialogueElement)) break;

				i--;
			}
		}
        
        [elements addObject:line];
		
		previousLine = line;
	}
    
	return elements;
}

#pragma mark - Line identifiers (UUIDs)

- (NSArray*)lineIdentifiers:(NSArray<Line*>*)lines {
	if (lines == nil) lines = self.lines;
	
	NSMutableArray *uuids = NSMutableArray.new;
	for (Line *line in lines) {
		[uuids addObject:line.uuid];
	}
	return uuids;
}
- (void)setIdentifiers:(NSArray*)uuids {
	for (NSInteger i = 0; i < uuids.count; i++) {
		id item = uuids[i];
		NSUUID *uuid;
		
		if ([item isKindOfClass:NSString.class]) {
			uuid = [NSUUID.alloc initWithUUIDString:item];
		} else {
			uuid = item;
		}
		
		if (i < self.lines.count) {
			Line *line = self.lines[i];
			line.uuid = uuid;
		}
	}
}
- (void)setIdentifiersForOutlineElements:(NSArray*)uuids {
    NSInteger i = 0;
    
    for (Line* line in self.safeLines) {
        if (!line.isOutlineElement) continue;
        
        NSUUID* uuid;
                
        // We can supply both UUID objects and strings
        id item = uuids[i];
        if ([item isKindOfClass:NSString.class]) uuid = [NSUUID.alloc initWithUUIDString:item];
        else if ([item isKindOfClass:NSUUID.class]) uuid = item;
        
        line.uuid = uuid;

        i += 1;
        
        if (i >= uuids.count) break; // Don't go out of range
    }
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


@end
/*
 
 Thank you, Hendrik Noeller, for making Beat possible.
 Without your massive original work, any of this had never happened.
 
 */
