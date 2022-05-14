//
//  BeatOutlineView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 07/10/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 BeatOutlineView uses a temporary structure (BeatSceneTree + BeatSceneTreeItem)
 to handle the sections. Represented item is still always an OutlineScene.
 
 */

#import "BeatOutlineView.h"
#import "ThemeManager.h"
#import "SceneFiltering.h"
#import "OutlineViewItem.h"
#import "ColorCheckbox.h"
#import "BeatSceneTree.h"

#define LOCAL_REORDER_PASTEBOARD_TYPE @"LOCAL_REORDER_PASTEBOARD_TYPE"
#define OUTLINE_DATATYPE @"OutlineDatatype"

@interface BeatOutlineView ()

@property (weak) IBOutlet NSSearchField *outlineSearchField;

@property (weak) IBOutlet NSBox *filterView;
@property (weak) IBOutlet NSLayoutConstraint *filterViewHeight;
@property (weak) IBOutlet NSPopUpButton *characterBox;
@property (weak) IBOutlet NSButton *resetColorFilterButton;
@property (weak) IBOutlet NSButton *resetCharacterFilterButton;

@property (nonatomic) OutlineScene *draggedScene;
@property (nonatomic) bool outlineEdit;

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

//    So, back to the code:

@property (weak) IBOutlet ColorCheckbox *redCheck;
@property (weak) IBOutlet ColorCheckbox *blueCheck;
@property (weak) IBOutlet ColorCheckbox *greenCheck;
@property (weak) IBOutlet ColorCheckbox *orangeCheck;
@property (weak) IBOutlet ColorCheckbox *cyanCheck;
@property (weak) IBOutlet ColorCheckbox *brownCheck;
@property (weak) IBOutlet ColorCheckbox *magentaCheck;
@property (weak) IBOutlet ColorCheckbox *pinkCheck;

@property (nonatomic) BeatSceneTree *sceneTree;
@property (nonatomic) NSMutableArray *collapsed;

@end

@implementation BeatOutlineView

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	return self;
}

