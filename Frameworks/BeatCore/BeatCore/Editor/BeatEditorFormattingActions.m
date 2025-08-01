//
//  BeatEditorFormattingActions.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This is a collection of IBAction methods for screenplay editing.
 
 */

#import "BeatEditorFormattingActions.h"
#import <BeatCore/BeatLocalization.h>
#import <TargetConditionals.h>
#import <BeatCore/BeatCore.h>

@implementation BeatEditorFormattingActions

static NSString *lineBreak = @"\n\n===\n\n";
static NSString *boldSymbol = @"**";
static NSString *italicSymbol = @"*";
static NSString *underlinedSymbol = @"_";
static NSString *noteOpen = @"[[";
static NSString *noteClose= @"]]";
static NSString *omitOpen = @"/*";
static NSString *omitClose= @"*/";

static NSString *centeredStart = @"> ";
static NSString *centeredEnd = @" <";

static NSString *highlightSymbolOpen = @"<<";
static NSString *highlightSymbolClose = @">>";
static NSString *macroSymbolOpen = @"{{";
static NSString *macroSymbolClose = @"}}";


#pragma mark - Init

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate
{
	self = [super init];
	if (self) {
		_delegate = delegate;
	}
	return self;
}


#pragma mark - Validate editor action items (macOS)

#if !TARGET_OS_IOS
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return _delegate.editorTabVisible;
}
#endif


#pragma mark - Editor actions

#pragma mark More abstract Methods

- (NSString*)titlePage
{
	NSDateFormatter *dateFormatter = NSDateFormatter.new;
	[dateFormatter setDateFormat:@"dd.MM.yyyy"];
	return [NSString stringWithFormat:@"Title: \nCredit: \nAuthor: \nDraft date: %@\nContact: \n\n", [dateFormatter stringFromDate:NSDate.date]];
}

- (IBAction)addTitlePage:(id)sender
{
	Line* firstLine = _delegate.parser.lines.firstObject;
	
	if (!firstLine.isTitlePage) {
		[_delegate.textActions addString:[self titlePage] atIndex:0];

		_delegate.selectedRange = NSMakeRange(7, 0);
	}
}


#pragma mark - Dialogue and character cues

- (IBAction)dualDialogue:(id)sender
{
    Line *currentLine = _delegate.currentLine;
    
    if (!currentLine.isDialogue && !currentLine.isDualDialogue) return;
    
    NSInteger idx = [_delegate.parser.lines indexOfObject:currentLine];
    
    if (currentLine.isDialogue) {
        // This block is not dual dialogue, let's find out where we should start the block.
        Line* leftCue;
        Line* rightCue;

        while (idx >= 0) {
            Line* l = _delegate.parser.lines[idx];
            if (l.type == character && rightCue == nil) rightCue = l;
            else if (l.type == character && leftCue == nil) leftCue = l;
            else if (!l.isDialogue && !l.isDialogue && l.type != empty) break;
            
            if (rightCue && leftCue) break;
            
            idx--;
        }
        
        // We'll require both left and right cues to exist.
        if (leftCue && rightCue) [self.delegate.textActions addString:@"^" atIndex:NSMaxRange(rightCue.textRange)];
    }
    else if (currentLine.isDualDialogue) {
        // Remove dual dialogue
        Line* cue;
        while (idx >= 0) {
            Line* l = _delegate.parser.lines[idx];
            if (l.type == dualDialogueCharacter) {
                cue = l;
                break;
            }
            idx--;
        }
        
        if (cue) {
            NSInteger i = [cue.string rangeOfString:@"^" options:NSBackwardsSearch].location;
            if (i != NSNotFound) {
                [self.delegate.textActions replaceRange:NSMakeRange(cue.position + i, 1) withString:@""];
            }
        }
    }
}

