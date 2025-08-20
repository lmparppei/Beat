//
//  BeatOutlineView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 07/10/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatUserDefaults.h>
#import <BeatCore/BeatMeasure.h>
#import <BeatCore/BeatAutocomplete.h>
#import <BeatDynamicColor/BeatDynamicColor.h>
#import <BeatCore/OutlineViewItem.h>

#import "BeatOutlineView.h"
#import "SceneFiltering.h"
#import "ColorCheckbox.h"
#import "Beat-Swift.h"

#define LOCAL_REORDER_PASTEBOARD_TYPE @"LOCAL_REORDER_PASTEBOARD_TYPE"
#define OUTLINE_DATATYPE @"OutlineDatatype"

@interface BeatOutlineView () <NSPopoverDelegate, BeatOutlineSettingDelegate, NSMenuDelegate, BeatSceneOutlineView>

@property (weak) IBOutlet NSSearchField *outlineSearchField;

@property (weak) IBOutlet NSBox *filterView;
@property (weak) IBOutlet NSLayoutConstraint *filterViewHeight;
@property (weak) IBOutlet NSPopUpButton *characterBox;
@property (weak) IBOutlet NSButton *resetColorFilterButton;
@property (weak) IBOutlet NSButton *resetCharacterFilterButton;

@property (weak) IBOutlet BeatAutomaticAppearanceView* appearanceView;

@property (nonatomic) OutlineScene *draggedScene;
@property (nonatomic) bool outlineEdit;

@property (nonatomic) NSPopover* settingsPopover;

// Fuck you macOS & Apple. For two things, particulary:
//
// 1) IBOutletCollection is iOS-only
// 2) This computer (and my phone and everything else) is made in
//    horrible conditions in some sweatshop in China, just to add
//    to your fucking sky-high profits, you fucking despicable capitalist fucks.
//
//    You are the most profitable company operating in our current monetary
//    and economic system. EQUALITY, WELFARE AND FREEDOM FOR EVERYONE.
//    FUCK YOU, APPLE.
//
//    2020 edit: FUCK YOU EVEN MORE, fucking capitalist motherfuckers, for
//    allowing UIGHUR SLAVE LABOUR in your subcontracting factories, you fucking
//    pieces of human garbage!!! Go fuck yourself, Apple. Fucking evil corp!!!
//
//    2021 edit: YOU STILL HAVEN'T FIXED ANY OF THE PROBLEMS STATED ABOVE.
//	  If you can't make a big enough profit without using slave labour, maybe
//    you should go FUCK YOURSELVES.
//
//	  2022 edit: Ok, so your latest OS versions support IBOutletCollection,
//	  but you are STILL using basically slave labour in China and other countries.
//	  FUCK YOU. Bring down capitalism, please.
//
//	  2023 edit: I removed the weird SceneTree structure and the class again uses
//    plain OutlineScene objects. One thing still stands: Apple CAN GO FUCK THEMSELVES.
//    They stil don't give a fuck for the lives of their workers.
//	  BURN DOWN THEIR FACTORIES.
//    STEAL YOUR MAC.
//
//    2023 pre-new-year edit: FUCK YOU APPLE.
//
//    2024 edit: I'm conforming this class to the outline view protocol, and almost
//	  forgot to add that APPLE SHOULD GO FUCK THEMSELVES.
//
//    Late 2024 edit: I'm on the Geneva airport, trying to make sense to this code.
//    And yes, FUCK YOU APPLE. Go fuck yourselves with all the pink washing.
//    STOP THE GENOCIDE IN PALESTINE AND END UYGHUR SLAVE CAMPS.
//    SEIZE THE MEANS OF PRODUCTION.


//    So, back to the code:

@property (weak) IBOutlet ColorCheckbox *redCheck;
@property (weak) IBOutlet ColorCheckbox *blueCheck;
@property (weak) IBOutlet ColorCheckbox *greenCheck;
@property (weak) IBOutlet ColorCheckbox *orangeCheck;
@property (weak) IBOutlet ColorCheckbox *cyanCheck;
@property (weak) IBOutlet ColorCheckbox *brownCheck;
@property (weak) IBOutlet ColorCheckbox *magentaCheck;
@property (weak) IBOutlet ColorCheckbox *pinkCheck;

