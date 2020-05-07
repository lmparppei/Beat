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
	return [super init];
}

- (void)awakeFromNib {
	_buttonDefaultY = _outlineButtonY.constant;
	
	// Save buttons for later use
	_editorButtons = @[_outlineButton, _cardsButton, _timelineButton];
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
	
	// Draw margins if they don't fall outside the viewport
	if (self.frame.size.width > 800) {
		[_marginColor setFill];
		
		CGFloat marginWidth = (_insetWidth - 130) * _magnificationLevel;
		if (marginWidth > 0) {
			// Set margin boxes
			NSRect marginLeft = NSMakeRect(0, 0, marginWidth, self.frame.size.height);
			NSRect marginRight = NSMakeRect((self.frame.size.width - marginWidth), 0, marginWidth, self.frame.size.height);
			
			[NSGraphicsContext saveGraphicsState];
			NSRectFillUsingOperation(marginLeft, NSCompositingOperationSourceOver);
			NSRectFillUsingOperation(marginRight, NSCompositingOperationSourceOver);
			[NSGraphicsContext restoreGraphicsState];
		}
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
	for (NSButton *button in _editorButtons) {
		[[button animator] setAlphaValue:0.0];
	}
}
- (void)showButtons {
	for (NSButton *button in _editorButtons) {
		[[button animator] setAlphaValue:1.0];
	}
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
	
	// Save original constant
	if (_buttonDefaultY == 0) _buttonDefaultY = _outlineButtonY.constant;
	
	if (!findBarVisible) {
		_outlineButtonY.constant = _buttonDefaultY;
	} else {
		_outlineButtonY.constant += height;
	}
}

- (void) findBarViewDidChangeHeight {
	if (self.findBarVisible) {
		CGFloat height = [self findBarView].frame.size.height;
		_outlineButtonY.constant = _buttonDefaultY + height;
	}
	//CGFloat height = [self findBarView].frame.size.height;
}


@end
