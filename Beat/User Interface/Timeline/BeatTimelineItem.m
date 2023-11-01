//
//  BeatTimelineItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import <Quartz/Quartz.h>
#import <BeatCore/BeatColors.h>
#import <BeatCore/BeatLocalization.h>
#import "BeatTimelineItem.h"
#import "BeatColorMenuItem.h"

#define TEXT_PADDING 4.0
#define MAXHEIGHT 30

#define UNSELECTED_ALPHA 0.8
#define FONTSIZE_SCENE 10.0
#define FONTSIZE_SYNOPSIS 9.0
#define FONTSIZE_SECTION 12.5

#define SECTION_Y 2

@interface BeatTimelineItem ()
@property (nonatomic) NSString *text;
@property (nonatomic) NSColor *color;
@property (nonatomic) CATextLayer *textLayer;
@property (weak) id<BeatTimelineItemDelegate> delegate;
@end

@implementation BeatTimelineItem

#pragma mark - Update view & layers

- (id)initWithDelegate:(id<BeatTimelineItemDelegate>)delegate {
	self = [super init];
	if (self) {
		_delegate = delegate;
		
		if (self.enclosingScrollView.menu) {
			self.menu = self.enclosingScrollView.menu;
		} else {
			self.menu = self.delegate.sceneMenu;
		}
		
		// Setup layer
		_textLayer = CATextLayer.layer;
		_textLayer.wrapped = NO;
		_textLayer.fontSize = FONTSIZE_SCENE;
		_textLayer.contentsScale = NSScreen.mainScreen.backingScaleFactor;
		_textLayer.backgroundColor = NSColor.clearColor.CGColor;
				
		self.wantsLayer = YES;
		[self.layer addSublayer:_textLayer];

		NSTrackingArea *trackingArea = [NSTrackingArea.alloc initWithRect:self.frame options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];
		[self.window setAcceptsMouseMovedEvents:YES];
		[self addTrackingArea:trackingArea];
	}
	return self;
}
- (void)setItem:(OutlineScene*)scene rect:(NSRect)rect reset:(bool)reset {
	[self setItem:scene rect:rect reset:reset storyline:NO forceColor:nil];
}
- (void)setItem:(OutlineScene*)scene rect:(NSRect)rect reset:(bool)reset storyline:(bool)storyline forceColor:(NSColor* __nullable)forcedColor {
	_representedItem = scene;
	
	if (reset) {
		if (storyline) _type = TimelineStoryline;
		else if (scene.type == heading) _type = TimelineScene;
		else if (scene.type == section) {
			// Lower and higher sections
			if (scene.sectionDepth < 2) _type = TimelineSection;
			else _type = TimelineLowerSection;
		} else if (scene.type == synopse) _type = TimelineSynopsis;
		
		self.color = [BeatColors color:scene.color.lowercaseString];
		
		if (!self.color) {
			// Default colors for elements
			if (self.type == TimelineScene) self.color = NSColor.darkGrayColor;
			else if (self.type == TimelineSection || self.type == TimelineLowerSection) self.color = NSColor.whiteColor;
			else self.color = NSColor.grayColor;
		}
		
		// Uppercase text for scenes
		if (scene.type == heading) self.text = [scene.stringForDisplay uppercaseString];
		else self.text = scene.stringForDisplay;
		
		self.toolTip = scene.stringForDisplay;
	}

	if (forcedColor) self.color = forcedColor;
		
	// Reset item styles to match the represented element or update their x position
	if (_type == TimelineScene) {
		[self setSceneFor:rect];
	}
	else if (_type == TimelineSection) {
		if (reset) [self setSectionFor:rect];
		else [self updateSectionPosition:rect];
	}
	else if (_type == TimelineLowerSection) {
		if (reset) [self setLowerSectionFor:rect];
		else [self updateLowerSectionPosition:rect];
	}
	else if (_type == TimelineSynopsis) {
		if (reset) [self setSynopsisFor:rect];
		else [self updateSynopsisPosition:rect];
	}
	else if (_type == TimelineStoryline) {
		if (reset) [self setStorylineFor:rect];
		else [self updateStorylinePosition:rect];
	}
	
	if (self.selected) [self select];
	[self setNeedsDisplay:YES];
}


#pragma mark - Stylization

