//
//  NCRAutocompleteTextView.m
//  Modified for Beat
//
//  Copyright (c) 2014 Null Creature. All rights reserved.
//  Parts copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import "NCRAutocompleteTextView.h"
#import "DynamicColor.h"

#define MAX_RESULTS 10

#define HIGHLIGHT_STROKE_COLOR [NSColor selectedMenuItemColor]
#define HIGHLIGHT_FILL_COLOR [NSColor selectedMenuItemColor]
#define HIGHLIGHT_RADIUS 0.0
#define INTERCELL_SPACING NSMakeSize(20.0, 3.0)

//#define WORD_BOUNDARY_CHARS [[NSCharacterSet alphanumericCharacterSet] invertedSet]
//#define WORD_BOUNDARY_CHARS [[NSCharacterSet alphanumericCharacterSet] invertedSet]
#define WORD_BOUNDARY_CHARS [NSCharacterSet newlineCharacterSet]
#define POPOVER_WIDTH 300.0
#define POPOVER_PADDING 0.0

#define POPOVER_APPEARANCE NSAppearanceNameVibrantDark
//#define POPOVER_APPEARANCE NSAppearanceNameVibrantLight

#define POPOVER_FONT [NSFont fontWithName:@"Courier Prime" size:12.0]
// The font for the characters that have already been typed
#define POPOVER_BOLDFONT [NSFont fontWithName:@"Courier Prime Bold" size:12.0]
#define POPOVER_TEXTCOLOR [NSColor whiteColor]

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
@interface NCRAutocompleteTextView ()
@property (weak) IBOutlet NSTouchBar *touchBar;

@property (nonatomic, strong) NSPopover *autocompletePopover;
@property (nonatomic, weak) NSTableView *autocompleteTableView;
@property (nonatomic, strong) NSArray *matches;
@property (nonatomic) bool nightMode;
// Used to highlight typed characters and insert text
@property (nonatomic, copy) NSString *substring;
// Used to keep track of when the insert cursor has moved so we
// can close the popover. See didChangeSelection:
@property (nonatomic, assign) NSInteger lastPos;

@end

@implementation NCRAutocompleteTextView

- (void)awakeFromNib {
	self.pageBreaks = [NSMutableArray array];
	
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
	[tableView setDoubleAction:@selector(insert:)];
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
	[contentViewController setView:contentView];
	
	self.autocompletePopover = [[NSPopover alloc] init];
	self.autocompletePopover.appearance = [NSAppearance appearanceNamed:POPOVER_APPEARANCE];
	
	self.autocompletePopover.animates = NO;
	self.autocompletePopover.contentViewController = contentViewController;
	
	self.matches = [NSMutableArray array];
	self.lastPos = -1;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeSelection:) name:@"NSTextViewDidChangeSelectionNotification" object:nil];
	
	// BEAT BEAT BEAT
	self.masks = [NSMutableArray array];
}

- (NSTouchBar*)makeTouchBar {
	return _touchBar;
}
- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:ColorPickerItemIdentifier]) {
		NSLog(@"jes");
	}
	return nil;
}

- (void)keyDown:(NSEvent *)theEvent {
	NSInteger row = self.autocompleteTableView.selectedRow;
	BOOL shouldComplete = YES;
	
	switch (theEvent.keyCode) {
		case 51:
			// Delete
			[self.autocompletePopover close];
			shouldComplete = NO;
			break;
		case 53:
			// Esc
			if (self.autocompletePopover.isShown)
				[self.autocompletePopover close];
			return; // Skip default behavior
		case 125:
			// Down
			if (self.autocompletePopover.isShown) {
				[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
				[self.autocompleteTableView scrollRowToVisible:self.autocompleteTableView.selectedRow];
				return; // Skip default behavior
			}
			break;
		case 126:
			// Up
			if (self.autocompletePopover.isShown) {
				[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row-1] byExtendingSelection:NO];
				[self.autocompleteTableView scrollRowToVisible:self.autocompleteTableView.selectedRow];
				return; // Skip default behavior
			}
			break;
		case 36:
		case 48:
			// Return or tab
			if (self.autocompletePopover.isShown) {
				[self insert:self];
				//return; // Skip default behavior (nah, we don't need two returns?)
			}
/*
		case 49:
			// Space
			if (self.autocompletePopover.isShown) {
				[self.autocompletePopover close];
			}
			break;
*/
	}
	[super keyDown:theEvent];
	if (shouldComplete) {
		if (self.automaticTextCompletionEnabled) {
			[self complete:self];
		}
	}
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

- (void)insert:(id)sender {
	if (self.autocompleteTableView.selectedRow >= 0 && self.autocompleteTableView.selectedRow < self.matches.count) {
		NSString *string = [self.matches objectAtIndex:self.autocompleteTableView.selectedRow];
		NSInteger beginningOfWord = self.selectedRange.location - self.substring.length;
		NSRange range = NSMakeRange(beginningOfWord, self.substring.length);
		if ([self shouldChangeTextInRange:range replacementString:string]) {
			[self replaceCharactersInRange:range withString:string];
			[self didChangeText];
		}
	}
	[self.autocompletePopover close];
}

- (void)didChangeSelection:(NSNotification *)notification {
	if ((self.selectedRange.location - self.lastPos) > 1) {
		// If selection moves by more than just one character, hide autocomplete
		[self.autocompletePopover close];
	}
}

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
	
	NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:self.matches[row] attributes:@{NSFontAttributeName:POPOVER_FONT, NSForegroundColorAttributeName:POPOVER_TEXTCOLOR}];
	
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

