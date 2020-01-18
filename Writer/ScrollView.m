//
//  ScrollView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

/*
 
 This is a subclass for drawing margins behind the view and
 to move some UI elements out of the way of the find bar
 
 */

#import "ScrollView.h"
#import "DynamicColor.h"

@implementation ScrollView

- (void)drawRect:(NSRect)dirtyRect {
	[NSGraphicsContext saveGraphicsState];
    [super drawRect:dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
	
	// Draw background (we have drawBackground se as NO, as otherwise the margins didn't work.)
	// I can't get my head around this so let's just do the background manually.
	[NSGraphicsContext saveGraphicsState];
	[self.backgroundColor setFill];
	NSRectFill(NSMakeRect(0, 0, self.frame.size.width, self.frame.size.height));
	[NSGraphicsContext restoreGraphicsState];
	
	// Draw margins
	if (self.frame.size.width > 1000) {
		[_marginColor setFill];
		
		CGFloat modifier = 1 / self.magnification;
		CGFloat marginWidth = _insetWidth - 120;
		
		NSRect marginLeft = NSMakeRect(0, 0, marginWidth, self.frame.size.height);
		NSRect marginRight = NSMakeRect((self.frame.size.width - marginWidth) * modifier, 0, marginWidth + 200, self.frame.size.height);
		
		[NSGraphicsContext saveGraphicsState];
		NSRectFillUsingOperation(marginLeft, NSCompositingOperationSourceOver);
		NSRectFillUsingOperation(marginRight, NSCompositingOperationSourceOver);
		
		[NSGraphicsContext restoreGraphicsState];
	}
}

// Listen to find bar open/close and move the buttons accordingly
- (void)setFindBarVisible:(BOOL)findBarVisible {
	[super setFindBarVisible:findBarVisible];
	
	CGFloat height = [self findBarView].frame.size.height;
	
	if (!findBarVisible) {
		_outlineButtonY.constant -= height;
	} else {
		_outlineButtonY.constant += height;
	}	
}

- (void) findBarViewDidChangeHeight {
	
}


@end