@property (nonatomic) NSMutableArray *collapsed;
@property (nonatomic) NSArray *cachedOutline;

@property (weak, nonatomic) IBOutlet NSButton *synopsisCheckbox;

@property (nonatomic) bool showSynopsis;
@property (nonatomic) bool showSceneNumbers;
@property (nonatomic) bool showNotes;

@property (nonatomic) NSArray *tree;

@end

@implementation BeatOutlineView

-(instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	return self;
}

-(void)awakeFromNib
{
	self.delegate = self;
	self.dataSource = self;
		
	self.filters = SceneFiltering.new;
	_filters.editorDelegate = self.editorDelegate;
	self.filteredOutline = NSMutableArray.new;
	
	self.menu.delegate = self;
	
	self.characterBox.menu.delegate = self;
	
	[self registerForDraggedTypes:@[LOCAL_REORDER_PASTEBOARD_TYPE, OUTLINE_DATATYPE]];
	[self setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	
	[self hideFilterView];
	
	// Register this view
	[self.editorDelegate registerSceneOutlineView:self];

}

-(void)setup
{
	self.usesAutomaticRowHeights = true;
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(searchOutline) name:NSControlTextDidChangeNotification object:self.outlineSearchField];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
}

- (void)drawBackgroundInClipRect:(NSRect)clipRect
{
	//[super drawBackgroundInClipRect:clipRect];
	NSRange rows = [self rowsInRect:clipRect];
	// Get current scene and represented row
	NSInteger selectedRow = [self rowForItem:self.editorDelegate.currentScene];
		
	for (NSUInteger i = rows.location; i < NSMaxRange(rows); i++) {
		OutlineScene* item = [self itemAtRow:i];

		NSRect rect = [self rectOfRow:i];
		rect.origin.x += 2;
		rect.size.width -= 4;
		rect.size.height -= 1;

		if (item.type != section) {
			CGFloat indent = self.indentationPerLevel * item.sectionDepth;
			rect.size.width = rect.size.width - indent;
			rect.origin.x += indent;
		}
		
		NSBezierPath *bg = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:3 yRadius:3];
		NSColor* fillColor = nil;

		if (i == selectedRow) {
			fillColor = (self.appearanceView.appearAsDark) ? ThemeManager.sharedManager.outlineHighlight.darkColor : ThemeManager.sharedManager.outlineHighlight.lightColor;
			[fillColor setFill];
		} else if (item.type != section && [BeatUserDefaults.sharedDefaults getBool:BeatSettingRelativeOutlineHeights]) {
			// In relative mode, we'll paint a background for each scene
			fillColor = [NSColor.grayColor colorWithAlphaComponent:0.2];
			/*
			// For future generations
			if (item.color.length > 0) {
				BXColor* c = [BeatColors color:item.color];
				if (c != nil) fillColor = c;
			}
			 */
			[fillColor setFill];
		}
		
		if (fillColor != nil) [bg fill];
	}
}

- (NSTouchBar*)makeTouchBar
{
	return _touchBar;
}


#pragma mark - Listen to changes in editor

- (bool)visible
{
	return (self.editorDelegate.sidebarVisible && self.enclosingTabView.tabView.selectedTabViewItem == self.enclosingTabView);
}

- (void)reloadInBackground { 
	// Maybe we don't need this here?
}

- (void)reloadView { 
	if (self.visible) [self reloadOutline];
}


- (void)didMoveToSceneIndex:(NSInteger)index
{
	if (self.dragging || self.editing) return;
	
	OutlineScene* scene = self.editorDelegate.parser.outline[index];
	[self scrollToScene:scene];
	
	self.needsDisplay = true;
}


#pragma mark - Reload data

