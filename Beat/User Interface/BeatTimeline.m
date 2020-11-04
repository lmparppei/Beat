//
//  BeatTimeline.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.9.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 Replacement for the JavaScript-based timeline. Super fast & efficient.
 This can be wrapped in a PinchScrollView or something similar.
 
 */

#import "BeatTimeline.h"
#import "Line.h"
#import "OutlineScene.h"
#import "BeatColors.h"
#import "BeatTimelineItem.h"
#import <Quartz/Quartz.h>

#define STORYLINE_TITLE @"Track Storyline"

#define DEFAULT_HEIGHT 120.0
#define DEFAULT_Y 33.0
#define SECTION_HEADROOM 6.0
#define PADDING 8.0
#define MAXHEIGHT 30.0
#define STORYLINE_LABELS_WIDTH 60.0

@interface BeatTimeline ()

// Interface
@property (weak) IBOutlet NSPopUpButton *storylinePopup;

@property NSMutableArray *items;
@property NSInteger selectedItem;

@property NSTimer *refreshTimer;

@property NSInteger totalLength;
@property bool hasSections;
@property NSMutableArray *scenes;
@property NSMutableArray *storylineItems;
@property NSMutableArray *storylineLabels;

@property CAShapeLayer *playhead;
@end

@implementation BeatTimeline

- (void)awakeFromNib {
	_selectedItem = -1; // No item selected
	_items = [NSMutableArray array];
	_scenes = [NSMutableArray array];
	
	// Storyline elements
	_storylineItems = [NSMutableArray array];
	_storylines = [NSMutableArray array];
	_storylineLabels = [NSMutableArray array];
	[_storylinePopup setHidden:YES];
	
	// Graphical setup
	self.wantsLayer = YES;
	[self.enclosingScrollView setBackgroundColor:[BeatColors color:@"backgroundGray"]];
	_backgroundColor = [BeatColors color:@"backgroundGray"];
		
	// Setup playhead
	_playhead = [CAShapeLayer layer];
	_playhead.bounds = CGRectMake(1, 1, 1, self.frame.size.height);
	_playhead.fillColor = NSColor.redColor.CGColor;
	_playhead.path = CGPathCreateWithRect(CGRectMake(1, 1, 1, self.frame.size.height), nil);
	_playhead.lineWidth = 3;
	
	[self.layer addSublayer:_playhead];
	
	// Storylines test
	_showStorylines = YES;
	_visibleStorylines = [NSMutableArray arrayWithArray:@[@"B PLOT"]];
	
	[self updateStorylineLabels];
}

- (void)refreshWithDelay {
	// Refresh timeline at an interval and cancel if any changes are made before refresh.
	[_refreshTimer invalidate];
	
	_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
		self.outline = [self.delegate getOutlineItems];
		[self updateScenesAndRebuild:YES];
	}];
}

- (void)updateScenes {
	[self updateScenesAndRebuild:NO];
}

