//
//  BeatEditorFormattingActions.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatEditorFormattingActions.h"
#import <BeatCore/BeatLocalization.h>

@implementation BeatEditorFormattingActions

static NSString *lineBreak = @"\n\n===\n\n";
static NSString *boldSymbol = @"**";
static NSString *italicSymbol = @"*";
static NSString *underlinedSymbol = @"_";
static NSString *noteOpen = @"[[";
static NSString *noteClose= @"]]";
static NSString *omitOpen = @"/*";
static NSString *omitClose= @"*/";
static NSString *forceHeadingSymbol = @".";
static NSString *forceActionSymbol = @"!";
static NSString *forceCharacterSymbol = @"@";
static NSString *forcetransitionLineSymbol = @">";
static NSString *forceLyricsSymbol = @"~";
static NSString *forceDualDialogueSymbol = @"^";

static NSString *highlightSymbolOpen = @"<<";
static NSString *highlightSymbolClose = @">>";
static NSString *strikeoutSymbolOpen = @"{{";
static NSString *strikeoutSymbolClose = @"}}";

static NSString *tagAttribute = @"BeatTag";
static NSString *revisionAttribute = @"Revision";

- (NSString*)titlePage
{
	NSDateFormatter *dateFormatter = NSDateFormatter.new;
	[dateFormatter setDateFormat:@"dd.MM.yyyy"];
	return [NSString stringWithFormat:@"Title: \nCredit: \nAuthor: \nDraft date: %@\nContact: \n\n", [dateFormatter stringFromDate:[NSDate date]]];
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if (!_delegate.editorTabVisible) return NO;
	else return YES;
}


- (IBAction)addTitlePage:(id)sender
{
	Line* firstLine = _delegate.parser.lines.firstObject;
	
	if (!firstLine.isTitlePage) {
		[_delegate addString:[self titlePage] atIndex:0];

		_delegate.selectedRange = NSMakeRange(7, 0);
	}
}

- (IBAction)dualDialogue:(id)sender {
	Line *currentLine = _delegate.currentLine;
	
	// Current line is character
	if (currentLine.type == character) {
		// We won't allow making a first dialogue block dual, let's see if there is another block of dialogue
		NSInteger index = [_delegate.parser.lines indexOfObject:currentLine] - 1;
		bool previousDialogueFound = NO;
		
		while (index >= 0) {
			Line* previousLine = [_delegate.parser.lines objectAtIndex:index];
			if (previousLine.type == character) { previousDialogueFound = YES; break; }
			if ((previousLine.type == action && previousLine.string.length > 0) || previousLine.type == heading) break;
			index--;
		}
		
		if (previousDialogueFound) [_delegate addString:forceDualDialogueSymbol atIndex:currentLine.position + currentLine.string.length];
	
	// if it's already a dual dialogue cue, remove the symbol
	} else if (currentLine.type == dualDialogueCharacter) {
		NSRange range = [currentLine.string rangeOfString:forceDualDialogueSymbol];
		// Remove symbol
		[_delegate  removeString:forceDualDialogueSymbol atIndex:currentLine.position + range.location];
		
	// Dialogue block. Find the character cue and add/remove dual dialogue symbol
	} else if (currentLine.type == dialogue ||
			   currentLine.type == dualDialogue ||
			   currentLine.type == parenthetical ||
			   currentLine.type == dualDialogueParenthetical) {
		NSInteger index = [_delegate.parser.lines indexOfObject:currentLine] - 1;
		while (index >= 0) {
			Line* previousLine = [_delegate.parser.lines objectAtIndex:index];

			if (previousLine.type == character) {
				// Add
				[_delegate addString:forceDualDialogueSymbol atIndex:previousLine.position + previousLine.string.length];
				break;
			}
			if (previousLine.type == dualDialogueCharacter) {
				// Remove
				NSRange range = [previousLine.string rangeOfString:forceDualDialogueSymbol];
				[_delegate removeString:forceDualDialogueSymbol atIndex:previousLine.position + range.location];
				break;
			}
			index--;
		}
	}
}

