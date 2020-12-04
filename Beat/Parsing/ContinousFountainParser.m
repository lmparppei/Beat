//
//  ContinousFountainParser.m
//  Writer / Beat
//
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  Parts copyright © 2019-2020 Lauri-Matti Parppei. All rights reserved.

//  Relased under GPL

/*
 
 This code is still mostly based on Hendrik Noeller's work.
 It is heavily modified for Beat, and is all the time more reliable.
 
 Main differences include:
 - double-checking for all-caps actions mistaken for character cues
 - convoluted recursive logic for lookback / lookforward (should be dismantled)
 - title page parsing (mostly for preview & export purposes)
 - new data structure called OutlineScene, which contains scene name and length, as well as a reference to original line
 - overall tweaks to parsing here and there
 - parsing large chunks of text is optimized
 
 The file and class are still called Continous, instead of Continuous, because I haven't had the time and willpower to fix Hendrik's small typo. Also, singular synopsis lines are called 'synopse' for some reason. :-)
 
 
 Future Considerations:
 
 DELEGATION
 
 For now, correcting some faulty interpretation of the Fountain format
 (like all-caps action lines mistaken for character cues) is done in the
 Document class. This should be fixed in order to be able to make porting
 Beat to iOS easier.
 
 Document should act as a delegate for the parser, and there is already one
 implementation in action, changing heading into action. In the same way, we
 should tell the UI to change the character cue line into action, rather than
 the UI making the decision itself and parsing the changes recursively, as
 it happens now.
 
 This is a big, big structural change for my skill level, and requires a lot
 of work and time, which I don't have right now. However, implementing delegation
 would make the Countinuous Parser more reliable and the code much easier to debug.
 
 Lauri-Matti Parppei
 2020
 
 
 Update 2020-11-07: Delegation is now implemented
 
 */

#import "ContinousFountainParser.h"
#import "RegExCategories.h"
#import "Line.h"
#import "NSString+Whitespace.h"
#import "NSMutableIndexSet+Lowest.h"
#import "OutlineScene.h"

@interface  ContinousFountainParser ()
@property (nonatomic) BOOL changeInOutline;
@property (nonatomic) Line *editedLine;
@property (nonatomic) Line *lastEditedLine;
@property (nonatomic) NSUInteger editedIndex;

// Title page parsing
@property (nonatomic) NSString *openTitlePageKey;
@property (nonatomic) NSString *previousTitlePageKey;

@end

@implementation ContinousFountainParser

#pragma mark - Parsing

#pragma mark Bulk Parsing