- (void)updateScenesAndRebuild:(bool)rebuild {
	if (rebuild) {
		_totalLength = 0;
		_hasSections = NO;
		
		bool hasStorylines = NO;
		
		_currentScene = self.delegate.currentScene;
		NSInteger storylineBlocks = 0;
		
		// Calculate total length
		for (OutlineScene *scene in _outline) {
			// Skip some elements
			if (scene.omited) continue;
			else if (scene.type == synopse) continue;
			
			if (scene.type == heading) _totalLength += scene.sceneLength;
			if (scene.type == section) _hasSections = YES;
			if (scene.storylines.count) hasStorylines = YES;
		}
		
		NSInteger diff = self.outline.count + storylineBlocks - self.scenes.count;
		
		// We need more items
		if (diff > 0) {
			for (NSInteger i = 0; i < diff; i++) {
				BeatTimelineItem *item = [[BeatTimelineItem alloc] initWithDelegate:self];
				[_scenes addObject:item];
				[self addSubview:item];
			}
		}
		// There are extra items
		else if (diff < 0) {
			for (NSInteger i = 0; i < diff; i++) {
				[_scenes[0] removeFromSuperview];
				[_scenes removeObjectAtIndex:0];
			}
		}
		
		// Remove storyline items when they are not needed
		if (_visibleStorylines.count == 0 && _storylineItems.count > 0) {
			for (BeatTimelineItem *item in _storylineItems) {
				[item removeFromSuperview];
			}
			[_storylineItems removeAllObjects];
		}
	}
	
	// CREATE TIMELINE ELEMENTS
	
	// Item width - calculate padding + spacing
	CGFloat x = PADDING;
	if (_visibleStorylines.count) x = PADDING + STORYLINE_LABELS_WIDTH;
	
	CGFloat width = self.frame.size.width - self.outline.count - PADDING - x;
	CGFloat height = self.frame.size.height * 50;
	if (height > MAXHEIGHT) height = MAXHEIGHT;
	
	CGFloat factor = width / _totalLength;

	// Make the scenes be centered in the frame
	//CGFloat yPosition = (self.frame.size.height - height) / 2;
	CGFloat yPosition = DEFAULT_Y;
	if (_hasSections) yPosition += SECTION_HEADROOM;
	
	NSInteger index = 0;
	NSInteger storylines = 0;
	
	OutlineScene *previousScene;
	BeatTimelineItem *previousItem;
	BeatTimelineItem *previousSynopsis;
	BeatTimelineItem *previousSection;
	
	NSRect selectionRect = NSZeroRect;
	
	for (OutlineScene *scene in self.outline) {
		if (scene.omited) continue;

		bool selected = NO;
		NSInteger selection = self.delegate.selectedRange.location;
		
		if (selection >= scene.sceneStart && selection < scene.sceneStart + scene.sceneLength) selected = YES;

		NSRect rect;
		CGFloat width;
		if (scene.type == heading) {
			width = scene.sceneLength * factor;
			rect = NSMakeRect(x, yPosition, width, height);
		} else {
			width = 1;
			rect = NSMakeRect(x, yPosition, 1, 1);
		}
		
		BeatTimelineItem *item = _scenes[index];
		[item setItem:scene rect:rect reset:rebuild];
		if (item.selected) selectionRect = item.frame;
		
		// Show storylines
		if (scene.type == heading && scene.storylines.count && _visibleStorylines.count) {
			// Create the needed items
			for (NSString *storyline in scene.storylines) {
				if ([_visibleStorylines containsObject:storyline.uppercaseString]) {
					storylines++;
					
					if (storylines > _storylineItems.count || _storylineItems.count == 0) {
						// Create new
						BeatTimelineItem *storylineItem = [[BeatTimelineItem alloc] initWithDelegate:self];
						[self addSubview:storylineItem];
						[storylineItem setItem:scene rect:rect reset:rebuild storyline:YES];
						[_storylineItems addObject:storylineItem];
					} else {
						// Reuse old items
						BeatTimelineItem *storylineItem = _storylineItems[storylines - 1];
						[storylineItem setItem:scene rect:rect reset:rebuild storyline:YES];
					}
				}
				
				// Remove unused items
				if (storylines > _storylineItems.count - 1) {
					NSInteger diff = _storylineItems.count - storylines;
					for (int i = 0; i < diff; i++) {
						[[_storylineItems lastObject] removeFromSuperview];
						[_storylineItems removeLastObject];
					}
				}
			}
			
		}
		
		// Clip sections & synopsis markers
		if (scene.type == section) {
			if (previousSection) {
				if (previousSection.frame.origin.x + previousSection.frame.size.width > item.frame.origin.x) {
					CGFloat difference = previousSection.frame.origin.x + previousSection.frame.size.width - item.frame.origin.x;
					NSRect frame = previousSection.frame;
					
					frame.size.width -= difference - 1;
					if (frame.size.width < 0) frame.size.width = 0;
					
					[previousSection setFrame:frame];
				} else {
					NSRect frame = previousSection.frame;
					frame.size.width = item.frame.origin.x - frame.origin.x;
					[previousSection setFrame:frame];
				}
			}
			
			previousSection = item;
		}
		else if (scene.type == synopse) {
			// There is a chance that the synopsis line describes the CONTENT OF A SCENE and not a story point.
			// The parser already takes this into account, so we'll just check if it is within the ranges.
			if (NSLocationInRange(scene.sceneStart, previousScene.range)) {
				NSRect frame = item.frame;
				frame.origin.x = previousItem.frame.origin.x;
				item.frame = frame;
			}
			
			if (previousSynopsis) {
				if (previousSynopsis.frame.origin.x + previousSynopsis.frame.size.width > item.frame.origin.x) {
					CGFloat difference = previousSynopsis.frame.origin.x + previousSynopsis.frame.size.width - item.frame.origin.x;
					NSRect frame = previousSynopsis.frame;
					
					frame.size.width -= difference - 1;
					if (frame.size.width < 0) frame.size.width = 0;
					
					[previousSynopsis setFrame:frame];
					[previousSynopsis setNeedsDisplay:YES];
				} else {
					NSRect frame = previousSynopsis.frame;
					frame.size.width = item.frame.origin.x - frame.origin.x;
					[previousSynopsis setFrame:frame];
				}
			}
			previousSynopsis = item;
		}
		
		// Only add the width to the total width if it's a scene
		// Sections add 3 px to account for the separator, while synopses add 0
		if (scene.type == heading) {
			x += width + 1;
		} else if (scene.type == section) {
			x += 2;
		}
		
		previousItem = item;
		previousScene = scene;
		index++;
	}
		
	// Move playhead to the selected position
	if (!NSIsEmptyRect(selectionRect)) [self movePlayhead:selectionRect];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
	[self updateScenes];
	
	// Let's draw labels
	if (_visibleStorylines) [self updateStorylineLabels];
}
- (void)scrollToScene:(NSInteger)index {
	if (index >= _outline.count || index == NSNotFound) return;
	
	[self deselectAll];
	
	NSRect selectionRect = NSZeroRect;
	OutlineScene *selectedScene = [_outline objectAtIndex:index];
	for (BeatTimelineItem *item in self.scenes) {
		if (item.representedItem == selectedScene) {
			[item select];
			selectionRect = item.frame;
			break;
		}
	}
	
	if (!NSIsEmptyRect(selectionRect)) {
		NSRect bounds = self.enclosingScrollView.contentView.bounds;
		bounds.origin.x = selectionRect.origin.x - ((self.enclosingScrollView.frame.size.width - selectionRect.size.width) / 2);

		[self.enclosingScrollView.contentView.animator setBoundsOrigin:bounds.origin];
	}
	
	[self movePlayhead:selectionRect];
	[self updateLayer];
}