- (void)drawRect:(NSRect)dirtyRect {
	[NSGraphicsContext saveGraphicsState];
	[super drawRect:dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
	
	// Draw page margins
	if (self.frame.size.width > 1000) {
		// Multiply background color to make for a darker margin
		NSColor *fillColor = self.backgroundColor;
		fillColor = [fillColor colorWithAlphaComponent:0.3];
		[fillColor setFill];
		
		CGFloat marginWidth = self.textContainerInset.width - 120;
		CGFloat modifier = 1 / _zoomLevel;
		
		NSRect marginLeft = NSMakeRect(0, 0, marginWidth, self.frame.size.height);
		NSRect marginRight = NSMakeRect((self.frame.size.width - marginWidth) * modifier, 0, marginWidth, self.frame.size.height);
		
		[NSGraphicsContext saveGraphicsState];
		NSRectFillUsingOperation(marginLeft, NSCompositingOperationMultiply);
		NSRectFillUsingOperation(marginRight, NSCompositingOperationMultiply);
		
		[NSGraphicsContext restoreGraphicsState];
	}
	
	// An array of NSRanges which are used to mask parts of the text.
	// Used to hide irrelevant parts when filtering scenes.
	if ([_masks count]) {
		for (NSValue * value in _masks) {
			NSColor* fillColor = self.backgroundColor;
			fillColor = [fillColor colorWithAlphaComponent:0.85];
			[fillColor setFill];
			
			NSRect rect = [self.layoutManager boundingRectForGlyphRange:value.rangeValue inTextContainer:self.textContainer];
			rect.origin.x = 0;
			rect.origin.y += self.textContainerInset.height - 12; // You say: never hardcode a value, but YOU DON'T KNOW ME, DO YOU!!!
			rect.size.width = self.frame.size.width;
			
			NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
		}
	}
	
	/*
	NSGraphicsContext *context = [NSGraphicsContext currentContext];
	[context saveGraphicsState];

	for (NSNumber *pageBreakPosition in self.pageBreaks) {
		NSColor* fillColor = NSColor.grayColor;
		[fillColor setFill];
		
		NSRect rect = NSMakeRect(0, [pageBreakPosition doubleValue], self.frame.size.width, 1);
		NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
	}
	[context restoreGraphicsState];
	*/
	 
	/*
	 
	 WIP
	 
	 Test for graphical page breaks while editing.
	 
	 Trouble is, page length etc. should be calculated while parsing. Some elements do not print (section, synopses) and page breaks can be forced, too.
	 
	 ---
	
	 NSLayoutManager *manager = self.textContainer.layoutManager;
	 NSRange glyphRange = [manager glyphRangeForTextContainer:self.textContainer];
	 
	 CGFloat pagePosition = 0;
	 NSInteger pages = 1;
	 CGFloat pageBreak = 600;

	 NSMutableArray *pageBreaks = [NSMutableArray array];
	 NSGraphicsContext *context = [NSGraphicsContext currentContext];

	 for (NSInteger glyphIndex = glyphRange.location; glyphIndex < NSMaxRange(glyphRange); glyphIndex++) {
		 
		 NSRect lineFragmentRect = [manager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
		 CGFloat position = lineFragmentRect.origin.y;
		 pagePosition = position - (pages - 1) * pageBreak;
		 
		 if (pagePosition > pageBreak) {
			 pages++;
			 [pageBreaks addObject:[NSNumber numberWithFloat:position]];
		 }
	 }

	 [context saveGraphicsState];

	 for (NSNumber *pageBreakPosition in pageBreaks) {
		 NSColor* fillColor = NSColor.grayColor;
		 [fillColor setFill];
		 
		 NSRect rect = NSMakeRect(0, [pageBreakPosition floatValue], 500, 1);
		 NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
	 }
	 [context restoreGraphicsState];
	 */
	 
}


@end