/*
 // For those who come after.
 -(void)reloadDiffedOutline {
 NSArray* outline = self.outline;
 
 if (@available(macOS 10.15, *)) {
 NSOrderedCollectionDifference* diff = [outline differenceFromArray:self.cachedOutline];
 
 for (OutlineScene* removed in diff.removals) {
 NSLog(@"Removed: %@", removed);
 }
 
 for (OutlineScene* inserted in diff.insertions) {
 NSLog(@"Added: %@", inserted);
 }
 
 self.cachedOutline = outline.copy;
 
 } else {
 [self reloadData];
 return;
 }
 }
 */

- (void)reloadItem:(id)item
{
	[super reloadItem:item];
}


-(void)reloadWithChanges:(OutlineChanges*)changes
{
	if (!self.visible) return;
	
	// Store current outline
	NSArray* outline = self.outline;
	
	// Do a full update if needed
	if (changes.removed.count > 0 || changes.added.count > 0 || ![_cachedOutline isEqualToArray:self.outline] || changes.needsFullUpdate) {
		_cachedOutline = self.outline.copy;
		[self reloadOutline];
		return;
	}
	
	_tree = self.editorDelegate.parser.outlineTree;
	NSRect bounds = self.enclosingScrollView.contentView.bounds;
	
	// Disable animations
	[self beginUpdates];
	[NSAnimationContext beginGrouping];
	[NSAnimationContext.currentContext setDuration:0.0];
	
	for (OutlineScene* element in changes.updated.allObjects) {
		[self reloadItem:element];
	}
	
	// Sections should be expanded by default
	for (OutlineScene *scene in outline) {
		if (![_collapsed containsObject:scene] && scene.type == section && ![self isItemExpanded:scene]) {
			[self expandItemWithoutAnimation:scene expandChildren:true];
		}
	}
	
	// Scroll back to where we were
	self.enclosingScrollView.contentView.bounds = bounds;
	
	// Enable animations again
	[NSAnimationContext endGrouping];
	[self endUpdates];
	
	self.cachedOutline = outline.copy;
}

-(void)reloadOutline
{
	// Store the current outline
	NSArray* outline = self.outline;
	_tree = self.editorDelegate.parser.outlineTree;
	
	// Save outline scroll position
	NSRect bounds = self.enclosingScrollView.contentView.bounds;
	
	// Disable animations
	[self beginUpdates];
	[NSAnimationContext beginGrouping];
	[NSAnimationContext.currentContext setDuration:0.0];
	
	// Check if there are filters on and then reload data
	[self filterOutline];
	[self reloadData];
	
	// Initialize collapsed item array if needed
	if (_collapsed == nil) _collapsed = NSMutableArray.new;
	
	// Expand any new sections by default
	for (OutlineScene *scene in outline) {
		if (![_collapsed containsObject:scene] && scene.type == section) {
			[self expandItem:scene expandChildren:YES];
		}
	}
	
	// Enable animations again
	[NSAnimationContext endGrouping];
	[self endUpdates];
	
	// Scroll back to where we were
	self.enclosingScrollView.contentView.bounds = bounds;
	
	self.cachedOutline = outline;
}

-(void)reloadData
{
	self.dragging = false; // Stop any drag operations
	[super reloadData];
}

-(void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	// Store the collapsed section
	OutlineScene *collapsedSection = [notification.userInfo valueForKey:@"NSObject"];
	[_collapsed addObject:collapsedSection];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	// Remove this from list of collapsed sections
	OutlineScene *expandedSection = [notification.userInfo valueForKey:@"NSObject"];
	[_collapsed removeObject:expandedSection];
}


#pragma mark - Setting getters

- (OutlineItemOptions)options
{
	OutlineItemOptions options = 0;
	if (self.showHeadings) options |= OutlineItemIncludeHeading;
	if (self.showSynopsis) options |= OutlineItemIncludeSynopsis;
	if (self.showNotes) options |= OutlineItemIncludeNotes;
	if (self.showSceneNumbers) options |= OutlineItemIncludeSceneNumber;
	if (self.showMarkers) options |= OutlineItemIncludeMarkers;
	if (((id<BeatDarknessDelegate>)NSApp.delegate).isDark) options |= OutlineItemDarkMode;
	
	return options;
}

