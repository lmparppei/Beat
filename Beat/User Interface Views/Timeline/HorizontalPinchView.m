//
//  HorizontalPinchView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "HorizontalPinchView.h"
#import "BeatTimeline.h"

#define MIN_SCALE 1.0
#define MAX_SCALE 10.0

@interface HorizontalPinchView ()
@property CGFloat magnificationDelta;
@property (nonatomic) NSMagnificationGestureRecognizer *recognizer;
@property IBOutlet NSSlider *magnificationSlider;
@property IBOutlet BeatTimeline *timeline;
@end

@implementation HorizontalPinchView

-(void)awakeFromNib {
	_horizontalMagnification = 1.0;
	_magnificationDelta = 1.0;
	_recognizer = [[NSMagnificationGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];
	self.translatesAutoresizingMaskIntoConstraints = NO;
	
	[self addGestureRecognizer:_recognizer];
}
-(IBAction)zoom:(id)sender {
	// Zoom using slider. Centers on the selected scene.
	
	CGFloat zoom = [(NSSlider*)sender floatValue];
	self.horizontalMagnification = zoom  / 100;
	
	// Calculate center point
	CGFloat locationInScrollView;
	CGFloat locationNormalized;
	CGFloat locationInView;
	
	if (_timeline.playheadPosition > 0) {
		locationNormalized = _timeline.playheadPosition / self.documentView.frame.size.width;
		locationInView = self.frame.size.width / 2;
	} else {
		locationInScrollView = self.contentView.bounds.origin.x + self.frame.size.width / 2;
		locationNormalized = locationInScrollView / self.documentView.frame.size.width;
		locationInView = self.frame.size.width / 2;
	}
	
	// Set new size
	CGFloat originalWidth = self.frame.size.width;
	CGFloat newWidth = originalWidth * self.horizontalMagnification;
	self.documentView.frame = NSMakeRect(0, 0, newWidth, self.documentView.frame.size.height);
	self.documentView.needsDisplay = YES;
	
	// Scroll back into view
	CGFloat zoomXscaled = newWidth * locationNormalized;
	CGFloat x = zoomXscaled - locationInView;
	NSRect bounds = self.contentView.bounds;
	bounds.origin.x = x;
	self.contentView.bounds = bounds;
}

-(void)pinch:(NSEvent*)event {
	// Zoom using pinch gesture
	
	if (self.recognizer.state == NSGestureRecognizerStateBegan) _magnificationDelta = self.horizontalMagnification;
	
	// Zoom in more aggressively when we're closer
	CGFloat magFactor = ((_magnificationDelta + event.magnification) * self.documentView.frame.size.width) / self.frame.size.width;
	self.horizontalMagnification = _magnificationDelta + event.magnification * (1 + magFactor * 0.05);
	
	CGPoint locationScrollview = [_recognizer locationInView:self.documentView];
	CGFloat normalized = locationScrollview.x / self.documentView.frame.size.width;
	CGPoint locationInView = [_recognizer locationInView:self];
	
	[self scaleInto:locationInView.x normalized:normalized];
	[self updateSlider];
}

- (void)scrollWheel:(NSEvent *)event {
	[super scrollWheel:event];
	
	// Zoom in only when alt is pressed
	if (NSEvent.modifierFlags == NSEventModifierFlagOption) {
		CGFloat amount = .15;
		
		if (event.deltaY > 0) {
			self.horizontalMagnification += amount;
		} else {
			self.horizontalMagnification -= amount;
		}
		
		NSPoint locationInScrollview = [self convertPoint:event.locationInWindow toView:_timeline];
		CGFloat normalized = locationInScrollview.x / self.documentView.frame.size.width;
		CGPoint locationInView = [self convertPoint:event.locationInWindow toView:nil];
		
		[self scaleInto:locationInView.x normalized:normalized];
		[self updateSlider];
	}
}
- (void)scaleInto:(CGFloat)locationInView normalized:(CGFloat)normalized {
	CGFloat originalWidth = self.frame.size.width;
	CGFloat minScale = MIN_SCALE;
	CGFloat maxScale = MAX_SCALE;
	
	self.horizontalMagnification = MIN(self.horizontalMagnification, maxScale);
	self.horizontalMagnification = MAX(self.horizontalMagnification, minScale);
	
	CGFloat newWidth = originalWidth * self.horizontalMagnification;
	self.documentView.frame = NSMakeRect(0, 0, newWidth, self.documentView.frame.size.height);
	
	CGFloat pinchXScaled = newWidth * normalized;
	CGFloat x = pinchXScaled - locationInView;
	
	NSRect bounds = self.contentView.bounds;
	bounds.origin.x = x;
	self.contentView.bounds = bounds;
}
- (void)updateSlider {
	[_magnificationSlider setFloatValue:self.horizontalMagnification * 100];
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
}

@end
/*
 
 i started something
 and took you to a zone and
 you were clearly never meant to go...
 hair brushed and parted
 (typical me, typical me)
 i started something
 and now i'm not too sure
 
 */
