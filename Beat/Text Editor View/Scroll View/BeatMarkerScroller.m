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

@interface BeatMarkerScroller ()
@property (nonatomic) NSArray *markers;
@property (nonatomic) NSMutableArray *labels;
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

-(void)updateTrackingAreas {
	[super updateTrackingAreas];
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
																options:(NSTrackingMouseEnteredAndExited |
																		 NSTrackingActiveInActiveApp |
																		 NSTrackingMouseMoved)
																  owner:self
															   userInfo:nil];
	[self addTrackingArea:trackingArea];
}

- (NSBezierPath*)triangle:(CGFloat)y {
	CGFloat width = self.frame.size.width;
	
	NSBezierPath *path = NSBezierPath.bezierPath;
	[path moveToPoint:NSMakePoint(width, y)];
	[path lineToPoint:NSMakePoint(width / 2, y + 5)];
	[path lineToPoint:NSMakePoint(width, y + 10)];
	[path closePath];
	return path;
}

- (NSBezierPath*)marker:(CGFloat)y {
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

- (void)drawRect:(NSRect)dirtyRect {
	if ([BeatUserDefaults.sharedDefaults getBool:@"showMarkersInScrollbar"]) {
		// Reload markers
		if (self.editorDelegate.hasChanged) _markers = _editorDelegate.markers;
		
		for (NSDictionary *marker in _markers) {
			NSColor *color = [BeatColors color:marker[@"color"]];
			if (color) {
				[color setFill];
				CGFloat y = [(NSNumber*)marker[@"y"] floatValue] * self.frame.size.height;
				
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

/*
- (void)showLabels {
	_labels = NSMutableArray.array;
	
	for (NSDictionary *marker in _markers) {
		NSColor *color = [BeatColors color:marker[@"color"]];
		
		if (color) {
			CGFloat y = [(NSNumber*)marker[@"y"] floatValue] * self.frame.size.height;
			NSPopover *popover = [self newLabelWithString:marker[@"color"] y:y];
			[popover showRelativeToRect:(NSRect){ 0, y, self.frame.size.width, 1 } ofView:self preferredEdge:NSRectEdgeMinX];
			[_labels addObject:popover];
		}
	}
	
}

- (void)hideLabels {
	for (NSPopover* popover in _labels) {
		[popover close];
	}
	
	[_labels removeAllObjects];
}

- (NSPopover*)newLabelWithString:(NSString*)string y:(CGFloat)y {
	NSTextField *label = [NSTextField labelWithString:string];
	label.controlSize = NSControlSizeMini;
	label.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];

	NSView *contentView = [NSView.alloc initWithFrame:NSMakeRect(300, y, label.attributedStringValue.size.width + 20, label.attributedStringValue.size.height * 1.5)];
	[contentView addSubview:label];
	
	NSViewController *contentViewController = [[NSViewController alloc] init];
	[contentViewController setView:contentView];
		
	// Autocomplete popover
	NSPopover *popover = [[NSPopover alloc] init];
	
	if (@available(macOS 10.14, *)) popover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
	
	//popover.animates = NO;
	popover.contentViewController = contentViewController;
	
	return popover;
}
*/

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
	// Do nothing
}

- (void)mouseExited:(NSEvent *)theEvent
{
	[super mouseExited:theEvent];
	// [self hideLabels];
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
	
	//if (_labels.count == 0) [self showLabels];
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
/*
 
 Как на улочке солдат
 Булочку ест, сладкому рад
 Он тебе и сын и брат
 Мёдом цветёт яблонный сад
 
 */