/// Adds a character cue in the current position. **Note** that you might need to set the typing attributes for text view separately for the cue to take action.
- (void)addCue
{
    if (_delegate.currentLine == nil) return;
    
    // Move at the beginning of the line to avoid issues with .currentLine
    _delegate.selectedRange = NSMakeRange(_delegate.currentLine.position, 0);
    
    // If current line is not empty, find the end of block.
    if (_delegate.currentLine.type != empty) {
        NSArray *block = [_delegate.parser blockFor:_delegate.currentLine];
        Line *lastLine = block.lastObject;
        if (lastLine == nil) lastLine = _delegate.currentLine;
        _delegate.selectedRange = NSMakeRange(lastLine.position, 0);
    }
    
    // ... then in the new position, check again if we need a line break
    if (_delegate.currentLine.type != empty && _delegate.currentLine.length > 0) {
        // Add line break at the end of block
        [_delegate.textActions addString:@"\n" atIndex: NSMaxRange(_delegate.currentLine.textRange) skipAutomaticLineBreaks:true];
        _delegate.selectedRange = NSMakeRange(NSMaxRange(_delegate.currentLine.textRange) + 2, 0);
    }
    
    // Do we need a line break before current line, too?
    Line *prevLine = [_delegate.parser previousLine:_delegate.currentLine];
    if (prevLine != nil && prevLine.type != empty && prevLine.string.length != 0) {
        [_delegate.textActions addString:@"\n" atIndex:NSMaxRange(prevLine.textRange) skipAutomaticLineBreaks:true];
    }
    
    // ... and see if we *still* need another line break at this position?
    Line *nextLine = [_delegate.parser nextLine:_delegate.currentLine];
    if (nextLine != nil && nextLine.type != empty && nextLine.string.length != 0) {
        NSInteger loc = _delegate.currentLine.position;
        [_delegate.textActions addString:@"\n" atIndex:NSMaxRange(_delegate.currentLine.textRange) skipAutomaticLineBreaks:true];
        _delegate.selectedRange = NSMakeRange(loc, 0);
    }
    
    // If the caret is at end, we need to do some very, very nasty trickery for some reason
    NSRange selectedRange = self.delegate.selectedRange;
    if (NSMaxRange(selectedRange) == self.delegate.textStorage.length) {
        [_delegate.textActions addString:@"\n" atIndex:NSMaxRange(selectedRange)];
        self.delegate.selectedRange = selectedRange;
    }
    
    // If no line is selected, return and do nothing.
    Line *currentLine =_delegate.currentLine;
    if (currentLine == nil) return;
    
    // Force the line to become a character cue
    [_delegate setTypeAndFormat:currentLine type:character];
    
    // Note the editor that we're forcing a character cue at this point.
    _delegate.characterInputForLine = currentLine;
    _delegate.characterInput = YES;
}

/// Adds character extension stub on current line or moves to edit it
- (void)addOrEditCharacterExtension
{
    Line * currentLine = self.delegate.currentLine;
    NSLog(@"Current line: %@", currentLine);
    if (!currentLine.isAnyCharacter) return;
    
    if (currentLine.hasExtension) {
        // Move the caret to extension
        NSInteger loc = [currentLine.string rangeOfString:@"("].location;
        self.delegate.selectedRange = NSMakeRange(loc + currentLine.position + 1, 0);
    } else {
        // Add space if needed
        if (currentLine.lastCharacter != ' ' && currentLine.length > 0) [self.delegate.textActions addString:@" " atIndex:NSMaxRange(currentLine.textRange)];
        // Add a new extension placeholder
        [self.delegate.textActions addString:@"()" atIndex:NSMaxRange(currentLine.textRange)];
        // Move selection between parentheses
        self.delegate.selectedRange = NSMakeRange(NSMaxRange(currentLine.textRange) - 1, 0);
    }
}


#pragma mark Pure formatting and blocks

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
		[_delegate.textActions addString:lineBreak atIndex:location];
	}
}

- (IBAction)makeBold:(id)sender
{
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range startingSymbol:boldSymbol endSymbol:boldSymbol style:Bold];
}

- (IBAction)makeItalic:(id)sender
{
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range startingSymbol:italicSymbol endSymbol:italicSymbol style:Italic];
}

- (IBAction)makeUnderlined:(id)sender
{
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range startingSymbol:underlinedSymbol endSymbol:underlinedSymbol style:Underline];
}

- (IBAction)makeCentered:(id)sender
{
    NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
    [self format:range startingSymbol:centeredStart endSymbol:centeredEnd style:Centered];
}

- (IBAction)makeNote:(id)sender
{
	//Retreiving the cursor location
	NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
	[self format:range startingSymbol:noteOpen endSymbol:noteClose style:Note];
}

- (IBAction)makeOmitted:(id)sender
{
	[self format:_delegate.selectedRange startingSymbol:omitOpen endSymbol:omitClose style:Block];
}

- (IBAction)omitScene:(id)sender {
	OutlineScene *scene = [_delegate.parser sceneAtPosition:_delegate.selectedRange.location];
	if (scene.omitted) return;
	
	[_delegate.textActions addString:@"/*\n" atIndex:scene.position];
	[_delegate.textActions addString:@"*/\n\n" atIndex:scene.position + scene.range.length];
}

