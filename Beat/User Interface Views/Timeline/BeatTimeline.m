//
//  BeatTimeline.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.9.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Replacement for the JavaScript-based timeline. Super fast & efficient.
 This can be wrapped in a PinchScrollView or something similar.

 Some weirdness:
 
 - BeatTimelineItem asks its delegate (this class) to select itself. The timeline THEN
   selects it through [item select].
 - Items handle their own context menu and take care of setting their storyline.
   For colors, however, the action is connected into this class.
 - We are using STORYLINE NAMES and not Storybeat objects here!
 
 */

#import <BeatParsing/BeatParsing.h>
#import <Quartz/Quartz.h>
#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2.h>
#import "BeatTimeline.h"
#import "BeatTimelineItem.h"
#import "HorizontalPinchView.h"

#define STORYLINE_TITLE @"Track Storyline"
#define PLACEHOLDER_WIDTH 0.01

#define DEFAULT_HEIGHT 130.0
#define DEFAULT_Y 33.0
#define SECTION_HEADROOM 6.0
#define PADDING 8.0
#define BOTTOM_PADDING 10.0
#define MAXHEIGHT 30.0
#define STORYLINE_LABELS_WIDTH 65.0
#define STORYLINE_HEIGHT 15.0

#define POPOVER_WIDTH 200.0
#define POPOVER_PADDING 5.0
#define POPOVER_HEIGHT 28.0
#define POPOVER_APPEARANCE NSAppearanceNameVibrantDark

@interface BeatTimeline ()

@property (nonatomic, weak) IBOutlet NSButton* toggleButton;

// Interface
@property (nonatomic, weak) IBOutlet NSPopUpButton *storylinePopup;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *localHeightConstraint;
@property (nonatomic) CGFloat originalHeight;
@property (nonatomic) NSTimer *refreshTimer;

@property (nonatomic, weak) IBOutlet NSView* containerView;

// Timeline data
@property (nonatomic) CGFloat totalLength;
@property (nonatomic) bool hasSections;
@property (nonatomic) NSInteger sectionDepth;
@property (nonatomic) NSMutableArray<BeatTimelineItem*>* scenes;
@property (nonatomic) NSMutableArray *storylineItems;
@property (nonatomic) NSMutableArray *storylineLabels;
@property (nonatomic) NSArray *storylineColors;

// Storyline UI
@property (nonatomic) NSPopover *storylinePopover;
@property (nonatomic) NSTextField *storylineField;

// Playhead layer
@property (nonatomic) CAShapeLayer *playhead;
@end

@implementation BeatTimeline

- (void)setup {
}