- (void)movePlayhead:(NSRect)selectionRect {
	_playhead.bounds = CGRectMake(0, 0, 1, self.frame.size.height);
	_playhead.path = CGPathCreateWithRect(CGRectMake(0, 0, 1, self.frame.size.height), nil);
	_playhead.position = CGPointMake(selectionRect.origin.x, self.frame.size.height / 2);
}

- (CGFloat)playheadPosition {
	return _playhead.position.x;
}

- (void)deselectAll {
	for (BeatTimelineItem *item in self.scenes) {
		[item deselect];
	}
}

// A timeline item was clicked, call delegate and jump to the scene
- (void)didSelectItem:(id)item {
	NSInteger index = [_outline indexOfObject:[(BeatTimelineItem*)item representedItem]];
	if (index != NSNotFound) [_delegate didSelectTimelineItem:index];
}

- (BOOL)isFlipped { return YES; }

- (void)reload {
	_outline = [_delegate getOutlineItems];
	
	[self updateScenesAndRebuild:YES];
	[self updateStorylines];
}

#pragma mark - Storyline handling

- (void)updateStorylines {
	[_storylines removeAllObjects];
	
	// Add storylines
	for (OutlineScene* scene in _outline) {
		if (scene.storylines.count) {
			for (NSString *storyline in scene.storylines) {
				if (![_storylines containsObject:storyline.uppercaseString]) [_storylines addObject:storyline.uppercaseString];
			}
		}
	}
	
	// If there are storylines present, show the popup
	if (_storylines.count) [_storylinePopup setHidden:NO];
	else {
		[_storylinePopup setHidden:YES];
		_visibleStorylines = [NSMutableArray array];
	}

	// Check that any removed storylines are not tracked
	// ....
	
	// Clear the storyline popup and add storyline titles
	[self.storylinePopup removeAllItems];
	
	[_storylinePopup addItemWithTitle:STORYLINE_TITLE];
	for (NSString *storyline in _storylines) {
		[_storylinePopup addItemWithTitle:storyline];
		if ([_visibleStorylines containsObject:storyline]) _storylinePopup.lastItem.state = NSOnState;
	}
}

- (IBAction)selectStoryline:(id)sender {
	NSMenuItem *item = [(NSPopUpButton*)sender selectedItem];
	if (item.state == NSOnState) {
		item.state = NSOffState;
		[_visibleStorylines removeObject:item.title.uppercaseString];
	} else {
		item.state = NSOnState;
		[_visibleStorylines addObject:item.title.uppercaseString];
	}
	
	[self updateStorylineLabels];
	[self updateScenesAndRebuild:YES];
}

- (void)updateStorylineLabels {
	for (NSTextField *label in _storylineLabels) {
		[label removeFromSuperview];
	}
	[_storylineLabels removeAllObjects];

	for (int i = 0; i < _visibleStorylines.count; i++) {
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 60, 12)];
		textField.editable = NO;
		textField.bezeled = NO;
		textField.drawsBackground = NO;
		textField.alignment = NSTextAlignmentRight;
		textField.textColor = NSColor.whiteColor;
		textField.font = [NSFont systemFontOfSize:8.5];
		
		[self addSubview:textField];
		[_storylineLabels addObject:textField];
	}

	for (int i = 0; i < _visibleStorylines.count; i++) {
		NSTextField *textField = _storylineLabels[i];
		textField.stringValue = _visibleStorylines[i];
		
		NSRect frame = textField.frame;
		frame.origin.y = DEFAULT_Y + 30 + i * 20 + 5;
		if (_hasSections) frame.origin.y += SECTION_HEADROOM;
		textField.frame = frame;
	}
}

#pragma mark - Sizing + frame

- (void)show {
	_heightConstraint.constant = [self desiredHeight];
	[self reload];
	self.enclosingScrollView.hasHorizontalScroller = YES;
	[self setNeedsLayout:YES];
}
- (void)hide {
	self.enclosingScrollView.hasHorizontalScroller = NO;
	_heightConstraint.constant = 0;
}

- (CGFloat)desiredHeight {
	CGFloat height = DEFAULT_HEIGHT;
	if (_visibleStorylines) height += 20 * _visibleStorylines.count;
	
	return height;
}

@end
/*
 
 tähän kesään kuului sun persoonasi
 varovaiset suudelmat liikennepuistossa
 kävelyt ja hauskimmat keskustelut
 mitä olen käynyt taas aikoihin
 
 niin silti elämä jatkuu ilman sua
 matkusta vaan rauhassa
 me pärjäämme ilman sua
 vaikka onhan se
 köyhempää
 
 */