- (IBAction)makeUppercase:(id)sender {
    if (_delegate.selectedRange.length == 0) return;
    
    NSRange range = _delegate.selectedRange;
    NSString* string = [_delegate.text substringWithRange:range];
    
    [_delegate.textActions replaceRange:range withString:string.uppercaseString];
}

- (IBAction)makeMacro:(id)sender
{
    NSRange range = [self rangeUntilLineBreak:_delegate.selectedRange];
    [self format:range startingSymbol:macroSymbolOpen endSymbol:macroSymbolClose style:Other];
}

/*
 // An initial attempt at making a more sensible formatting method but... uh. No hope.
- (void)addFormattingTo:(NSRange)range open:(NSString*)openSymbol close:(NSString*)closeSymbol style:(BeatMarkupStyle)style
{
    NSString* text = _delegate.text;
        
    bool strip = false;
    
    // First look around the item
    NSInteger start = range.location;
    NSInteger end = NSMaxRange(range);
    
    NSInteger precedingStars = 0;
    NSInteger followingStars = 0;
    
    while (start >= 0) {
        if ([text characterAtIndex:start] != '*') break;
        precedingStars++;
        start--;
    }
    while (end < text.length && followingStars < precedingStars) {
        if ([text characterAtIndex:end] != '*') break;
        followingStars++;
        end++;
    }
    
    // Same amount of stars OR over 3 stars. Strip the styling we were about to add
    if ((precedingStars && followingStars && precedingStars == openSymbol.length) ||
        (precedingStars == followingStars && precedingStars > 2)) {
        strip = true;
    }

    
    if (strip) {
        // Remove anything that's here
    }
}
*/

- (void)format:(NSRange)cursorLocation startingSymbol:(NSString*)startingSymbol endSymbol:(NSString*)endSymbol style:(NSInteger)style
{
    //[self addFormattingTo:cursorLocation open:startingSymbol close:endSymbol style:style];
    
    // Looking at this in 2023... oh my. TODO: Fix this at some point.
    
	// Don't go out of range
    if (NSMaxRange(cursorLocation) > _delegate.text.length) return;
	
	// Check if the selected text is already formated in the specified way
	NSString *selectedString = [_delegate.text substringWithRange:cursorLocation];
	NSInteger selectedLength = selectedString.length;
	NSInteger symbolLength = startingSymbol.length + endSymbol.length;
	
	NSInteger addedCharactersBeforeRange;
	NSInteger addedCharactersInRange;
    
    // Special rules for centered..... added in 2023 feeling agony. This whole method has to be fixed one day.
    if (style == Centered) {
        NSArray* lines = (cursorLocation.length > 0) ? [self.delegate.parser linesInRange:cursorLocation] : @[[self.delegate.parser lineAtPosition:cursorLocation.location]];
        
        for (Line* line in lines) {
            if (line.string.length == 0) {
                [self.delegate.textActions addString:startingSymbol atIndex:line.position];
                [self.delegate.textActions addString:endSymbol atIndex:line.position + line.length];
                continue;
            }
            
            if ([line.string characterAtIndex:0] != '>') {
                [self.delegate.textActions addString:startingSymbol atIndex:line.position];
            }
            if (line.lastCharacter != '<') {
                [self.delegate.textActions addString:endSymbol atIndex:line.position + line.length];
            }
        }
        return;
    }
	
	// See if the selected range already has formatting INSIDE the selected area
	bool alreadyFormatted = NO;
	if (selectedLength >= symbolLength) {
		alreadyFormatted = [self rangeHasFormatting:cursorLocation open:startingSymbol end:endSymbol];
		
		if (style == Italic) {
			// Bold and Italic have similar stylization, so weed to do an additional check
			if ([self rangeHasFormatting:cursorLocation open:boldSymbol end:boldSymbol]) alreadyFormatted = NO;
		}
	}
	
	if (alreadyFormatted) {
		NSString *replacementString = [selectedString substringWithRange:NSMakeRange(startingSymbol.length, selectedLength - startingSymbol.length - endSymbol.length)];
		
		//The Text is formatted, remove the formatting
		[_delegate.textActions replaceRange:cursorLocation withString:replacementString];

		addedCharactersBeforeRange = 0;
		addedCharactersInRange = -(startingSymbol.length + endSymbol.length);
		
	} else {
		//The Text isn't formatted, but let's alter the cursor range and check again because there might be formatting right outside the selected area
		alreadyFormatted = NO;
		
		NSRange safeRange = (NSRange) { cursorLocation.location - startingSymbol.length, cursorLocation.length + startingSymbol.length + endSymbol.length };
		
		if (NSIntersectionRange(safeRange, (NSRange){ 0, _delegate.text.length }).length == safeRange.length) {
			alreadyFormatted = [self rangeHasFormatting:safeRange open:startingSymbol end:endSymbol];
			
			if (style == Italic) {
				// Additional check for italic
				if ([self rangeHasFormatting:safeRange open:boldSymbol end:boldSymbol]) alreadyFormatted = NO;
				// One more additional check for BOLD-ITALIC lol
				if ([self rangeHasFormatting:(NSRange){ safeRange.location - 1, safeRange.length + 2 } open:italicSymbol end:italicSymbol]) alreadyFormatted = YES;
			}
		}
		
		if (alreadyFormatted) {
			//NSString *replacementString = [selectedString substringWithRange:NSMakeRange(startingSymbol.length, selectedLength - startingSymbol.length - endSymbol.length)];
			
			[_delegate.textActions replaceRange:safeRange withString:selectedString];
			addedCharactersBeforeRange = - startingSymbol.length;
			addedCharactersInRange = 0;
		} else {
			//The text really isn't formatted. Just add the formatting using the original data.
			[_delegate.textActions addString:endSymbol atIndex:cursorLocation.location + cursorLocation.length];
			[_delegate.textActions addString:startingSymbol atIndex:cursorLocation.location];
			
			addedCharactersBeforeRange = startingSymbol.length;
			addedCharactersInRange = 0;
		}
	}
	
	// Return range to how it was
	self.delegate.selectedRange = NSMakeRange(cursorLocation.location+addedCharactersBeforeRange, cursorLocation.length+addedCharactersInRange);
}