- (bool)showHeadings
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowHeadingsInOutline];
}
- (bool)showSynopsis
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowSynopsisInOutline];
}
- (bool)showNotes
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowNotesInOutline];
}
- (bool)showSceneNumbers
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowSceneNumbersInOutline];
}
- (bool)showMarkers
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowMarkersInOutline];
}

#pragma mark - Delegation

-(void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(nonnull id)cell forTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item
{
	/*
	 // For those who come after
	 if (![item isKindOfClass:[OutlineScene class]]) return;
	 
	 OutlineScene *scene = item;
	 if (scene.type == section) [cell setEditable:YES];
	 */
}


- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	BeatSceneSnapshotCell* view = [outlineView makeViewWithIdentifier:@"SceneView" owner:self];
	//view.textField.attributedStringValue = [OutlineViewItem withScene:item currentScene:self.editorDelegate.currentScene options:self.options];
	view.textField.stringValue = ((OutlineScene*)item).stringForDisplay;
	
	[view configureWithDelegate:self.editorDelegate scene:item outlineView:self];
	
	return view;
}

- (void)outlineViewColumnDidResize:(NSNotification *)notification
{
	// Update row heights when needed
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.0];
	
	[self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:(NSRange){ 0, self.numberOfRows }]];
	
	[NSAnimationContext endGrouping];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item;
{
	// If we have a search term, let's use the filtered array
	if (_filters.activeFilters) {
		return _filteredOutline.count;
	} else {
		if (item == nil) {
			return _tree.count;
		} else {
			OutlineScene* scene = item;
			return scene.children.count;
		}
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	// If there is a search term, let's search the filtered array
	if (_filters.activeFilters) {
		return [_filteredOutline objectAtIndex:index];
	} else {
		if (item) {
			OutlineScene *section = item;
			if (section.children.count > index) return section.children[index];
			else return nil;
			
		} else {
			if (_tree.count > index) return _tree[index];
			else return nil;
		}
	}
}

- (NSArray*)outline
{
	return self.editorDelegate.parser.outline;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (_filteredOutline.count > 0) return NO;
	
	OutlineScene *scene = item;
	if (scene.type == section) return YES;
	else return NO;
}

// FOR CELL-BASED VIEW.
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([item isKindOfClass:[OutlineScene class]]) {
		// Note: OutlineViewItem returns an NSMutableAttributedString
		bool dark = ((id<BeatDarknessDelegate>)NSApp.delegate).isDark;
		return [OutlineViewItem withScene:item currentScene:self.editorDelegate.currentScene sceneNumber:self.showSceneNumbers synopsis:self.showSynopsis notes:self.showNotes markers:self.showMarkers isDark:dark];
	}
	return @"";
	
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	_editing = NO;
	
	if (![item isKindOfClass:[OutlineScene class]]) return NO;
	
	[self.editorDelegate scrollToScene:item];
	return YES;
}


/*
-(void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	_editing = NO;
	if (![item isKindOfClass:[OutlineScene class]]) return;
	
	OutlineScene *scene = item;
	NSString *newValue = [(NSAttributedString*)object string];
	if (scene.type != section || newValue == 0) return;
	
	newValue = [NSString stringWithFormat:@"# %@", newValue];
	
	[self replaceRange:scene.line.textRange withString:newValue];
}
*/

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray *)draggedItems
{
	_editing = NO;
	[session.draggingPasteboard setData:[NSData data] forType:LOCAL_REORDER_PASTEBOARD_TYPE];
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
	// ?
}

