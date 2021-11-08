//
//  BeatMarkerScroller.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 Scroller subclass used to draw markers under scroll bar
 
 */

#import "BeatMarkerScroller.h"
#import "BeatColors.h"
@interface BeatMarkerScroller ()
@property (nonatomic) NSArray *markers;
@end
@implementation BeatMarkerScroller

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self == nil) {
		return nil;
	}
	[self setupView];
	return self;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	[self setupView];
}

- (void)setupView
{
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
																options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingMouseMoved)
																  owner:self
															   userInfo:nil];
	[self addTrackingArea:trackingArea];
}

- (void)drawRect:(NSRect)dirtyRect {
	
	if (self.editorDelegate.hasChanged) {
		_markers = _editorDelegate.markers;
	}
	
	for (NSDictionary *marker in _markers) {
		NSColor *color = [BeatColors color:marker[@"color"]];
		if (color) {
			CGFloat y = [(NSNumber*)marker[@"y"] floatValue] * self.frame.size.height;
			NSRect rect = (NSRect){ 0, y, 25, 2 };
			[color setFill];
			NSRectFill(rect);
		}
	}
	
	[self drawKnob];
}

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
	// Do nothing
}


- (void)mouseExited:(NSEvent *)theEvent
{
	[super mouseExited:theEvent];
	[self fadeOut];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	[super mouseEntered:theEvent];
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.1f;
		[self.animator setAlphaValue:1.0f];
	} completionHandler:^{
	}];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	[super mouseMoved:theEvent];
	self.alphaValue = 1.0f;
}

- (void)setFloatValue:(float)aFloat
{
	[super setFloatValue:aFloat];
	[self.animator setAlphaValue:1.0f];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	[self performSelector:@selector(fadeOut) withObject:nil afterDelay:1.5f];
}

- (void)fadeOut
{
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.3f;
		[self.animator setAlphaValue:0.0f];
	} completionHandler:^{
	}];
}

+(CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize scrollerStyle:(NSScrollerStyle)scrollerStyle{
	return [super scrollerWidthForControlSize:controlSize scrollerStyle:scrollerStyle];
	//return 15;
}

/*
+ (BOOL)isCompatibleWithOverlayScrollers
{
	return self == [BeatMarkerScroller class];
}
*/
@end
