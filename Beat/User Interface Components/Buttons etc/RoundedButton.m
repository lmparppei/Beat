//
//  RoundedButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 29.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "RoundedButton.h"

@implementation RoundedButton
#define PADDING 8.0
#define RADIUS 5.0

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	//[super drawWithFrame:cellFrame inView:controlView];
	if (!self.borderColor) self.borderColor = NSColor.whiteColor;
	
	CGFloat alpha = 1.0;
	if (self.clicked) alpha = 0.7;
	NSColor *drawColor = [self.borderColor colorWithAlphaComponent:alpha];
	
	NSRect rect = NSMakeRect(cellFrame.origin.x + PADDING, cellFrame.origin.y + PADDING,
							 cellFrame.size.width - PADDING * 2, cellFrame.size.height - PADDING * 2);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:RADIUS yRadius:RADIUS];
	
	[drawColor setStroke];
	
	[path stroke];
	
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
	[paragraphStyle setAlignment:NSTextAlignmentCenter];
	
	NSAttributedString *label = [[NSAttributedString alloc] initWithString:self.title attributes:@{
		NSFontAttributeName: self.font,
		NSParagraphStyleAttributeName: paragraphStyle,
		NSForegroundColorAttributeName: drawColor
	}];
	
	CGFloat x = (cellFrame.size.width - label.size.width) / 2;
	CGFloat y = (cellFrame.size.height - label.size.height) / 2 - 1;
	
	[label drawAtPoint:NSMakePoint(x, y)];
	 
}
- (void)mouseEntered:(NSEvent *)event {
	NSLog(@"enter");
}

@end
