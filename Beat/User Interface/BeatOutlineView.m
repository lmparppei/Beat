//
//  BeatOutlineView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 07/10/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import "BeatOutlineView.h"

@implementation BeatOutlineView

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
}
- (void)drawBackgroundInClipRect:(NSRect)clipRect {
	//[super drawBackgroundInClipRect:clipRect];
	
	if (self.currentScene != NSNotFound) {
		NSRect rect = [self rectOfRow:self.currentScene];
		
		NSColor* fillColor = NSColor.grayColor;
		fillColor = [fillColor colorWithAlphaComponent:0.4];
		[fillColor setFill];
		
		NSRectFill(rect);
	}
}

- (NSTouchBar*)makeTouchBar {
	return _touchBar;
}

@end
