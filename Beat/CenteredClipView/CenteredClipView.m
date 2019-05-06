//
//  CenteredClipView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.5.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//  Thanks to uchuugaka @ stackoverflow

#import <Cocoa/Cocoa.h>
#import "CenteredClipView.h"

@implementation CenteredClipView

- (instancetype) initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	self.centersDocumentView = YES;
	return self;
}
- (instancetype) initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	self.centersDocumentView = YES;
	return self;
}

- (NSRect)constrainBoundsRect:(NSRect)proposedClipViewBoundsRect {
	
	NSRect constrainedClipViewBoundsRect = [super constrainBoundsRect:proposedClipViewBoundsRect];
	
	// Early out if you want to use the default NSClipView behavior.
	if (self.centersDocumentView == NO) {
		return constrainedClipViewBoundsRect;
	}
	
	NSRect documentViewFrameRect = [self.documentView frame];
	
	// If proposed clip view bounds width is greater than document view frame width, center it horizontally.
	if (proposedClipViewBoundsRect.size.width >= documentViewFrameRect.size.width) {
		// Adjust the proposed origin.x
		constrainedClipViewBoundsRect.origin.x = centeredCoordinateUnitWithProposedContentViewBoundsDimensionAndDocumentViewFrameDimension(proposedClipViewBoundsRect.size.width, documentViewFrameRect.size.width);
	}
	
	// If proposed clip view bounds is hight is greater than document view frame height, center it vertically.
	if (proposedClipViewBoundsRect.size.height >= documentViewFrameRect.size.height) {
		
		// Adjust the proposed origin.y
		constrainedClipViewBoundsRect.origin.y = centeredCoordinateUnitWithProposedContentViewBoundsDimensionAndDocumentViewFrameDimension(proposedClipViewBoundsRect.size.height, documentViewFrameRect.size.height);
	}
	
	return constrainedClipViewBoundsRect;
}


CGFloat centeredCoordinateUnitWithProposedContentViewBoundsDimensionAndDocumentViewFrameDimension
(CGFloat proposedContentViewBoundsDimension,
 CGFloat documentViewFrameDimension )
{
	CGFloat result = floor( (proposedContentViewBoundsDimension - documentViewFrameDimension) / -2.0F );
	return result;
}

@end
