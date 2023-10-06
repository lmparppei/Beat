//
//  BeatWidgetView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This is the master view for ALL WIDGETS in the sidebar
 
 */

#import "BeatWidgetView.h"
#define MARGIN 5.0


@interface BeatWidgetView ()
@property (nonatomic) NSMutableArray<BeatPluginUIView*> *widgets;
@end
@implementation BeatWidgetView

-(void)awakeFromNib {
	self.postsFrameChangedNotifications = YES;
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(frameDidChange) name:NSViewFrameDidChangeNotification object:self];
}

-(BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
	[NSColor.darkGrayColor setFill];
	CGFloat y = 0;
	
	// Draw separators
	for (BeatPluginUIView *view in _widgets) {
		y += view.frame.size.height;
		
		NSRect rect = (NSRect){0, y, self.frame.size.width, 1.0 };
		NSRectFill(rect);
		
		y += MARGIN * 2;
	}
	
    // Drawing code here.
}

- (void)addWidget:(BeatPluginUIView*)widget {
	if (_widgets == nil) _widgets = NSMutableArray.array;
	
	CGFloat y = 0;
	
	for (BeatPluginUIView *view in _widgets) {
		y += view.frame.size.height + MARGIN * 2;
	}
	
	NSRect frame = widget.frame;
	frame.origin.y = y;
	frame.size.width = self.frame.size.width;
	widget.frame = frame;
	widget.alphaValue = 0.0;
	
	// Add into view and animate
	[_widgets addObject:widget];
	[self addSubview:widget];
	[widget.animator setAlphaValue:1.0];
	
	/*
	NSRect rect = self.frame;
	rect.size.height = y + MARGIN;
	self.enclosingScrollView.documentView.frame = rect;
	 */
	
	[self setNeedsDisplay:YES];
}

- (void)removeWidget:(BeatPluginUIView*)widget {
	[_widgets removeObject:widget];
	[widget removeFromSuperview];
	
	//[self repositionWidgets];
	[self setNeedsDisplay:YES];
}

- (void)repositionWidgets {
	CGFloat y = 0;
	
	for (BeatPluginUIView *view in _widgets) {
		NSRect frame = view.frame;
		frame.origin.y = y;
		[view.animator setFrame:frame];
		
		y += MARGIN * 2;
	}
	
	NSRect rect = self.frame;
	rect.size.height = y + MARGIN;
	self.enclosingScrollView.documentView.frame = rect;
}

- (void)frameDidChange {
	
}

- (void)show:(BeatPluginUIView*)widget {
	// Show the widget view and scroll to the given widget
	[self.enclosingScrollView scrollPoint:(NSPoint){0, widget.frame.origin.y }];
}

- (void)reload {
	// Placeholder method
}

@end

/*
 
 We'll be alright, stay here some time
 This country dog won't die in the city
 
 */