- (void)setSceneFor:(NSRect)rect {
	self.frame = rect;
	self.layer.opacity = UNSELECTED_ALPHA;
	
	_textLayer.fontSize = FONTSIZE_SCENE;
	_textLayer.bounds = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
	_textLayer.position = CGPointMake(self.frame.size.width / 2 + TEXT_PADDING, 23);
	_textLayer.backgroundColor = NSColor.clearColor.CGColor;

	_textLayer.foregroundColor = [BeatColors color:@"lightGray"].CGColor;
	self.layer.backgroundColor = self.color.CGColor;
	
	if (self.frame.size.width > 40) {
		self.textLayer.string = [NSString stringWithFormat:@"%@ %@", _representedItem.sceneNumber, self.text];
	}
	else if (self.frame.size.width > 25) {
		self.textLayer.string = _representedItem.sceneNumber;
	}
	else {
		self.textLayer.string = @"";
	}
	
	// Text is white for scenes with a different background
	if (_representedItem.color.length) self.textLayer.foregroundColor = NSColor.whiteColor.CGColor;
}

- (void)setSynopsisFor:(NSRect)rect {
	self.layer.backgroundColor = NSColor.clearColor.CGColor;
	self.layer.opacity = 1.0;
	
	_textLayer.backgroundColor = NSColor.clearColor.CGColor;
	_textLayer.fontSize = FONTSIZE_SYNOPSIS;
	_textLayer.string = self.text;
	
	CGSize size = _textLayer.preferredFrameSize;
	_textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
	_textLayer.position = CGPointMake(size.width / 2, size.height / 2);
	
	// Get synopsis color if applicable
	if (_representedItem.color.length) {
		_textLayer.foregroundColor = self.color.CGColor;
	} else {
		_textLayer.foregroundColor = self.color.CGColor;
	}
	
	self.frame = NSMakeRect(rect.origin.x, rect.origin.y - 15, size.width + 10, 13);
}
- (void)updateLowerSectionPosition:(NSRect)rect {
	[self updateSynopsisPosition:rect];
}
- (void)updateSynopsisPosition:(NSRect)rect {
	NSRect frame = self.frame;
	frame.origin.x = rect.origin.x;
	self.frame = frame;
}

- (void)setLowerSectionFor:(NSRect)rect {
	self.layer.backgroundColor = NSColor.clearColor.CGColor;
	self.layer.opacity = 1.0;
	
	_textLayer.backgroundColor = NSColor.clearColor.CGColor;
	_textLayer.fontSize = FONTSIZE_SYNOPSIS;
	_textLayer.string = self.text;
	
	CGSize size = _textLayer.preferredFrameSize;
	_textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
	_textLayer.position = CGPointMake(size.width / 2, size.height / 2);
	_textLayer.foregroundColor = self.color.CGColor;
	
	self.frame = NSMakeRect(rect.origin.x, rect.origin.y - 26, size.width + 10, 13);
}

- (void)setSectionFor:(NSRect)rect {
	_textLayer.backgroundColor = NSColor.clearColor.CGColor;
	
	_textLayer.string = self.text;
	_textLayer.fontSize = FONTSIZE_SECTION;
	CGSize size = _textLayer.preferredFrameSize;
	_textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
	_textLayer.position = CGPointMake(size.width / 2 + 2, size.height / 2 + 2);
	_textLayer.foregroundColor = self.color.CGColor;
	
	self.layer.backgroundColor = NSColor.clearColor.CGColor;
	self.layer.opacity = 1.0;
	
	self.frame = NSMakeRect(rect.origin.x, SECTION_Y, size.width + 100, self.delegate.timelineHeight);
}
- (void)updateSectionPosition:(NSRect)rect {
	NSRect frame = self.frame;
	frame.origin.x = rect.origin.x;
	self.frame = frame;
}

- (void)setStorylineFor:(NSRect)rect {
	// The timeline track color is forced (see forceColor argument)
	self.layer.backgroundColor = self.color.CGColor;
	self.layer.opacity = 1.0;
	
	_textLayer.string = @"";
	
	self.frame = rect;
	self.frame = NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, 2);
}
- (void)updateStorylinePosition:(NSRect)rect {
	NSRect frame = self.frame;
	frame.origin.x = rect.origin.x;
	frame.size.width = rect.size.width;
	self.frame = frame;
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
	//self.layer.backgroundColor = self.color.CGColor;
    
	// Draw a separator
	if (self.type == TimelineSection) {
		NSRect rect = NSMakeRect(0, 0, 1, self.frame.size.height);
		[self.color setFill];
		NSRectFill(rect);
	}
}

#pragma mark - Selecting