- (ContinousFountainParser*)staticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings {
	return [self initWithString:string delegate:nil settings:settings];
}
- (ContinousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate {
	return [self initWithString:string delegate:delegate settings:nil];
}
- (ContinousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate settings:(BeatDocumentSettings*)settings {
	self = [super init];
	
	if (self) {
		_lines = [NSMutableArray array];
		_outline = [NSMutableArray array];
		_changedIndices = [NSMutableArray array];
		_titlePage = [NSMutableArray array];
		_storylines = [NSMutableArray array];
		_delegate = delegate;
		_staticDocumentSettings = settings;
		
		[self parseText:string];
	}
	
	return self;
}
- (ContinousFountainParser*)initWithString:(NSString*)string
{
	return [self initWithString:string delegate:nil];
}

- (void)parseText:(NSString*)text
{
	_lines = [NSMutableArray array];
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    
    NSUInteger position = 0; //To track at which position every line begins
	NSUInteger sceneIndex = -1;
	
	Line *previousLine;
	
    for (NSString *rawLine in lines) {
        NSInteger index = [self.lines count];
        Line* line = [[Line alloc] initWithString:rawLine position:position];
        [self parseTypeAndFormattingForLine:line atIndex:index];
		
		// Quick fix for mistaking an ALL CAPS action to character cue
		if (previousLine.type == character && (line.string.length < 1 || line.type == empty)) {
			previousLine.type = [self parseLineType:previousLine atIndex:index - 1 recursive:NO currentlyEditing:NO];
			if (previousLine.type == character) previousLine.type = action;
		}
		
		// For a quick scene index lookup
		if (line.type == heading || line.type == synopse || line.type == section) {
			sceneIndex++;
			line.sceneIndex = sceneIndex;
		}
		
		// Quick fix for recognizing split paragraphs
		if (line.type == action &&
			line.string.length > 0 &&
			previousLine.type == action &&
			previousLine.string.length > 0) line.isSplitParagraph = YES;
		
        //Add to lines array
        [self.lines addObject:line];
        //Mark change in buffered changes
        [self.changedIndices addObject:@(index)];
        
        position += [rawLine length] + 1; // +1 for newline character
		previousLine = line;
    }
    _changeInOutline = YES;
}

// This sets EVERY INDICE as changed.
- (void)resetParsing {
	NSInteger index = 0;
	while (index < [self.lines count]) {
		[self.changedIndices addObject:@(index)];
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
 
 */

- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string
{
	_lastEditedLine = nil;
	_editedIndex = -1;

    NSMutableIndexSet *changedIndices = [[NSMutableIndexSet alloc] init];
    if (range.length == 0) { //Addition
		[changedIndices addIndexes:[self parseAddition:string atPosition:range.location]];
		/*
        for (int i = 0; i < string.length; i++) {
            NSString* character = [string substringWithRange:NSMakeRange(i, 1)];
            [changedIndices addIndexes:[self parseCharacterAdded:character
                                                      atPosition:range.location+i]];
        }
		 */
    } else if ([string length] == 0) { //Removal
//		for (int i = 0; i < range.length; i++) {
//			[changedIndices addIndexes:[self parseCharacterRemovedAtPosition:range.location]];
//		}

		[changedIndices addIndexes:[self parseRemovalAt:range]];
		
    } else { //Replacement
//        for (int i = 0; i < range.length; i++) {
//            [changedIndices addIndexes:[self parseCharacterRemovedAtPosition:range.location]];
//        }
		
		//First remove
		[changedIndices addIndexes:[self parseRemovalAt:range]];

        // Then add
		[changedIndices addIndexes:[self parseAddition:string atPosition:range.location]];
		
//        for (int i = 0; i < string.length; i++) {
//            NSString* character = [string substringWithRange:NSMakeRange(i, 1)];
//            [changedIndices addIndexes:[self parseCharacterAdded:character
//                                                      atPosition:range.location+i]];
//        }
    }
    
    [self correctParsesInLines:changedIndices];
}

- (void)ensurePositions {
	// This is a method to fix anything that might get broken :-)

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
	if (line.type == heading || line.type == synopse || line.type == section) _changeInOutline = true;
	
    NSUInteger indexInLine = position - line.position;
	
	// If the added string is a multi-line block, we need to optimize the addition.
	// Else, just parse it character-by-character.
	if ([string rangeOfString:@"\n"].location != NSNotFound && string.length > 1) {
		// Split the original line into two
		NSString *head = [line.string substringToIndex:indexInLine];
		NSString *tail = (indexInLine + 1 <= line.string.length) ? [line.string substringFromIndex:indexInLine] : @"";
		
		/*
		NSLog(@"===== len %lu", string.length);
		NSInteger indx = 0;
		for (int i = 0; i < string.length; i++) {
			unichar chr = [string characterAtIndex:i];
			if (chr == '\n') printf("\\n\n"); else printf("%c", chr);
			indx = i;
		}
		NSLog(@"===== total %lu", indx);
		*/
		 
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
					addedLine = [[Line alloc] initWithString:tail position:offset];

					[self.lines insertObject:addedLine atIndex:lineIndex + i];
					[self incrementLinePositionsFromIndex:lineIndex + i + 1 amount:addedLine.string.length];
					offset += newLine.length + 1;
				} else {
					addedLine = [[Line alloc] initWithString:newLine position:offset];
					
					[self.lines insertObject:addedLine atIndex:lineIndex + i];
					[self incrementLinePositionsFromIndex:lineIndex + i + 1 amount:addedLine.string.length + 1];
					offset += newLine.length + 1;
				}
			}
		}
		
		[changedIndices addIndexesInRange:NSMakeRange(lineIndex, newLines.count)];
	} else {
        for (int i = 0; i < string.length; i++) {
            NSString* character = [string substringWithRange:NSMakeRange(i, 1)];
			[changedIndices addIndexes:[self parseCharacterAdded:character
                                                      atPosition:position+i]];
        }
	}
	
	[self report];
	
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

- (NSIndexSet*)parseCharacterAdded:(NSString*)character atPosition:(NSUInteger)position
{
	NSUInteger lineIndex;
	
	if (_editedIndex >= self.lines.count || _editedIndex < 0) {
		_editedIndex = [self lineIndexAtPosition:position];
	}
	
	lineIndex = _editedIndex;
	Line* line = self.lines[lineIndex];

    NSUInteger indexInLine = position - line.position;
	
	if (line.type == heading || line.type == synopse || line.type == section) _changeInOutline = true;
	
    if ([character isEqualToString:@"\n"]) {
        NSString* cutOffString;
        if (indexInLine == [line.string length]) {
            cutOffString = @"";
        } else {
            cutOffString = [line.string substringFromIndex:indexInLine];
            line.string = [line.string substringToIndex:indexInLine];
        }
        
        Line* newLine = [[Line alloc] initWithString:cutOffString
                                            position:position+1];
        [self.lines insertObject:newLine atIndex:lineIndex+1];
        
        [self incrementLinePositionsFromIndex:lineIndex+2 amount:1];
        
        return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lineIndex, 2)];
    } else {
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
	
	NSString *stringToRemove = [[self rawText] substringWithRange:range];
	NSInteger lineBreaks = [stringToRemove componentsSeparatedByString:@"\n"].count - 1;
	
	if (lineBreaks > 1) {
		// If there are 2+ line breaks, optimize the operation
		NSInteger lineIndex = [self lineIndexAtPosition:range.location];
		Line *firstLine = self.lines[lineIndex];
		
		// Change in outline
		if (firstLine.type == heading || firstLine.type == section || firstLine.type == synopse) _changeInOutline = YES;
		
		NSUInteger indexInLine = range.location - firstLine.position;
		
		NSString *retain = [firstLine.string substringToIndex:indexInLine];
		NSInteger nextIndex = lineIndex + 1;
				
		// +1 for line break
		NSInteger offset = firstLine.string.length - retain.length + 1;
		
		for (NSInteger i = 1; i <= lineBreaks; i++) {
			Line* nextLine = self.lines[nextIndex];
			
			if (nextLine.type == heading || nextLine.type == section || nextLine.type == synopse) {
				_changeInOutline = YES;
			}
			
			if (i < lineBreaks) {
				// NSLog(@"remove: %@", nextLine.string);
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
		// Do it normally
		for (int i = 0; i < range.length; i++) {
			[changedIndices addIndexes:[self parseCharacterRemovedAtPosition:range.location]];
		}
	}
	
	[self report];
	
	return changedIndices;
}
- (NSIndexSet*)parseCharacterRemovedAtPosition:(NSUInteger)position
{
	/*
	 
	 I have struggled to make this faster.
	 The solution (for now) is to cache the result of lineIndexAtPosition,
	 but it's not the ideal workaround. You can find a failed attempt at removing
	 larger chunks of text above. That method totally messes up the line indexes.
	 
	 Creating the temporary strings here might be the problem, though.
	 If I could skip those steps, iterating character by character might not be
	 that heavy of an operation. We could have @property NSRange affectedRange
	 and have this method check itself against that. If we'll be removing the next
	 character, too, don't bother appending any strings anywhere.
	 
	 */
	
	// Get index for current line
	NSUInteger lineIndex;
		
	if (_editedIndex >= self.lines.count || _editedIndex < 0) {
		_editedIndex = [self lineIndexAtPosition:position];
	}
	
	lineIndex = _editedIndex;
    Line* line = self.lines[lineIndex];

	NSUInteger indexInLine = position - line.position;

	if (indexInLine > line.string.length) indexInLine = line.string.length;
	
    if (indexInLine == [line.string length]) {
        //Get next line and put together
        if (lineIndex == [self.lines count] - 1) {
            return nil; //Removed newline at end of document without there being an empty line - should never happen but to be sure...
        }
		
        Line* nextLine = self.lines[lineIndex+1];
        line.string = [line.string stringByAppendingString:nextLine.string];
        if (nextLine.type == heading || nextLine.type == section || nextLine.type == synopse) {
            _changeInOutline = YES;
        }
		
        [self.lines removeObjectAtIndex:lineIndex+1];
        [self decrementLinePositionsFromIndex:lineIndex+1 amount:1];
        
        return [[NSIndexSet alloc] initWithIndex:lineIndex];
    } else {
        NSArray* pieces = @[[line.string substringToIndex:indexInLine],
                            [line.string substringFromIndex:indexInLine + 1]];
        
        line.string = [pieces componentsJoinedByString:@""];
        [self decrementLinePositionsFromIndex:lineIndex+1 amount:1];
        
        
        return [[NSIndexSet alloc] initWithIndex:lineIndex];
    }
}

- (NSUInteger)lineIndexAtPosition:(NSUInteger)position
{
	// First check the line we edited last
	bool wouldReturnMatch = NO;
	NSUInteger match = -1;
	
	if (_lastEditedLine) {
		if (_lastEditedLine.position > position &&
			position < _lastEditedLine.string.length + _lastEditedLine.position) {
			match = [self.lines indexOfObject:_lastEditedLine] - 1;
			if (match < self.lines.count && match >= 0) {
				wouldReturnMatch = YES;
				return match;
			}
		}
	}
	
    for (int i = 0; i < [self.lines count]; i++) {
        Line* line = self.lines[i];
        
        if (line.position > position) {
			_lastEditedLine = line;
						
            return i-1;
        }
    }
    return [self.lines count] - 1;
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

- (void)correctParsesInLines:(NSMutableIndexSet*)lineIndices
{
    while ([lineIndices count] > 0) {
        [self correctParseInLine:[lineIndices lowestIndex] indicesToDo:lineIndices];
    }
}

- (void)correctParseInLine:(NSUInteger)index indicesToDo:(NSMutableIndexSet*)indices
{
    //Remove index as done from array if in array
    if ([indices count]) {
        NSUInteger lowestToDo = [indices lowestIndex];
        if (lowestToDo == index) {
            [indices removeIndex:index];
        }
    }
    
    Line* currentLine = self.lines[index];
	
	//Correct type on this line
    LineType oldType = currentLine.type;
    bool oldOmitOut = currentLine.omitOut;
    [self parseTypeAndFormattingForLine:currentLine atIndex:index];
    
    if (!self.changeInOutline && (oldType == heading || oldType == section || oldType == synopse ||
        currentLine.type == heading || currentLine.type == section || currentLine.type == synopse)) {
        self.changeInOutline = YES;
    }
    
    [self.changedIndices addObject:@(index)];
    	
    if (oldType != currentLine.type || oldOmitOut != currentLine.omitOut) {
        //If there is a next element, check if it might need a reparse because of a change in type or omit out
        if (index < [self.lines count] - 1) {
            Line* nextLine = self.lines[index+1];
			if (currentLine.isTitlePage ||					// if line is a title page, parse next line too
                currentLine.type == section ||
                currentLine.type == synopse ||
                currentLine.type == character ||            //if the line became anythign to
                currentLine.type == parenthetical ||        //do with dialogue, it might cause
                currentLine.type == dialogue ||             //the next lines to be dialogue
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
                nextLine.omitIn != currentLine.omitOut) { //If the next line expected the end
                                                            //of the last line to end or not end
                                                            //with an open omit other than the
                                                            //line actually does, omites changed
                
                [self correctParseInLine:index+1 indicesToDo:indices];
            }
        }
    }
	
	
	if (currentLine.string.length > 0 && index > 1) {
		// Check for all-caps action lines mistaken for character cues
		
		//Line* lineBeforeThat = [self.lines objectAtIndex:index - 2];
		//Line* preceedingLine = [self.lines objectAtIndex:index - 1];
		
		// NSLog(@"Cursor: %lu // Line: %@ (%lu-%lu)", _delegate.selectedRange.location, currentLine.string, currentLine.position, currentLine.position + currentLine.string.length);
		
		/*
		NSLog(@"current: %@  //  %@ (%@) - %@ (%@)", currentLine.string, lineBeforeThat.string, lineBeforeThat.typeAsString, preceedingLine.string, preceedingLine.typeAsString);
		
		if (preceedingLine.string.length == 0 && lineBeforeThat.type == character) {
			NSLog(@"to action: %@", lineBeforeThat.string);
		}
		 */
		 
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

#define BOLD_PATTERN_LENGTH 2
#define ITALIC_PATTERN_LENGTH 1
#define UNDERLINE_PATTERN_LENGTH 1
#define NOTE_PATTERN_LENGTH 2
#define OMIT_PATTERN_LENGTH 2

#define COLOR_PATTERN "color"
#define STORYLINE_PATTERN "storyline" // wtf is this, past me?

- (void)parseTypeAndFormattingForLine:(Line*)line atIndex:(NSUInteger)index
{
    line.type = [self parseLineType:line atIndex:index];
	
    NSUInteger length = line.string.length;
    unichar charArray[length];
    [line.string getCharacters:charArray];
    
    NSMutableIndexSet* starsInOmit = [[NSMutableIndexSet alloc] init];
    if (index == 0) {
        line.omitedRanges = [self rangesOfOmitChars:charArray
                                             ofLength:length
                                               inLine:line
                                     lastLineOmitOut:NO
                                          saveStarsIn:starsInOmit];
    } else {
        Line* previousLine = self.lines[index-1];
        line.omitedRanges = [self rangesOfOmitChars:charArray
                                             ofLength:length
                                               inLine:line
                                     lastLineOmitOut:previousLine.omitOut
                                          saveStarsIn:starsInOmit];
    }
    
    line.boldRanges = [self rangesInChars:charArray
                                 ofLength:length
                                  between:BOLD_PATTERN
                                      and:BOLD_PATTERN
                               withLength:BOLD_PATTERN_LENGTH
                         excludingIndices:starsInOmit];
    line.italicRanges = [self rangesInChars:charArray
                                   ofLength:length
                                    between:ITALIC_PATTERN
                                        and:ITALIC_PATTERN
                                 withLength:ITALIC_PATTERN_LENGTH
                           excludingIndices:starsInOmit];
    line.underlinedRanges = [self rangesInChars:charArray
                                       ofLength:length
                                        between:UNDERLINE_PATTERN
                                            and:UNDERLINE_PATTERN
                                     withLength:UNDERLINE_PATTERN_LENGTH
                               excludingIndices:nil];
    line.noteRanges = [self rangesInChars:charArray
                                 ofLength:length
                                  between:NOTE_OPEN_PATTERN
                                      and:NOTE_CLOSE_PATTERN
                               withLength:NOTE_PATTERN_LENGTH
                         excludingIndices:nil];
	
    if (line.type == heading) {
		line.sceneNumberRange = [self sceneNumberForChars:charArray ofLength:length];
        
		if (line.sceneNumberRange.length == 0) {
            line.sceneNumber = nil;
        } else {
            line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
        }
		
		line.color = [self colorForHeading:line];
		line.storylines = [self storylinesForHeading:line];
    }
	
	// set color for outline elements
	if (line.type == heading || line.type == section || line.type == synopse) {
		line.color = [self colorForHeading:line];
	}
	
	if (line.isTitlePage) {
		if ([line.string rangeOfString:@":"].location != NSNotFound && line.string.length > 0) {
			// If the title doesn't begin with \t or space, format it as key name	
			if ([line.string characterAtIndex:0] != ' ' &&
				[line.string characterAtIndex:0] != '\t' ) line.titleRange = NSMakeRange(0, [line.string rangeOfString:@":"].location + 1);
			else line.titleRange = NSMakeRange(0, 0);
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
	
	Line* preceedingLine = (index == 0) ? nil : (Line*) self.lines[index-1];
	
	// So we need to pull all sorts of tricks out of our sleeve here.
	// Usually Fountain files are parsed from bottom to up, but here we are parsing in a linear manner.
	// I have no idea how I got this to work but it does.

	// Check for all-caps actions mistaken for character cues
	if (self.delegate && NSThread.isMainThread) {
		if (preceedingLine.string.length == 0 && NSLocationInRange(self.delegate.selectedRange.location + 1, line.range)) {
			// If the preceeding line is empty, we'll check the line before that, too, to be sure.
			// This way we can check for false character cues
			if (index > 1) {
				Line* lineBeforeThat = (Line*)self.lines[index - 2];
				if (lineBeforeThat.type == character) {
					lineBeforeThat.type = action;
					[self.changedIndices addObject:@(index - 2)];
				}
			}
		}
	}
	
    // Check if empty.
    if (length == 0) {
		// If previous line is part of dialogue block, this line becomes dialogue right away
		// Else it's just empty.
		if (preceedingLine.type == character || preceedingLine.type == parenthetical || preceedingLine.type == dialogue) {
			// If preceeding line is formatted as dialogue BUT it's empty, we'll just return empty. OMG IT WORKS!
			if ([preceedingLine.string length] > 0) {
				// If preceeded by character cue, return dialogue
				if (preceedingLine.type == character) return dialogue;
				// If its a parenthetical line, return dialogue
				else if (preceedingLine.type == parenthetical) return dialogue;
				// AND if its just dialogue, return action.
				else return action;
			} else {
				return empty;
			}
		} else {
			return empty;
		}
    }
	
    char firstChar = [string characterAtIndex:0];
    char lastChar = [string characterAtIndex:length-1];
    
    bool containsOnlyWhitespace = [string containsOnlyWhitespace]; //Save to use again later
    bool twoSpaces = (length == 2 && firstChar == ' ' && lastChar == ' ');
    //If not empty, check if contains only whitespace. Exception: two spaces indicate a continued whatever, so keep them
    if (containsOnlyWhitespace && !twoSpaces) {
        return empty;
    }
	
	// Reset to zero to avoid strange formatting issues
	line.numberOfPreceedingFormattingCharacters = 0;
	
    //Check for forces (the first character can force a line type)
    if (firstChar == '!') {
        line.numberOfPreceedingFormattingCharacters = 1;
        return action;
    }
    if (firstChar == '@') {
        line.numberOfPreceedingFormattingCharacters = 1;
        return character;
    }
    if (firstChar == '~') {
        line.numberOfPreceedingFormattingCharacters = 1;
        return lyrics;
    }
    if (firstChar == '>' && lastChar != '<') {
        line.numberOfPreceedingFormattingCharacters = 1;
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
		line.numberOfPreceedingFormattingCharacters = depth;
        return section;
    }
    if (firstChar == '=' && (length >= 2 ? [string characterAtIndex:1] != '=' : YES)) {
        line.numberOfPreceedingFormattingCharacters = 1;
        return synopse;
    }
	
	// '.' forces a heading. Because our American friends love to shoot their guns like we Finnish people love our booze, screenwriters might start dialogue blocks with such "words" as '.44'
	// So, let's NOT return a scene heading IF the previous line is not empty OR is a character OR is a parenthetical...
    if (firstChar == '.' && length >= 2 && [string characterAtIndex:1] != '.') {
		if (preceedingLine) {
			if (preceedingLine.type == character) return dialogue;
			if (preceedingLine.type == parenthetical) return dialogue;
			if ([preceedingLine.string length] > 0) return action;
		}
		
		line.numberOfPreceedingFormattingCharacters = 1;
		return heading;
    }
		
    //Check for scene headings (lines beginning with "INT", "EXT", "EST",  "I/E"). "INT./EXT" and "INT/EXT" are also inside the spec, but already covered by "INT".
	if (preceedingLine.type == empty ||
		[preceedingLine.string length] == 0 ||
		line.position == 0 ||
		[preceedingLine.string isEqualToString:@"*/"] ||
		[preceedingLine.string isEqualToString:@"/*"]) {
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
					if (nextChar == '.' || nextChar == ' ') {
						// Line begins with int. or ext. etc.
						// Signal change into the document to make undo work correctly
						if (line.type != heading) [self.delegate actionChangedToHeadingAt:line];
						return heading;
					} else {
						// If the line is just "internal" or "estoy aqui", it should NOT be a scene heading
						if (line.type == heading) {
							// Signal change to action
							[self.delegate headingChangedToActionAt:line];
						}
					}
				}
            }
        }
    }
	
	//Check for title page elements. A title page element starts with "Title:", "Credit:", "Author:", "Draft date:" or "Contact:"
	//it has to be either the first line or only be preceeded by title page elements.
	if (!preceedingLine ||
		preceedingLine.type == titlePageTitle ||
		preceedingLine.type == titlePageAuthor ||
		preceedingLine.type == titlePageCredit ||
		preceedingLine.type == titlePageSource ||
		preceedingLine.type == titlePageContact ||
		preceedingLine.type == titlePageDraftDate ||
		preceedingLine.type == titlePageUnknown) {
		
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
			 return preceedingLine.type;
			 } else if (length >= 1 && [[string substringToIndex:1] isEqualToString:@"\t"]) {
			 line.numberOfPreceedingFormattingCharacters = 1;
			 return preceedingLine.type;
			 } */
			if (_openTitlePageKey) {
				NSMutableDictionary* dict = [_titlePage lastObject];
				[(NSMutableArray*)dict[_openTitlePageKey] addObject:line.string];
			}
			
			return preceedingLine.type;
		}
		
	}
	    
    //Check for transitionLines and page breaks
    if (length >= 3) {
        //transitionLine happens if the last three chars are "TO:"
        NSRange lastThreeRange = NSMakeRange(length-3, 3);
        NSString *lastThreeChars = [[string substringWithRange:lastThreeRange] lowercaseString];
        if ([lastThreeChars isEqualToString:@"to:"]) {
            return transitionLine;
        }
        
        //Page breaks start with "==="
        NSString *firstChars;
        if (length == 3) {
            firstChars = lastThreeChars;
        } else {
            firstChars = [string substringToIndex:3];
        }
        if ([firstChars isEqualToString:@"==="]) {
            return pageBreak;
        }
    }
    
    //Check if all uppercase (and at least 3 characters to not indent every capital leter before anything else follows) = character name.
    if (preceedingLine.type == empty || [preceedingLine.string length] == 0) {
        if (length >= 3 && [string containsOnlyUppercase] && !containsOnlyWhitespace) {
            // A character line ending in ^ is a double dialogue character
            if (lastChar == '^') {
				// PLEASE NOTE:
				// nextElementIsDualDialogue is ONLY used while staticly parsing for printing,
				// and SHOULD NOT be used anywhere else, as it won't be updated.
				NSUInteger i = index - 1;
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
				// WIP
				
				if (index + 2 < self.lines.count && currentLine) {
					Line* nextLine = (Line*)self.lines[index+1];
					Line* twoLinesOver = (Line*)self.lines[index+2];
					
					if (recursive && [nextLine.string length] == 0 && [twoLinesOver.string length] > 0) {
						return action;
					}
				}
                return character;
            }
        }
    }
    
    //Check for centered text
    if (firstChar == '>' && lastChar == '<') {
        return centered;
    }

    //If it's just usual text, see if it might be (double) dialogue or a parenthetical, or section/synopsis
    if (preceedingLine) {
        if (preceedingLine.type == character || preceedingLine.type == dialogue || preceedingLine.type == parenthetical) {
            //Text in parentheses after character or dialogue is a parenthetical, else its dialogue
			if (firstChar == '(' && [preceedingLine.string length] > 0) {
                return parenthetical;
            } else {
				if ([preceedingLine.string length] > 0) {
					return dialogue;
				} else {
					return action;
				}
            }
        } else if (preceedingLine.type == dualDialogueCharacter || preceedingLine.type == dualDialogue || preceedingLine.type == dualDialogueParenthetical) {
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
		else if (preceedingLine.type == section) {
            return section;
        } else if (preceedingLine.type == synopse) {
            return synopse;
        }
		*/
    }
    
    return action;
}

- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength excludingIndices:(NSIndexSet*)excludes
{
    NSMutableIndexSet* indexSet = [[NSMutableIndexSet alloc] init];
    
    NSInteger lastIndex = length - delimLength; //Last index to look at if we are looking for start
    NSInteger rangeBegin = -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
    
    for (int i = 0;;i++) {
		if (i > lastIndex) break;
		
        // If this index is contained in the omit character indexes, skip
		if ([excludes containsIndex:i]) continue;
		
		// No range is currently inspected
        if (rangeBegin == -1) {
            bool match = YES;
            for (int j = 0; j < delimLength; j++) {
				// Check for escape character (like \*)
				if (i > 0 && string[j + i - 1] == '\\') {
					match = NO;
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
                }
            }
            if (match) {
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

- (NSRange)sceneNumberForChars:(unichar*)string ofLength:(NSUInteger)length
{
	// Uh, Beat scene coloring (ie. note ranges) messed this unichar array lookup.
	
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

- (NSString *)colorForHeading:(Line *)line
{
	__block NSString *color = @"";
	
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSString * note = [line.string substringWithRange:range];

		NSRange noteRange = NSMakeRange(NOTE_PATTERN_LENGTH, [note length] - NOTE_PATTERN_LENGTH * 2);
		note =  [note substringWithRange:noteRange];
        
		if ([note localizedCaseInsensitiveContainsString:@COLOR_PATTERN] == true) {
			if ([note length] > [@COLOR_PATTERN length] + 1) {
				NSRange colorRange = [note rangeOfString:@COLOR_PATTERN options:NSCaseInsensitiveSearch];
				color = [note substringWithRange:NSMakeRange(colorRange.length, [note length] - colorRange.length)];
				color = [color stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			}
		}
	}];

	return color;
}
- (NSArray *)storylinesForHeading:(Line *)line {
	__block NSMutableArray *storylines = [NSMutableArray array];
	
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSString * note = [line.string substringWithRange:range];

		NSRange noteRange = NSMakeRange(NOTE_PATTERN_LENGTH, [note length] - NOTE_PATTERN_LENGTH * 2);
		note =  [note substringWithRange:noteRange];
        
		if ([note localizedCaseInsensitiveContainsString:@STORYLINE_PATTERN] == true) {
			// Make sure it is really a storyline block with space & all
			if ([note length] > [@STORYLINE_PATTERN length] + 1) {
				line.storylineRange = range; // Save for editor use
				
				// Only the storylines
				NSRange storylineRange = [note rangeOfString:@STORYLINE_PATTERN options:NSCaseInsensitiveSearch];
			
				NSString *storylineString = [note substringWithRange:NSMakeRange(storylineRange.length, [note length] - storylineRange.length)];
				
				// Check that the user didn't mistype it "storylines"
				if (storylineString.length > 2) {
					NSString *firstChrs = [storylineString.uppercaseString substringToIndex:2];
					if ([firstChrs isEqualToString:@"S "]) storylineString = [storylineString substringFromIndex:2];
				}
				
				NSArray *components = [storylineString componentsSeparatedByString:@","];
				// Make uppercase & trim
				for (NSString* string in components) {
					[storylines addObject:[string.uppercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
				}
			}
		}
	}];
	
	return storylines;
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
    if (line >= [self.lines count]) {
        return NSNotFound;
    } else {
        Line* l = self.lines[line];
        return l.position;
    }
}

- (NSString*)sceneNumberAtLine:(NSUInteger)line
{
    if (line >= [self.lines count]) {
        return nil;
    } else {
        Line* l = self.lines[line];
        return l.sceneNumber;
    }
}

#pragma mark - Outline Data

- (NSUInteger)numberOfOutlineItems
{
	[self createOutline];
	return [_outline count];
}

- (OutlineScene*) getOutlineForLine: (Line *) line {
	for (OutlineScene * item in _outline) {
		if (item.line == line) {
			return item;
		}
		else if ([item.scenes count]) {
			for (OutlineScene * subItem in item.scenes) {
				if (subItem.line == line) {
					return subItem;
				}
			}
		}
	}
	return nil;
}
- (NSArray*) outlineItems {
	[self createOutline];
	return self.outline;
}
- (void) createOutline
{
	[_outline removeAllObjects];
	[_storylines removeAllObjects];
	
	NSUInteger result = 0;

	// Get first scene number
	NSUInteger sceneNumber = 1;
	
	if ([self.documentSettings getInt:@"Scene Numbering Starts From"] > 0) {
		sceneNumber = [self.documentSettings getInt:@"Scene Numbering Starts From"];
	}
	
	// We will store a section depth to adjust depth for scenes that come after a section
	NSUInteger sectionDepth = 0;
	
	OutlineScene *previousScene;
	OutlineScene *currentScene;
	
	// This is for allowing us to include synopses INSIDE scenes when needed
	OutlineScene *sceneBlock;
	Line *previousLine;
	
	for (Line* line in self.lines) {
		if (line.type == section || line.type == synopse || line.type == heading) {
			
			// When handling synopses, we might want to move them alongside with scenes
			if (line.type == synopse) {
				
			}
			
			// Create an outline item
			OutlineScene *item = [[OutlineScene alloc] init];
			
			currentScene = item;
			
			item.type = line.type;
			item.omited = line.omited;
			item.line = line;
			item.storylines = line.storylines;
			item.color = line.color;
			
			if (!item.omited) item.string = line.stripInvisible;
			else item.string = line.stripNotes;
			
			// Add storylines to the storyline bank
			// btw: this is a fully speculative feature, no idea if it'll be used
			for (NSString* storyline in item.storylines) {
				if (![_storylines containsObject:storyline]) [_storylines addObject:storyline];
			}
			
			if (item.type == section) {
				// Save section depth
				sectionDepth = line.sectionDepth;
				item.sectionDepth = sectionDepth;
			} else {
				item.sectionDepth = sectionDepth;
			}
			
			if (item.string.length > 0) {
				// Remove formatting characters from the outline item string if needed
				if ([item.string characterAtIndex:0] == '#' && [item.string length] > 1) {
					item.string = [item.string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
				}
				if ([item.string characterAtIndex:0] == '=' && [item.string length] > 1) {
					item.string = [item.string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
				}
			}
			
			if (line.type == heading) {
				// Check if the scene is omitted
				// If the scene is omited, let's not increment scene number for it.
				// However, if the scene has a forced number, we'll maintain it
				if (line.sceneNumberRange.length > 0) {
					item.sceneNumber = line.sceneNumber;
					
					/*
					// Also, if the document wants to start the scene numbering from first scene,
					// let's offset the numbering, IF it returns a valid number
					if (self.delegate.offsetFromFirstCustomSceneNumber) {
						NSInteger sceneNumberOffset = [item.sceneNumber integerValue];
						if (sceneNumberOffset > 0) sceneNumber = sceneNumberOffset + 1;
					}
					*/
				}
				else {
					if (!line.omited) {
						item.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
						line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
						sceneNumber++;
					} else {
						item.sceneNumber = @"";
						line.sceneNumber = @"";
					}
				}
			}
			
			// Get in / out points
			item.sceneStart = line.position;
			
			// If this scene is omited, we need to figure out where the omission starts from.
			if (item.omited) {
				NSUInteger index = [self.lines indexOfObject:line];
				while (index > 0) {
					index--;
					Line* previous = [self.lines objectAtIndex:index];
					
					// So, this is kind of brute force, but here's my rationalization:
					// a) The scene heading is already omited
					// b) Somewhere before there NEEDS to be a line which starts the omission
					// c) I mean, if there is omission INSIDE omission, the user can/should blame themself?
					if ([previous.string rangeOfString:@OMIT_OPEN_PATTERN].location != NSNotFound) {
						item.sceneStart = previous.position;
						
						// Shorten the previous scene accordingly
						if (previousScene) {
							previousScene.sceneLength = item.sceneStart - previous.position;
						}
						break;
					// So, what did I say about blaming the user?
					// I remembered that I have myself sometimes omited several scenes at once, so if we come across a scene heading while going through the lines, let's just reset and tell the previous scene that its omission is unterminated. We need this information for swapping the scenes around.
					// btw, I have really learned to code
					// in a shady way
					// but what does it count...
						// the only thing that matters is how you walk through the fire
					} else if (previous.type == heading) {
						item.sceneStart = line.position;
						item.noOmitIn = YES;
						if (previousScene) previousScene.noOmitOut = YES;
					}
				}
			}
			
			if (previousScene) {
				
				// If this is a synopsis line, it might need to be included in the previous scene length (for moving them around)
				
				if (item.type == synopse) {
					
					if (previousLine.type == heading) {
						// This synopse belongs into a block, so don't set the length for previous scene
						sceneBlock = previousScene;
					} else {
						// Act normally
						previousScene.sceneLength = item.sceneStart - previousScene.sceneStart;
					}
					 
				} else {
					if (sceneBlock) {
						// Reset scene block
						sceneBlock.sceneLength = item.sceneStart - sceneBlock.sceneStart;
						sceneBlock = nil;
					} else {
						previousScene.sceneLength = item.sceneStart - previousScene.sceneStart;
					}
				}
				
				//previousScene.sceneLength = item.sceneStart - previousScene.sceneStart;
			}
			
			// Set previous scene to point to the current one
			previousScene = item;

			result++;
			[_outline addObject:item];
		}
		
		// Done. Set the previous line.
		if (line.type != empty) previousLine = line;
		
		// As the loop has completed, let's set the length for last outline item.
		if (line == [self.lines lastObject]) {
			currentScene.sceneLength = line.position + [line.string length] - currentScene.sceneStart;
		}
	}
}

// Deprecated (why though?)
- (NSInteger)outlineItemIndex:(Line*)item {
	return [self.lines indexOfObject:item];
}

- (BOOL)getAndResetChangeInOutline
{
    if (_changeInOutline) {
        _changeInOutline = NO;
        return YES;
    }
    return NO;
}

#pragma mark - Convenience

- (NSInteger)numberOfScenes {
	NSInteger scenes = 0;
	for (Line *line in self.lines) {
		if (line.type == heading) scenes++;
	}
	return scenes;
}
- (NSMutableArray *) getScenes {
	NSMutableArray * scenes = [NSMutableArray array];
	for (OutlineScene * scene in [self outline]) {
		if (scene.type == heading) [scenes addObject:scene];
	}
	
	return scenes;
}

#pragma mark - Utility

- (NSString *)description
{
    NSString *result = @"";
    NSUInteger index = 0;
    for (Line *l in self.lines) {
        //For whatever reason, %lu doesn't work with a zero
        if (index == 0) {
            result = [result stringByAppendingString:@"0 "];
        } else {
            result = [result stringByAppendingFormat:@"%lu ", (unsigned long) index];
        }
        result = [[result stringByAppendingString:[l toString]] stringByAppendingString:@"\n"];
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
		if (line.type == section || line.type == synopse || line.omited || line.isTitlePage) continue;
		
		result = [result stringByAppendingFormat:@"%@\n", line.cleanedString];
	}
	
	return result;
}

- (Line*)lineAtPosition:(NSInteger)position {
	for (Line* line in self.lines) {
		if (position >= line.position && position < line.position + line.string.length + 1) return line;
	}
	return nil;
}

- (NSArray*)preprocessForPrinting {
	[self createOutline];
	return [self preprocessForPrintingWithLines:self.lines];
}
- (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines {
	if (!lines) lines = self.lines;
	
	NSMutableArray *elements = [NSMutableArray array];
	Line *previousLine;
	
	NSInteger sceneNumber = 1;
	if (self.delegate) {
		sceneNumber = [self.documentSettings getInt:@"Scene Numbering Starts From"];
		if (sceneNumber < 1) sceneNumber = 1;
	}
	
	for (Line *line in lines) {
		// Skip over certain elements
		if (line.type == synopse || line.type == section || line.omited || [line isTitlePage]) {
			if (line.type == empty) previousLine = line;
			continue;
		}
		
		// If there is no delegate, show scene numbers. Otherwise, ask the delegate.
		if (line.type == heading && (self.delegate.printSceneNumbers || !self.delegate)) {
			if (line.sceneNumberRange.length > 0) {
				line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
				line.string = line.stripSceneNumber;
			} else {
				line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
				line.string = line.stripSceneNumber;
				sceneNumber += 1;
			}
		}
		
		// This is a paragraph with a line break, so append the line to the previous one
		// A quick explanation for this practice: We generally skip empty lines and instead
		// calculate margins before elements. This is a legacy of the old Fountain parser,
		// but is actually somewhat sensitive approach. That's why we join the lines into
		// one element.
		
		if (line.type == action && line.isSplitParagraph && [lines indexOfObject:line] > 0) {
			Line *previousLine = [elements objectAtIndex:elements.count - 1];

			previousLine.string = [previousLine.string stringByAppendingFormat:@"\n%@", line.string];
			if (line.changed) previousLine.changed = YES; // Inherit change status
			
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
			bool previousCharacterFound = NO;
			NSInteger i = elements.count - 2; // Go for previous element
			while (i > 0) {
				Line *previousLine = [elements objectAtIndex:i];
				
				if (!(previousLine.isDialogueElement || previousLine.isDualDialogueElement)) break;
				
				if (previousLine.type == character ) {
					previousLine.nextElementIsDualDialogue = YES;
					previousCharacterFound = YES;
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

- (NSDictionary*)scriptForPrinting {
	// NOTE: Use ONLY for static parsing
	return @{ @"title page": self.titlePage, @"script": [self preprocessForPrinting] };
}

@end
