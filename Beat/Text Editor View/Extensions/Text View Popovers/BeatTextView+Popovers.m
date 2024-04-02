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
	[self.popoverController displayWithRange:substringRange items:matches callback:^BOOL(NSString * _Nonnull string, NSInteger index) {
		[self insertAutocompletionString:string];
		// This block returns false so that we can press enter for a new paragraph after autocompleting a line, or tab to stay on that line.
		return false;
	}];
	
	[self.popoverController selectRowWithIndex:index];
}

/// Called from popover controller block to insert the selected string at current line.
- (void)insertAutocompletionString:(NSString*)string
{
	NSInteger beginningOfWord;
	
	Line* currentLine = self.editorDelegate.currentLine;
	if (currentLine) {
		NSInteger locationInString = self.selectedRange.location - currentLine.position;
		beginningOfWord = self.selectedRange.location - locationInString;
	} else {
		beginningOfWord = self.selectedRange.location - self.partialText.length;
	}
	
	NSRange range = NSMakeRange(beginningOfWord, self.partialText.length);
	
	if ([self shouldChangeTextInRange:range replacementString:string]) {
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
	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	NSInteger symbols = string.length;
	
	for (NSString *line in lines) {
		for (NSString *word in [line componentsSeparatedByString:@" "]) {
			if (word.length > 0) words += 1;
		}
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
							words,
							NSLocalizedString(@"textView.information.characters", nil),
							symbols];
	// Append page count
	if (wholeDocument) {
		infoString = [infoString stringByAppendingFormat:@"\n%@: %lu", NSLocalizedString(@"textView.information.pages", nil), numberOfPages];
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