-(void)select {
	// Don't select anything else than a scene
	if (self.type != TimelineScene) return;
	
	_selected = YES;
	
	// Set colors
	self.layer.backgroundColor = NSColor.whiteColor.CGColor;
	if (self.representedItem.color.length > 0) self.textLayer.foregroundColor = self.color.CGColor;
	else self.textLayer.foregroundColor = NSColor.darkGrayColor.CGColor;
	
	self.layer.opacity = 1.0;
}
-(void)deselect {
	if (self.type != TimelineScene) return;
	if (!_selected) return;
	
	_selected = NO;
	
	// Reset colors
	self.layer.backgroundColor = self.color.CGColor;
	self.layer.opacity = UNSELECTED_ALPHA;
	if (self.representedItem.color.length > 0) self.textLayer.foregroundColor = NSColor.whiteColor.CGColor;
	else self.textLayer.foregroundColor = [BeatColors color:@"lightGray"].CGColor;
}

-(void)mouseUp:(NSEvent *)event {
	// Only allow clicking if this is a scene
	if (self.type == TimelineScene) {
		
		// Cmd pressed while selecting
		if (NSEvent.modifierFlags == NSEventModifierFlagCommand) {
			if (!self.selected) [_delegate addSelected:self];
			else [_delegate deselect:self];
		}
		else if (NSEvent.modifierFlags == NSEventModifierFlagShift) {
			[_delegate selectTo:self];
		}
		else {
			[_delegate setSelected:self];
		}
	}
}

#pragma mark - Some hover effects
-(void)mouseEntered:(NSEvent *)event {
	if (_selected) return;
	if (self.type == TimelineScene) self.layer.opacity = 1.0;
}
-(void)mouseExited:(NSEvent *)event {
	if (_selected) return;
	if (self.type == TimelineScene) self.layer.opacity = 0.8;
}
- (BOOL)isFlipped { return YES; }


#pragma mark - Contextual Menus

-(NSMenu *)menuForEvent:(NSEvent *)event {
	_delegate.clickedItem = self.representedItem;

	NSMenu *menu = self.menu.copy;
	[menu addItem:NSMenuItem.separatorItem];
	
    for (NSMenuItem *menuItem in menu.itemArray) {
        [menuItem setAction:@selector(setSceneColor:)];
    }
    
	// List Storylines
	for (NSString *storyline in _delegate.storylines) {
		[menu addItemWithTitle:storyline action:@selector(addStoryline:) keyEquivalent:@""];
		
		if (self.delegate.selectedItems.count > 1) {
			// Check state of multiple items
			NSInteger mutual = 0;
			
			for (BeatTimelineItem *item in self.delegate.selectedItems) {
				if ([item.representedItem.storylines containsObject:storyline]) mutual++;
			}
			
			if (mutual == self.delegate.selectedItems.count) [menu.itemArray.lastObject setState:NSOnState];
			else if (mutual > 0) [menu.itemArray.lastObject setState:NSMixedState];
			else [menu.itemArray.lastObject setState:NSOffState];
			
		} else {
			// Set on state for the clicked item
			if ([self.representedItem.storylines containsObject:storyline]) {
				[menu.itemArray.lastObject setState:NSOnState];
			}
		}
	}
	
	[menu addItemWithTitle:[BeatLocalization localizedStringForKey:@"storyline.add"] action:@selector(newStoryline) keyEquivalent:@""];

	
	return menu;
}

- (void)addStoryline:(id)sender {
	NSString *storyline = [(NSMenuItem*)sender title];
	
	NSMenuItem *menuItem = sender;
	if (menuItem.state == NSOnState) {
		[_delegate removeStoryline:storyline from:_representedItem];
	} else {
		[_delegate addStoryline:storyline to:_representedItem];
	}
}
- (void)newStoryline {
	_delegate.clickedItem = self.representedItem;
	[_delegate newStorylineFor:self.representedItem item:self];
}

- (void)setSceneColor:(id)sender {
	BeatColorMenuItem *item = sender;
	NSString *color = item.colorKey;
	[_delegate setSceneColor:color for:self.representedItem];
}

@end
/*
 
 vägen hem var mycket lång
 och ingen har jag mött
 nu blir kvällarna kyliga och sena
 
 kom trösta mig en smula
 för nu är jag ganska trött
 och med ens så förfärligt allena
 
 det finns så mycket saker som
 jag skulle sagt och gjort
 och det är så väldigt jag gjorde
 
 */