- (void)awakeFromNib {
	// Register this view to be updated
	[_delegate registerSceneOutlineView:self];
	[_delegate registerPaginationBoundView:self];
	
	// No item selected
	_clickedItem = nil;
	
	_scenes = NSMutableArray.new;;
	_selectedItems = NSMutableArray.new;;
	
	// Storyline elements
	_storylineItems = NSMutableArray.new;;
	_storylines = NSMutableArray.new;;
	_storylineLabels = NSMutableArray.new;;
	[_storylinePopup setHidden:YES];
	_storylineColors = @[[BeatColors color:@"blue"], [BeatColors color:@"magenta"], [BeatColors color:@"orange"], [BeatColors color:@"green"], [BeatColors color:@"yellow"]];
	
	// Graphical setup
	_originalHeight = self.localHeightConstraint.constant; // Save the default height from Interface Builder
	self.wantsLayer = YES;
	[self.enclosingScrollView setBackgroundColor:[BeatColors color:@"backgroundGray"]];
	_backgroundColor = [BeatColors color:@"backgroundGray"];
	
	// Setup playhead
	CGPathRef path = CGPathCreateWithRect(CGRectMake(1, 1, 1, self.frame.size.height), nil);
	_playhead = [CAShapeLayer layer];
	_playhead.bounds = CGRectMake(1, 1, 1, self.frame.size.height);
	_playhead.fillColor = NSColor.redColor.CGColor;
	_playhead.path = path;
	_playhead.lineWidth = 3;
	_playhead.position = CGPointMake(-5, self.frame.size.height / 2);
	
	CGPathRelease(path);
	
	[self.layer addSublayer:_playhead];
	
	// Storylines
	_visibleStorylines = NSMutableArray.new;;
	
	// Setup "Add Storyline" popover
	_storylinePopover = [[NSPopover alloc] init];
	_storylinePopover.contentViewController = [[NSViewController alloc] init];
	
	NSView *storylineView = [[NSView alloc] initWithFrame:NSZeroRect];
	_storylineField = [[NSTextField alloc] initWithFrame:NSMakeRect(POPOVER_PADDING, POPOVER_PADDING, POPOVER_WIDTH - POPOVER_PADDING * 2, POPOVER_HEIGHT - POPOVER_PADDING * 2)];
	_storylineField.editable = YES;
	_storylineField.placeholderString = [BeatLocalization localizedStringForKey:@"storyline.placeholder"];
	_storylineField.bezeled = NO;
	_storylineField.drawsBackground = NO;
	[storylineView addSubview:_storylineField];
	[_storylinePopover.contentViewController setView:storylineView];
	[_storylinePopover setContentSize:NSMakeSize(POPOVER_WIDTH, POPOVER_HEIGHT)];
	_storylinePopover.appearance = [NSAppearance appearanceNamed:POPOVER_APPEARANCE];
	
	_storylineField.delegate = self;
	
	[self updateStorylineLabels];
	
	[self hide];
}

- (BOOL)isFlipped { return YES; }


#pragma mark - Mouse events

- (void)scrollWheel:(NSEvent *)event
{
	// For some reason we need to do this on macOS Sonoma.
	// No events are registered in the scroll view when another scroll view is earlier in responder chain in this window. No idea.
	if (@available(macOS 14.0, *)) {
		CGPoint p = [self convertPoint:event.locationInWindow fromView:nil];
		if ([self mouse:p inRect:self.bounds]) {
			[self.enclosingScrollView scrollWheel:event];
			return;
		}
	}
	[super scrollWheel:event];
}

-(void)mouseUp:(NSEvent *)event
{
	[super mouseUp:event];
	
	// Close "add storyline" popover
	if (_storylinePopover.isShown) {
		[_storylinePopover close];
		_storylineField.stringValue = @"";
	}
}


#pragma mark - Create items

/// Creates needed amount of timeline item views (or removes extra ones)
- (void)createTimelineItemViews:(NSInteger)scenes
{
	NSInteger diff = scenes - self.scenes.count;
	if (diff > 0) {
		// We need more items
		for (int i = 0; i < diff; i++) {
			BeatTimelineItem *item = [BeatTimelineItem.alloc initWithDelegate:self];
			[_scenes addObject:item];
			[self addSubview:item];
		}
	} else if (diff < 0) {
		// There are extra items
		for (NSInteger i = 0; i < -diff; i++) {
			BeatTimelineItem *item = _scenes.lastObject;
			[item removeFromSuperview];
			[_scenes removeObject:item];
		}
	}
}

/// Creates needed amount of storyline item views (or removes extra ones)
- (void)createStorylineItems:(NSInteger)storylineBlocks {
	NSInteger diff = storylineBlocks - self.storylineItems.count;
	if (diff > 0) {
		for (int i = 0; i < diff; i++) {
			BeatTimelineItem *item = [[BeatTimelineItem alloc] initWithDelegate:self];
			[_storylineItems addObject:item];
			[self addSubview:item];
		}
	} else if (diff < 0) {
		for (NSInteger i = 0; i < -diff; i++) {
			[_storylineItems.lastObject removeFromSuperview];
			[_storylineItems removeLastObject];
		}
	}
	
	// Remove all storyline items when they are not needed
	if ((storylineBlocks == 0 && _visibleStorylines.count) ||
		(_visibleStorylines.count == 0 && _storylineItems.count > 0)) {
		for (BeatTimelineItem *item in _storylineItems) {
			[item removeFromSuperview];
		}
		
		[_storylineItems removeAllObjects];
		[self removeStorylineLabels];
		[_visibleStorylines removeAllObjects];
	}
}


