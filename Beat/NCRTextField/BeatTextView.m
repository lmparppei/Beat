//
//	BeatTextView.m
//  Based on NCRAutocompleteTextView.m
//  Heavily modified for Beat
//
//  Copyright (c) 2014 Null Creature. All rights reserved.
//  Parts copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This NSTextView subclass is used to provide the additional editor features:
 - auto-completion (filled by methods from Document)
 - force line type (set in this class)
 - draw masks (array of masks provided by Document)
 - draw page breaks (array of breaks with y position provided by Document/FountainPaginator)
 
 Document acts as delegate, so some of its methods are accessible from this class too.
 This is a bit convoluted design, but works for now.
 
 Auto-completion function is based on NCRAutoCompleteTextView.
 
 */

#import <QuartzCore/QuartzCore.h>
#import "BeatTextView.h"
#import "DynamicColor.h"
#import "Line.h"
#import "ScrollView.h"
#import "ContinousFountainParser.h"
#import "FountainPaginator.h"
#import "BeatColors.h"
#import "ThemeManager.h"

#define DEFAULT_MAGNIFY 1.02
#define MAGNIFYLEVEL_KEY @"Magnifylevel"

// This helps to create some sense of easeness
#define MARGIN_CONSTANT 10
#define SHADOW_WIDTH 20
#define SHADOW_OPACITY 0.0125

// Maximum results for autocomplete
#define MAX_RESULTS 10

#define HIGHLIGHT_STROKE_COLOR [NSColor selectedMenuItemColor]
#define HIGHLIGHT_FILL_COLOR [NSColor selectedMenuItemColor]
#define HIGHLIGHT_RADIUS 0.0
#define INTERCELL_SPACING NSMakeSize(20.0, 3.0)

#define WORD_BOUNDARY_CHARS [NSCharacterSet newlineCharacterSet]
#define POPOVER_WIDTH 300.0
#define POPOVER_PADDING 0.0

#define POPOVER_APPEARANCE NSAppearanceNameVibrantDark

#define POPOVER_FONT [NSFont fontWithName:@"Courier Prime" size:12.0]
// The font for the characters that have already been typed
#define POPOVER_BOLDFONT [NSFont fontWithName:@"Courier Prime Bold" size:12.0]
#define POPOVER_TEXTCOLOR [NSColor whiteColor]

#define CARET_WIDTH 2

@interface NCRAutocompleteTableRowView : NSTableRowView
@end

#pragma mark - Draw autocomplete table
@implementation NCRAutocompleteTableRowView

- (void)drawSelectionInRect:(NSRect)dirtyRect {
	if (self.selectionHighlightStyle != NSTableViewSelectionHighlightStyleNone) {
		NSRect selectionRect = NSInsetRect(self.bounds, 0.5, 0.5);
		[HIGHLIGHT_STROKE_COLOR setStroke];
		[HIGHLIGHT_FILL_COLOR setFill];
		NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRoundedRect:selectionRect xRadius:HIGHLIGHT_RADIUS yRadius:HIGHLIGHT_RADIUS];
		[selectionPath fill];
		[selectionPath stroke];
	}
}
- (NSBackgroundStyle)interiorBackgroundStyle {
	if (self.isSelected) {
		return NSBackgroundStyleDark;
	} else {
		return NSBackgroundStyleLight;
	}
}
@end

static NSTouchBarItemIdentifier ColorPickerItemIdentifier = @"com.TouchBarCatalog.colorPicker";

#pragma mark - Autocompleting
@interface BeatTextView ()
@property (nonatomic, weak) IBOutlet NSTouchBar *touchBar;

@property (nonatomic, strong) NSPopover *taggingPopover;

@property (nonatomic, strong) NSPopover *infoPopover;
@property (nonatomic, strong) NSTextView *infoTextView;

@property (nonatomic, strong) NSPopover *autocompletePopover;
@property (nonatomic, weak) NSTableView *autocompleteTableView;
@property (nonatomic, strong) NSArray *matches;

@property (nonatomic) bool nightMode;
@property (nonatomic) bool forceElementMenu;

@property (nonatomic) BeatTextviewPopupMode popupMode;

// Used to highlight typed characters and insert text
@property (nonatomic, copy) NSString *substring;

// Used to keep track of when the insert cursor has moved so we
// can close the popover. See didChangeSelection:
@property (nonatomic, assign) NSInteger lastPos;

// New scene numbering system
@property (nonatomic) NSMutableArray *sceneNumberLabels;
@property (nonatomic) NSMutableArray *sectionBackgrounds;

// Text container tracking area
@property (nonatomic) NSTrackingArea *trackingArea;

// Section rects
@property NSMutableArray* sections;

// Page number fields
@property (nonatomic) NSMutableArray *pageNumberLabels;

// Scale factor
@property (nonatomic) CGFloat scaleFactor;

@end

@implementation BeatTextView

