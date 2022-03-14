//
//  BeatTagButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 24.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTagButton.h"
@interface BeatTagButton ()
@property (nonatomic) IBInspectable NSColor *itemColor;
@end

@implementation BeatTagButton
#define Inset 0

-(void)awakeFromNib {
	self.cell.bordered = NO;
	self.cell.backgroundStyle = 0;
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	
	CGFloat radius = self.frame.size.height * .4;
	NSRect circle = NSMakeRect((self.frame.size.height - radius) / 2, (self.frame.size.height - radius) / 2, radius, radius);
	NSBezierPath *circlePath = [NSBezierPath bezierPathWithRoundedRect:circle xRadius:radius / 2 yRadius:radius / 2];
	
	NSRect rect = NSMakeRect(Inset, Inset, self.frame.size.width - Inset * 2, self.frame.size.height - Inset * 2);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:10 yRadius:10];
	
	NSColor *fillColor = NSColor.darkGrayColor;
	NSColor *textColor  = NSColor.whiteColor;
	
	if (self.isHighlighted) {
		fillColor = NSColor.blackColor;
	}
	else if (self.state == NSControlStateValueOn) {
		fillColor = NSColor.whiteColor;
		textColor = NSColor.darkGrayColor;
	}

	[fillColor setFill];
	[path fill];
	[_itemColor setFill];
	[circlePath fill];
	
	NSString *titleText = [NSString stringWithString:self.title];

	NSRect textRect = NSMakeRect(0, 0, rect.size.width, rect.size.height);
	NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:(titleText) ? titleText : @""];
	
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	//style.alignment = NSTextAlignmentCenter;
	[title addAttribute:NSParagraphStyleAttributeName value:style range:(NSRange){0, title.length}];
	[title addAttribute:NSForegroundColorAttributeName value:textColor range:(NSRange){0, title.length}];
	CGFloat textHeight = [title boundingRectWithSize:(NSSize){ textRect.size.width, textRect.size.height } options:NSStringDrawingUsesLineFragmentOrigin].size.height;
	
	
	NSRect drawingRect = NSMakeRect(radius * 2.2, (textRect.size.height - textHeight) / 2 + Inset, textRect.size.width, textRect.size.height);
	[NSGraphicsContext saveGraphicsState];
	[title drawInRect:drawingRect];
	[NSGraphicsContext restoreGraphicsState];
}

@end
