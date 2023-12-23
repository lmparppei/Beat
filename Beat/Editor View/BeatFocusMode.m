//
//  BeatFocusMode.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatFocusMode.h"
#import <BeatCore/BeatCore.h>
#import <BeatThemes/BeatThemes.h>

@interface BeatFocusMode() <BeatSelectionObserver>
@property (nonatomic, weak) id<BeatEditorDelegate> delegate;
@end

@implementation BeatFocusMode

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate
{
	self = [super init];
	if (self) {
		self.delegate = delegate;
		
		BOOL focusMode = [BeatUserDefaults.sharedDefaults getBool:BeatSettingFocusMode];
		if (focusMode) [_delegate registerSelectionObserver:self];
	}
	return self;
}

- (void)selectionDidChange:(NSRange)selectedRange
{
	[self focus:selectedRange];
}

- (void)toggle
{
	BOOL focusMode = ![BeatUserDefaults.sharedDefaults getBool:BeatSettingFocusMode];
	if (focusMode) {
		// Start observing
		[_delegate registerSelectionObserver:self];
		[self focus:self.delegate.selectedRange];
	} else {
		// Remove temporary attributes and stop observing
		[_delegate unregisterSelectionObserver:self];
		NSLayoutManager* lm = self.delegate.layoutManager;
		[lm removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:NSMakeRange(0, self.delegate.text.length)];
	}
	
	[BeatUserDefaults.sharedDefaults saveBool:focusMode forKey:BeatSettingFocusMode];
}

- (void)focus:(NSRange)selectedRange
{
	NSRange sentenceRange = NSMakeRange(NSNotFound, 0);
	
	Line* line = self.delegate.currentLine;
	NSString* text = self.delegate.text;
	
	if (line.type == heading || line.isTitlePage || line.note) {
		sentenceRange = line.textRange;
	} else {
		sentenceRange = [self findSentenceRangeWithSelectedRange:selectedRange];
	}
	
	[self.delegate.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:NSMakeRange(0, text.length)];
	
	if (sentenceRange.location != NSNotFound) {
		NSColor* color = [ThemeManager.sharedManager.textColor colorWithAlphaComponent:0.3];
		NSLayoutManager* lm = self.delegate.layoutManager;
		
		NSRange startRange = NSMakeRange(0, sentenceRange.location);
		NSRange endRange = NSMakeRange(NSMaxRange(sentenceRange), text.length - NSMaxRange(sentenceRange));
		
		[lm addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:startRange];
		[lm addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:endRange];
	}
}

- (NSRange)findSentenceRangeWithSelectedRange:(NSRange)range
{
	NSRange sentenceRange = NSMakeRange(0, 0);
	if (self.delegate.text.length == 0) return sentenceRange;
	
	NSString* text = self.delegate.text;
	
	for (NSInteger i=self.delegate.selectedRange.location - 1; i>=0; i--) {
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