- (void)awakeFromNib {
	/*
	BeatLayoutManager *layoutManager = [[BeatLayoutManager alloc] init];
	[self.textContainer replaceLayoutManager:layoutManager];
	*/
	
	self.pageBreaks = [NSArray array];
	
	// Make a table view with 1 column and enclosing scroll view. It doesn't
	// matter what the frames are here because they are set when the popover
	// is displayed
	NSTableColumn *column1 = [[NSTableColumn alloc] initWithIdentifier:@"text"];
	[column1 setEditable:NO];
	[column1 setWidth:POPOVER_WIDTH - 2 * POPOVER_PADDING];
	
	NSTableView *tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
	[tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
	[tableView setBackgroundColor:[NSColor clearColor]];
	[tableView setRowSizeStyle:NSTableViewRowSizeStyleSmall];
	[tableView setIntercellSpacing:INTERCELL_SPACING];
	[tableView setHeaderView:nil];
	[tableView setRefusesFirstResponder:YES];
	[tableView setTarget:self];
	[tableView setDoubleAction:@selector(clickPopupItem:)];
	[tableView addTableColumn:column1];
	[tableView setDelegate:self];
	[tableView setDataSource:self];
	self.autocompleteTableView = tableView;
	
	NSScrollView *tableScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	[tableScrollView setDrawsBackground:NO];
	[tableScrollView setDocumentView:tableView];
	[tableScrollView setHasVerticalScroller:YES];
	
	NSView *contentView = [[NSView alloc] initWithFrame:NSZeroRect];
	[contentView addSubview:tableScrollView];
	
	NSViewController *contentViewController = [[NSViewController alloc] init];
	[contentViewController setView:contentView];;
	
	// Autocomplete popover
	self.autocompletePopover = [[NSPopover alloc] init];
	self.autocompletePopover.appearance = [NSAppearance appearanceNamed:POPOVER_APPEARANCE];
	
	self.autocompletePopover.animates = NO;
	self.autocompletePopover.contentViewController = contentViewController;
	
	// Info popover
	self.infoPopover = [[NSPopover alloc] init];

	self.matches = [NSMutableArray array];
	NSView *infoContentView = [[NSView alloc] initWithFrame:NSZeroRect];
	_infoTextView = [[NSTextView alloc] initWithFrame:NSZeroRect];
	[_infoTextView setEditable:NO];
	[_infoTextView setDrawsBackground:NO];
	[_infoTextView setRichText:NO];
	[_infoTextView setUsesRuler:NO];
	[_infoTextView setSelectable:NO];
	[_infoTextView setTextContainerInset:NSMakeSize(8, 8)];
	
	[infoContentView addSubview:_infoTextView];
	NSViewController *infoViewController = [[NSViewController alloc] init];
	[infoViewController setView:infoContentView];;

	self.infoPopover.contentViewController = infoViewController;

	self.lastPos = -1;
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeSelection:) name:@"NSTextViewDidChangeSelectionNotification" object:nil];
	
	// Arrays for special elements
	self.masks = [NSMutableArray array];
	self.sections = [NSMutableArray array];
	
	_trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];
	[self.window setAcceptsMouseMovedEvents:YES];
	[self addTrackingArea:_trackingArea];
	
	[self setInsets];
}
-(void)removeFromSuperview {
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[super removeFromSuperview];
}

- (void)closePopovers {
	[_infoPopover close];
	[_autocompletePopover close];
	_forceElementMenu = NO;
	
	_popupMode = NoPopup;
}

- (IBAction)showInfo:(id)sender {
	bool wholeDocument = NO;
	NSRange range;
	if (self.selectedRange.length == 0) {
		wholeDocument = YES;
		range = NSMakeRange(0, self.string.length);
	} else {
		range = self.selectedRange;
	}
		
	NSInteger words = 0;
	NSArray *lines = [[self.string substringWithRange:range] componentsSeparatedByString:@"\n"];
	NSInteger symbols = [[self.string substringWithRange:range] length];
	
	for (NSString *line in lines) {
		for (NSString *word in [line componentsSeparatedByString:@" "]) {
			if (word.length > 0) words += 1;
		}
		
	}
	[_infoTextView setString:@""];
	[_infoTextView.layoutManager ensureLayoutForTextContainer:_infoTextView.textContainer];
	
	NSString *infoString = [NSString stringWithFormat:@"Words: %lu\nCharacters: %lu", words, symbols];

	// Get number of pages / page number for selection
	if (wholeDocument) {
		NSInteger pages = [self numberOfPages];
		if (pages > 0) infoString = [infoString stringByAppendingFormat:@"\nPages: %lu", pages];
	} else {
		NSInteger page = [self getPageNumber:self.selectedRange.location];
		if (page > 0) infoString = [infoString stringByAppendingFormat:@"\nPage: %lu", page];
	}
	
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
	[attributes setObject:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]] forKey:NSFontAttributeName];
	
	
	if (wholeDocument) infoString = [NSString stringWithFormat:@"Document\n%@", infoString];
	else infoString = [NSString stringWithFormat:@"Selection\n%@", infoString];
	_infoTextView.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	_infoTextView.string = infoString;
	[_infoTextView.textStorage addAttributes:attributes range:NSMakeRange(0, [infoString rangeOfString:@"\n"].location)];
		
	[_infoTextView.layoutManager ensureLayoutForTextContainer:_infoTextView.textContainer];
	NSRect result = [_infoTextView.layoutManager usedRectForTextContainer:_infoTextView.textContainer];
	
	NSRect frame = NSMakeRect(0, 0, 200, result.size.height + 16);
	[self.infoPopover setContentSize:NSMakeSize(NSWidth(frame), NSHeight(frame))];
	[self.infoTextView setFrame:NSMakeRect(0, 0, NSWidth(frame), NSHeight(frame))];
	
	self.substring = [self.string substringWithRange:NSMakeRange(range.location, 0)];
	
	NSRect rect;
	if (!wholeDocument) {
		rect = [self firstRectForCharacterRange:NSMakeRange(range.location, 0) actualRange:NULL];
	} else {
		rect = [self firstRectForCharacterRange:NSMakeRange(self.selectedRange.location, 0) actualRange:NULL];
	}
	rect = [self.window convertRectFromScreen:rect];
	rect = [self convertRect:rect fromView:nil];
	rect.size.width = 5;
	
	[self.infoPopover showRelativeToRect:rect ofView:self preferredEdge:NSMaxYEdge];
	[self.window makeFirstResponder:self];
}

- (void)mouseDown:(NSEvent *)event {
	[self closePopovers];
	[super mouseDown:event];
}

- (NSTouchBar*)makeTouchBar {
	[NSApp setAutomaticCustomizeTouchBarMenuItemEnabled:NO];
	
	if (@available(macOS 10.15, *)) {
		NSTouchBar.automaticCustomizeTouchBarMenuItemEnabled = NO;
	}
	
	return _touchBar;
}
- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:ColorPickerItemIdentifier]) {
		// What?
	}
	return nil;
}

