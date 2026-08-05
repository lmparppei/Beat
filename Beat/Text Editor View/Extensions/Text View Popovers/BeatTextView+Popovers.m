//
//  BeatTextView+Autocompletion.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 8.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+Popovers.h"
#import "Beat-Swift.h"

@interface BeatTextView(Autocompletion) <BeatEditorPopoverDelegate>
@end

@implementation BeatTextView (Autocompletion)

- (void)setupPopovers
{
	self.popoverController = [BeatEditorPopoverController.alloc initWithDelegate:self];
}

/// Closes __all__ popovers and resets popover mode
- (void)closePopovers
{
	[self.infoPopover close];
	[self.popoverController close];
}


#pragma mark - Autocompletion menu

/// Called to display a list of autocompletions
- (void)showAutocompletions
{
	NSCharacterSet* suggestionBoundaries = NSCharacterSet.newlineCharacterSet;
	
	NSInteger startOfWord = self.selectedRange.location;
	for (NSInteger i = startOfWord - 1; i >= 0; i--) {
		if ([suggestionBoundaries characterIsMember:[self.string characterAtIndex:i]]) {
			break;
		} else {
			startOfWord--;
		}
	}
	
	NSInteger lengthOfWord = 0;
	for (NSInteger i = startOfWord; i < self.string.length; i++) {
		if ([suggestionBoundaries characterIsMember:[self.string characterAtIndex:i]]) {
			break;
		} else {
			lengthOfWord++;
		}
	}
	
	self.partialText = [self.string substringWithRange:NSMakeRange(startOfWord, lengthOfWord)];
	NSRange substringRange = NSMakeRange(startOfWord, self.selectedRange.location - startOfWord);
	
	if (substringRange.length == 0 || lengthOfWord == 0) {
		// This happens when we just started a new word or if we have already typed the entire word
		[self closePopovers];
		return;
	}
	
	
	NSInteger index = 0;
	NSArray<NSString*>* matches = [self completionsForPartialWordRange:substringRange indexOfSelectedItem:&index];
	
	if (matches.count == 0) {
		[self closePopovers];
		return;
	} else if (matches.count == 1 &&
			   ([matches.firstObject localizedCaseInsensitiveCompare:self.partialText] == NSOrderedSame ||
				self.partialText.length > matches.firstObject.length)) {
		// If we have only one possible match and it's the same the user has already typed, close the menu
		NSString *match = matches.firstObject;
		if ([match localizedCaseInsensitiveCompare:self.partialText] == NSOrderedSame) {
			[self closePopovers];
			return;
		}
	}
	
	self.lastPos = self.selectedRange.location;
	[self.popoverController reloadData];
		
	// Display the matches
	[self.popoverController displayWithRange:substringRange items:matches callback:^BOOL(NSString * _Nonnull string, NSInteger index, uint16_t keyCode) {
		// If this block returns TRUE, any default keyboard events are cancelled (like return or tab)
		// We'll return 48 for tab every time
		BOOL preventDefault = (keyCode == 48);
		
		[self insertAutocompletionString:string];
		
		Line* currentLine = self.editorDelegate.currentLine;
		
		if (currentLine.isAnyCharacter) {
			// Avoid being weird with enter presses when editing / adding cue extensions.
			Line* nextLine = [self.editorDelegate.parser nextLine:currentLine];
			if (nextLine.length > 0 || self.selectedRange.location < NSMaxRange(currentLine.textRange)) preventDefault = true;
		}
		
		return preventDefault;
	}];
	
	[self.popoverController selectRowWithIndex:index];
}

/// Called from popover controller block to insert the selected string at current line.
- (void)insertAutocompletionString:(NSString*)string
{
	NSRange range;
	// IF the string is something wrapped in parentheses AND we're inside parentheses, we'll replace just that range.
	// This is a little convoluted, but bear with me.
	if (string.wrappedInParentheses && [self.text positionInsideParentheticals:self.selectedRange.location]) {
		range = [self.text parentheticalRangeAt:self.selectedRange.location];
	} else {
		NSInteger beginningOfWord;
		Line* currentLine = self.editorDelegate.currentLine;
		if (currentLine) {
			NSInteger locationInString = self.selectedRange.location - currentLine.position;
			beginningOfWord = self.selectedRange.location - locationInString;
		} else {
			beginningOfWord = self.selectedRange.location - self.partialText.length;
		}
		
		range = NSMakeRange(beginningOfWord, self.partialText.length);
	}
		
	if (range.location != NSNotFound && [self shouldChangeTextInRange:range replacementString:string]) {
		[self replaceCharactersInRange:range withString:string];
		[self didChangeText];
		[self setAutomaticTextCompletionEnabled:NO];
	}
}


