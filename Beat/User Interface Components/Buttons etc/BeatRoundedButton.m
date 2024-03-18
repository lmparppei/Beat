//
//  BeatRoundedButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 29.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatRoundedButton.h"
#import "RoundedButton.h"

@implementation BeatRoundedButton

- (instancetype)initWithFrame:(NSRect)frameRect {
	return [super initWithFrame:frameRect];
}
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    // Drawing code here.
}
- (void)mouseDown:(NSEvent *)event {
	[super mouseDown:event];
	
	RoundedButton* button = self.cell;
	button.clicked = YES;
	[self setNeedsDisplay];
}
- (void)mouseUp:(NSEvent *)event {
	[super mouseUp:event];
	
	RoundedButton* button = self.cell;
	button.clicked = NO;
	[self setNeedsDisplay];
}
- (void)mouseExited:(NSEvent *)event {
	[super mouseExited:event];
	
	RoundedButton* button = self.cell;
	button.clicked = NO;
	[self setNeedsDisplay];
}

@end
