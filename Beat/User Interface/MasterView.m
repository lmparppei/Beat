//
//  MasterView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 5.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import "MasterView.h"

@implementation MasterView

#define HIDE_INTERVAL 1.0
#define TITLEBAR_HEIGHT 22

- (instancetype)init {
	//_mouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:HIDE_INTERVAL target:self selector:@selector(hideTitleBar) userInfo:nil repeats:NO];
	_titleBarVisible = YES;
	
	return [super init];
}

-(void)awakeFromNib {
	/*
	[self.window setAcceptsMouseMovedEvents:YES];
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];

	[self addTrackingArea:trackingArea];
	 */
    //[self.master setAcceptsMouseMovedEvents:YES];
	//[self.masterView addTrackingArea:trackingArea];
	//[self.masterView setPostsBoundsChangedNotifications:YES];
}

-(void)mouseMoved:(NSEvent *)event {

}


/*
// Some other day
 
-(void)updateTrackingAreas {

	if (_trackingArea != nil) [self removeTrackingArea:_trackingArea];
	
	NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect |
							 NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved);
	NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[self bounds]
														options:options
														  owner:self
													   userInfo:nil];
	[self addTrackingArea:area];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}
- (void)mouseMoved:(NSEvent *)event {
	[_mouseMoveTimer invalidate];
	[self showTitleBar];
	
	_mouseMoveTimer = [NSTimer scheduledTimerWithTimeInterval:HIDE_INTERVAL target:self selector:@selector(shouldHideTitleBar:) userInfo:event repeats:NO];

}
- (void)shouldHideTitleBar:(NSTimer *) timer {
	[self hideTitleBar];
}
- (void)hideTitleBar {
	//[[[[self.window standardWindowButton:NSWindowCloseButton] superview] animator] setAlphaValue:0];
	[[[[self.window standardWindowButton:NSWindowCloseButton] superview] animator] setAlphaValue:0];
}
- (void)showTitleBar {
	[[[[self.window standardWindowButton:NSWindowCloseButton] superview] animator] setAlphaValue:1.0];
}
 */
 

@end