#pragma mark - Selection info popup

/// Displays selection info
- (IBAction)showInfo:(id)sender
{
	bool wholeDocument = NO;
	NSRange range = self.selectedRange;
	
	if (range.length == 0) {
		wholeDocument = YES;
		range = NSMakeRange(0, self.string.length);
	}
	
	NSString* string = [self.string substringWithRange:range];
	
	// Calculate amount of words in range
	NSInteger words = 0;
	NSInteger printedWords = 0;
	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	NSInteger symbols = string.length;
	
	for (NSString *line in lines) {
		for (NSString *word in [line componentsSeparatedByString:@" "]) {
			if (word.length > 0) words += 1;
		}
	}
	
	// Printed lengths
	NSArray<Line*>* linesInRange = [self.editorDelegate.parser linesInRange:(!wholeDocument) ? self.selectedRange : self.attributedString.range];
	NSMutableString* mStr = NSMutableString.new;
	for (Line* line in linesInRange) {
		if (line.effectivelyEmpty) continue;
		
		NSInteger p = line.position;
		NSAttributedString* lStr = [line attributedStringForOutputWith:self.editorDelegate.exportSettings];
		
		if (!wholeDocument) {
			// We have to find the intersection range in this line and its printed content
			if (NSLocationInRange(self.selectedRange.location, line.textRange) || NSLocationInRange(NSMaxRange(self.selectedRange), line.range)) {
				NSMutableString* parts = NSMutableString.new;
				[lStr enumerateAttribute:@"BeatEditorRange" inRange:lStr.range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
					NSRange editorRange = ((NSNumber*)value).rangeValue;
					NSRange globalRange = NSMakeRange(p + editorRange.location, editorRange.length);
										
					NSRange iRange = NSIntersectionRange(self.selectedRange, globalRange);
					if (iRange.length > 0){
						// This is the snippet which is actually represented
						NSString* part = [lStr.string substringWithRange:range];

						// We then interpolate the actual part from the editor range
						NSRange resultRange = NSMakeRange(iRange.location - globalRange.location, iRange.length);
						[parts appendString:[part substringWithRange:resultRange]];
					}
				}];
				
				if (parts.length) {
					[mStr appendString:parts];
					if (line != linesInRange.lastObject) [mStr appendString:@" "];
				}
			} else if (NSIntersectionRange(self.selectedRange, line.textRange).length == line.length) {
				// Full string
				[mStr appendString:[line attributedStringForOutputWith:self.editorDelegate.exportSettings].string];
				if (line != linesInRange.lastObject) [mStr appendString:@" "];
			}
		} else {
			// With whole document, we can just use the resulting string
			[mStr appendString:[line attributedStringForOutputWith:self.editorDelegate.exportSettings].string];
			if (line != linesInRange.lastObject) [mStr appendString:@" "];
		}
	}
	
	for (NSString *word in [mStr componentsSeparatedByString:@" "]) {
		if (word.length > 0) printedWords += 1;
	}
	
	// Get number of pages / page number for selection
	NSInteger numberOfPages = 0;
	if (wholeDocument) numberOfPages = self.editorDelegate.previewController.pagination.numberOfPages;
	else numberOfPages = [self.editorDelegate.previewController.pagination pageNumberAt:self.selectedRange.location];
		
	// Create the string
	NSString* infoString = [NSString stringWithFormat:
							@"%@\n"
							"%@: %lu\n"
							"%@: %lu",
							(wholeDocument) ? NSLocalizedString(@"textView.information.document", nil) : NSLocalizedString(@"textView.information.selection", nil),
							NSLocalizedString(@"textView.information.words", nil),
							printedWords,
							NSLocalizedString(@"textView.information.characters", nil),
							mStr.length];
	// Append page count
	if (wholeDocument) {
		infoString = [infoString stringByAppendingFormat:@"\n%@: %lu", NSLocalizedString(@"textView.information.pages", nil), numberOfPages];
	} else {
		BeatPaginationManager* pm = [BeatPaginationManager.alloc initWithSettings:self.editorDelegate.exportSettings delegate:nil renderer:[BeatRenderer.alloc initWithSettings:self.editorDelegate.exportSettings] livePagination:false];
		
		NSArray<Line*>* rawLines = [self.editorDelegate.parser linesInRange:self.selectedRange];
		NSArray<Line*>* lines = [ContinuousFountainParser preprocessForPrintingWithLines:rawLines documentSettings:self.editorDelegate.documentSettings];

		[pm paginateWithLines:lines];
		
		NSArray<NSNumber*>* length = pm.lengthInEights;
		NSInteger pages = length.firstObject.integerValue;
		NSInteger eights = length.lastObject.integerValue;
		
		NSString* l = [NSString stringWithFormat:@"%lu%@", pages, eights != 0 ? [NSString stringWithFormat:@" %lu/8", eights] : @""];
		infoString = [infoString stringByAppendingFormat:@"\n%@: %@", NSLocalizedString(@"textView.information.pages", nil), l];
	}
	
	// Create the stylized string with a bolded heading
	NSMutableAttributedString* attrString = [NSMutableAttributedString.alloc initWithString:infoString];
	NSDictionary* attributes = @{
		NSFontAttributeName: [NSFont systemFontOfSize:NSFont.systemFontSize],
		NSForegroundColorAttributeName: NSColor.textColor
	};
	
	[attrString addAttributes:attributes range:NSMakeRange(0, attrString.length)];
	[attrString addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:NSFont.systemFontSize] range:NSMakeRange(0, [attrString.string rangeOfString:@"\n"].location)];
	
	// Display popover at selected position
	NSInteger location = (wholeDocument) ? self.selectedRange.location : range.location;
	NSInteger length = (wholeDocument) ? 0 : range.length;
	
	[self showPopoverWithText:attrString inRange:NSMakeRange(location, length)];
}