- (IBAction)addPageBreak:(id)sender
{
	NSRange cursorLocation = _delegate.selectedRange;
	if (cursorLocation.location != NSNotFound) {
		//Step forward to end of line
		NSUInteger location = cursorLocation.location + cursorLocation.length;
		NSUInteger length = _delegate .text.length;
		while (true) {
			if (location == length) {
				break;
			}
			NSString *nextChar = [_delegate.text substringWithRange:NSMakeRange(location, 1)];
			if ([nextChar isEqualToString:@"\n"]) {
				break;
			}
			
			location++;
		}
		_delegate.selectedRange = NSMakeRange(location, 0);
		[_delegate addString:lineBreak atIndex:location];
	}
}

- (IBAction)makeBold:(id)sender
{
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range beginningSymbol:boldSymbol endSymbol:boldSymbol style:Bold];
}

- (IBAction)makeItalic:(id)sender
{
	//Retreiving the cursor location
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range beginningSymbol:italicSymbol endSymbol:italicSymbol style:Italic];
}

- (IBAction)makeUnderlined:(id)sender
{
	//Retreiving the cursor location
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range beginningSymbol:underlinedSymbol endSymbol:underlinedSymbol style:Underline];
}


- (IBAction)makeNote:(id)sender
{
	//Retreiving the cursor location
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range beginningSymbol:noteOpen endSymbol:noteClose style:Note];
}

- (IBAction)makeOmitted:(id)sender
{
	//Retreiving the cursor location
	NSRange cursorLocation = _delegate.selectedRange;
	[self format:cursorLocation beginningSymbol:omitOpen endSymbol:omitClose style:Block];

}
- (IBAction)omitScene:(id)sender {
	OutlineScene *scene = [_delegate.parser sceneAtPosition:_delegate.selectedRange.location];
	if (scene.omitted) return;
	
	[_delegate addString:@"/*\n" atIndex:scene.position];
	[_delegate addString:@"*/\n\n" atIndex:scene.position + scene.range.length];
}

- (IBAction)forceSceneNumberForScene:(id)sender {
	BeatModalInput *input = BeatModalInput.new;
	
	[input inputBoxWithMessage:[BeatLocalization localizedStringForKey:@"editor.setSceneNumber"]
						  text:[BeatLocalization localizedStringForKey:@"editor.setSceneNumber.info"]
				   placeholder:@"123A" forWindow:_delegate.documentWindow completion:^(NSString * _Nonnull result) {
		
		if (result.length > 0) {
			OutlineScene *scene = self.delegate.currentScene;
			
			if (scene) {
				if (scene.line.sceneNumberRange.length) {
					// Remove existing scene number
					[self.delegate replaceRange:(NSRange){ scene.line.position + scene.line.sceneNumberRange.location, scene.line.sceneNumberRange.length } withString:result];
				} else {
					// Add empty scene number
					[self.delegate addString:[NSString stringWithFormat:@" #%@#", result] atIndex:scene.line.position + scene.line.string.length];
				}
			}
		}
	}];
}

- (IBAction)makeSceneNonNumbered:(id)sender {
	OutlineScene *scene = _delegate.currentScene;
	if (!scene) return;
	
	if (scene.line.sceneNumberRange.length) {
		// Remove existing scene number
		[_delegate replaceRange:(NSRange){ scene.line.position + scene.line.sceneNumberRange.location, scene.line.sceneNumberRange.length } withString:@" "];
	} else {
		// Add empty scene number
		[_delegate addString:@" # #" atIndex:scene.line.position + scene.line.string.length];
	}
}

- (bool)rangeHasFormatting:(NSRange)range open:(NSString*)open end:(NSString*)end {
	if (range.location < 0 || range.location == NSNotFound) return NO;
	
	// Check that the range actually intersects with text
	if (NSIntersectionRange(range, (NSRange){ 0, _delegate.text.length }).length == range.length) {
		// Grab formatting symbols in given range
		NSString *leftSide = [_delegate.text substringWithRange:(NSRange){ range.location, open.length }];
		NSString *rightSide = [_delegate.text substringWithRange:(NSRange){ range.location + range.length - end.length, end.length }];
		
		if ([leftSide isEqualToString:open] && [rightSide isEqualToString:end]) return YES;
		else return NO;
	
	} else {
		return NO;
	}
}

