//
//  MarginView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//
//  This draws a "paper" view under BeatTextView.

#import "MarginView.h"
#import "DynamicColor.h"

#define WHITESPACE 120
#define SHADOW_WIDTH 20
#define SHADOW_OPACITY 0.0125

@implementation MarginView

- (void)drawRect:(NSRect)dirtyRect {
	[NSGraphicsContext saveGraphicsState];
    [super drawRect:dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
    
	 // Draw background (we have drawBackground se as NO, as otherwise the margins didn't work.)
	 // I can't get my head around this so let's just do the background manually.
	 [self.backgroundColor setFill];
	
	 NSRectFill(NSMakeRect(0, 0, self.frame.size.width, self.frame.size.height));
	 
	 // Draw margins if they don't fall outsid(e/ish) the viewport
	 if (self.frame.size.width > 800) {
		 [self.marginColor setFill];
		 
		 CGFloat marginWidth = (_insetWidth - WHITESPACE) * _magnificationLevel;
		 
		 if (marginWidth > 0) {
			 // Set margin boxes
			 NSRect marginLeft = NSMakeRect(0, 0, marginWidth, self.frame.size.height);
			 NSRect marginRight = NSMakeRect((self.frame.size.width - marginWidth), 0, marginWidth, self.frame.size.height);
			 
			 NSRect shadowLeft = (NSRect){ marginLeft.size.width - SHADOW_WIDTH, 0, SHADOW_WIDTH, marginLeft.size.height };
			 NSRect shadowRight = (NSRect){ marginRight.origin.x, 0, SHADOW_WIDTH, marginRight.size.height };
			 
			 NSRectFillUsingOperation(marginLeft, NSCompositingOperationSourceOver);
			 NSRectFillUsingOperation(marginRight, NSCompositingOperationSourceOver);
			 
			 NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:NSColor.clearColor endingColor:[NSColor.blackColor colorWithAlphaComponent:SHADOW_OPACITY]];
			 [gradient drawInRect:shadowLeft angle:0];
			 [gradient drawInRect:shadowRight angle:180];
			 
		 }
	 }
}
- (bool)isFullscreen {
	return (([self.window styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

@end
/*
 
 kun mä kasvan isoksi
 haluan puutarhan
 ja pienen veneen
 
 istutan metsän talon ympärille
 tutustun sen eläimiin
 ja yritän oppia niiltä jotain
 
 kuten piiloutumisen taidon
 tai no sen mä opin
 jo lapsena jossakin
 
 */
