//
//  BeatTextView+SelectionEvents.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.8.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+SelectionEvents.h"
#import "BeatTextView+Popovers.h"
#import "Beat-Swift.h"

@implementation BeatTextView (SelectionEvents)

#pragma mark - Selection events

/**
 
 There are TWO different didChangeSelection listeners, here and in Document.
 This one deals with text editor events, such as tagging, typewriter scroll,
 closing autocomplete and displaying reviews.
 
 The one in Document handles other UI-related stuff, such as updating views
 that are hooked into the parsed screenplay contents, and also updates plugins.
 
 */
- (void)didChangeSelection:(NSNotification *)notification
{
	// Skip event when needed
	if (self.editorDelegate.skipSelectionChangeEvent) {
		self.editorDelegate.skipSelectionChangeEvent = NO;
		return;
	}
		
	// If selection moves by more than just one character, hide autocomplete
	if ((self.selectedRange.location - self.lastPos) > 1) {
		if (self.popoverController.isShown) [self setAutomaticTextCompletionEnabled:NO];
		[self closePopovers];
	}
	
	// Show tagging/review options for selected range
	
	switch (self.editorDelegate.mode) {
		case TaggingMode:
			// Show tag list
			[self showTagSelector];
			break;
		case ReviewMode:
			// Show review editor
			[self.editorDelegate.review showReviewIfNeededWithRange:self.selectedRange forEditing:YES];
			break;
		default:
			[self selectionEvents];
			break;
	}
}

- (bool)selectionAtEnd
{
	return (self.selectedRange.location == self.string.length);
}

- (void)selectionEvents
{
	// TODO: I could/should make this one a registered event, too.
	
	// Don't go out of range. We can't check for attributes at the last index.
	NSUInteger pos = self.selectedRange.location;
	if (NSMaxRange(self.selectedRange) >= self.string.length) pos = self.string.length - 1;
	if (pos < 0) pos = 0;
	
	// Review items
	if (self.string.length > 0) {
		BeatReviewItem *reviewItem = [self.textStorage attribute:BeatReview.attributeKey atIndex:pos effectiveRange:nil];
		if (reviewItem && !reviewItem.emptyReview) {
			[self.editorDelegate.review showReviewIfNeededWithRange:NSMakeRange(pos, 0) forEditing:NO];
			[self.window makeFirstResponder:self];
		} else {
			[self.editorDelegate.review closePopover];
		}
	}
}

@end
