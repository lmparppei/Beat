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

#define HIDE_INTERVAL 5.0

- (instancetype)init {
	_mouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:HIDE_INTERVAL target:self selector:@selector(hideButtons) userInfo:nil repeats:NO];
	return [super init];
}

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

- (void)shouldHideButtons:(NSTimer *) timer {
	NSEvent *event = timer.userInfo;
	
	// Don't hide the toolbar buttons if the mouse is in the upper section of the window
	if (event.locationInWindow.y < _outlineButton.frame.origin.y - 5) [self hideButtons];
	else return;
}
- (void)hideButtons {
	[[_outlineButton animator] setAlphaValue:0.0];
	[[_cardsButton animator] setAlphaValue:0.0];
	[[_timelineButton animator] setAlphaValue:0.0];
}
- (void)showButtons {
	[[_outlineButton animator] setAlphaValue:1.0];
	[[_cardsButton animator] setAlphaValue:1.0];
	[[_timelineButton animator] setAlphaValue:1.0];
}

- (void)mouseMoved:(NSEvent *)event {
	[self showButtons];
	[_mouseMoveTimer invalidate];
	
	_mouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:HIDE_INTERVAL target:self selector:@selector(shouldHideButtons:) userInfo:event repeats:NO];
}

// Listen to find bar open/close and move the outline / card view buttons accordingly
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