- (id <NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item
{
	// Don't allow reordering a filtered list
	if (_filters.activeFilters) return nil;
	
	OutlineScene *scene = (OutlineScene*)item;
	_draggedScene = scene;
	
	NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];
	[pboardItem setString:scene.string forType: NSPasteboardTypeString];
	return pboardItem;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id < NSDraggingInfo >)info proposedItem:(id)targetItem proposedChildIndex:(NSInteger)index
{
	// Don't allow reordering a filtered list
	if (_filters.activeFilters) return NSDragOperationNone;
	
	// Don't allow dropping into non-nested scenes
	OutlineScene *targetScene = (OutlineScene*)targetItem;
	if (targetScene.type == section) return NSDragOperationMove;
	else if (targetScene.string.length > 0 || index < 0) return NSDragOperationNone;
	
	return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id < NSDraggingInfo >)info item:(id)targetItem childIndex:(NSInteger)index
{
	// Don't allow reordering a filtered list
	if (_filteredOutline.count > 0 || _outlineSearchField.stringValue.length > 0) return NSDragOperationNone;
	
	/*
	 I have no idea what this code actually does. I've written it in lockdown (probably) and it's now November 2022.
	 Now, I'll do my best to document and comment the code.
	 
	 Update on Geneva airport in 2024: You didn't comment it at all, past me.
	 */
	
	// Target is always a SECTION, childIndex speaks for itself.
	
	OutlineScene *scene;
	NSArray *outline = self.outline;
	NSInteger numberOfChildren = [self numberOfChildrenOfItem:targetItem];
	
	OutlineScene* targetScene = targetItem;
	
	// What is this?
	if (index < numberOfChildren) scene = [self outlineView:self child:index ofItem:targetItem];
	
	// First we'll determine the indices
	NSInteger to = index;
	NSInteger from = [outline indexOfObject:_draggedScene];
	NSInteger position = 0; // Used for sections
	
	// The other indices are local (section-bound) indices, so we nede to figure out the actual position in flat outline.
	if (index == NSNotFound || index < 0) {
		// Dropped directly into a section header
		OutlineScene *lastInSection = targetScene.siblings.lastObject;
				
		if (lastInSection != nil) {
			// There were items in the section
			position = lastInSection.position + lastInSection.length;
			to = [self.outline indexOfObject:lastInSection];
		} else {
			// No items in the section
			to = [self.outline indexOfObject:targetItem] + 1;
		}
	} else {
		// Dropped normally between scenes
		if (scene) {
			to = [self.outline indexOfObject:scene];
			position = scene.position;
		} else {
			// Dropped at the end of a section. Look at this terniary hell.
			if (targetScene != nil) {
				OutlineScene* parent = (targetScene.parent != nil) ? targetScene.parent : targetScene;
				to = [self.outline indexOfObject:(parent.children.count > 0) ? parent.children.lastObject : targetScene] + 1;
				position = NSMaxRange(parent.children.lastObject.range);
			} else {
				to = self.outline.count;
				position = self.editorDelegate.text.length;
			}
		}
	}
	
	// If scene is being moved to the same index, do nothing.
	if (from == to || from == to - 1) return NO;
	
	self.dragging = true;
	
	if (_draggedScene.type == section) {
		// If the dropped item is a section, let's move everything it contains
		NSArray <OutlineScene*>*scenesInSection = @[_draggedScene];
		scenesInSection = [scenesInSection arrayByAddingObjectsFromArray:[self.editorDelegate.parser scenesInSection:_draggedScene]];
		
		NSInteger location = scenesInSection.firstObject.position;
		NSInteger length = NSMaxRange(scenesInSection.lastObject.range) - location;
		NSRange sectionRange = NSMakeRange(location, length);
				
		[self.editorDelegate.textActions moveScenesInRange:sectionRange to:position];
	} else {
		// Move a single scene
		self.editorDelegate.outlineEdit = YES;
		[self.editorDelegate.textActions moveScene:_draggedScene from:from to:to];
		self.editorDelegate.outlineEdit = NO;
	}
	
	return YES;
}

- (void)scrollToScene:(OutlineScene*)scene
{
	if (scene == nil) scene = self.editorDelegate.currentScene;
	if (scene == nil) return;
	
	// Check if we have filtering turned on, and do nothing if scene is not in the filter results
	if (self.filteredOutline.count) {
		if (![self.filteredOutline containsObject:scene]) return;
	}
	
	// If the current scene is inside a section, show the section
	if (scene.parent != nil) {
		if (![self isItemExpanded:scene.parent]) [self expandItemWithoutAnimation:scene expandChildren:false];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
			context.allowsImplicitAnimation = YES;
			[self scrollRowToVisible:[self rowForItem:scene]];
		} completionHandler:NULL];
	});
}


