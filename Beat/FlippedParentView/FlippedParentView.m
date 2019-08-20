//
//  FlippedParentView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.5.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FlippedParentView.h"

@implementation FlippedParentView

- (BOOL) isFlipped { return YES; }

- (void)awakeFromNib
{
	NSScrollView *scrollvw = [self enclosingScrollView];
	_fullSizeView = [[FlippedParentView alloc] initWithFrame: [self frame]];
	[scrollvw setDocumentView:_fullSizeView];
	[_fullSizeView setAutoresizesSubviews:NO];
	[_fullSizeView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin | NSViewMaxXMargin | NSViewMinXMargin];
	[self setAutoresizingMask: NSViewNotSizable];
	[_fullSizeView addSubview:self];
}
- (NSRect) visibleRect
{
	NSRect visRect = [super visibleRect];
	if ( visRect.size.width == 0 )
	{
		visRect = [[self superview] visibleRect];
		if ( visRect.size.width == 0 )
		{
			// this jacks up everything
			// DUMP( @"bad visibleRect" );
		}
		visRect.origin = NSZeroPoint;
	}
	return visRect;
}
- (void) _my_zoom: (double)newZoom
{
	NSRect oldVisRect = [[self superview] visibleRect];
	
	double kZoomFactorMax = 2.0;
	
	if ( newZoom < 1.0 )
		newZoom = 1.0;
	if ( newZoom > kZoomFactorMax ) newZoom = kZoomFactorMax;
	
	float oldZoom = _zoomFactor;
	
	_zoomFactor = newZoom;
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// Stay locked on users' relative mouse location, so user can zoom in and back out without
	// the view scrolling out from under the mouse location.
	NSPoint center = NSMakePoint(self.frame.size.width / 2, self.frame.size.height / 2);
	
	NSRect newVisRect;
	newVisRect.size = [self visibleRect].size;
	newVisRect.origin = center;
	
	if ( newVisRect.origin.x < 1 ) newVisRect.origin.x = 1;
	if ( newVisRect.origin.y < 1 ) newVisRect.origin.y = 1;
	
	
	//   NSLog( @"zoom scrollRectToVisible %@ bounds %@", NSStringFromRect(newVisRect), NSStringFromRect([[self superview] bounds]) );
	// if ( iUseMousePt || isSlider )
	[[self superview] scrollRectToVisible:newVisRect];
}


@end
