//
//  BeatLaunchButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatLaunchButton.h"
#import "NSImage+ProportionalScaling.h"

#define PADDING 3.0

@interface BeatLaunchButton ()
@property (nonatomic) IBInspectable NSString *subtitle;
@end

@implementation BeatLaunchButton

-(void)awakeFromNib {
	
	NSButton *button = (NSButton*)self.controlView;
	
	button.wantsLayer = YES;
	button.layer.cornerRadius = 5.0;
	
	NSTrackingArea* trackingArea = [[NSTrackingArea alloc]
									initWithRect:button.bounds
									options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
									owner:self userInfo:nil];
	[button addTrackingArea:trackingArea];
	
}

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	[super drawWithFrame:cellFrame inView:controlView];
}

-(NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView {
	NSButton *button = (NSButton*)controlView;
	
	// Save current appearance
	NSAppearance * appearance = NSAppearance.currentAppearance;
	[NSAppearance setCurrentAppearance:controlView.window.effectiveAppearance];
	
	// Text colors
	NSColor *color; NSColor *topColor;
	if (@available(macOS 10.14, *)) {
		color = [NSColor.controlTextColor colorWithAlphaComponent:.6];
		topColor = [NSColor.controlTextColor colorWithAlphaComponent:.9];
		
		if (button.isHighlighted) {
			color = [color colorWithAlphaComponent:1.0];
			topColor = [NSColor.controlTextColor colorWithAlphaComponent:1.0];
		}
	} else {
		// Legacy colors for Mojave
		color = [NSColor.lightGrayColor colorWithAlphaComponent:.6];
		topColor = [NSColor.lightGrayColor colorWithAlphaComponent:.9];
	}
	
	// Create the label using both button title & tooltip
	NSString *topTitle = button.title;
	NSString *bottomTitle = self.subtitle;
	
	// Stylize the label
	NSMutableAttributedString *attrStr = [NSMutableAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@\n%@", topTitle, bottomTitle]];
	[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:NSFont.systemFontSize] range:(NSRange){ 0, attrStr.length }];
	[attrStr addAttribute:NSForegroundColorAttributeName value:color range:(NSRange){ 0, attrStr.length }];
	[attrStr addAttribute:NSForegroundColorAttributeName value:topColor range:(NSRange){ 0, topTitle.length }];
	
	[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13.0] range:(NSRange){ 0, topTitle.length }];
	[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:8.5] range:(NSRange){ topTitle.length + 1, bottomTitle.length }];
	
	// Draw text on cell
	NSRect stringRect = (NSRect){ controlView.frame.size.height + 8, (controlView.frame.size.height - attrStr.size.height) / 2 - 1 , attrStr.size.width, attrStr.size.height };
	[attrStr drawInRect:stringRect];
	
	// Restore appearance
	[NSAppearance setCurrentAppearance:appearance];
	
	return stringRect;
}

-(void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView {
	NSButton *button = (NSButton*)controlView;
	NSAppearance * appearance = NSAppearance.currentAppearance;
	[NSAppearance setCurrentAppearance:controlView.window.effectiveAppearance];
	
	NSImage *scaledImage = [image imageByScalingProportionallyToSize:(NSSize){ controlView.frame.size.height - PADDING * 2, controlView.frame.size.height - PADDING * 2 }];
	
	// Colorize the image based on button status
	NSColor *color = [NSColor.controlTextColor colorWithAlphaComponent:.6];
	if (button.isHighlighted) color = [color colorWithAlphaComponent:1.0];
	
	// Apply tint to image
	[scaledImage lockFocus];
	[color set];
	NSRect imageRect = {NSZeroPoint, scaledImage.size};
	NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
	[scaledImage unlockFocus];
	
	// Draw image
	[scaledImage drawInRect:(NSRect){ 0 + PADDING, 0 + PADDING, scaledImage.size.width, scaledImage.size.height }];
	
	[NSAppearance setCurrentAppearance:appearance];
}

-(void)mouseEntered:(NSEvent *)event {
	NSAppearance * appearance = NSAppearance.currentAppearance;
	[NSAppearance setCurrentAppearance:self.controlView.window.effectiveAppearance];
	
	self.controlView.layer.backgroundColor = [NSColor.windowBackgroundColor colorWithAlphaComponent:.8].CGColor;
	
	[NSAppearance setCurrentAppearance:appearance];
}
-(void)mouseExited:(NSEvent *)event {
	NSAppearance * appearance = NSAppearance.currentAppearance;
	[NSAppearance setCurrentAppearance:self.controlView.window.effectiveAppearance];
	
	self.controlView.layer.backgroundColor = NSColor.clearColor.CGColor;
	
	[NSAppearance setCurrentAppearance:appearance];
}

- (NSString*)subtitle {
	NSString *str = NSLocalizedString(self.localizationId, nil);
	if (str.length) return str;
	else return _subtitle;
}

@end
/*
 
 the music's out
 we used to play it so loud
 just before we'd hit the town
 but we grow old
 kings give up their thrones
 and no one wants to be alone
 
 */