- (void)keyDown:(NSEvent *)theEvent {
	NSInteger row = self.autocompleteTableView.selectedRow;
	BOOL shouldComplete = YES;
	
	switch (theEvent.keyCode) {
		case 51:
			// Delete
			[self closePopovers];
			shouldComplete = NO;
			
			break;
		case 53:
			// Esc
			if (self.autocompletePopover.isShown || self.infoPopover.isShown) [self closePopovers];
		
			return; // Skip default behavior
		case 125:
			// Down
			if (row + 1 >= self.autocompleteTableView.numberOfRows) row = -1;
			
			if (self.autocompletePopover.isShown) {
				[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
				[self.autocompleteTableView scrollRowToVisible:self.autocompleteTableView.selectedRow];
				return; // Skip default behavior
			}
			break;
		case 126:
			// Up
			if (self.autocompletePopover.isShown) {
				if (row - 1 < 0) row = self.autocompleteTableView.numberOfRows;
				
				[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row-1] byExtendingSelection:NO];
				[self.autocompleteTableView scrollRowToVisible:self.autocompleteTableView.selectedRow];
				return; // Skip default behavior
			}
			break;
		case 48:
			// Tab
			if (_forceElementMenu || _popupMode == ForceElement) {
				// force element + skip default
				[self force:self];
				return;
				
			} else if (_popupMode == Tagging) {
				// handle tagging + skip default
				return;
				
			} else if (self.autocompletePopover.isShown && _popupMode == Autocomplete) {
				[self insert:self];
				return; // don't insert a line-break after tab key
				
			} else {
				// Call delegate to handle normal tab press
				if ([self.delegate respondsToSelector:@selector(handleTabPress)]) {
					[(id)self.delegate handleTabPress];
					return; // skip default
				}
			}
			break;
		case 36:
			// HANDLE RETURN
			if (self.autocompletePopover.isShown) {
				// Check whether to force an element or to just autocomplete
				if (_forceElementMenu || _popupMode == ForceElement) {
					[self force:self];
					return; // skip default
				} else if (_popupMode == Tagging) {
					[self setTag:self];
					return;
				} else if (self.autocompletePopover.isShown) {
					[self insert:self];
				}
			}
			else if (theEvent.modifierFlags) {
				NSUInteger flags = [theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
				
				// Alt was pressed && autocomplete is not visible
				if (flags == NSEventModifierFlagOption && !self.autocompletePopover.isShown) {
					_forceElementMenu = YES;
					_popupMode = ForceElement;
					
					self.automaticTextCompletionEnabled = YES;

					[self forceElement:self];
					return; // Skip defaut behavior
				}
			}
	}
	
	if (self.infoPopover.isShown) [self closePopovers];
	
	[super keyDown:theEvent];
	
	if (shouldComplete && self.popupMode != Tagging) {
		if (self.automaticTextCompletionEnabled) {
			[self complete:self];
		}
	}
}

// Phantom methods
- (void)handleTabPress { }

- (void)clickPopupItem:(id)sender {
	if (_popupMode == Autocomplete)	[self insert:sender];
	if (_popupMode == Tagging) [self setTag:sender];
	else [self closePopovers];
}


// Beat customization
- (IBAction)toggleDarkPopup:(id)sender {
	/*
	 // Nah. Saved for later use.
	 
	_nightMode = !_nightMode;
	
	if (_nightMode) {
		self.autocompletePopover.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantDark];
	} else {
		self.autocompletePopover.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantLight];
	}
	 */
}

- (NSInteger)getPageNumber:(NSInteger)location {
	if ([self.delegate respondsToSelector:@selector(getPageNumber:)]) {
		return [(id)self.delegate getPageNumber:location];
	}
	return 0;
}
- (NSInteger)numberOfPages {
	if ([self.delegate respondsToSelector:@selector(numberOfPages)]) {
		return [(id)self.delegate numberOfPages];
	}
	return 0;
}

- (void)insert:(id)sender {
	if (self.popupMode != Autocomplete) return;
	
	if (self.autocompleteTableView.selectedRow >= 0 && self.autocompleteTableView.selectedRow < self.matches.count) {
		NSString *string = [self.matches objectAtIndex:self.autocompleteTableView.selectedRow];
		
		NSInteger beginningOfWord;
		
		Line* currentLine = _editorDelegate.getCurrentLine;
		if (currentLine) {
			NSInteger locationInString = self.selectedRange.location - currentLine.position;
			beginningOfWord = self.selectedRange.location - locationInString;
		} else {
			beginningOfWord = self.selectedRange.location - self.substring.length;
		}
				
		NSRange range = NSMakeRange(beginningOfWord, self.substring.length);
		
		if ([self shouldChangeTextInRange:range replacementString:string]) {
			[self replaceCharactersInRange:range withString:string];
			[self didChangeText];
			[self setAutomaticTextCompletionEnabled:NO];
		}
	}
	[self.autocompletePopover close];
}

- (void)didChangeSelection:(NSNotification *)notification {
	if ((self.selectedRange.location - self.lastPos) > 1) {
		// If selection moves by more than just one character, hide autocomplete
		if (self.autocompletePopover.shown) [self setAutomaticTextCompletionEnabled:NO];
		[self.autocompletePopover close];
	}
	
	if (self.editorDelegate.mode == TaggingMode) {
		[self showTaggingOptions];
	}
}

#pragma mark - Tagging / Force Element menu

- (void)showTaggingOptions {
	NSString *selectedString = [self.string substringWithRange:self.selectedRange];
	
	// Don't allow line breaks in tagged content. Limit the selection if break is found.
	if ([selectedString rangeOfString:@"\n"].location != NSNotFound) {
		[self setSelectedRange:(NSRange){ self.selectedRange.location,  [selectedString rangeOfString:@"\n"].location }];
	}
	
	if (self.selectedRange.length < 1) return;
	
	_popupMode = Tagging;
	[self showPopupWithItems:BeatTagging.styledTags];
}

- (void)forceElement:(id)sender {
	_popupMode = ForceElement;
	[self showPopupWithItems:@[@"Action", @"Scene Heading", @"Character", @"Lyrics"]];
}

- (void)showPopupWithItems:(NSArray*)items {
	NSInteger location = self.selectedRange.location;
	
	self.matches = items;
	[self.autocompleteTableView reloadData];
	
	NSInteger index = 0;
	[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	[self.autocompleteTableView scrollRowToVisible:index];
	
	NSInteger numberOfRows = MIN(self.autocompleteTableView.numberOfRows, MAX_RESULTS);
	
	CGFloat height = (self.autocompleteTableView.rowHeight + self.autocompleteTableView.intercellSpacing.height) * numberOfRows + 2 * POPOVER_PADDING;
	NSRect frame = NSMakeRect(0, 0, POPOVER_WIDTH, height);
	[self.autocompleteTableView.enclosingScrollView setFrame:NSInsetRect(frame, POPOVER_PADDING, POPOVER_PADDING)];
	[self.autocompletePopover setContentSize:NSMakeSize(NSWidth(frame), NSHeight(frame))];
	
	self.substring = [self.string substringWithRange:NSMakeRange(location, 0)];
	
	NSRect rect = [self firstRectForCharacterRange:NSMakeRange(location, 0) actualRange:NULL];
	rect = [self.window convertRectFromScreen:rect];
	rect = [self convertRect:rect fromView:nil];
	
	rect.size.width = 5;
	
	[self.autocompletePopover showRelativeToRect:rect ofView:self preferredEdge:NSMaxYEdge];
}

- (void)force:(id)sender {
	if (self.autocompleteTableView.selectedRow >= 0 && self.autocompleteTableView.selectedRow < self.matches.count) {
		if ([self.delegate respondsToSelector:@selector(forceElement:)]) {
			[(id)self.delegate forceElement:[self.matches objectAtIndex:self.autocompleteTableView.selectedRow]];
		}
	}
	[self.autocompletePopover close];
	_forceElementMenu = NO;
	_popupMode = NoPopup;
}

- (void)setTag:(id)sender {
	id tag = [self.matches objectAtIndex:self.autocompleteTableView.selectedRow];
	
	NSString *tagStr;
	if ([tag isKindOfClass:NSAttributedString.class]) tagStr = [(NSAttributedString*)tag string];
	else tagStr = tag;
	
	// Tag string in the menu is prefixed by "● " or "× " so take them it out
	tagStr = [tagStr stringByReplacingOccurrencesOfString:@"× " withString:@""];
	tagStr = [tagStr stringByReplacingOccurrencesOfString:@"● " withString:@""];
	
	[self.taggingDelegate tagRange:self.selectedRange withType:[BeatTagging tagFor:tagStr]];
	
	// Deselect
	self.selectedRange = (NSRange){ self.selectedRange.location + self.selectedRange.length, 0 };
	
	[self.autocompletePopover close];
	_popupMode = NoPopup;
}

#pragma mark - Autocomplete & data source

- (void)complete:(id)sender {
	NSInteger startOfWord = self.selectedRange.location;
	for (NSInteger i = startOfWord - 1; i >= 0; i--) {
		if ([WORD_BOUNDARY_CHARS characterIsMember:[self.string characterAtIndex:i]]) {
			break;
		} else {
			startOfWord--;
		}
	}
	
	NSInteger lengthOfWord = 0;
	for (NSInteger i = startOfWord; i < self.string.length; i++) {
		if ([WORD_BOUNDARY_CHARS characterIsMember:[self.string characterAtIndex:i]]) {
			break;
		} else {
			lengthOfWord++;
		}
	}
	
	self.substring = [self.string substringWithRange:NSMakeRange(startOfWord, lengthOfWord)];
	NSRange substringRange = NSMakeRange(startOfWord, self.selectedRange.location - startOfWord);
	
	if (substringRange.length == 0 || lengthOfWord == 0) {
		// This happens when we just started a new word or if we have already typed the entire word
		[self.autocompletePopover close];
		return;
	}
	
	NSInteger index = 0;
	self.matches = [self completionsForPartialWordRange:substringRange indexOfSelectedItem:&index];
	
	if (self.matches.count > 0) {

		// Beat customization: if we have only one possible match and it's the same the user has already typed, close it
		if (self.matches.count == 1) {
			NSString *match = [self.matches objectAtIndex:0];
			if ([match localizedCaseInsensitiveCompare:self.substring] == NSOrderedSame) {
				[self.autocompletePopover close];
				return;
			}
		}
		
		self.lastPos = self.selectedRange.location;
		[self.autocompleteTableView reloadData];
		
		[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[self.autocompleteTableView scrollRowToVisible:index];
		
		// Make the frame for the popover. We want it to shrink with a small number
		// of items to autocomplete but never grow above a certain limit when there
		// are a lot of items. The limit is set by MAX_RESULTS.
		NSInteger numberOfRows = MIN(self.autocompleteTableView.numberOfRows, MAX_RESULTS);
		CGFloat height = (self.autocompleteTableView.rowHeight + self.autocompleteTableView.intercellSpacing.height) * numberOfRows + 2 * POPOVER_PADDING;
		NSRect frame = NSMakeRect(0, 0, POPOVER_WIDTH, height);
		[self.autocompleteTableView.enclosingScrollView setFrame:NSInsetRect(frame, POPOVER_PADDING, POPOVER_PADDING)];
		[self.autocompletePopover setContentSize:NSMakeSize(NSWidth(frame), NSHeight(frame))];
		
		// We want to find the middle of the first character to show the popover.
		// firstRectForCharacterRange: will give us the rect at the begeinning of
		// the word, and then we need to find the half-width of the first character
		// to add to it.
		NSRect rect = [self firstRectForCharacterRange:substringRange actualRange:NULL];
		rect = [self.window convertRectFromScreen:rect];
		rect = [self convertRect:rect fromView:nil];
		NSString *firstChar = [self.substring substringToIndex:1];
		NSSize firstCharSize = [firstChar sizeWithAttributes:@{NSFontAttributeName:self.font}];
		rect.size.width = firstCharSize.width;
		
		_popupMode = Autocomplete;
		[self.autocompletePopover showRelativeToRect:rect ofView:self preferredEdge:NSMaxYEdge];
	
	} else {
		[self.autocompletePopover close];
	}
}
- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	if ([self.delegate respondsToSelector:@selector(textView:completions:forPartialWordRange:indexOfSelectedItem:)]) {
		return [self.delegate textView:self completions:@[] forPartialWordRange:charRange indexOfSelectedItem:index];
	}
	return @[];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.matches.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"MyView" owner:self];
	if (cellView == nil) {
		cellView = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
		[textField setBezeled:NO];
		[textField setDrawsBackground:NO];
		[textField setEditable:NO];
		[textField setSelectable:NO];
		[cellView addSubview:textField];
		cellView.textField = textField;
		if ([self.delegate respondsToSelector:@selector(textView:imageForCompletion:)]) {
			NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
			[imageView setImageFrameStyle:NSImageFrameNone];
			[imageView setImageScaling:NSImageScaleNone];
			[cellView addSubview:imageView];
			cellView.imageView = imageView;
		}
		cellView.identifier = @"MyView";
	}
	
	
	NSMutableAttributedString *as;
	id label = self.matches[row];
	
	// If the row item is an attributed string, handle the previous attributes
	if ([label isKindOfClass:NSAttributedString.class]) {
		as = [[NSMutableAttributedString alloc] initWithAttributedString:(NSAttributedString*)label];
		[as addAttribute:NSFontAttributeName value:POPOVER_FONT range:NSMakeRange(0, as.string.length)];
	} else {
		as = [[NSMutableAttributedString alloc] initWithString:(NSString*)label attributes:@{NSFontAttributeName:POPOVER_FONT, NSForegroundColorAttributeName:POPOVER_TEXTCOLOR}];
	}
	
	if (self.substring) {
		NSRange range = [as.string rangeOfString:self.substring options:NSAnchoredSearch|NSCaseInsensitiveSearch];
		[as addAttribute:NSFontAttributeName value:POPOVER_BOLDFONT range:range];
	}
	
	[cellView.textField setAttributedStringValue:as];
	
	if ([self.delegate respondsToSelector:@selector(textView:imageForCompletion:)]) {
		//NSImage *image = [self.delegate textView:self imageForCompletion:self.matches[row]];
		//[cellView.imageView setImage:image];
	}
	
	return cellView;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
	return [[NCRAutocompleteTableRowView alloc] init];
}

#pragma mark - Rects for masking, page breaks etc.

- (NSRect)rectForRange:(NSRange)range {
	NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:nil];
	return [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
}

- (NSArray*)rectsForChanges {
	NSMutableArray *rects = [NSMutableArray array];

	[self.editorDelegate.changes enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRect rect = [self rectForRange:range];
		NSRect highlight = NSMakeRect(self.textContainerInset.width - 20, self.textContainerInset.height + rect.origin.y, 2, rect.size.height);
		[rects addObject:[NSValue valueWithRect:highlight]];
	}];
		
	return rects;
}

