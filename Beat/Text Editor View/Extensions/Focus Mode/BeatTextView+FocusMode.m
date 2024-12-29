//
//  BeatTextView+FocusMode.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 1.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+FocusMode.h"
#import "Document.h"

@implementation BeatTextView (FocusMode)

- (void)setupFocusMode
{
	BeatFocusModeType focusMode = [BeatUserDefaults.sharedDefaults getInteger:BeatSettingFocusMode];
	if (focusMode != BeatFocusModeOff) [self.editorDelegate registerSelectionObserver:self];
}

- (void)selectionDidChange:(NSRange)selectedRange
{
	[self focusRange:selectedRange];
}

- (void)setFocusModeType:(BeatFocusModeType)type
{
	[BeatUserDefaults.sharedDefaults saveInteger:type forKey:BeatSettingFocusMode];
	
	if (self.focusModeType != BeatFocusModeOff) {
		// Start observing
		[self.editorDelegate registerSelectionObserver:self];
		[self focusRange:self.editorDelegate.selectedRange];
	} else {
		// Remove temporary attributes and stop observing
		[self.editorDelegate unregisterSelectionObserver:self];
		NSLayoutManager* lm = self.layoutManager;
		[lm removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:NSMakeRange(0, self.text.length)];
	}
}

- (BeatFocusModeType)focusModeType
{
	return (BeatFocusModeType)[BeatUserDefaults.sharedDefaults getInteger:BeatSettingFocusMode];
}

- (IBAction)toggleFocusMode:(id)sender
{
	NSMenuItem* item = sender;

	// Toggle focus mode for every document
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc.textView setFocusModeType:(BeatFocusModeType)item.tag];
	}
}

- (BOOL)validateFocusMode:(NSMenuItem*)menuItem
{
	if (menuItem.tag == self.focusModeType) menuItem.state = NSOnState;
	else menuItem.state = NSOffState;
	return true;
}

- (void)focusRange:(NSRange)selectedRange
{
	NSRange focusRange;
		
	Line* line = self.editorDelegate.currentLine;
	NSString* text = self.text;
	
	if (line.type == heading || line.isTitlePage || line.isNote || self.focusModeType == BeatFocusModeBlock) {
		focusRange = line.textRange;
	} else {
		focusRange = [self findSentenceRangeWithSelectedRange:selectedRange];
	}
	
	[self.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:NSMakeRange(0, text.length)];
	
	if (focusRange.location != NSNotFound) {
		NSColor* color = [ThemeManager.sharedManager.textColor colorWithAlphaComponent:0.45];
		NSLayoutManager* lm = self.layoutManager;
		
		NSRange startRange = NSMakeRange(0, focusRange.location);
		NSRange endRange = NSMakeRange(NSMaxRange(focusRange), text.length - NSMaxRange(focusRange));
		
		[lm addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:startRange];
		[lm addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:endRange];
	}
}

- (NSRange)findSentenceRangeWithSelectedRange:(NSRange)range
{
	NSRange sentenceRange = NSMakeRange(0, 0);
	if (self.text.length == 0) return sentenceRange;
	
	NSString* text = self.text;
	
	for (NSInteger i=self.selectedRange.location - 1; i>=0; i--) {
		unichar c1 = [text characterAtIndex:i];
		if (c1 == '\n') {
			sentenceRange.location = i;
			break;
		}
		if (i < 1) {
			sentenceRange.location = 0;
			break;
		}
		if (c1 == ' ') {
			unichar c2 = [text characterAtIndex:i-1];
			if (c2 == '.' || c2 == '?' || c2 == '!') {
				sentenceRange.location = i;
				break;
			}
		}
	}
	
	for (NSInteger i=NSMaxRange(range); i<=text.length; i++) {
		if (i == text.length) {
			sentenceRange.length = i - sentenceRange.location;
			break;
		}
		
		unichar c1 = [text characterAtIndex:i];
		if (c1 == '\n') {
			sentenceRange.length = i - sentenceRange.location;
			break;
		}
		if (c1 == ' ' && i > 0) {
			unichar c2 = [text characterAtIndex:i-1];
			if (c2 == '!' || c2 == '?' || c2 == '.') {
				sentenceRange.length = i - sentenceRange.location;
				break;
			}
		}
	}
	
	// Caret at end
	if (NSMaxRange(range) == text.length) {
		sentenceRange.length = text.length - sentenceRange.location;
	}
	
	return sentenceRange;
}

@end
