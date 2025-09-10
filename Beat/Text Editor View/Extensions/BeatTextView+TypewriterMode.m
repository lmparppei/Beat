//
//  BeatTextView+TypewriterMode.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+TypewriterMode.h"
#import "BeatClipView.h"

@implementation BeatTextView (TypewriterMode)


#pragma mark - Typewriter scroll

- (bool)typewriterMode
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingTypewriterMode];
}
- (void)setTypewriterMode:(bool)typewriterMode
{
	[BeatUserDefaults.sharedDefaults saveBool:typewriterMode forKey:BeatSettingTypewriterMode];
}

- (IBAction)toggleTypewriterMode:(id)sender
{
	self.typewriterMode = !self.typewriterMode;
	
	for (id<BeatEditorDelegate>doc in NSDocumentController.sharedDocumentController.documents) {
		[doc updateLayout];
	}
}

- (void)updateTypewriterView
{
	// Do nothing if the selection is longer than 0
	if (self.selectedRange.length > 0) return;
	
	NSRange range = [self.layoutManager glyphRangeForCharacterRange:self.selectedRange actualCharacterRange:nil];
	NSRect rect = [self.layoutManager boundingRectForGlyphRange:range inTextContainer:self.textContainer];
	
	CGFloat viewOrigin = self.enclosingScrollView.documentVisibleRect.origin.y;
	CGFloat viewHeight = self.enclosingScrollView.documentVisibleRect.size.height;
	CGFloat y = rect.origin.y + self.textContainerInset.height;
	if (y < viewOrigin || y > viewOrigin + viewHeight) [self typewriterScroll];
}

- (void)typewriterScroll
{
	if (self.needsLayout) [self layout];
	[self.layoutManager ensureLayoutForCharacterRange:self.editorDelegate.currentLine.range];
	
	BeatClipView* clipView = (BeatClipView*)self.enclosingScrollView.contentView;
	
	// Find the rect for current range
	NSRect rect = [self rectForRange:self.selectedRange];
		
	// Calculate correct scroll position
	CGFloat scrollY = (rect.origin.y - self.editorDelegate.fonts.regular.pointSize * 2) * self.editorDelegate.magnification;
	
	// Take find & replace bar height into account
	// CGFloat findBarHeight = (self.enclosingScrollView.findBarVisible) ? self.enclosingScrollView.findBarView.frame.size.height : 0;
	
	// Calculate container height with insets
	CGFloat containerHeight = [self.layoutManager usedRectForTextContainer:self.textContainer].size.height;
	containerHeight = containerHeight * self.editorDelegate.magnification + self.textInsetY * 2 * self.editorDelegate.magnification;
	
	NSRect bounds = NSMakeRect(clipView.bounds.origin.x, scrollY, clipView.bounds.size.width, clipView.bounds.size.height);
	
	[self.superview.animator setBoundsOrigin:bounds.origin];
}

@end