/// This is a generic way to create a popover with any attributed string in the editor text view. Handle showing it yourself.
- (NSPopover*)createPopoverWithText:(NSAttributedString*)text
{
	if (self.infoPopover == nil) {
		// Info popover
		NSPopover* popover = NSPopover.new;
		popover.behavior = NSPopoverBehaviorTransient;
		
		NSView *infoContentView = [[NSView alloc] initWithFrame:NSZeroRect];
		NSTextView* infoTextView = [[NSTextView alloc] initWithFrame:NSZeroRect];
		
		infoTextView.editable = false;
		infoTextView.drawsBackground = false;
		infoTextView.richText = false;
		infoTextView.usesRuler = false;
		infoTextView.selectable = false;
		[infoTextView setTextContainerInset:NSMakeSize(8, 8)];
		
		infoTextView.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
		
		[infoContentView addSubview:infoTextView];
		
		NSViewController *infoViewController = NSViewController.new;
		infoViewController.view = infoContentView;
		
		popover.contentViewController = infoViewController;
		
		self.infoPopover = popover;
	}
	
	NSTextView* infoTextView = (NSTextView*)self.infoPopover.contentViewController.view.subviews.firstObject;
	
	// calculate content size
	[infoTextView.textStorage setAttributedString:text];
	[infoTextView.layoutManager ensureLayoutForTextContainer:infoTextView.textContainer];
	
	NSRect usedRect = [infoTextView.layoutManager usedRectForTextContainer:infoTextView.textContainer];
	NSRect frame = NSMakeRect(0, 0, 200, usedRect.size.height + 16);
	
	self.infoPopover.contentSize = frame.size;
	infoTextView.frame = NSMakeRect(0, 0, frame.size.width, frame.size.height);
	
	return self.infoPopover;
}

- (void)showPopoverWithText:(NSAttributedString*)text inRange:(NSRange)range
{
	if (self.infoPopover.isShown) [self.infoPopover close];
	
	NSRect rect = [self firstRectForCharacterRange:range actualRange:NULL];
	rect = [self.window convertRectFromScreen:rect];
	rect = [self convertRect:rect fromView:nil];
	rect.size.width = 5;
	
	NSPopover* popover = [self createPopoverWithText:text];
	[popover showRelativeToRect:rect ofView:self preferredEdge:NSMaxYEdge];

	[self.window makeFirstResponder:self];
}

@end
/**
 
 kylän häpeä
 helvetin kitaan heittäkää
 tyttö tää, karitsan pää
 ihmispään tilalla
 ja elämä pilalla
 
 en häpeä sinua!

 kylän häpeä
 tyttö tää vailla nimeä
 sen paha suu puhuu
 vaan ei liiku suu, eikä puhe kuulu
 (myös te halveeraajat saatte haavat)
 
 en häpeä sinua!
 
 mä sanoin: "älä mee"
 sä sanoit: "älä älättele.
 en mä tänne jää,
 en oo niin paha kuin väitetään"
 
 painaa mieltäsi pilkat
 painaa mieltäsi haavat
 painaa mieltäsi nimet
 painaa mieltäsi menneet
 painaa mieltäsi ilot
 painaa mieltäsi inho
 painaa mieltäsi bää-huudot
 painaa mieltäsi
 
 */