#pragma mark - Outline settings

- (IBAction)openSettings:(NSButton*)sender {
	self.settingsPopover = NSPopover.new;
	BeatOutlineSettings* settingsViewController = BeatOutlineSettings.new;
	settingsViewController.outlineDelegate = self;
	
	self.settingsPopover.contentViewController = settingsViewController;
	self.settingsPopover.behavior = NSPopoverBehaviorTransient;
	[self.settingsPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMinY];
}

- (void)popoverDidClose:(NSNotification *)notification {
	self.settingsPopover = nil;
}


#pragma mark - Filtering

- (void)filterOutline
{
	// We don't need to GET outline at this point, let's use the cached one
	[_filteredOutline removeAllObjects];
	if (!_filters.activeFilters) return;
	
	if (_filters.character.length > 0) {
		[_filters byCharacter:self.filters.character];
	} else {
		[_filters resetScenes];
	}

	NSLog(@"OUTLINE: %@", self.editorDelegate.outline);
	
	for (OutlineScene* scene in self.editorDelegate.outline) {
		if ([_filters match:scene]) [_filteredOutline addObject:scene];
	}	
}

#pragma mark - Advanced Filtering

- (IBAction)toggleFilterView:(id)sender
{
	NSButton *button = (NSButton*)sender;
	
	if (button.state == NSControlStateValueOn) {
		self.filterView.hidden = false;
		[self.filterViewHeight setConstant:80.0];
		[self.editorDelegate.autocompletion collectCharacterNames];
	} else {
		self.filterView.hidden = true;
		[_filterViewHeight setConstant:0.0];
	}
}
- (void)hideFilterView
{
	[_filterViewHeight setConstant:0.0];
}

- (IBAction)toggleColorFilter:(id)sender
{
	ColorCheckbox *button = (ColorCheckbox*)sender;
	
	if (button.state == NSControlStateValueOn) {
		// Apply color filter
		[_filters addColorFilter:button.colorName];
	} else {
		[_filters removeColorFilter:button.colorName];
	}
	
	// Hide / show button to reset filters
	if (_filters.colors.count > 0) [_resetColorFilterButton setHidden:NO]; else [_resetColorFilterButton setHidden:YES];
	
	// Reload outline and set visual masks to apply the filter
	[self reloadOutline];
}

- (IBAction)resetColorFilters:(id)sender
{
	[_filters.colors removeAllObjects];
	
	// Read more about this (and my political views) in the property declarations
	[_redCheck setState:NSControlStateValueOff];
	[_blueCheck setState:NSControlStateValueOff];
	[_greenCheck setState:NSControlStateValueOff];
	[_orangeCheck setState:NSControlStateValueOff];
	[_cyanCheck setState:NSControlStateValueOff];
	[_brownCheck setState:NSControlStateValueOff];
	[_magentaCheck setState:NSControlStateValueOff];
	[_pinkCheck setState:NSControlStateValueOff];
	
	// Reload outline & reset masks
	[self reloadOutline];
	
	// Hide the button
	[_resetColorFilterButton setHidden:YES];
}

- (IBAction)filterByCharacter:(id)sender
{
	NSString *characterName = _characterBox.selectedItem.title;
	
	if ([characterName isEqualToString:@" "] || characterName.length == 0) {
		[self resetCharacterFilter:nil];
		return;
	}
	[_filters byCharacter:characterName];
	
	// Reload outline and set visual masks to apply the filter
	[self reloadOutline];
	
	// Show the button to reset character filter
	[_resetCharacterFilterButton setHidden:NO];
}

- (IBAction)resetCharacterFilter:(id)sender
{
	[_filters resetScenes];
	_filters.character = @"";
	
	[self reloadOutline];
	
	// Hide the button to reset filter
	[_resetCharacterFilterButton setHidden:YES];
	
	// Select the first item (hopefully it exists by now)
	[_characterBox selectItem:[_characterBox.itemArray objectAtIndex:0]];
}


- (IBAction)expandAll:(id)sender
{
	for (OutlineScene *scene in self.editorDelegate.outline) {
		if ([self isExpandable:scene]) [self expandItem:scene expandChildren:YES];
	}
}

