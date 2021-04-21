//
//  BeatOutlineView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 07/10/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

/*
 
 I'm in the process of moving all of the outline stuff here and out of the Document
 
 */

#import "BeatOutlineView.h"
#import "ThemeManager.h"
#import "SceneFiltering.h"
#import "OutlineViewItem.h"
#import "ColorCheckbox.h"

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

//    So, back to the code:

@property (weak) IBOutlet ColorCheckbox *redCheck;
@property (weak) IBOutlet ColorCheckbox *blueCheck;
@property (weak) IBOutlet ColorCheckbox *greenCheck;
@property (weak) IBOutlet ColorCheckbox *orangeCheck;
@property (weak) IBOutlet ColorCheckbox *cyanCheck;
@property (weak) IBOutlet ColorCheckbox *brownCheck;
@property (weak) IBOutlet ColorCheckbox *magentaCheck;
@property (weak) IBOutlet ColorCheckbox *pinkCheck;

@end

@implementation BeatOutlineView

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	return self;
}

-(void)awakeFromNib {
	self.delegate = self;
	self.dataSource = self;
	
	self.filters = [[SceneFiltering alloc] init];
	_filters.editorDelegate = self.editorDelegate;
	self.filteredOutline = [NSMutableArray array];
	
	[self registerForDraggedTypes:@[LOCAL_REORDER_PASTEBOARD_TYPE, OUTLINE_DATATYPE]];
	[self setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
}
- (void)drawBackgroundInClipRect:(NSRect)clipRect {
	//[super drawBackgroundInClipRect:clipRect];
	
	if (self.currentScene != NSNotFound) {
		NSRect rect = [self rectOfRow:self.currentScene];
		
		NSColor* fillColor = [[ThemeManager sharedManager] outlineHighlight];
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
	
	// Scroll back to original position after reload
	[self.enclosingScrollView.contentView scrollPoint:scrollPosition];
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

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item;
{
	// If we have a search term, let's use the filtered array
	if ([_filters activeFilters]) {
		return [_filteredOutline count];
	} else {
		return [[self.editorDelegate getOutlineItems] count];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	// If there is a search term, let's search the filtered array
	if (_filters.activeFilters) {
		return [_filteredOutline objectAtIndex:index];
	} else {
		return [[self.editorDelegate getOutlineItems] objectAtIndex:index];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return NO;
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
	
	if ([item isKindOfClass:[OutlineScene class]]) {
		[self.editorDelegate scrollToScene:item];
	}
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
	if ([_filters activeFilters]) return nil;
	
	OutlineScene *scene = (OutlineScene*)item;
	_draggedScene = scene;
	
	NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];
	[pboardItem setString:scene.string forType: NSPasteboardTypeString];
	return pboardItem;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id < NSDraggingInfo >)info proposedItem:(id)targetItem proposedChildIndex:(NSInteger)index{
	
	// Don't allow reordering a filtered list
	if ([_filters activeFilters]) return NSDragOperationNone;
	
	// Don't allow dropping INTO scenes
	OutlineScene *targetScene = (OutlineScene*)targetItem;
	if ([targetScene.string length] > 0 || index < 0) return NSDragOperationNone;
	
	return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id < NSDraggingInfo >)info item:(id)targetItem childIndex:(NSInteger)index{
	// Don't allow reordering a filtered list
	if ([_filteredOutline count] > 0 || [_outlineSearchField.stringValue length] > 0) return NSDragOperationNone;
	
	NSMutableArray *outline = [self.editorDelegate getOutlineItems];
	
	NSInteger to = index;
	NSInteger from = [outline indexOfObject:_draggedScene];
	
	if (from == to || from  == to - 1) return NO;
	
	// Let's move the scene
	self.editorDelegate.outlineEdit = YES;
	[self.editorDelegate moveScene:_draggedScene from:from to:to];
	self.editorDelegate.outlineEdit = NO;
	return YES;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	// For those who come after
	/*
	OutlineScene *outlineItem = item;
	if (outlineItem.type == section) {
		_outlineView.editing = YES;
		return YES;
	}
	else {
		_outlineView.editing = NO;
		return NO;
	}
	 */
	return NO;
}

- (void)scrollToScene:(OutlineScene*)scene {
	if (!scene) scene = self.editorDelegate.currentScene;
	
	// Check if we have filtering turned on, and do nothing if scene is not in the filter results
	if (self.filteredOutline.count) {
		if (![self.filteredOutline containsObject:scene]) return;
	}

	dispatch_async(dispatch_get_main_queue(), ^(void){
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
			context.allowsImplicitAnimation = YES;
			[self scrollRowToVisible:[self rowForItem:scene]];
		} completionHandler:NULL];
	});
}

#pragma mark - Filtering

- (void) filterOutline {
	// We don't need to GET outline at this point, let's use the cached one
	[_filteredOutline removeAllObjects];
	if (![_filters activeFilters]) return;
	
	if (_filters.character.length > 0) {
		//[_filters setScript:self.editorDelegate.lines scenes:self.editorDelegate.getOutlineItems];
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

	if ([characterName isEqualToString:@" "] || [characterName length] == 0) {
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


@end
/*
 
 synnyn uudestaan
 samaan kehoon
 uuteen aikaan
 
 */
