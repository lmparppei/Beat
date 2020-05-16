//
//  ScrollView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

/*
 
 This is a subclass for moving some UI elements out of the way of the find bar
 
 */

#import "ScrollView.h"
#import "DynamicColor.h"

@implementation ScrollView

#define HIDE_INTERVAL 7.0

- (instancetype)init {
	return [super init];
}

- (void)awakeFromNib {
	_buttonDefaultY = _outlineButtonY.constant;
	
	// Save buttons for later use
	_editorButtons = @[_outlineButton, _cardsButton, _timelineButton];
	
	// Setup timer
	//_mouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:HIDE_INTERVAL target:self selector:@selector(shouldHideButtons:) userInfo:nil repeats:NO];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}
- (bool)isFullSize {
	return (([self.window styleMask] & NSWindowStyleMaskFullSizeContentView) == NSWindowStyleMaskFullSizeContentView);
}
- (bool)isFullscreen {
	return (([self.window styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

- (void)shouldHideButtons:(NSTimer *) timer {
	NSEvent *event = timer.userInfo;
	
	// Don't hide the toolbar buttons if the mouse is in the upper section of the window
	if (event.locationInWindow.y < _outlineButton.frame.origin.y - 5) [self hideButtons];
	else return;
}
- (void)hideButtons {
	if ([self isFullSize]) {
		[[[[self.window standardWindowButton:NSWindowCloseButton] superview] animator] setAlphaValue:0];
		[self.window setTitlebarAppearsTransparent:YES];
	}
	
	
	for (NSButton *button in _editorButtons) {
		[[button animator] setAlphaValue:0.0];
	}
	
}
- (void)showButtons {
	if ([self isFullSize]) {
		[[[[self.window standardWindowButton:NSWindowCloseButton] superview] animator] setAlphaValue:1];
		[self.window setTitlebarAppearsTransparent:NO];
	}
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