#pragma mark - Updating scenes

- (void)updateScenes {
	[self updateScenesAndRebuild:NO];
}

- (void)updateScenesAndRebuild:(bool)rebuild {
	_clickedItem = nil;
	bool sectionsHaveContent = [[self.delegate.documentSettings getString:DocSettingStylesheet] isEqualToString:@"Novel"]; //TODO: Fix this to somethign more generic
	
	if (rebuild) {
		[self deselectAll];
		_totalLength = 0;
		_hasSections = NO;
		
		NSInteger scenes = 0;
		NSInteger storylineBlocks = 0;
		
		// Calculate total length
		for (OutlineScene *scene in _outline) {
			// Skip some elements
			if (scene.omitted) continue;
			
			if (scene.type == section && !sectionsHaveContent) {
				// Having sections transforms the view, so save the depth, too
				_hasSections = YES;
				if (scene.sectionDepth > _sectionDepth) _sectionDepth = scene.sectionDepth;
			} else {
				_totalLength += (scene.printedLength > PLACEHOLDER_WIDTH) ?  scene.printedLength : PLACEHOLDER_WIDTH;
			}
			
			if (scene.storylines.count) {
				NSMutableSet *storylines = [NSMutableSet setWithArray:scene.storylines];
				[storylines intersectSet:[NSSet setWithArray:_visibleStorylines]];
				storylineBlocks += storylines.count;
			}
			
			scenes++;
		}
		
		if (_totalLength == 0.0) _totalLength = 0.01;
		
		// Create timeline items
		[self createTimelineItemViews:scenes];
		
		// Do the same for storyline blocks
		[self createStorylineItems:storylineBlocks];
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
	CGFloat yPosition = DEFAULT_Y;
	if (_hasSections) {
		if (_sectionDepth == 1) yPosition += SECTION_HEADROOM;
		else yPosition += 2 * SECTION_HEADROOM;
	}
	
	NSInteger index = 0;
	NSInteger storylineIndex = 0;
	
	BeatTimelineItem *previousSection;
	
	NSRect selectionRect = NSZeroRect;
	
	for (OutlineScene *scene in self.outline) {
		if (scene.omitted) continue;
		
		// Handle regular scenes
		//bool selected = NO;
		//NSInteger selection = self.delegate.selectedRange.location;
		//if (selection >= scene.sceneStart && selection < scene.sceneStart + scene.sceneLength) selected = YES;
		
		NSRect rect;
		CGFloat width;
		if (scene.type == section && !sectionsHaveContent) {
			width = 1;
			rect = NSMakeRect(x, yPosition, 1, 1);
		} else {
			CGFloat length = scene.printedLength > PLACEHOLDER_WIDTH ? scene.printedLength : PLACEHOLDER_WIDTH;
			width = length * factor;
			rect = NSMakeRect(x, yPosition, width, height);
		}
		
		// Apply the scene data to the representing item
		BeatTimelineItem *item = _scenes[index];
		
		[item setItem:scene rect:rect reset:rebuild];
		if (item.selected) selectionRect = item.frame;
		
		// Show storylines
		// A much more sensible approach would be to really create timelines by a track, but whatever.
		// The track y positions should still maybe be set while creating the labels. That way,
		// we would have the exact and correct y position to match the label.
		if (scene.type == heading && scene.storylines.count && _visibleStorylines.count) {
			int storylineTrack = 0;
			
			// Go through the storylines in this scene
			for (NSString *storyline in _visibleStorylines) {
				if ([scene.storylines containsObject:storyline.uppercaseString]) {
					BeatTimelineItem *storylineItem = _storylineItems[storylineIndex];
					
					// We will adjust the frame a bit
					rect.origin.y = yPosition + 10 + STORYLINE_HEIGHT * 2 + STORYLINE_HEIGHT * storylineTrack;
					[storylineItem setItem:scene rect:rect reset:rebuild storyline:YES forceColor:_storylineColors[storylineTrack % _storylineColors.count]];
					
					storylineIndex++;
				}
				storylineTrack++;
			}
		}
		
		// Clip sections & synopsis markers for same and higher level sections
		if (scene.type == section) {
			if (previousSection && previousSection.representedItem.sectionDepth >= scene.sectionDepth) {
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
		
		// Only add the width to the total width if it's a scene
		// Sections add 2 px to account for the separator
		if (scene.type == section && !sectionsHaveContent) {
			x += 2;
		} else {
			x += width + 1;
		}
		
		index++;
	}
	
	[self moveToCurrentSceneAnimated:false];
}

- (void)moveToCurrentSceneAnimated:(BOOL)animated
{
	// Move playhead to the selected position
	[CATransaction begin];
	
	// Disable core animation
	if (animated) [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	[self moveToScene:_delegate.currentScene scroll:false];
	
	[CATransaction commit];
}


#pragma mark - Drawing

-(void)setFrame:(NSRect)frame
{
	CGFloat magnification = [(HorizontalPinchView*)self.enclosingScrollView horizontalMagnification];
	CGFloat newWidth = self.enclosingScrollView.frame.size.width * magnification;
	frame.size.width = newWidth;
	frame.size.height = self.enclosingScrollView.frame.size.height - 2.0;
	
	[super setFrame:frame];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	[self updateScenes];
	[self drawPageNumbers];
	
	// Let's draw labels
	if (_visibleStorylines) [self updateStorylineLabels];
}

- (void)drawPageNumbers
{
	NSDictionary* attrs = @{
		NSFontAttributeName: [NSFont systemFontOfSize:6.0],
		NSForegroundColorAttributeName: NSColor.secondaryLabelColor
	};

	NSInteger sceneIdx = 0;
	CGFloat sceneStartPage = 0.0;

	CGFloat prevX = -1.0;
	NSUInteger density = NSNotFound;

	NSArray<BeatPaginationPage*>* pages = self.delegate.pagination.finishedPagination.pages;
	
	for (NSInteger p = 0; p < pages.count; p++) {

		CGFloat pagePos = (CGFloat)p; // page-space position

		BeatPaginationPage* page = pages[p];
		if (page.lines.firstObject.type == heading || page.lines.firstObject.type == section) {
			// Let's find the index of this item
			OutlineScene* newScene = [self.delegate.parser sceneWithUUID:page.lines.firstObject.uuidString];
			NSInteger newSceneIndex = [self.outline indexOfObject:newScene];
			if (newSceneIndex != NSNotFound) {
				sceneIdx = newSceneIndex;
				sceneStartPage = p;
			}
		}
		
		while (sceneIdx < self.scenes.count) {
			BeatTimelineItem *item = self.scenes[sceneIdx];
			CGFloat sceneLength = item.representedItem.printedLength;
			CGFloat sceneEndPage = sceneStartPage + sceneLength;

			// Does this page live inside this scene?
			if (pagePos >= sceneStartPage && pagePos < sceneEndPage) {

				CGFloat t = (pagePos - sceneStartPage) / sceneLength;
				CGFloat x = item.frame.origin.x + t * item.frame.size.width;

				// Define density of page numbers
				if (density == NSNotFound && prevX >= 0.0) {
					CGFloat dx = x - prevX;
					if (dx < 10.0) density = 10;
					else if (dx < 15.0) density = 5;
					else density = 1;
				}

				if (density == NSNotFound || p % density == 0) {
					NSAttributedString *pStr =
						[[NSAttributedString alloc]
							initWithString:[NSString stringWithFormat:@"%ld", p + 1]
								attributes:attrs];

					[pStr drawAtPoint:CGPointMake(x, 80.0)];
				}

				prevX = x;
				break;
			}

			sceneStartPage = sceneEndPage;
			sceneIdx++;
		}
	}

}


#pragma mark - Move to scenes

/// Called by the editor to tell we moved to this scene
- (void)didMoveToSceneIndex:(NSInteger)index
{
	[self moveToSceneIndex:index scroll:true];
}

- (void)moveToScene:(OutlineScene*)scene scroll:(bool)scroll
{
	NSUInteger i = [self.delegate.parser.outline indexOfObject:scene];
	[self moveToSceneIndex:i scroll:scroll];
}

- (void)moveToSceneIndex:(NSInteger)index scroll:(bool)scroll
{
	[self deselectAll];

	CGRect selectionRect = CGRectMake(0, 0, 0, 0);
	
	BeatTimelineItem* selectedItem;
	NSInteger selectedLoc = _delegate.selectedRange.location;
	
	if ((index >= _outline.count || index == NSNotFound) && selectedLoc >= _outline.firstObject.position) {
		// Check if the caret is at end and select the last item in that case.
		selectedItem = _scenes.lastObject;
	} else if (index != NSNotFound) {
		OutlineScene *selectedScene = self.outline[index];
		selectedItem = [self timelineItemFor:selectedScene];
	}
	
	// Nothing to do here. Deselect all and return.
	if (selectedItem == nil) {
		[self deselectAll];
		return;
	}
	
	// Select item
	if (selectedItem) {
		[selectedItem select];
		[_selectedItems setArray:@[selectedItem]];
		selectionRect = selectedItem.frame;
	}
	
	// Calculate the actual playhead position inside scenes
	if (selectedItem.representedItem.type == heading) {
		NSInteger location = selectedItem.representedItem.position;
		NSInteger length = selectedItem.representedItem.length;
		
		CGFloat relativePos = (CGFloat)(selectedLoc - location) / (CGFloat)length;
		
		selectionRect.origin.x += selectedItem.frame.size.width * relativePos;
	}

	
	// If the scene is not in view, scroll it into center
	if (scroll) {
		NSRect bounds = self.enclosingScrollView.contentView.bounds;
		if (!NSLocationInRange(selectionRect.origin.x, NSMakeRange(bounds.origin.x, bounds.size.width))) {
			bounds.origin.x = selectionRect.origin.x - ((self.enclosingScrollView.frame.size.width - selectionRect.size.width) / 2);
			
			[self.enclosingScrollView.contentView.animator setBoundsOrigin:bounds.origin];
		}
	}
	 
	[self movePlayhead:selectionRect];
	[self updateLayer];
}

- (void)movePlayhead:(NSRect)selectionRect {
	CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, 1, self.frame.size.height), nil);
	_playhead.bounds = CGRectMake(0, 0, 1, self.frame.size.height);
	_playhead.path = path;
	_playhead.position = CGPointMake(selectionRect.origin.x, self.frame.size.height / 2);
	CGPathRelease(path);
}

- (CGFloat)playheadPosition {
	return _playhead.position.x;
}

#pragma mark - Data model

- (BeatTimelineItem*)timelineItemFor:(OutlineScene*)scene
{
	for (BeatTimelineItem *item in self.scenes) {
		if (item.representedItem == scene) return item;
	}
	return nil;
}


#pragma mark - Selecting

- (void)deselectAll {
	[_selectedItems removeAllObjects];
	for (BeatTimelineItem *item in self.scenes) {
		[item deselect];
	}
}
- (void)deselect:(id)item {
	[(BeatTimelineItem*)item deselect];
	[_selectedItems removeObject:item];
}

/// A _single_ timeline item was clicked. It calls its delegate (this class) and we jump to the scene
- (void)setSelected:(id)item
{
	// Reset array
	[self deselectAll];
	[_selectedItems setArray:@[item]];
	
	[(BeatTimelineItem*)item select];
	NSInteger index = [_outline indexOfObject:[(BeatTimelineItem*)item representedItem]];
	
	if (index != NSNotFound) {
		OutlineScene* scene = _outline[index];
		[self.delegate scrollToScene:scene];
	}
}

/// Multiple timeline items were selected using CMD. Called by the item.
- (void)addSelected:(id)item
{
	// Add to array
	[_selectedItems addObject:item];
	[(BeatTimelineItem*)item select];
}

/// A range of items was selected using shift key.
- (void)selectTo:(id)item
{
	BeatTimelineItem *selectedItem = item;
	NSInteger lastIndex = [_scenes indexOfObject:_selectedItems.firstObject];
	NSInteger index = [_scenes indexOfObject:selectedItem];
	
	NSInteger from;
	NSInteger to;
	
	if (lastIndex < index) {
		from = lastIndex + 1;
		to = index;
	} else {
		from = index;
		to = lastIndex - 1;
	}
	
	for (NSInteger i = from; i <= to; i++) {
		BeatTimelineItem *scene = self.scenes[i];
		if (scene.type == TimelineScene && ![_selectedItems containsObject:scene]) {
			[_selectedItems addObject:scene];
			[scene select];
		}
	}
}


#pragma mark - Random shit

- (BOOL)showsTrueLengths
{
	return true;
}

#pragma mark - Storyline handling

- (void)updateStorylines
{
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
	if (_storylines.count) {
		[_storylinePopup setHidden:NO];
	} else {
		[_storylinePopup setHidden:YES];
		_visibleStorylines = NSMutableArray.new;;
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

- (IBAction)selectStoryline:(id)sender
{
	NSMenuItem *item = [(NSPopUpButton*)sender selectedItem];
	if (item.state == NSOnState) {
		item.state = NSOffState;
		[_visibleStorylines removeObject:item.title.uppercaseString];
	} else {
		item.state = NSOnState;
		[_visibleStorylines addObject:item.title.uppercaseString];
	}
	
	[self desiredHeight];
	[self updateStorylineLabels];
	[self updateScenesAndRebuild:YES];
}

- (void)removeStorylineLabels
{
	for (NSTextField *label in _storylineLabels) {
		[label removeFromSuperview];
	}
	[_storylineLabels removeAllObjects];
}

- (void)updateStorylineLabels
{
	[self removeStorylineLabels];
	
	for (int i = 0; i < _visibleStorylines.count; i++) {
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, STORYLINE_LABELS_WIDTH + 5, 12)];
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
		frame.origin.y = DEFAULT_Y + 30 + i * STORYLINE_HEIGHT + 5;
		if (_hasSections) {
			if (_sectionDepth == 1) frame.origin.y += SECTION_HEADROOM;
			else frame.origin.y += SECTION_HEADROOM * 2;
		}
		textField.frame = frame;
	}
}


#pragma mark - Displaying the view

- (IBAction)toggleTimeline:(id)sender
{
	self.visible = !self.visible;
	if (self.visible) [self show]; else [self hide];

	self.toggleButton.state = (self.visible) ? NSOnState : NSOffState;
}

- (void)show
{
	self.containerView.hidden = false;
	[self desiredHeight];

	self.enclosingScrollView.hasHorizontalScroller = YES;
	
	self.needsLayout = YES;
	self.visible = YES;
	
	[self reload];
	[self moveToScene:_delegate.currentScene scroll:true];
}

- (void)hide {
	self.containerView.hidden = true;
	self.enclosingScrollView.hasHorizontalScroller = NO;
	_localHeightConstraint.constant = 0;
	_heightConstraint.constant = 0;
	
	self.visible = NO;
}

- (void)desiredHeight
{
	CGFloat height = DEFAULT_HEIGHT;
	
	if (_visibleStorylines.count > 0) {
		height += BOTTOM_PADDING + 20 * (_visibleStorylines.count - 1);
		_localHeightConstraint.constant = _originalHeight + BOTTOM_PADDING + (_visibleStorylines.count - 1) * STORYLINE_HEIGHT;
	} else {
		_localHeightConstraint.constant = _originalHeight;
	}
	
	_heightConstraint.constant = height;
	[self setNeedsDisplay:YES];
}

- (CGFloat)timelineHeight
{
	return _originalHeight;
}


#pragma mark - Delegate methods

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene
{
	if (_selectedItems.count <= 1) [_delegate.textActions addStoryline:storyline to:scene];
	else {
		// Multiple items selected
		NSArray *selected = [NSArray arrayWithArray:_selectedItems];
		for (BeatTimelineItem* item in selected) {
			[_delegate.textActions addStoryline:storyline to:item.representedItem];
		}
	}
}

- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene
{
	if (_selectedItems.count <= 1) [_delegate.textActions removeStoryline:storyline from:scene];
	else {
		// Multiple items selected
		NSArray *selected = [NSArray arrayWithArray:_selectedItems];
		for (BeatTimelineItem* item in selected) {
			[_delegate.textActions removeStoryline:storyline from:item.representedItem];
		}
	}
}

- (void)newStorylineFor:(OutlineScene*)scene item:(id)item
{
	if (self.storylinePopover.isShown) [self.storylinePopover close];
	
	BeatTimelineItem *sceneItem = item;
	[self.storylinePopover showRelativeToRect:sceneItem.frame ofView:sceneItem preferredEdge:NSRectEdgeMaxY];
	[self.storylinePopover showRelativeToRect:sceneItem.frame ofView:self preferredEdge:NSRectEdgeMinY];
	
	[self.window makeFirstResponder:self.storylineField];
}

- (void)setSceneColor:(NSString*)color for:(OutlineScene*)scene
{
	if (_selectedItems.count <= 1) {
		[_delegate.textActions setColor:color forScene:scene];
	} else {
		// Multiple items selected
		NSArray *selected = [NSArray arrayWithArray:_selectedItems];
		for (BeatTimelineItem* item in selected) {
			[_delegate.textActions setColor:color forScene:item.representedItem];
		}
	}
}


#pragma mark - TextField delegation

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
	if (commandSelector == @selector(insertNewline:)) {
		NSString *storyline = _storylineField.stringValue.uppercaseString;
		
		if (_clickedItem) {
			if (_selectedItems.count <= 1) [_delegate.textActions addStoryline:storyline to:_clickedItem];
			else {
				NSArray *selected = [NSArray arrayWithArray:_selectedItems];
				for (BeatTimelineItem* item in selected) {
					[_delegate.textActions addStoryline:storyline to:item.representedItem];
				}
			}
		}
		
		[_storylinePopover close];
		_storylineField.stringValue = @""; // Empty the string
		_clickedItem = nil;
		return YES;
	}
	else if (commandSelector == @selector(insertTab:) ||
			 commandSelector == @selector(cancelOperation:)) {
		[_storylinePopover close];
		_storylineField.stringValue = @""; // Empty the string
		_clickedItem = nil;
		return YES;
	}
	
	// return YES if the action was handled; otherwise NO
	return NO;
}


#pragma mark - Reloading (to conform to scene outline view protocol)

- (void)reloadInBackground
{
	[self reload];
}

- (void)reloadView
{
	[self reload];
}

- (void)reloadWithChanges:(OutlineChanges *)changes
{
	if (self.visible) [self reload];
}

- (void)paginationFinished
{
	if (!self.visible) return;
	_outline = _delegate.parser.safeOutline;
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self updateScenesAndRebuild:YES];
	});
}

- (void)reload
{
	// Don't load in background
	if (!self.visible) return;
	
	_outline = _delegate.parser.safeOutline;
	
	[self updateScenesAndRebuild:YES];
	[self updateStorylines];
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
