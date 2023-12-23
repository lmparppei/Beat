//
//  BeatClipView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.10.2021.
//  Copyright © 2021-2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatClipView.h"
#import "BeatTextView.h"

@implementation BeatClipView

-(void)awakeFromNib {
	[super awakeFromNib];
	self.wantsLayer = NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

-(void)layout {
	// We are not laying out the clip view, because it can cause an endless layout loop on some systems.
	// No idea about the possible reprecussions, but this is the way now. Uncomment if needed, but you'll
	// probably kill support for many computers. Greetings from March 2022.

	if (@available(macOS 11.0, *)) {
		// [super layout];
	} else {
		[super layout];
	}
}


- (NSRect)constrainBoundsRect:(NSRect)proposedBounds {
	BeatTextView* textView = (BeatTextView*)_editorDelegate.getTextView;
	if (!textView.typewriterMode) return [super constrainBoundsRect:proposedBounds];
	return proposedBounds;
}


@end