- (IBAction)forceHeading:(id)sender
{
	[self.delegate.textActions forceLineType:heading];
}

- (IBAction)forceAction:(id)sender
{
	[self.delegate.textActions forceLineType:action];
}

- (IBAction)forceCharacter:(id)sender
{
	[self.delegate.textActions forceLineType:character];
}

- (IBAction)forceTransition:(id)sender
{
	[self.delegate.textActions forceLineType:transitionLine];
}

- (IBAction)forceLyrics:(id)sender
{
	[self.delegate.textActions forceLineType:lyrics];
}

- (IBAction)force:(id)sender {
	
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

- (IBAction)addMarker:(id)sender {

    NSString* value = @"";
    
    // A cross-platform way to get the possible additional color value
    if ([sender valueForKey:@"colorKey"] != nil) {
        value = [NSString stringWithFormat:@" %@", [sender valueForKey:@"colorKey"]];
    }
    
    NSString* marker = [NSString stringWithFormat:@"[[marker%@]]", value];
    if (self.delegate.currentLine.type != empty) {
        // Add at the end of this line
        self.delegate.selectedRange = NSMakeRange(NSMaxRange(self.delegate.currentLine.textRange), 0);
        marker = [NSString stringWithFormat:@" %@", marker];
    }
    [self.delegate.textActions replaceRange:self.delegate.selectedRange withString:marker];
}


#pragma mark - Scene number locking

- (IBAction)makeSceneNonNumbered:(id)sender
{
    OutlineScene *scene = _delegate.currentScene;
    if (!scene) return;
    
    if (scene.line.sceneNumberRange.length) {
        // Remove existing scene number
        [_delegate.textActions replaceRange:(NSRange){ scene.line.position + scene.line.sceneNumberRange.location, scene.line.sceneNumberRange.length } withString:@" "];
    } else {
        // Add empty scene number
        [_delegate.textActions addString:@" # #" atIndex:NSMaxRange(scene.line.textRange)];
    }
}

- (IBAction)lockSceneNumbers:(id)sender
{
    NSInteger sceneNumber = [self.delegate.documentSettings getInt:DocSettingSceneNumberStart];
    if (sceneNumber == 0) sceneNumber = 1;
    
    NSArray* lines = self.delegate.parser.lines.copy;
    
    for (Line* line in lines) {
        if (line.type != heading) continue;
        
        if (line.sceneNumberRange.length == 0) {
            unichar lastChr = (line.length > 0) ? line.lastCharacter : '_';
            
            NSString * sn = [NSString stringWithFormat:@"%@#%lu#", ((lastChr != ' ') ? @" " : @""), sceneNumber];
            [self.delegate.textActions addString:sn atIndex:line.textRange.location + line.textRange.length];
            sceneNumber++;
        } else {
            
        }
    }
    
    [self.delegate ensureLayout];
}

- (IBAction)unlockSceneNumbers:(id)sender
{
    NSArray* outline = self.delegate.parser.outline.copy;
    
    for (OutlineScene* scene in outline) {
        NSRange r = scene.line.sceneNumberRange;
        if (r.length > 0) {
            [self.delegate.textActions replaceRange:NSMakeRange(scene.line.position + r.location - 1, r.length + 2) withString:@""];
        }
    }
    
    [self.delegate ensureLayout];
}


#pragma mark - Helper methods

/// Returns `true` if the selected range actually is wrapped by formatting symbols
- (bool)rangeHasFormatting:(NSRange)range open:(NSString*)open end:(NSString*)end
{
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


#pragma mark - Synopsis, sections etc.

- (IBAction)addSection:(id)sender
{
    [self.delegate.textActions addSection:self.delegate.selectedRange.location];
}

- (IBAction)addSynopsis:(id)sender
{
    [self.delegate.textActions addSynopsis:self.delegate.selectedRange.location];
}

- (IBAction)addShot:(id)sender
{
    [self.delegate.textActions addShot:self.delegate.selectedRange.location];
}



#pragma mark - Block actions

- (IBAction)moveSelectedLinesUp:(id)sender
{
    NSArray *lines = [self.delegate.parser blockForRange:self.delegate.selectedRange];
    [self.delegate.textActions moveBlockUp:lines];
}

- (IBAction)moveSelectedLinesDown:(id)sender
{
    NSArray *lines = [self.delegate.parser blockForRange:self.delegate.selectedRange];
    [self.delegate.textActions moveBlockDown:lines];
}

- (IBAction)copyBlock:(id)sender
{
    NSArray *block = [self.delegate.parser blockForRange:self.delegate.selectedRange];
    NSRange range = [self.delegate.parser rangeForBlock:block];
    
    [self.delegate setSelectedRange:range];
    [self.delegate.getTextView copy:self];
}

- (IBAction)cutBlock:(id)sender
{
    NSArray *block = [self.delegate.parser blockForRange:self.delegate.selectedRange];
    NSRange range = [self.delegate.parser rangeForBlock:block];
    
    [self.delegate setSelectedRange:range];
    [self.delegate.getTextView cut:self];
}


#pragma mark - Macros

- (IBAction)addPanelMacro:(id)sender
{
    [self.delegate.textActions addString:@"{{panel}}" atIndex:self.delegate.selectedRange.location];
}

- (IBAction)addDateMacro:(id)sender
{
    [self.delegate.textActions addString:@"{{date YYYY-MM-dd}}" atIndex:self.delegate.selectedRange.location];
}

- (IBAction)defineSerialMacro:(id)sender
{
    NSString* string = @"{{serial name = 1}}";
    NSInteger loc = self.delegate.selectedRange.location;
    
    [self.delegate.textActions addString:string atIndex:self.delegate.selectedRange.location];
    
    self.delegate.selectedRange = NSMakeRange(loc + string.length - 2, 0);
}

- (IBAction)defineTextMacro:(id)sender
{
    NSString* string = @"{{name = value}}";
    NSInteger loc = self.delegate.selectedRange.location;
    
    [self.delegate.textActions addString:string atIndex:self.delegate.selectedRange.location];
    
    self.delegate.selectedRange = NSMakeRange(loc + string.length - 2, 0);
}


#pragma mark - Switch between alternative versions of text

- (IBAction)nextVersion:(id)sender
{
    [self stepVersion:1];
}

- (IBAction)prevVersion:(id)sender
{
    [self stepVersion:-1];
}

- (void)stepVersion:(NSInteger)amount
{
    // First bake revisions
    [self.delegate bakeRevisions];
    
    Line* line = self.delegate.currentLine;
    if (line.versions.count <= 1) return;
    
    NSDictionary* version = [line switchVersion:amount];
    if (version != nil && version[@"text"] != nil) {
        [self.delegate.textActions replaceRange:line.textRange withString:version[@"text"]];
        [self.delegate.revisionTracking loadLocalRevision:version[@"revisions"] line:line];
    }
    
    
    /*
    if (newText != nil) {
        [self.delegate.textActions replaceRange:line.textRange withString:newText];
    }
     */
}

-  (IBAction)addVersionForLine:(id)sender
{
    Line* line = self.delegate.currentLine;
    [line addVersion];
    [self.delegate.layoutManager invalidateDisplayForCharacterRange:line.textRange];
}


@end