- (void)format:(NSRange)cursorLocation beginningSymbol:(NSString*)beginningSymbol endSymbol:(NSString*)endSymbol style:(BeatFormatting)style
{
	// Don't go out of range
	if (cursorLocation.location  + cursorLocation.length > _delegate.text.length) return;
	
	// Check if the selected text is already formated in the specified way
	NSString *selectedString = [_delegate.text substringWithRange:cursorLocation];
	NSInteger selectedLength = selectedString.length;
	NSInteger symbolLength = beginningSymbol.length + endSymbol.length;
	
	NSInteger addedCharactersBeforeRange;
	NSInteger addedCharactersInRange;
	
	// See if the selected range already has formatting INSIDE the selected area
	bool alreadyFormatted = NO;
	if (selectedLength >= symbolLength) {
		alreadyFormatted = [self rangeHasFormatting:cursorLocation open:beginningSymbol end:endSymbol];
		
		if (style == Italic) {
			// Bold and Italic have similar stylization, so weed to do an additional check
			if ([self rangeHasFormatting:cursorLocation open:boldSymbol end:boldSymbol]) alreadyFormatted = NO;
		}
	}
	
	if (alreadyFormatted) {
		NSString *replacementString = [selectedString substringWithRange:NSMakeRange(beginningSymbol.length, selectedLength - beginningSymbol.length - endSymbol.length)];
		
		//The Text is formatted, remove the formatting
		[_delegate replaceRange:cursorLocation withString:replacementString];

		addedCharactersBeforeRange = 0;
		addedCharactersInRange = -(beginningSymbol.length + endSymbol.length);
		
	} else {
		//The Text isn't formatted, but let's alter the cursor range and check again because there might be formatting right outside the selected area
		alreadyFormatted = NO;
		
		NSRange safeRange = (NSRange) { cursorLocation.location - beginningSymbol.length, cursorLocation.length + beginningSymbol.length + endSymbol.length };
		
		if (NSIntersectionRange(safeRange, (NSRange){ 0, _delegate.text.length }).length == safeRange.length) {
			alreadyFormatted = [self rangeHasFormatting:safeRange open:beginningSymbol end:endSymbol];
			
			if (style == Italic) {
				// Additional check for italic
				if ([self rangeHasFormatting:safeRange open:boldSymbol end:boldSymbol]) alreadyFormatted = NO;
				// One more additional check for BOLD-ITALIC lol
				if ([self rangeHasFormatting:(NSRange){ safeRange.location - 1, safeRange.length + 2 } open:italicSymbol end:italicSymbol]) alreadyFormatted = YES;
			}
		}
		
		if (alreadyFormatted) {
			//NSString *replacementString = [selectedString substringWithRange:NSMakeRange(beginningSymbol.length, selectedLength - beginningSymbol.length - endSymbol.length)];
			
			[_delegate replaceRange:safeRange withString:selectedString];
			addedCharactersBeforeRange = - beginningSymbol.length;
			addedCharactersInRange = 0;
		} else {
			//The text really isn't formatted. Just add the formatting using the original data.
			[_delegate addString:endSymbol atIndex:cursorLocation.location + cursorLocation.length];
			[_delegate addString:beginningSymbol atIndex:cursorLocation.location];
			
			addedCharactersBeforeRange = beginningSymbol.length;
			addedCharactersInRange = 0;
		}
	}
	
	// Return range to how it was
	self.delegate.selectedRange = NSMakeRange(cursorLocation.location+addedCharactersBeforeRange, cursorLocation.length+addedCharactersInRange);
}

- (void)forceElement:(LineType)lineType {
	if (lineType == action) [self forceAction:self];
	else if (lineType == heading) [self forceHeading:self];
	else if (lineType == character) [self forceCharacter:self];
	else if (lineType == lyrics) [self forceLyrics:self];
	else if (lineType == transitionLine) [self forceTransition:self];
}

