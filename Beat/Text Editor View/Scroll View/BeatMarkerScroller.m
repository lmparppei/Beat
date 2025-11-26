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

#import <BeatCore/BeatUserDefaults.h>
#import "BeatMarkerScroller.h"
#import "BeatTextView.h"

@interface BeatMarkerScroller ()
@property (nonatomic) NSArray *markers;
@property (nonatomic) NSMutableArray *labels;

@property (nonatomic) CGFloat previousValue;
@property (nonatomic) CGFloat pendingValue;
@property (nonatomic) BOOL updateScheduled;

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
	self.window.acceptsMouseMovedEvents = YES;
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
																options:(NSTrackingMouseEnteredAndExited |
																		 NSTrackingActiveInActiveApp |
																		 NSTrackingMouseMoved)
																  owner:self
															   userInfo:nil];
	[self addTrackingArea:trackingArea];
}

-(void)updateTrackingAreas
{
	[super updateTrackingAreas];
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
																options:(NSTrackingMouseEnteredAndExited |
																		 NSTrackingActiveInActiveApp |
																		 NSTrackingMouseMoved)
																  owner:self
															   userInfo:nil];
	[self addTrackingArea:trackingArea];
}

- (BOOL)shouldAutoHide
{
	return ![[NSUserDefaults.standardUserDefaults stringForKey:@"AppleShowScrollBars"] isEqualToString:@"Always"];
}


- (void)setFloatValue:(float)aFloat
{
	[super setFloatValue:aFloat];
	
	/** On macOS 26+, even the slightest attribute changes can trigger a scroll event, so we need to double-check the values so we are not flickering the scroller in and out of view.
	`.waitingForFormatting` is set on macOS when characters in text storage were edited, and then reset at `applyFormattingChanges` */
	
	if (!self.editorDelegate.waitingForFormatting && _previousValue != aFloat) {
		_previousValue = aFloat;
	
		[self.animator setAlphaValue:1.0f];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOutIfNeeded) object:nil];
		[self performSelector:@selector(fadeOutIfNeeded) withObject:nil afterDelay:1.5f];
	}
}


#pragma mark - Drawing

- (NSBezierPath*)triangle:(CGFloat)y
{
	CGFloat width = self.frame.size.width;
	
	NSBezierPath *path = NSBezierPath.bezierPath;
	[path moveToPoint:NSMakePoint(width, y)];
	[path lineToPoint:NSMakePoint(width / 2, y + 5)];
	[path lineToPoint:NSMakePoint(width, y + 10)];
	[path closePath];
	return path;
}

- (NSBezierPath*)marker:(CGFloat)y
{
	CGFloat width = self.frame.size.width;
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(width, y)];
	[path lineToPoint:NSMakePoint(0, y)];
	[path lineToPoint:NSMakePoint(width / 2, y + 5)];
	[path lineToPoint:NSMakePoint(0, y + 10)];
	[path lineToPoint:NSMakePoint(width, y + 10)];
	[path closePath];
	return path;
}

- (void)drawRect:(NSRect)dirtyRect
{
	if ([BeatUserDefaults.sharedDefaults getBool:@"showMarkersInScrollbar"]) {
		// Reload markers
		if (self.editorDelegate.hasChanged) {
			BeatTextView* textView = (BeatTextView*)self.editorDelegate.getTextView;
			_markers = textView.markersAndPositions;
		}
		
		for (NSDictionary *marker in _markers) {
			NSColor *color = [BeatColors color:marker[@"color"]];
			if (color) {
				[color setFill];
				CGFloat y = [(NSNumber*)marker[@"y"] floatValue] * self.frame.size.height;
				
				// Do nothing if we're not in the rect
				if (y < dirtyRect.origin.y || y >= NSMaxY(dirtyRect)) continue;
				
				if (!marker[@"scene"]) {
					NSBezierPath *path = [self marker:y];
					[path fill];
				} else {
					NSRect rect = (NSRect){ 0, y, 25, 2 };
					NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:2 yRadius:2];
					//NSRectFill(rect);
					[path fill];
				}
			}
		}
	}
	
	[self drawKnob];
}

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
	// Do nothing
}


#pragma mark - Mouse events

- (void)mouseExited:(NSEvent *)theEvent
{
	[super mouseExited:theEvent];
	[self fadeOutIfNeeded];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	[super mouseEntered:theEvent];
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.1f;
		[self.animator setAlphaValue:1.0f];
	} completionHandler:^{
	}];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOutIfNeeded) object:nil];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	[super mouseMoved:theEvent];
	self.alphaValue = 1.0f;
}


#pragma mark - Fade Out

- (void)fadeOutIfNeeded
{
	if (!self.shouldAutoHide) return;
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.3f;
		[self.animator setAlphaValue:0.0f];
	} completionHandler:^{
	}];
}

#pragma mark - Sizing

+(CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize scrollerStyle:(NSScrollerStyle)scrollerStyle{
	return [super scrollerWidthForControlSize:controlSize scrollerStyle:scrollerStyle];
}

/*
+ (BOOL)isCompatibleWithOverlayScrollers
{
	return self == [BeatMarkerScroller class];
}
*/
@end
/*
 
 Как на улочке солдат
 Булочку ест, сладкому рад
 Он тебе и сын и брат
 Мёдом цветёт яблонный сад
 
 */
