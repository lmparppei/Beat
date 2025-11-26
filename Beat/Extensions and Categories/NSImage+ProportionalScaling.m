//
//  NSImage+ProportionalScaling.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 23.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "NSImage+ProportionalScaling.h"

@implementation NSImage (ProportionalScaling)

- (NSImage*)imageByScalingProportionallyToSize:(NSSize)targetSize
{
	NSImage* sourceImage = self;
	NSImage* newImage = nil;
	
	// For invalid images, return empty image
	if (!sourceImage.isValid) return NSImage.new;

	NSSize imageSize = [sourceImage size];
	float width  = imageSize.width;
	float height = imageSize.height;

	float targetWidth  = targetSize.width;
	float targetHeight = targetSize.height;

	float scaleFactor  = 0.0;
	float scaledWidth  = targetWidth;
	float scaledHeight = targetHeight;

	NSPoint thumbnailPoint = NSZeroPoint;

	if ( NSEqualSizes( imageSize, targetSize ) == NO )
	{

	  float widthFactor  = targetWidth / width;
	  float heightFactor = targetHeight / height;
	  
	  if ( widthFactor < heightFactor )
		scaleFactor = widthFactor;
	  else
		scaleFactor = heightFactor;
	  
	  scaledWidth  = width  * scaleFactor;
	  scaledHeight = height * scaleFactor;
	  
	  if ( widthFactor < heightFactor )
		thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
	  
	  else if ( widthFactor > heightFactor )
		thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
	}

	newImage = [[NSImage alloc] initWithSize:targetSize];
	if (newImage.size.width == 0 || newImage.size.height == 0) return newImage;
	
	[newImage lockFocus];

	  NSRect thumbnailRect;
	  thumbnailRect.origin = thumbnailPoint;
	  thumbnailRect.size.width = scaledWidth;
	  thumbnailRect.size.height = scaledHeight;
	  
	  [sourceImage drawInRect: thumbnailRect
					 fromRect: NSZeroRect
					operation: NSCompositingOperationSourceOver
					 fraction: 1.0];

	[newImage unlockFocus];
  
  return newImage;
}

- (NSImage*)tintedImageWithSelection:(bool)selected
{
	NSImage* img = self.copy;
	
	NSColor *tint;
	if (@available(macOS 10.14, *)) {
		tint = NSColor.controlAccentColor;
		if (!selected) tint = [NSColor.tertiaryLabelColor colorWithAlphaComponent:.35];
	} else {
		// Fallback on earlier versions
		tint = NSColor.secondaryLabelColor;
		if (!selected) tint = NSColor.whiteColor;
	}
	
	[img lockFocus];
	[tint set];
	NSRect imageRect = {NSZeroPoint, img.size};
	NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceIn);
	[img unlockFocus];
	
	return img;
}

@end