- (IBAction)collapseAll:(id)sender
{
	for (OutlineScene *scene in self.editorDelegate.outline) {
		if ([self isExpandable:scene]) [self collapseItem:scene collapseChildren:YES];
	}
}

-(void)expandItemWithoutAnimation:(id)item expandChildren:(BOOL)expandChildren {
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.0];
	
	[super expandItem:item expandChildren:expandChildren];
	
	[NSAnimationContext endGrouping];
}

#pragma mark - Search outline

- (void)searchOutline
{
	// This should probably be moved to BeatOutlineView, too.
	// Don't search if it's only spaces
	if (_outlineSearchField.stringValue.containsOnlyWhitespace ||
		_outlineSearchField.stringValue.length < 1) {
		[self.filters byText:@""];
	}
	
	[self.filters byText:_outlineSearchField.stringValue];
	[self reloadOutline];
}


#pragma mark - Menus

- (void)menuWillOpen:(NSMenu *)menu
{
	if (menu == self.characterBox.menu) [self characterMenuDidOpen:menu];
	else if (menu == self.menu) [self outlineMenuDidOpen:menu];
}

- (void)outlineMenuDidOpen:(NSMenu*)menu
{
	// Ensure menu items are correctly hooked (no idea)
	for (NSMenuItem* item in menu.itemArray) item.target = self;
}

- (void)characterMenuDidOpen:(NSMenu*)menu
{
	// Get previously selected character
	NSString* selected = self.characterBox.selectedItem.title;
	
	[menu removeAllItems];
	
	// Add an empty item at the beginning
	[self.characterBox addItemWithTitle:@" "];
	
	// Let's collect character names
	[self.editorDelegate.autocompletion collectCharacterNames];
	
	NSArray* names = self.editorDelegate.autocompletion.characterNames;
	for (NSString* name in names) {
		if (name.length == 0) continue;
		
		[self.characterBox addItemWithTitle:name.uppercaseString];
	}
	
	if (selected.length) {
		for (NSMenuItem* item in self.characterBox.itemArray) {
			if ([item.title isEqualToString:selected]) {
				[self.characterBox selectItem:item];
				break;
			}
		}
	}
}

#pragma mark - Actions

- (IBAction)addSection:(id)sender
{
	if (self.clickedRow == -1 || self.clickedRow == NSNotFound) return;
	
	OutlineScene *scene = [self itemAtRow:self.clickedRow];
	if (scene != nil) {
		NSInteger pos = scene.position + scene.length;
		[self.editorDelegate.textActions addSection:pos];
	}
}

- (IBAction)setSceneColor:(id)sender
{
	if (self.clickedRow == -1 || self.clickedRow == NSNotFound) return;
	
	BeatColorMenuItem *item = sender;	
	OutlineScene* selectedScene = [self itemAtRow:self.clickedRow];
	if (selectedScene != nil) [self.editorDelegate.textActions setColor:item.colorKey forScene:selectedScene];
}

#pragma mark - Mouse tracking

- (void)mouseMoved:(NSEvent *)event {
	[super mouseMoved:event];
	CGPoint point = [self convertPoint:event.locationInWindow fromView:self.window.contentView];
	
	NSInteger row = [self rowAtPoint:point];
	
	for (NSInteger i=0; i<self.numberOfRows; i++) {
		BeatSceneSnapshotCell* cellView = [self viewAtColumn:0 row:i makeIfNecessary:NO];
		if (i != row) [cellView closePopover];
	}
	
}

- (void)closeSnapshots
{
	for (id view in self.visibleSnapshots) {
		BeatSceneSnapshotCell* snapshot = view;
		[snapshot closePopover];
	}
	self.visibleSnapshots = @[];
}

- (void)addSnapshot:(NSTableCellView *)view
{
	if (self.visibleSnapshots == nil) self.visibleSnapshots = @[];
	self.visibleSnapshots = [self.visibleSnapshots arrayByAddingObject:view];
}

@end
/*
 
 synnyn uudestaan
 samaan kehoon
 uuteen aikaan
 
 */