- (IBAction)forceHeading:(id)sender
{
	NSRange cursorLocation = _delegate.selectedRange;
	[self forceLineType:cursorLocation symbol:forceHeadingSymbol];
}

- (IBAction)forceAction:(id)sender
{
	NSRange cursorLocation = _delegate.selectedRange;
	[self forceLineType:cursorLocation symbol:forceActionSymbol];
}

- (IBAction)forceCharacter:(id)sender
{
	NSRange cursorLocation = _delegate.selectedRange;
	[self forceLineType:cursorLocation symbol:forceCharacterSymbol];
}

- (IBAction)forceTransition:(id)sender
{
	NSRange cursorLocation = _delegate.selectedRange;
	[self forceLineType:cursorLocation symbol:forcetransitionLineSymbol];
}

- (IBAction)forceLyrics:(id)sender
{
	NSRange cursorLocation = _delegate.selectedRange;
	[self forceLineType:cursorLocation symbol:forceLyricsSymbol];
}

- (IBAction)force:(id)sender {
	
}

- (void)forceLineType:(NSRange)cursorLocation symbol:(NSString*)symbol
{
	//Find the index of the first symbol of the line
	NSUInteger indexOfLineBeginning = cursorLocation.location;
	while (true) {
		if (indexOfLineBeginning == 0) {
			break;
		}
		NSString *characterBefore = [_delegate.text substringWithRange:NSMakeRange(indexOfLineBeginning - 1, 1)];
		if ([characterBefore isEqualToString:@"\n"]) {
			break;
		}
		
		indexOfLineBeginning--;
	}
	
	NSRange firstCharacterRange;
	
	// If the cursor resides in an empty line
	// (because the beginning of the line is the end of the document or is indicated by the next character being a newline)
	// The range for the first charater in line needs to be an empty string
	
	if (indexOfLineBeginning == _delegate.text.length) {
		firstCharacterRange = NSMakeRange(indexOfLineBeginning, 0);
	} else if ([[_delegate.text substringWithRange:NSMakeRange(indexOfLineBeginning, 1)] isEqualToString:@"\n"]){
		firstCharacterRange = NSMakeRange(indexOfLineBeginning, 0);
	} else {
		firstCharacterRange = NSMakeRange(indexOfLineBeginning, 1);
	}
	NSString *firstCharacter = [_delegate.text substringWithRange:firstCharacterRange];
	
	// If the line is already forced to the desired type, remove the force
	if ([firstCharacter isEqualToString:symbol]) {
		[_delegate replaceString:firstCharacter withString:@"" atIndex:firstCharacterRange.location];
	} else {
		// If the line is not forced to the desired type, check if it is forced to be something else
		BOOL otherForce = NO;
		
		NSArray *allForceSymbols = @[forceActionSymbol, forceCharacterSymbol, forceHeadingSymbol, forceLyricsSymbol, forcetransitionLineSymbol];
		
		for (NSString *otherSymbol in allForceSymbols) {
			if (otherSymbol != symbol && [firstCharacter isEqualToString:otherSymbol]) {
				otherForce = YES;
				break;
			}
		}
		
		//If the line is forced to be something else, replace that force with the new force
		//If not, insert the new character before the first one
		if (otherForce) {
			[_delegate replaceString:firstCharacter withString:symbol atIndex:firstCharacterRange.location];
		} else {
			[_delegate addString:symbol atIndex:firstCharacterRange.location];
		}
	}
}

- (IBAction)addHighlight:(id)sender {
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range beginningSymbol:highlightSymbolOpen endSymbol:highlightSymbolClose style:Block];
}
- (IBAction)addStrikeout:(id)sender {
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range beginningSymbol:strikeoutSymbolOpen endSymbol:strikeoutSymbolClose style:Block];
}
- (NSRange)rangeUntilLineBreak:(NSRange)range {
	NSString *text = [_delegate.text substringWithRange:range];
	if ([text rangeOfString:@"\n"].location != NSNotFound) {
		NSInteger lineBreakIndex = [text rangeOfString:@"\n"].location;
		return (NSRange){ range.location, lineBreakIndex };
	} else {
		return range;
	}
}

@end

