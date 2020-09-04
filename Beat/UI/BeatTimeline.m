//
//  BeatTimeline.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.9.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 Replacement for the JavaScript-based timeline.
 Super fast & efficient.
 
 I just realized that could have built the Document class so that it would have
 a free-for-all delegate method for retrieving the outline array? How to reference
 to it, if not through a delegate method, though. But is it ok to have duplicate methods?
 
 */

#import "BeatTimeline.h"
#import "Line.h"
#import "OutlineScene.h"
#import "BeatColors.h"

@protocol BeatTimelineDelegate
- (NSRange)selectedRange;
- (NSArray*)getOutline;
@end

@interface BeatTimeline ()

@property NSMutableArray *items;
@property CGFloat playheadPosition;
@property CGFloat scrollPosition;
@property NSInteger selectedItem;

@end

@implementation BeatTimeline

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // beziering code here.
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    
    NSInteger totalLength = 0;
	
	// Calculate length
	bool hasSections = NO;
    for (NSDictionary *item in _items) {
		// Skip some elements
		if (item[@"invisible"]) continue;
		else if ([item[@"type"] isEqualToString:@"Synopse"]) continue;
		
		if ([item[@"type"] isEqualToString:@"Section"]) hasSections = YES;
        if ([item[@"type"] isEqualToString:@"Heading"]) totalLength += [item[@"length"] intValue];
    }
    
	CGFloat width = self.frame.size.width - self.items.count;
	CGFloat height = self.frame.size.height * 50;
	if (height > 30) height = 30;
	
	CGFloat factor = width / totalLength;
	CGFloat x = 0;
	
	// Make the scenes be centered in the frame
	CGFloat yPosition = (self.frame.size.height - height) / 2;
	// But not when there are sections?
	if (hasSections) { }
	
	NSFont *sceneFont = [NSFont systemFontOfSize:10];
    NSMutableDictionary *previousItem = nil;
    
    for (NSMutableDictionary *item in self.items) {
		if (item[@"invisible"]) continue;
		
        if ([item[@"type"] isEqualToString:@"Heading"]) {
            CGFloat width = [item[@"length"] intValue] * factor;
            NSRect rect = NSMakeRect(x, yPosition / 2, width, height);
            
			NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:0.5 yRadius:0.5];
			
			DynamicColor *color = item[@"color"];
			NSGradient *gradient = [[NSGradient alloc] initWithColors:@[color, [color colorWithAlphaComponent:0.9]]];
			[gradient drawInBezierPath:path angle:-90];
			
            [item setValue:[NSNumber numberWithFloat:x] forKey:@"start"];
            if (previousItem) [previousItem setValue:[NSNumber numberWithFloat:x - 1] forKey:@"end"];
            
			// Show text
			if (width > 30) {
				NSColor *textColor = NSColor.lightGrayColor;
				NSString *label = item[@"name"];
				NSRect textRect = NSMakeRect(x + 5, yPosition + 5 , width - 8, 10);
				NSDictionary *attributes = @{ NSForegroundColorAttributeName: textColor, NSFontAttributeName: sceneFont };
				
				[label drawWithRect:textRect options:NSStringDrawingTruncatesLastVisibleLine attributes:attributes context:nil];
			}
			
            x += width + 1;
        }
        else if ([item[@"type"] isEqualToString:@"Section"]){
            NSRect rect = NSMakeRect(x, 0, 1, self.frame.size.height);
            NSColor *color = NSColor.lightGrayColor;
            [color setFill];
            NSRectFill(rect);
			[item setValue:[NSNumber numberWithFloat:x] forKey:@"start"];
			
            if (previousItem) [previousItem setValue:[NSNumber numberWithFloat:x - 1] forKey:@"end"];
            
            NSAttributedString *title = [[NSAttributedString alloc] initWithString:item[@"name"] attributes:@{
                NSFontAttributeName: [NSFont labelFontOfSize:7],
                NSForegroundColorAttributeName: NSColor.whiteColor
            }];
            [title drawAtPoint:CGPointMake(x + 2, self.frame.size.height - 8)];
            
            x += 2;
        }
        
        previousItem = item;
    }
    // Set end location for last item
    // (now known as previous, as the iteration has ended)
    [previousItem setValue:[NSNumber numberWithFloat:x] forKey:@"end"];
    
	CGFloat magnification = 1.0;
	
    if (_playheadPosition >= 0) {
		NSRect rect = NSMakeRect(_playheadPosition * magnification - _scrollPosition, 0, 2, self.frame.size.height);
        NSColor *white = NSColor.whiteColor;
        [white setFill];
        NSRectFill(rect);
    }
    
    [context restoreGraphicsState];
	
}

-(void)awakeFromNib {
	self.wantsLayer = YES;
	[self.layer setBackgroundColor:NSColor.blackColor.CGColor];
	
    _scrollPosition = 0;
	_playheadPosition = 0;
    _selectedItem = -1; // No item selected

}

-(BOOL)isFlipped { return YES; }

- (void)reload:(NSArray*)scenes {
	_outline = scenes;

	_items = [NSMutableArray array];
     for (OutlineScene *scene in _outline) {
		 NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
            @"name": scene.string,
            @"length": [NSNumber numberWithInteger:scene.sceneLength],
            @"type": scene.line.typeAsString,
			@"item": scene
		 }];
		 
		 if (scene.color) {
			 NSColor *color = [BeatColors color:[scene.color lowercaseString]];
			 if (color) [item setValue:color forKey:@"color"];
			 else [item setValue:NSColor.darkGrayColor forKey:@"color"];
		 }
		 else [item setValue:NSColor.grayColor forKey:@"color"];
		 
		 if (scene.omited) [item setValue:@"YES" forKey:@"invisible"];
		 
		 [_items addObject:item];
     }
	
	[self setNeedsDisplay:YES];
}

@end
