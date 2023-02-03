//
//  ColorCheckbox.m
//	Released under MIT License
//
//  Created by Lauri-Matti Parppei on 26.12.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "ColorCheckbox.h"
#import <BeatCore/BeatColors.h>
#import <QuartzCore/QuartzCore.h>
IB_DESIGNABLE

@implementation ColorCheckbox
static CGFloat size = 12;

-(void)awakeFromNib {
	
	/*
	// Alternative, layer-based drawing prototype
	self.wantsLayer = YES;
	
	CAShapeLayer *layer = [CAShapeLayer layer];
	
	// Draw the circle
	CGRect rect = CGRectMake(0, 0, size, size);
	CGPathRef path = CGPathCreateWithEllipseInRect(rect, nil);
	
	layer.path = path;
	layer.fillColor = [_itemColor colorWithAlphaComponent:0.5].CGColor;
	self.layer = layer;
	 */
	
	_itemColor = [BeatColors color:self.colorName];
}

-(void)mouseUp:(NSEvent *)event {
	[super mouseUp:event];
}

- (void)drawRect:(NSRect)dirtyRect {
	/*
	// A reminder
	#if !TARGET_INTERFACE_BUILDER
	   // Run this code only in the app
	#else
	   // Run this code only in Interface Builder
	#endif
	*/
	
	NSGraphicsContext* context = [NSGraphicsContext currentContext];
	
    // Drawing code here.
	NSRect rect = NSMakeRect(self.frame.size.width / 2 - size / 2, self.frame.size.height / 2 - size / 2, size, size);
	
	NSBezierPath* circlePath = [NSBezierPath bezierPath];
	[circlePath appendBezierPathWithOvalInRect: rect];

	NSColor *strokeColor = NSColor.whiteColor;
	NSColor *fillColor = _itemColor;
	if (self.state == NSControlStateValueOff) {
		strokeColor = [strokeColor colorWithAlphaComponent:0.0];
		fillColor = [_itemColor colorWithAlphaComponent:0.5];
	}
	
	[strokeColor setStroke];
	[fillColor setFill];

	[context saveGraphicsState];
	[circlePath stroke];
	[circlePath fill];
	[context restoreGraphicsState];
}

@end
/*
 
 Стремясь всем показать в чём сила
 Трава сама себя косила
 
 */
