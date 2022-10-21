//
//  BeatSegmentedCell.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatSegmentedCell.h"

@implementation BeatSegmentedCell

-(void)drawSegment:(NSInteger)segment inFrame:(NSRect)frame withView:(NSView *)controlView {
	[super drawSegment:segment inFrame:frame withView:controlView];
	
	NSImage *image = [self imageForSegment:segment];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		
	[self drawCenteredImage:image inFrame:frame];
}

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	[NSColor.redColor setFill];
	NSRectFill(cellFrame);
}

-(void)drawCenteredImage:(NSImage*)image inFrame:(NSRect)frame
{
	NSRectFill(frame);
	
	CGSize imageSize = image.size;
	CGRect rect= NSMakeRect(frame.origin.x + (frame.size.width-imageSize.width)/2.0,
			   frame.origin.y + (frame.size.height-imageSize.height)/2.0,
			   imageSize.width,
			   imageSize.height );
	
	[image drawInRect:rect];
	
}

@end
/*
 
 when I trust you we can do it with the lights on
 when I trust you we can do it with the lights on
 when I trust you we'll make love until the morning
 let me tell you all my secrets, and I whisper 'til the day's done
 
 */