-(void)awakeFromNib {
	self.delegate = self;
	self.dataSource = self;
	
	self.filters = SceneFiltering.new;
	_filters.editorDelegate = self.editorDelegate;
	self.filteredOutline = [NSMutableArray array];
	
	[self registerForDraggedTypes:@[LOCAL_REORDER_PASTEBOARD_TYPE, OUTLINE_DATATYPE]];
	[self setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	
	[self hideFilterView];
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
}
- (void)drawBackgroundInClipRect:(NSRect)clipRect {
	//[super drawBackgroundInClipRect:clipRect];
	
	// Get current scene and represented row
	OutlineScene *currentScene = self.editorDelegate.currentScene;
	NSInteger row = [self rowForItem:currentScene];
	
	if (row != NSNotFound) {
		NSRect rect = [self rectOfRow:row];
		
		NSColor* fillColor = ThemeManager.sharedManager.outlineHighlight;
		[fillColor setFill];
		
		NSRectFill(rect);
	}
}

- (NSTouchBar*)makeTouchBar {
	return _touchBar;
}


#pragma mark - Reload data

-(void)reloadOutline {
	// Save outline scroll position
	NSPoint scrollPosition = self.enclosingScrollView.contentView.bounds.origin;
	
	[self filterOutline];
	[self reloadData];
	
	if (!_collapsed) _collapsed = NSMutableArray.new;
	
	for (OutlineScene *scene in self.outline) {
		// Sections are expanded by default
		if (![_collapsed containsObject:scene.line]) [self expandItem:scene expandChildren:YES];
	}
	
	// Scroll back to original position after reload
	[self.enclosingScrollView.contentView scrollPoint:scrollPosition];
}

-(void)outlineViewItemDidCollapse:(NSNotification *)notification {
	// We use lines rather than outline objects to keep track of collapsed an expanded sections
	OutlineScene *collapsedSection = [notification.userInfo valueForKey:@"NSObject"];
	[_collapsed addObject:collapsedSection.line];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification {
	OutlineScene *expandedSection = [notification.userInfo valueForKey:@"NSObject"];
	[_collapsed removeObject:expandedSection.line];
}


#pragma mark - Delegation


-(void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(nonnull id)cell forTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item {
	/*
	// For those who come after
	if (![item isKindOfClass:[OutlineScene class]]) return;
	
	OutlineScene *scene = item;
	if (scene.type == section) [cell setEditable:YES];
	*/
}

/*
- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
	NSMutableAttributedString *viewItem = [OutlineViewItem withScene:item currentScene:self.editorDelegate.currentScene];
	CGRect size = [viewItem boundingRectWithSize:CGSizeMake(self.frame.size.width, CGFLOAT_MAX) options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) context:nil];
	
	return size.size.height + 4;
}
 */

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item;
{
	// If we have a search term, let's use the filtered array
	if (_filters.activeFilters) {
		return _filteredOutline.count;
	} else {
		_sceneTree = [BeatSceneTree fromOutline:self.outline];
		
		if (!item) return _sceneTree.items.count;
		else {
			BeatSceneTreeItem *section = [_sceneTree itemWithScene:item];
			return section.children.count;
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
			return [_sceneTree sceneInSection:section index:index];
		} else {
			BeatSceneTreeItem *sceneItem = _sceneTree.items[index];
			return sceneItem.scene;
		}
	}
}

- (NSArray*)outline {
	NSArray *outline;
	if (!self.editorDelegate.parser.outline.count) outline = [self.editorDelegate getOutlineItems];
	else outline = self.editorDelegate.parser.outline;
	
	return outline;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (_filteredOutline.count > 0) return NO;
	
	OutlineScene *scene = item;
	if (scene.type == section) return YES;
	else return NO;
}

// Outline items
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([item isKindOfClass:[OutlineScene class]]) {
		// Note: OutlineViewItem returns an NSMutableAttributedString
		return [OutlineViewItem withScene:item currentScene:self.editorDelegate.currentScene];
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

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray *)draggedItems {
	//_draggedNodes = draggedItems;
	_editing = NO;
	[session.draggingPasteboard setData:[NSData data] forType:LOCAL_REORDER_PASTEBOARD_TYPE];
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	// ?
}

- (id <NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item{
	// Don't allow reordering a filtered list
	if (_filters.activeFilters) return nil;
	
	OutlineScene *scene = (OutlineScene*)item;
	_draggedScene = scene;
	
	NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];
	[pboardItem setString:scene.string forType: NSPasteboardTypeString];
	return pboardItem;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id < NSDraggingInfo >)info proposedItem:(id)targetItem proposedChildIndex:(NSInteger)index{
	// Don't allow reordering a filtered list
	if (_filters.activeFilters) return NSDragOperationNone;
	
	// Don't allow dropping into non-nested scenes
	OutlineScene *targetScene = (OutlineScene*)targetItem;
	if (targetScene.type == section) return NSDragOperationMove;
	else if (targetScene.string.length > 0 || index < 0) return NSDragOperationNone;
	
	return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id < NSDraggingInfo >)info item:(id)targetItem childIndex:(NSInteger)index{
	// Don't allow reordering a filtered list
	if (_filteredOutline.count > 0 || _outlineSearchField.stringValue.length > 0) return NSDragOperationNone;
	OutlineScene *scene;
	NSArray *outline = self.outline;
		
	if (index < [self numberOfChildrenOfItem:targetItem]) scene = [self outlineView:self child:index ofItem:targetItem];
	
	NSInteger to = index;
	NSInteger from = [outline indexOfObject:_draggedScene];
	NSInteger position; // Used for sections
	
	if (index == NSNotFound) {
		// Dropped directly into a section
		BeatSceneTreeItem *sceneTreeItem = [_sceneTree itemWithScene:targetItem];
		OutlineScene *lastInSection = sceneTreeItem.lastScene;
		position = lastInSection.position + lastInSection.length;
		
		to = [self.outline indexOfObject:lastInSection];
	} else {
		// Dropped normally
		if (scene) {
			to = [self.outline indexOfObject:scene];
			position = scene.position;
		}
		else {
			if (targetItem) {
				// Dropped at the end of a section
				BeatSceneTreeItem *sceneTreeItem = [_sceneTree itemWithScene:targetItem];
				to = [self.outline indexOfObject:sceneTreeItem.lastScene] + 1;
				position = sceneTreeItem.lastScene.position + sceneTreeItem.lastScene.length;
				
			} else {
				to = self.outline.count;
				position = self.editorDelegate.text.length;
			}
		}
	}
	
	if (from == to || from  == to - 1) return NO;
	
	// If it's a section, let's move everything it contains
	if (_draggedScene.type == section) {
		NSArray <OutlineScene*>*scenesInSection = [self.editorDelegate.parser scenesInSection:_draggedScene];
		
		NSInteger location = scenesInSection.firstObject.position;
		NSInteger length = scenesInSection.lastObject.position + scenesInSection.lastObject.length - location;
		NSRange sectionRange = (NSRange){ location, length };
				
		[self.editorDelegate moveStringFrom:sectionRange to:position actualString:[self.editorDelegate.text substringWithRange:sectionRange]];
		return YES;
	}
	
	// Move a single scene
	self.editorDelegate.outlineEdit = YES;
	[self.editorDelegate moveScene:_draggedScene from:from to:to];
	self.editorDelegate.outlineEdit = NO;
	return YES;
}

/*
-(BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	// For those who come after
	
	OutlineScene *outlineItem = item;
	if (outlineItem.type == section) {
		self.editing = YES;
		return YES;
	}
	else {
		self.editing = NO;
		return NO;
	}
}
 */

- (void)scrollToScene:(OutlineScene*)scene {
	if (!scene) scene = self.editorDelegate.currentScene;
	
	// Check if we have filtering turned on, and do nothing if scene is not in the filter results
	if (self.filteredOutline.count) {
		if (![self.filteredOutline containsObject:scene]) return;
	}
	
	// If the current scene is inside a section, show the section
	BeatSceneTreeItem *treeItem = [_sceneTree itemWithScene:scene];
	if (treeItem.parent) [self expandItem:treeItem.parent];

	dispatch_async(dispatch_get_main_queue(), ^(void){
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
			context.allowsImplicitAnimation = YES;
			[self scrollRowToVisible:[self rowForItem:scene]];
		} completionHandler:NULL];
	});
}

#pragma mark - Filtering

- (void)filterOutline {
	// We don't need to GET outline at this point, let's use the cached one
	[_filteredOutline removeAllObjects];
	if (!_filters.activeFilters) return;
	
	if (_filters.character.length > 0) {
		[_filters byCharacter:self.filters.character];
	} else {
		[_filters resetScenes];
	}

	//_filteredOutline = _filters.filteredScenes;

	for (OutlineScene * scene in self.editorDelegate.outline) {
		//NSLog(@"%@ - %@", scene.string, [_filters match:scene] ? @"YES" : @"NO");
		if ([_filters match:scene]) [_filteredOutline addObject:scene];
	}
}

#pragma mark - Advanced Filtering

- (IBAction)toggleFilterView:(id)sender {
	NSButton *button = (NSButton*)sender;
	
	if (button.state == NSControlStateValueOn) {
		[self.filterViewHeight setConstant:75.0];
	} else {
		[_filterViewHeight setConstant:0.0];
	}
}
- (void)hideFilterView {
	[_filterViewHeight setConstant:0.0];
}

- (IBAction)toggleColorFilter:(id)sender {
	ColorCheckbox *button = (ColorCheckbox*)sender;
		
	if (button.state == NSControlStateValueOn) {
		// Apply color filter
		[_filters addColorFilter:button.colorName];
	} else {
		[_filters removeColorFilter:button.colorName];
	}
	
	// Hide / show button to reset filters
	if ([_filters filterColor]) [_resetColorFilterButton setHidden:NO]; else [_resetColorFilterButton setHidden:YES];
	
	// Reload outline and set visual masks to apply the filter
	[self reloadOutline];
	[self.editorDelegate maskScenes];
}

- (IBAction)resetColorFilters:(id)sender {
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
	[self.editorDelegate maskScenes];
	
	// Hide the button
	[_resetColorFilterButton setHidden:YES];
}

- (IBAction)filterByCharacter:(id)sender {
	NSString *characterName = _characterBox.selectedItem.title;

	if ([characterName isEqualToString:@" "] || characterName.length == 0) {
		[self resetCharacterFilter:nil];
		return;
	}
	[_filters byCharacter:characterName];
	
	// Reload outline and set visual masks to apply the filter
	[self reloadOutline];
	[self.editorDelegate maskScenes];
	
	// Show the button to reset character filter
	[_resetCharacterFilterButton setHidden:NO];
}

- (IBAction)resetCharacterFilter:(id)sender {
	[_filters resetScenes];
	_filters.character = @"";
	
	[self reloadOutline];
	[self.editorDelegate maskScenes];
	
	// Hide the button to reset filter
	[_resetCharacterFilterButton setHidden:YES];
	
	// Select the first item (hopefully it exists by now)
	[_characterBox selectItem:[_characterBox.itemArray objectAtIndex:0]];
}


- (IBAction)expandAll:(id)sender {
	for (OutlineScene *scene in self.editorDelegate.outline) {
		if ([self isExpandable:scene]) [self expandItem:scene expandChildren:YES];
	}
}

- (IBAction)collapseAll:(id)sender {
	for (OutlineScene *scene in self.editorDelegate.outline) {
		if ([self isExpandable:scene]) [self collapseItem:scene collapseChildren:YES];
	}
}

@end
/*
 
 synnyn uudestaan
 samaan kehoon
 uuteen aikaan
 
 */