-(void)resizeWithOldSuperviewSize:(NSSize)oldSize {
	[super resizeWithOldSuperviewSize:oldSize];
}
-(void)viewDidEndLiveResize {
	//[super viewDidEndLiveResize];
	[self setInsets];
}
- (BOOL)needsToDrawRect:(NSRect)rect {
	return [super needsToDrawRect:rect];
}

-(void)drawViewBackgroundInRect:(NSRect)rect {
	// We need to draw the background to avoid certain graphical glitches.
	if (!NSGraphicsContext.currentContext) return;
	
	CGFloat height = self.frame.size.height * (1 / _zoomLevel);
	
	// Draw paper
	[self.editorDelegate.themeManager.backgroundColor setFill];
	
	NSRectFill(rect);
	
	CGFloat width = (self.enclosingScrollView.frame.size.width / 2 - _documentWidth * self.editorDelegate.magnification / 2) / self.editorDelegate.magnification - 120;
	
	NSColor *marginColor = self.editorDelegate.themeManager.marginColor;
	[marginColor setFill];
	NSRect marginLeft = (NSRect){ 0, 0, width, height };
	NSRect marginRight = (NSRect){ width + _documentWidth + 240, 0, width, height };
	
	NSRectFill(marginLeft);
	NSRectFill(marginRight);
	
	NSRect shadowLeft = (NSRect){ marginLeft.size.width - SHADOW_WIDTH, 0, SHADOW_WIDTH, marginLeft.size.height };
	NSRect shadowRight = (NSRect){ marginRight.origin.x, 0, SHADOW_WIDTH, marginRight.size.height };
	
	NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:NSColor.clearColor endingColor:[NSColor.blackColor colorWithAlphaComponent:SHADOW_OPACITY]];
	[gradient drawInRect:shadowLeft angle:0];
	[gradient drawInRect:shadowRight angle:180];
	
	CGFloat factor = 1 / _zoomLevel;
	
	// Section header backgrounds
	for (NSValue* value in _sections) {
		[self.marginColor setFill];
		NSRect sectionRect = [value rectValue];
		CGFloat width = self.frame.size.width * factor;

		NSRect rect = NSMakeRect(0, self.textContainerInset.height + sectionRect.origin.y - 7, width, sectionRect.size.height + 14);
		NSRectFill(rect);
		//if (self.editorDelegate.isDark) NSRectFillUsingOperation(rect, NSCompositingOperationScreen);
		//else NSRectFillUsingOperation(rect, NSCompositingOperationDarken);
		
	}
	
}
- (void)drawRect:(NSRect)dirtyRect {
	//NSLog(@"drawing %f -> %f     (in view: %f / %f)    mag: %f", dirtyRect.origin.y, dirtyRect.size.height, self.enclosingScrollView.contentView.bounds.origin.y, self.enclosingScrollView.contentView.bounds.size.height, self.zoomLevel);
	//dirtyRect = (NSRect){ dirtyRect.origin.x, dirtyRect.origin.y - 10, dirtyRect.size.width, dirtyRect.size.height + 20 };
 		
	[NSGraphicsContext saveGraphicsState];
	[super drawRect:dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
	
	// An array of NSRanges which are used to mask parts of the text.
	// Used to hide irrelevant parts when filtering scenes.
	if (_masks.count) {
		for (NSValue * value in _masks) {
			NSColor* fillColor = self.editorDelegate.themeManager.backgroundColor;
			fillColor = [fillColor colorWithAlphaComponent:0.85];
			[fillColor setFill];
			
			NSRect rect = [self.layoutManager boundingRectForGlyphRange:value.rangeValue inTextContainer:self.textContainer];
			rect.origin.x = self.textContainerInset.width;
			// You say: never hardcode a value, but YOU DON'T KNOW ME, DO YOU!!!
			rect.origin.y += self.textContainerInset.height - 12;
			rect.size.width = self.textContainer.size.width;
			
			//NSRectFill(rect);
			NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
		}
	}
}


- (void)drawInsertionPointInRect:(NSRect)aRect color:(NSColor *)aColor turnedOn:(BOOL)flag {
	aRect.size.width = CARET_WIDTH;
	[super drawInsertionPointInRect:aRect color:aColor turnedOn:flag];
}
 
- (void)setNeedsDisplayInRect:(NSRect)invalidRect {
	invalidRect = NSMakeRect(invalidRect.origin.x, invalidRect.origin.y, invalidRect.size.width + CARET_WIDTH - 1, invalidRect.size.height);
	[super setNeedsDisplayInRect:invalidRect];
}

-(void)viewDidChangeEffectiveAppearance {
	[self drawViewBackgroundInRect:self.bounds];
	[self drawRect:self.bounds];
}
-(void)redrawUI {
	[self scaleUnitSquareToSize:(NSSize){1.0, 1.0}];
	[self displayRect:self.frame];
	[self.layoutManager ensureLayoutForTextContainer:self.textContainer];
}

#pragma mark - Scene & page numbering

- (void)resetPageNumberLabels {
	for (NSInteger i = 0; i < _pageNumberLabels.count; i++) {
		NSTextField *label = _pageNumberLabels[i];
		[label removeFromSuperview];
	}
	[_pageNumberLabels removeAllObjects];
}

- (void)deletePageNumbers {
	for (NSTextField * label in _pageNumberLabels) {
		[label removeFromSuperview];
	}
	[_pageNumberLabels removeAllObjects];
}

- (void)updatePageNumbers {
	[self updatePageNumbers:nil];
}

- (void)updatePageNumbers:(NSArray*)pageBreaks {
	if (pageBreaks) _pageBreaks = pageBreaks;
	
	CGFloat factor = 1 / _zoomLevel;
	if (!_pageNumberLabels) _pageNumberLabels = [NSMutableArray array];
	
	DynamicColor *pageNumberColor = ThemeManager.sharedManager.pageNumberColor;
	NSInteger pageNumber = 1;

	CGFloat rightEdge = self.enclosingScrollView.frame.size.width * factor - self.textContainerInset.width + 35;
	// Compact page numbers if needed
	if (rightEdge + 70 > self.enclosingScrollView.frame.size.width * factor) {
		rightEdge = self.enclosingScrollView.frame.size.width * factor - 70;
	}

	for (NSNumber *pageBreakPosition in self.pageBreaks) {
		NSString *page = [@(pageNumber) stringValue];
		// Do we want the dot after page number?
		// page = [page stringByAppendingString:@"."];
		/*
		NSAttributedString* attrStr = [[NSAttributedString alloc] initWithString:page attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: pageNumberColor }];
		[attrStr drawAtPoint:CGPointMake(rightEdge, [pageBreakPosition floatValue] + self.textContainerInset.height)];
		attrStr = nil;
		 */
		
		NSTextField *label;
		
		// Add new label if needed
		if (pageNumber - 1 >= self.pageNumberLabels.count) label = [self createPageLabel:page];
		else label = self.pageNumberLabels[pageNumber - 1];
		
		[label setStringValue:page];
		
		NSRect rect = NSMakeRect(rightEdge, pageBreakPosition.floatValue + self.textContainerInset.height, 50, 20);
		label.frame = rect;
		
		[label setTextColor:pageNumberColor];

		pageNumber++;
	}
	
	// Remove excess labels
	if (_pageNumberLabels.count >= pageNumber - 1) {
		NSInteger labels = _pageNumberLabels.count;
		for (NSInteger i = pageNumber - 1; i < labels; i++) {
			NSTextField *label = _pageNumberLabels[pageNumber - 1];
			[self.pageNumberLabels removeObject:label];
			[label removeFromSuperview];
		}
	}
}

- (void)resetSceneNumberLabels {
	for (NSInteger i = 0; i < _sceneNumberLabels.count; i++) {
		NSTextField *label = _sceneNumberLabels[i];
		[label removeFromSuperview];
	}
	[_sceneNumberLabels removeAllObjects];
	
	[self updateSceneLabelsFrom:0];
}

- (void)updateSceneLabelsFrom:(NSInteger)changedIndex {
	[self updateSceneTextLabelsFrom:0];
}

- (void)updateSceneTextLabelsFrom:(NSInteger)changedIndex {
	[_sections removeAllObjects];
	
	ContinousFountainParser *parser = self.editorDelegate.parser;
	NSColor *textColor = self.editorDelegate.themeManager.currentTextColor;
	
	[parser createOutline];
	if (!self.sceneNumberLabels) self.sceneNumberLabels = [NSMutableArray array];
	
	NSInteger index = 0;
	for (OutlineScene *scene in parser.outline) {
		if (scene.type == synopse) continue;
		if (scene.type == section) {
			[self addSectionMarker:scene];
			continue;
		}

		// don't update scene labels if we are under the index
		if (scene.line.position + scene.line.string.length < changedIndex) {
			index++;
			continue;
		}
		
		// Don't do anything if the scene number labeling is not on
		if (!self.editorDelegate.showSceneNumberLabels) continue;
		
		NSTextField *label;
		
		// Add new label if needed
		if (index >= self.sceneNumberLabels.count) label = [self createLabel:scene];
		else label = self.sceneNumberLabels[index];
		
		if (scene.sceneNumber) { [label setStringValue:scene.sceneNumber]; }
		
		NSRect rect = [self rectForRange:scene.line.textRange];
		
		rect.size.width = 20 * scene.sceneNumber.length;
		rect.origin.x = self.textContainerInset.width - 40 - rect.size.width + 10;
		rect.origin.y += self.textInsetY + 2;
			
		label.frame = rect;
		
		if (scene.color.length) {
			NSString *color = scene.color.lowercaseString;
			[label setTextColor:[BeatColors color:color]];
		} else {
			[label setTextColor:textColor];
		}

		index++;
	}

	// Remove excess labels
	if (_sceneNumberLabels.count >= index) {
		NSInteger labels = _sceneNumberLabels.count;
		for (NSInteger i = index; i < labels; i++) {
			NSTextField *label = _sceneNumberLabels[index];
			[self.sceneNumberLabels removeObject:label];
			[label removeFromSuperview];
		}
	}
}

- (void)addSectionMarker:(OutlineScene*)sectionItem {
	// Don't draw breaks for less-important sections
	if (sectionItem.sectionDepth > 2) return;
	NSRange characterRange = NSMakeRange(sectionItem.line.position, sectionItem.line.string.length);
	
	NSRect rect = [self rectForRange:characterRange];

	// If the next line is something we care about, include it in the rect for a nicer display
	// If next line is NOT EMPTY, don't add the rect at all.
	NSInteger index = [_editorDelegate.parser.lines indexOfObject:sectionItem.line];
	
	if (sectionItem.line != _editorDelegate.parser.lines.lastObject) {
		Line* previousLine;
		Line* nextLine = [_editorDelegate.parser.lines objectAtIndex:index + 1];
		if (index > 0) previousLine = [_editorDelegate.parser.lines objectAtIndex:index - 1];
		
		if ((nextLine.type == synopse) && (previousLine.string.length < 1 || previousLine.type == section) ) {
			characterRange = NSMakeRange(nextLine.position, nextLine.string.length);
			NSRect nextRect = [self rectForRange:characterRange];
			
			rect.size.height += nextRect.size.height;
			
			[_sections addObject:[NSValue valueWithRect:rect]];
		}
		else if ((nextLine == empty || !nextLine.string.length || nextLine.type == section) && previousLine.string.length < 1 ) {
			[_sections addObject:[NSValue valueWithRect:rect]];
		}
	}
}

/*
 // This isn't working, don't know why
- (void)updateSectionLayers {
	NSInteger index = 0;
	self.wantsLayer = YES;
	
	if (!_sectionBackgrounds) _sectionBackgrounds = [NSMutableArray array];
	CGFloat factor = 1 / _zoomLevel;
	CGFloat width = self.frame.size.width * factor;
	//NSRect rect = NSMakeRect(0, self.textContainerInset.height + sectionRect.origin.y - 7, width, sectionRect.size.height + 14);
	
	for (NSValue *rectValue in _sections) {
		NSRect rect = rectValue.rectValue;
		
		CALayer *layer;
		if (index >= _sectionBackgrounds.count) {
			NSLog(@"Add new (%lu vs %lu)", index, _sectionBackgrounds.count);
			// Add new section
			layer = [[CALayer alloc] init];
			layer.backgroundColor = self.editorDelegate.themeManager.marginColor.CGColor;
			[self.layer addSublayer:layer];
			layer.zPosition = -1;
		} else {
			NSLog(@"Use existing (%lu vs %lu)", index, _sectionBackgrounds.count);
			layer = _sectionBackgrounds[index];
		}
		
		layer.frame = CGRectMake(0, rect.origin.y + self.textContainerInset.height - 7, width, rect.size.height + 14);
		[_sectionBackgrounds addObject:layer];
		
		index++;
	}
	
	// Remove excess backgrounds
	if (_sectionBackgrounds.count >= _sections.count && _sectionBackgrounds.count > 0) {
		NSInteger backgrounds = _sectionBackgrounds.count;
		for (NSInteger i = index; i < backgrounds; i++) {
			CALayer *bgLayer = _sectionBackgrounds[index];
			[self.sectionBackgrounds removeObject:bgLayer];
			[bgLayer removeFromSuperlayer];
		}
	}
	
	[self updateLayer];
}
 */

/*
- (void)updateSceneNumberLabelsWithLayer {
	// Alternative scene numbering system.
	// Gives some performance advantage, but also takes a bigger hit sometimes.

	self.wantsLayer = YES;
	if (!self.editorDelegate.parser.outline.count) [self.editorDelegate.parser createOutline];
	
	// This is pretty fast, but I'm not sure. Still kind of hard to figure out.
	if (!_sceneNumberLabels.count || !_sceneNumberLabels) _sceneNumberLabels = [NSMutableArray array];
	
	NSInteger difference = _sceneNumberLabels.count - self.editorDelegate.parser.scenes.count;

	// There are extra scene number labels, remove them from superlayer
	if (difference > 0) {
		for (NSInteger i = 0; i <= difference; i++) {
			[_sceneNumberLabels.lastObject removeFromSuperlayer];
			[_sceneNumberLabels removeLastObject];
		}
	}
	
	// Begin moving layers
	[CATransaction begin];
	[CATransaction setValue: (id) kCFBooleanTrue forKey: kCATransactionDisableActions];
	
	NSInteger index = 0;
	for (OutlineScene* scene in self.editorDelegate.parser.scenes) {
		NSString *number = scene.sceneNumber;
		
		NSRange characterRange = NSMakeRange(scene.line.position, scene.line.string.length);
		NSRange range = [self.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
		NSRect rect = [self.layoutManager boundingRectForGlyphRange:range inTextContainer:self.textContainer];
		
		// Create frame
		rect.size.width = 90;
		rect.origin.y += self.textContainerInset.height;
		CGFloat factor = 1 / self.enclosingScrollView.magnification;
		rect.origin.x += (self.textContainerInset.width - 140) * factor;
		
		
		// Color
		NSColor *color;
		if (scene.color) [BeatColors color:scene.color];
		else color = ThemeManager.sharedManager.textColor;
			
		// Retrieve or create layer
		CATextLayer *label;
		if (_sceneNumberLabels.count > index) {
			label = [_sceneNumberLabels objectAtIndex:index];
			[label setString:number];
			[label setFrame:rect];
			[label setForegroundColor:color.CGColor];
		} else {
			label = [CATextLayer layer];
			[label setShouldRasterize:YES];
			[label setFont:@"Courier Prime"];
			[label setRasterizationScale:4.0];
			[label setFontSize:17.2];
			[label setAlignmentMode:kCAAlignmentRight];
			
			[self.layer addSublayer:label];
			[_sceneNumberLabels addObject:label];
		}

		[label setContentsScale:1 / self.enclosingScrollView.magnification];
		[label setFrame:rect];
		[label setString:number];
		[label setForegroundColor:color.CGColor];
			
		index++;
	}
	[CATransaction commit];
	[self updateLayer];
}
*/


- (NSTextField *) createLabel: (OutlineScene *) scene {
	NSTextField * label;
	label = [[NSTextField alloc] init];
	
	if (scene != nil) {
		NSRange characterRange = NSMakeRange([scene.line position], [scene.line.string length]);
		NSRange range = [self.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
		
		if (scene.sceneNumber) [label setStringValue:scene.sceneNumber]; else [label setStringValue:@""];
		NSRect rect = [self.layoutManager boundingRectForGlyphRange:range inTextContainer:self.textContainer];
		rect.origin.y += _textInsetY;
		rect.size.width = 20 * [scene.sceneNumber length];
		rect.origin.x = self.textContainerInset.width - 80 - rect.size.width;
	}
	
	[label setBezeled:NO];
	[label setSelectable:NO];
	[label setDrawsBackground:NO];
	[label setFont:self.editorDelegate.courier];
	[label setAlignment:NSTextAlignmentRight];
	[self addSubview:label];
	
	[self.sceneNumberLabels addObject:label];
	return label;
}

- (NSTextField *) createPageLabel: (NSString*) numberStr {
	NSTextField * label;
	label = [[NSTextField alloc] init];
	
	[label setStringValue:numberStr];
	[label setBezeled:NO];
	[label setSelectable:NO];
	[label setDrawsBackground:NO];
	[label setFont:self.editorDelegate.courier];
	[label setAlignment:NSTextAlignmentRight];
	[self addSubview:label];
	
	[self.pageNumberLabels addObject:label];
	return label;
}


- (void) createAllLabels {
	ContinousFountainParser *parser = self.editorDelegate.parser;
	
	for (OutlineScene * scene in parser.outline) {
		[self createLabel:scene];
	}
}
- (void) deleteSceneNumberLabels {
	for (NSTextField * label in _sceneNumberLabels) {
		[label removeFromSuperview];
	}
	[_sceneNumberLabels removeAllObjects];
}

#pragma mark - Mouse events

- (void)mouseMoved:(NSEvent *)event {
	// point in this scaled text view
	NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
	
	// point in unscaled parent view
	NSPoint superviewPoint = [self.enclosingScrollView convertPoint:event.locationInWindow fromView:nil];
	
	// y position in window
	CGFloat y = event.locationInWindow.y;
	
	// Super cursor when inside the text container, otherwise arrow
	if (self.window.isKeyWindow) {
		if ((point.x > self.textContainerInset.width &&
			 point.x * (1/_zoomLevel) < (self.textContainer.size.width + self.textContainerInset.width) * (1/_zoomLevel)) &&
			 y < self.window.frame.size.height - 22 &&
			 superviewPoint.y < self.enclosingScrollView.frame.size.height
			) {
			//[super mouseMoved:event];
			[NSCursor.IBeamCursor set];
		} else if (point.x > 10) {
			//[super mouseMoved:event];
			[NSCursor.arrowCursor set];
		}
	}
}

- (void)mouseExited:(NSEvent *)event {
	//[[NSCursor arrowCursor] set];
}

- (void)scaleUnitSquareToSize:(NSSize)newUnitSize {
	[super scaleUnitSquareToSize:newUnitSize];
}

- (void)setInsets {
	CGFloat width = (self.enclosingScrollView.frame.size.width / 2 - _documentWidth * self.editorDelegate.magnification / 2) / self.editorDelegate.magnification;
	self.textContainerInset = NSMakeSize(width, _textInsetY);
	self.textContainer.size = NSMakeSize(_documentWidth, self.textContainer.size.height);

	[self resetCursorRects];
	[self addCursorRect:(NSRect){0,0, 200, 2500} cursor:NSCursor.crosshairCursor];
	[self addCursorRect:(NSRect){self.frame.size.width * .5,0, self.frame.size.width * .5, self.frame.size.height} cursor:NSCursor.crosshairCursor];
	
	[self drawViewBackgroundInRect:self.bounds];
}

-(void)resetCursorRects {
	[super resetCursorRects];
}

-(void)cursorUpdate:(NSEvent *)event {
	[NSCursor.IBeamCursor set];
}

#pragma mark - Context Menu

-(NSMenu *)menu {
	NSMenu *defaultMenu = [super menu];
	
	// Add items from context menu prototype to the default menu
	// (This is run only once)
	if (_contextMenu.itemArray.count) {
		[defaultMenu addItem:[NSMenuItem separatorItem]];
		
		for (NSMenuItem *item in _contextMenu.itemArray) {
			[_contextMenu removeItem:item];
			[defaultMenu addItem:item];
		}
		
		[defaultMenu addItem:[NSMenuItem separatorItem]];
	}
	
	return defaultMenu;
}

#pragma mark - Scrolling interface

- (void)scrollToRange:(NSRange)range {
	//CGFloat containerHeight = [self.layoutManager usedRectForTextContainer:self.textContainer].size.height;
	//containerHeight = containerHeight * _zoomLevel + self.textContainerInset.height * 2 * _zoomLevel;
	
	NSRect rect = [self rectForRange:range];
	CGFloat y = _zoomLevel * (rect.origin.y + rect.size.height) + self.textContainerInset.height * (_zoomLevel) - self.enclosingScrollView.contentView.bounds.size.height / 2;
	
	[[self.enclosingScrollView.contentView animator] setBoundsOrigin:NSMakePoint(0, y)];
}

#pragma mark - Layout Delegation

#pragma mark - Zooming


@end
/*
 
 hyvä että ilmoitit aikeistasi
 olimme taas kahdestaan liikennepuistossa
 hyvä ettei kumpikaan itkisi
 jos katoaisit matkoille vuosiksi

 niin, kyllä elämä jatkuu ilman sua
 matkusta vain rauhassa
 me pärjäämme ilman sua.
 vaikka tuntuiskin
 tyhjältä.
 
 */
