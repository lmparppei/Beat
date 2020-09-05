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

#define PADDING 8.0

@protocol BeatTimelineDelegate
- (NSRange)selectedRange;
- (NSArray*)getOutline;
@end

@interface BeatTimeline ()

@property NSMutableArray *items;
@property CGFloat playheadPosition;
@property CGFloat scrollPosition;
@property NSInteger selectedItem;
@property CGFloat magnification;

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
    for (OutlineScene *scene in _outline) {
		// Skip some elements
		if (scene.omited) continue;
		else if (scene.type == synopse) continue;
		
		if (scene.type == section) hasSections = YES;
		if (scene.type == heading) totalLength += scene.sceneLength;
    }
    
	CGFloat width = self.frame.size.width - self.items.count - PADDING * 4;
	CGFloat height = self.frame.size.height * 50;
	if (height > 30) height = 30;
	
	CGFloat factor = (width) / totalLength;
	CGFloat x = PADDING;
	
	// Make the scenes be centered in the frame
	CGFloat yPosition = (self.frame.size.height - height) / 2;
	// But not when there are sections?
	if (hasSections) { }
	
	NSFont *sceneFont = [NSFont systemFontOfSize:10];
    //NSMutableDictionary *previousItem = nil;
	OutlineScene *previousScene;
    
    for (OutlineScene *scene in self.outline) {
		if (scene.omited) continue;
		
		if (scene.type == heading) {
			bool selected = NO;
			NSInteger selection = self.delegate.selectedRange.location;
			if (selection >= scene.sceneStart && selection < scene.sceneStart + scene.sceneLength) selected = YES;
			
			CGFloat width = scene.sceneLength * factor;
            NSRect rect = NSMakeRect(x, yPosition / 2, width, height);
			NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:0.5 yRadius:0.5];
			
			NSColor *color = [BeatColors colors][scene.color];
			NSLog(@"color %@", color);
			if (color == nil) color = NSColor.darkGrayColor;
			
			NSColor *textColor = NSColor.lightGrayColor;
			
			if (selected) {
				textColor = color;
				color = NSColor.whiteColor;
			}
			
			
			
			NSGradient *gradient = [[NSGradient alloc] initWithColors:@[color, [color colorWithAlphaComponent:0.9]]];
			[gradient drawInBezierPath:path angle:-90];
			
            //[item setValue:[NSNumber numberWithFloat:x] forKey:@"start"];
            //if (previousItem) [previousItem setValue:[NSNumber numberWithFloat:x - 1] forKey:@"end"];
            
			// Show text
			if (width > 20) {
				NSString *label = [NSString stringWithFormat:@"%@ %@", scene.sceneNumber, scene.string];
				NSRect textRect = NSMakeRect(x + 5, yPosition + 5 , width - 8, 10);
				NSDictionary *attributes = @{ NSForegroundColorAttributeName: textColor, NSFontAttributeName: sceneFont };
				
				[label drawWithRect:textRect options:NSStringDrawingTruncatesLastVisibleLine attributes:attributes context:nil];
			}
			
            x += width + 1;
        }
		else if (scene.type == section){
            NSRect rect = NSMakeRect(x, 0, 1, self.frame.size.height);
            NSColor *color = NSColor.lightGrayColor;
            [color setFill];
            NSRectFill(rect);
			
			//[item setValue:[NSNumber numberWithFloat:x] forKey:@"start"];
            //if (previousItem) [previousItem setValue:[NSNumber numberWithFloat:x - 1] forKey:@"end"];
            
			NSAttributedString *title = [[NSAttributedString alloc] initWithString:scene.string attributes:@{
                NSFontAttributeName: [NSFont labelFontOfSize:7],
                NSForegroundColorAttributeName: NSColor.whiteColor
            }];
            [title drawAtPoint:CGPointMake(x + 2, self.frame.size.height - 8)];
            
            x += 2;
        }
        
        previousScene = scene;
    }
    // Set end location for last item
    // (now known as previous, as the iteration has ended)
    // [previousItem setValue:[NSNumber numberWithFloat:x] forKey:@"end"];
    
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
	[self setFrame:NSMakeRect(0, 0, self.superview.frame.size.width, self.superview.frame.size.height)];
	[self.enclosingScrollView.documentView setFrame:self.frame];
	
	self.enclosingScrollView.documentView.wantsLayer = YES;
	[self.enclosingScrollView.documentView.layer setBackgroundColor:NSColor.blackColor.CGColor];
	
    _scrollPosition = 0;
	_playheadPosition = 0;
    _selectedItem = -1; // No item selected

}

-(BOOL)isFlipped { return YES; }

- (void)reload:(NSArray*)scenes {
	_outline = [NSArray arrayWithArray:scenes];

	[self setNeedsDisplay:YES];
}
- (void)refresh {
	// Set selected scene
}

- (IBAction)magnify:(id)sender {
	_magnification = [(NSSlider*)sender doubleValue];
	NSLog(@"mag : %f", _magnification);
	[self magnifyTo:_magnification];
}
- (void)magnifyTo:(CGFloat)magnify {
	_magnification = magnify;
	NSRect frame = self.enclosingScrollView.frame;
	frame.size.width *= magnify;
	[self setFrame:frame];
	[self.enclosingScrollView.documentView setFrame:frame];
	[self setNeedsDisplay:YES];
}

@end
