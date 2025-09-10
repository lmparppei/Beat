//
//  BeatTextView+MouseEvents.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+MouseEvents.h"
#import "BeatTextView+Popovers.h"

@implementation BeatTextView (MouseEvents)


#pragma mark - Mouse events

-(void)scrollWheel:(NSEvent *)event
{
	// If the user scrolls, let's ignore any other scroll behavior
	if (event.phase == NSEventPhaseBegan || event.phase == NSEventPhaseChanged) self.scrolling = YES;
	else if (event.phase == NSEventPhaseEnded) self.scrolling = NO;
	
	[super scrollWheel:event];
}


- (void)mouseDown:(NSEvent *)event
{
	[self closePopovers];
	[super mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event
{
	[super mouseUp:event];
}

- (void)otherMouseUp:(NSEvent *)event
{
	// We'll use buttons 3/4 to navigate between scenes
	switch (event.buttonNumber) {
		case 3:
			[self.editorDelegate nextScene:self];
			return;
		case 4:
			[self.editorDelegate previousScene:self];
			return;
		default:
			break;
	}
	
	[super otherMouseUp:event];
}

- (void)mouseMoved:(NSEvent *)event
{
	// point in this scaled text view
	NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
	
	// point in unscaled parent view
	NSPoint superviewPoint = [self.enclosingScrollView convertPoint:event.locationInWindow fromView:nil];
	
	// y position in window
	CGFloat y = event.locationInWindow.y;
	
	// Super cursor when inside the text container, otherwise arrow
	if (self.window.isKeyWindow) {
		CGFloat leftX = self.textContainerInset.width + BeatTextView.linePadding;
		CGFloat rightX = (self.textContainer.size.width + self.textContainerInset.width - BeatTextView.linePadding) * (1/self.zoomLevel);
		
		if ((point.x > leftX && point.x * (1/self.zoomLevel) < rightX) &&
			y < self.window.frame.size.height - 22 &&
			superviewPoint.y < self.enclosingScrollView.frame.size.height) {
			//[super mouseMoved:event];
			[NSCursor.IBeamCursor set];
		} else if (point.x > 10) {
			[NSCursor.arrowCursor set];
		}
	}
}

-(void)resetCursorRects
{
	[super resetCursorRects];
}

-(void)cursorUpdate:(NSEvent *)event
{
	[NSCursor.IBeamCursor set];
}


@end
