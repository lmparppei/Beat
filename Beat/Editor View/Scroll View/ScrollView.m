//
//  ScrollView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This is a subclass for moving some UI elements out of the way of the find bar,
 and also hiding the UI button bar when the mouse is not moved.
 
 Also handles pinch-zooming.
 
 */

#import <BeatThemes/BeatThemes.h>

#import "ScrollView.h"
#import "BeatTextView.h"
#import "Beat-Swift.h"
#import "BeatTextView.h"

@interface ScrollView()
@property (nonatomic) NSGestureRecognizer *recognizer;
@end
@implementation ScrollView

#define HIDE_INTERVAL 6.0
#define TIMER_HIDE_INTERVAL 5.0

- (instancetype)init {
	return [super init];
}

- (void)awakeFromNib {
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];
	[self.window setAcceptsMouseMovedEvents:YES];
	[self addTrackingArea:trackingArea];
	
	self.wantsLayer = NO;
	
	_recognizer = [[NSMagnificationGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];
	[self addGestureRecognizer:_recognizer];
}

- (void)removeFromSuperview {
	[_mouseMoveTimer invalidate];
	[_timerMouseMoveTimer invalidate];
	
	_mouseMoveTimer = nil;
	_timerMouseMoveTimer = nil;
	
	self.documentView = nil;
	
	[super removeFromSuperview];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}
- (bool)isFullSize {
	return ((self.window.styleMask & NSWindowStyleMaskFullSizeContentView) == NSWindowStyleMaskFullSizeContentView);
}
- (bool)isFullscreen {
	return ((self.window.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

-(void)setFrame:(NSRect)frame {
	[super setFrame:frame];
}

- (void)viewDidChangeEffectiveAppearance {
	// Update button style
	for (NSView *view in _buttonView.subviews) {
		[view layout];
	}
}


#pragma mark - Hiding and showing editor buttons

- (void)shouldHideButtons:(NSTimer *) timer {
	NSPoint mouseLoc = [NSEvent mouseLocation];
	NSPoint location = [self convertPoint:mouseLoc toView:nil];

	// Don't hide the toolbar buttons if the mouse is in the upper section of the window
	if (location.y > 35 && location.y > 0) [self hideButtons];
	else return;
}
- (void)shouldHideTimer:(NSTimer *) timer {
	NSPoint mouseLoc = [NSEvent mouseLocation];
	NSPoint location = [self convertPoint:mouseLoc toView:nil];
	
	if (location.y < self.frame.size.height && location.y > self.frame.size.height - self.timerView.frame.size.height * 2) {
		return;
	} else {
		[self hideTimer];
	}
}
- (void)hideButtons {
	[_buttonView.animator setAlphaValue:0.0];
}
- (void)hideTimer {
	[_timerView.animator setAlphaValue:0.0];
}

- (void)showButtons {
	[_buttonView.animator setAlphaValue:1.0];
}
- (void)showTimer {
	[_timerView.animator setAlphaValue:1.0];
}
- (void)timerDidStart {
	[self showTimer];
	[_timerMouseMoveTimer invalidate];
	_timerMouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_HIDE_INTERVAL target:self selector:@selector(shouldHideTimer:) userInfo:nil repeats:NO];
}

- (void)mouseMoved:(NSEvent *)event {
	[super mouseMoved:event];
	
	// Show upper buttons
	[self showButtons];
	[_mouseMoveTimer invalidate];
	_mouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:HIDE_INTERVAL target:self selector:@selector(shouldHideButtons:) userInfo:event repeats:NO];
	
	// Show timer if mouse is at the bottom of the screen
	NSPoint location = [self convertPoint:event.locationInWindow toView:nil];
	if (location.y < self.frame.size.height && location.y > self.frame.size.height - self.timerView.frame.size.height * 2) {
		[self showTimer];
		[_timerMouseMoveTimer invalidate];
		_timerMouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_HIDE_INTERVAL target:self selector:@selector(shouldHideTimer:) userInfo:event repeats:NO];
		
	}
}

- (void)layoutButtons {
	for (NSButton *button in self.editorButtons) {
		[button setNeedsLayout:YES];
	}
}


#pragma mark - Find bar listener

// Listen to find bar open/close and move the outline / card view buttons accordingly
- (void)setFindBarVisible:(BOOL)findBarVisible {
	[super setFindBarVisible:findBarVisible];
	
	NSRect frame = _buttonView.frame;
	CGFloat height = self.findBarView.frame.size.height;
	
	// Save original constant
	if (_buttonDefaultY == 0) _buttonDefaultY = _buttonView.frame.origin.y;
	
	if (!findBarVisible) {
		frame.origin.y = _buttonDefaultY;		
		[self.window makeFirstResponder:self.documentView];
	} else {
		frame.origin.y -= height;
	}
	
	_buttonView.frame = frame;
	
}

- (void)findBarViewDidChangeHeight {
	if (self.findBarVisible) {
		NSRect frame = _buttonView.frame;
		CGFloat height = self.findBarView.frame.size.height;
		frame.origin.y = _buttonDefaultY - height;
		_buttonView.frame = frame;
	}
	
	[super findBarViewDidChangeHeight];
}

CGFloat _originalZoomLevel;
- (void)pinch:(NSEvent*)event {
	BeatTextView *textView = self.documentView;
	
	if (self.recognizer.state == NSGestureRecognizerStateBegan) _originalZoomLevel = textView.zoomLevel;
	
	[textView adjustZoomLevel:_originalZoomLevel + event.magnification * .25];
}


double clampf(double d, double min, double max) {
	const double t = d < min ? min : d;
	return t > max ? max : t;
}


@end
/*

 suljetaan
 ovet meidän takana
 näiltä kauheita vuosilta
 eikä katsota taa
 
 maalataan
 kasvot sinisellä savella
 kuoritaan pois kuollutta ihoa
 en sano sun nimeäs
 enää koskaan
 
 en sano sun nimeäs
 enää koskaan
 
 kukaan meistä ei aio sanoa
 sun nimeäs enää
 
 sä et lyö mua enää
 sä et lyö mua enää.
 
 */
