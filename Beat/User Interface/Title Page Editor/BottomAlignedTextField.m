//
//  BottomAlignedTextField.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.5.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BottomAlignedTextField.h"

@implementation BottomAlignedTextField

- (NSRect) titleRectForBounds:(NSRect)frame {
	CGFloat stringHeight = self.attributedStringValue.size.height;
	NSRect titleRect = [super titleRectForBounds:frame];
	CGFloat oldOriginY = frame.origin.y;
	titleRect.origin.y = frame.origin.y + (frame.size.height - stringHeight);
	titleRect.size.height = titleRect.size.height - (titleRect.origin.y - oldOriginY);
	return titleRect;
}

- (void) drawInteriorWithFrame:(NSRect)cFrame inView:(NSView*)cView {
	[super drawInteriorWithFrame:[self titleRectForBounds:cFrame] inView:cView];
}

@end
