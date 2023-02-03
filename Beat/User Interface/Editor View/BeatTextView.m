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
 - set custom glyphs when hiding Fountain markup
 - render uppercase characters when needed (scene headings, transitions etc)
 
 Document can be accessed using .editorDelegate
 Note that this is NOT the BeatEditorDelegate seen elsewhere, but a custom one
 just for BeatTextView. It has some methods that don't have to be exposed elsewhere.
 
 Auto-completion function is based on NCRAutoCompleteTextView.
 Heavily modified for Beat.
 
 */

#import <QuartzCore/QuartzCore.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatPaginationCore/BeatPaginationCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore.h>

#import "BeatTextView.h"
#import "ScrollView.h"
#import "BeatPasteboardItem.h"
#import "BeatMeasure.h"
#import "BeatLayoutManager.h"
#import "Beat-Swift.h"
#import "BeatFonts.h"
#import "BeatEditorFormatting.h"


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

#define TEXT_INSET_TOP 50

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
@property (nonatomic) BeatTagType currentTagType;

// Used to highlight typed characters when autocompleting and insert text
@property (nonatomic, copy) NSString *substring;

// Used to keep track of when the insert cursor has moved so we
// can close the popover. See didChangeSelection:
@property (nonatomic, assign) NSInteger lastPos;

// New scene numbering system
@property (nonatomic) NSMutableArray *sceneNumberLabels;
@property (nonatomic) NSUInteger linesBeforeLayout;
@property (nonatomic) NSMutableArray <CATextLayer*>*sceneLayerLabels;

// Text container tracking area
@property (nonatomic) NSTrackingArea *trackingArea;

// Page number fields
@property (nonatomic) NSMutableArray *pageNumberLabels;

// Scroll wheel behavior
@property (nonatomic) bool scrolling;
@property (nonatomic) bool selectionAtEnd;

@property (nonatomic) bool updatingSceneNumberLabels; /// YES if scene number labels are being updated

@property (nonatomic) NSMutableDictionary *markerLayers;

@end

@implementation BeatTextView

+ (CGFloat)linePadding {
	return 50;
}

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	// Load custom layout manager and set a bit bigger line fragment padding
	// to fit our revision markers in the margin
	
	BeatLayoutManager *layoutMgr = BeatLayoutManager.new;
	layoutMgr.textView = self;
	[self.textContainer replaceLayoutManager:layoutMgr];
	self.textContainer.lineFragmentPadding = [BeatTextView linePadding];
	
	self.textStorage.delegate = self;
	
	// Setup magnification
	[self setupZoom];
	
	return self;
}


- (void)awakeFromNib {
	self.matches = NSMutableArray.array;
	self.pageBreaks = NSArray.new;
	
	self.lastPos = -1;

	[self setupPopovers];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didChangeSelection:) name:@"NSTextViewDidChangeSelectionNotification" object:self];
	
	self.layoutManager.delegate = self;
}

-(void)setup {
	self.editable = YES;
	self.textContainer.widthTracksTextView = NO;
	self.textContainer.heightTracksTextView = NO;
	
	// Style
	self.font = _editorDelegate.courier;
	self.automaticDataDetectionEnabled = NO;
	self.automaticQuoteSubstitutionEnabled = NO;
	self.automaticDashSubstitutionEnabled = NO;
	
	if (self.editorDelegate.hideFountainMarkup) self.layoutManager.allowsNonContiguousLayout = NO;
	else self.layoutManager.allowsNonContiguousLayout = YES;
	
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	[paragraphStyle setLineHeightMultiple:self.editorDelegate.lineHeight];
	[self setDefaultParagraphStyle:paragraphStyle];
	
	_trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];
	[self.window setAcceptsMouseMovedEvents:YES];
	[self addTrackingArea:_trackingArea];
	
	// Turn layers on if you want to use CATextLayer labels.
	// self.wantsLayer = YES;
	[self setInsets];
}

-(void)setupPopovers {
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
	
	// Avoid the "modern" padding on Big Sur
	if (@available(macOS 11.0, *)) {
		tableView.style = NSTableViewStyleFullWidth;
	}
	
	self.autocompleteTableView = tableView;
	
	NSScrollView *tableScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	[tableScrollView setDrawsBackground:NO];
	[tableScrollView setDocumentView:tableView];
	[tableScrollView setHasVerticalScroller:YES];
	
	NSView *contentView = [[NSView alloc] initWithFrame:NSZeroRect];
	[contentView addSubview:tableScrollView];
	
	NSViewController *contentViewController = [[NSViewController alloc] init];
	[contentViewController setView:contentView];
	
	// Autocomplete popover
	self.autocompletePopover = [[NSPopover alloc] init];
	self.autocompletePopover.appearance = [NSAppearance appearanceNamed:POPOVER_APPEARANCE];
	
	self.autocompletePopover.animates = NO;
	self.autocompletePopover.contentViewController = contentViewController;
	
	// Info popover
	self.infoPopover = [[NSPopover alloc] init];
	
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
	[infoViewController setView:infoContentView];

	self.infoPopover.contentViewController = infoViewController;
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

#pragma mark - Window interactions

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


-(void)setBounds:(NSRect)bounds {
	[super setBounds:bounds];
}
-(void)setFrame:(NSRect)frame {
	// There is a strange bug (?) in macOS Monterey which causes some weird sizing errors.
	// This is a duct-tape fix. Sorry for anyone reading this.
	
	static CGSize prevSize;
	static CGSize sizeBeforeThat;
		
	if (prevSize.width > 0 && frame.size.height == prevSize.height) {
		// Some duct-tape which might have not worked, or dunno
		//if (frame.size.width == sizeBeforeThat.width) return;
	}
	
	// I don't know why this happens, but text view frame can sometimes become wider than
	// its enclosing view, causing some weird horizontal scrolling. Let's clamp the value.
	if (frame.size.width > self.superview.frame.size.width) frame.size.width = self.superview.frame.size.width;
	[super setFrame:frame];
	
	sizeBeforeThat = prevSize;
	prevSize = frame.size;
}

#pragma mark - Key events

-(void)keyUp:(NSEvent *)event {
	if (self.editorDelegate.typewriterMode) [self typewriterScroll];
}
- (void)keyDown:(NSEvent *)theEvent {
	if (self.editorDelegate.contentLocked) {
		// Show lock status for alphabet keys
		NSString * const character = [theEvent charactersIgnoringModifiers];
		if (character.length > 0) {
			unichar c = [character characterAtIndex:0];
			if ([NSCharacterSet.letterCharacterSet characterIsMember:c]) [self.editorDelegate showLockStatus];
		}
	}
	
	NSInteger row = self.autocompleteTableView.selectedRow;
	BOOL shouldComplete = YES;
	BOOL preventDefault = NO;
	
	switch (theEvent.keyCode) {
		case 51:
			// Delete
			[self closePopovers];
			shouldComplete = NO;
			
			break;
		case 53:
			// Esc
			if (self.autocompletePopover.isShown || self.infoPopover.isShown) {
				[self closePopovers];
			}
			else {
				[self.editorDelegate cancelOperation:self];
			}
			
			preventDefault = YES;
			break;
			
			//return; // Skip default behavior
		case 125:
			// Down
			if (self.autocompletePopover.isShown) {
				if (row + 1 >= self.autocompleteTableView.numberOfRows) row = -1;
				[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
				[self.autocompleteTableView scrollRowToVisible:self.autocompleteTableView.selectedRow];
				preventDefault = YES;
				//return; // Skip default behavior
			}
			break;
		case 126:
			// Up
			if (self.autocompletePopover.isShown) {
				if (row - 1 < 0) row = self.autocompleteTableView.numberOfRows;
				
				[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row-1] byExtendingSelection:NO];
				[self.autocompleteTableView scrollRowToVisible:self.autocompleteTableView.selectedRow];
				preventDefault = YES;
				//return; // Skip default behavior
			}
			break;
		case 48:
			// Tab
			if (_forceElementMenu || _popupMode == ForceElement) {
				// force element + skip default
				[self force:self];
				preventDefault = YES;
				//return;
				
			} else if (_popupMode == Tagging) {
				// handle tagging + skip default
				preventDefault = YES;
				//return;
				
			} else if (self.autocompletePopover.isShown && _popupMode == Autocomplete) {
				[self insert:self];
				preventDefault = YES;
				//return; // don't insert a line-break after tab key
				
			} else {
				// Call delegate to handle normal tab press
				NSUInteger flags = theEvent.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;

				if (flags == 0 || flags == NSEventModifierFlagCapsLock) {
					[self.editorDelegate handleTabPress];
				}
				
				preventDefault = YES;
			}
			break;
		case 36:
			// HANDLE RETURN
			if (self.autocompletePopover.isShown) {
				// Check whether to force an element or to just autocomplete
				if (_forceElementMenu || _popupMode == ForceElement) {
					[self force:self];
					preventDefault = YES;
					break;
					//return; // skip default
				} else if (_popupMode == Tagging) {
					[self setTag:self];
					preventDefault = YES;
					break;
					//return;
				} else if (_popupMode == SelectTag) {
					[self selectTag:self];
					preventDefault = YES;
					break;
					//return;
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
					preventDefault = YES;
					break;
					//return; // Skip defaut behavior
				}
			}
	}
	
	if (self.infoPopover.isShown) [self closePopovers];
	
	// Skip super methods when needed
	if (preventDefault) return;
	
	// Run superclass method for the event
	[super keyDown:theEvent];
	
	// Run completion block
	if (shouldComplete && self.popupMode != Tagging) {
		if (self.automaticTextCompletionEnabled) {
			[self complete:self];
		}
	}
}

- (void)clickPopupItem:(id)sender {
	if (_popupMode == Autocomplete)	[self insert:sender];
	if (_popupMode == Tagging) [self setTag:sender];
	else [self closePopovers];
}


#pragma mark - Typewriter scroll

- (void)updateTypewriterView {
	NSRange range = [self.layoutManager glyphRangeForCharacterRange:self.selectedRange actualCharacterRange:nil];
	NSRect rect = [self.layoutManager boundingRectForGlyphRange:range inTextContainer:self.textContainer];
	
	CGFloat viewOrigin = self.enclosingScrollView.documentVisibleRect.origin.y;
	CGFloat viewHeight = self.enclosingScrollView.documentVisibleRect.size.height;
	CGFloat y = rect.origin.y + self.textContainerInset.height;
	if (y < viewOrigin || y > viewOrigin + viewHeight) [self typewriterScroll];
}

- (void)typewriterScroll {
	if (self.needsLayout) [self layout];
	[self.layoutManager ensureLayoutForCharacterRange:self.editorDelegate.currentLine.range];

	NSClipView *clipView = self.enclosingScrollView.documentView;

	// Find the rect for current range
	NSRect rect = [self rectForRange:self.selectedRange];
	//NSRange range = [self.layoutManager glyphRangeForCharacterRange:self.selectedRange actualCharacterRange:nil];
	//NSRect rect = [self.layoutManager boundingRectForGlyphRange:range inTextContainer:self.textContainer];

	// Calculate correct scroll position
	CGFloat scrollY = (rect.origin.y - self.editorDelegate.fontSize / 2 - 10) * self.editorDelegate.magnification;
	
	// Take find & replace bar height into account
	CGFloat findBarHeight = (self.enclosingScrollView.findBarVisible) ? self.enclosingScrollView.findBarView.frame.size.height : 0;
	
	CGFloat boundsY = clipView.bounds.size.height + findBarHeight + clipView.bounds.origin.y;
	CGFloat maxY = self.frame.size.height;
	CGFloat pixelsToBottom = maxY - boundsY;
	if (pixelsToBottom < self.editorDelegate.fontSize * _editorDelegate.magnification * 0.5 && pixelsToBottom > 0) {
		scrollY -= 5 * _editorDelegate.magnification;
	}
	

	// Calculate container height with insets
	CGFloat containerHeight = [self.layoutManager usedRectForTextContainer:self.textContainer].size.height;
	containerHeight = containerHeight * self.editorDelegate.magnification + self.textInsetY * 2 * self.editorDelegate.magnification;
		
	// how many pixels the view should shift
	CGFloat delta = fabs(scrollY - self.superview.bounds.origin.y);
	
	CGFloat fontSize = self.editorDelegate.fontSize * self.editorDelegate.magnification;
	if (scrollY < containerHeight && delta > fontSize) {
		//scrollY = containerHeight - _textClipView.frame.size.height;
		[self.superview.animator setBoundsOrigin:NSMakePoint(self.superview.bounds.origin.x, scrollY)];
	}
}
-(void)scrollWheel:(NSEvent *)event {
	// If the user scrolls, let's ignore any other scroll behavior
	_selectionAtEnd = NO;
	
	if (event.phase == NSEventPhaseBegan || event.phase == NSEventPhaseChanged) _scrolling = YES;
	else if (event.phase == NSEventPhaseEnded) _scrolling = NO;
	
	[super scrollWheel:event];
}

-(NSRect)adjustScroll:(NSRect)newVisible {
	if (self.editorDelegate.typewriterMode && !_scrolling && _selectionAtEnd) {
		if (self.selectedRange.location == self.string.length) {
			return self.enclosingScrollView.documentVisibleRect;
		}
	}
	
	return [super adjustScroll:newVisible];
}

#pragma mark - Info popup

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
		NSInteger pages = _editorDelegate.numberOfPages;
		if (pages > 0) infoString = [infoString stringByAppendingFormat:@"\nPages: %lu", pages];
	} else {
		NSInteger page = [_editorDelegate getPageNumber:self.selectedRange.location];
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

#pragma mark - Insert

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
	/*
	 
	 There are TWO different didChangeSelection listeners, here and in Document.
	 This one deals with text editor events, such as tagging, typewriter scroll,
	 closing autocomplete and displaying reviews.
	 
	 The one in Document handles other UI-related stuff, such as updating views
	 that are hooked into the parsed screenplay contents, and also updates plugins.
	 
	 */
	
	// Skip event when needed
	if (_editorDelegate.skipSelectionChangeEvent) {
		_editorDelegate.skipSelectionChangeEvent = NO;
		return;
	}
	
	// Update view position if needed
	if (self.editorDelegate.typewriterMode) [self updateTypewriterView];
	
	// If selection moves by more than just one character, hide autocomplete
	if ((self.selectedRange.location - self.lastPos) > 1) {
		if (self.autocompletePopover.shown) [self setAutomaticTextCompletionEnabled:NO];
		[self.autocompletePopover close];
	}
	
	// Show tagging/review options for selected range
	if (_editorDelegate.mode == TaggingMode) {
		// Show tag list
		[self showTaggingOptions];
	}
	else if (_editorDelegate.mode == ReviewMode) {
		// Show review editor
		[_editorDelegate.review showReviewItemWithRange:self.selectedRange forEditing:YES];
	}
	else {
		// We are in editor mode. Run any required events.
		[self selectionEvents];
	}
}

- (bool)selectionAtEnd {
	if (self.selectedRange.location == self.string.length) return YES;
	else return NO;
}

- (void)selectionEvents {
	/*
	 
	 NB: I could/should make this one a registered event, too.
	 
	 */
	
	// Don't go out of range. We can't check for attributes at the last index.
	NSUInteger pos = self.selectedRange.location;
	if (NSMaxRange(self.selectedRange) >= self.string.length) pos = self.string.length - 1;
	if (pos < 0) pos = 0;
	
	// Review items
	if (self.string.length > 0) {
		BeatReviewItem *reviewItem = [self.textStorage attribute:BeatReview.attributeKey atIndex:pos effectiveRange:nil];
		if (reviewItem && !reviewItem.emptyReview) {
			[_editorDelegate.review showReviewItemWithRange:NSMakeRange(pos, 0) forEditing:NO];
			[self.window makeFirstResponder:self];
		} else {
			[[_editorDelegate.review popover] close];
		}
	}
	
	
}

#pragma mark - Tagging / Force Element menu

- (void)showTaggingOptions {
	NSString *selectedString = [self.string substringWithRange:self.selectedRange];
	
	// Don't allow line breaks in tagged content. Limit the selection if break is found.
	if ([selectedString containsString:@"\n"]) {
		[self setSelectedRange:(NSRange){ self.selectedRange.location, [selectedString rangeOfString:@"\n"].location }];
	}
	
	if (self.selectedRange.length < 1) return;
	
	_popupMode = Tagging;
	[self showPopupWithItems:BeatTagging.styledTags];
}

- (void)forceElement:(id)sender {
	_popupMode = ForceElement;
	[self showPopupWithItems: [self forceableTypes].allKeys ];
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
	[self.autocompletePopover setContentSize:NSMakeSize(NSWidth(frame), NSHeight(frame) + POPOVER_PADDING)];
	
	self.substring = [self.string substringWithRange:NSMakeRange(location, 0)];
	
	NSRect rect = [self firstRectForCharacterRange:NSMakeRange(location, 0) actualRange:NULL];
	rect = [self.window convertRectFromScreen:rect];
	rect = [self convertRect:rect fromView:nil];
	
	rect.size.width = 5;
	
	[self.autocompletePopover showRelativeToRect:rect ofView:self preferredEdge:NSMaxYEdge];
}

- (NSDictionary*)forceableTypes {
	return @{
		[BeatLocalization localizedStringForKey:@"force.heading"]: @(heading),
		[BeatLocalization localizedStringForKey:@"force.character"]: @(character),
		[BeatLocalization localizedStringForKey:@"force.action"]: @(action),
		[BeatLocalization localizedStringForKey:@"force.lyrics"]: @(lyrics),
	};
}

- (void)force:(id)sender {
	if (self.autocompleteTableView.selectedRow >= 0 && self.autocompleteTableView.selectedRow < self.matches.count) {
		NSString *localizedType = [self.matches objectAtIndex:self.autocompleteTableView.selectedRow];
		NSDictionary *types = [self forceableTypes];
		NSNumber *val = types[localizedType];
		
		// Do nothing if something went wront
		if (val == nil) return;
		
		LineType type = val.integerValue;
		[self.editorDelegate forceElement:type];
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
		
	if (self.selectedRange.length > 0) {
		NSString *tagString = [self.textStorage.string substringWithRange:self.selectedRange].lowercaseString;
		BeatTagType type = [BeatTagging tagFor:tagStr];
		
		if (![self.tagging tagExists:tagString type:type]) {
			// If a tag with corresponding text & type doesn't exist, let's find possible similar tags
			NSArray *possibleMatches = [self.tagging searchTagsByTerm:tagString type:type];
			
			if (possibleMatches.count == 0)	[self.tagging tagRange:self.selectedRange withType:type];
			else {
				NSArray *items = @[[NSString stringWithFormat:@"New: %@", tagString]];
				self.matches = [items arrayByAddingObjectsFromArray:possibleMatches];
				_popupMode = SelectTag;
				_currentTagType = type;
				[self.autocompleteTableView reloadData];
				[self.autocompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
				return;
			}
			
		} else {
			[self.tagging tagRange:self.selectedRange withType:type];
		}
		
		// Deselect
		self.selectedRange = (NSRange){ self.selectedRange.location + self.selectedRange.length, 0 };
	}
		
	[self.autocompletePopover close];
	_popupMode = NoPopup;
}
- (void)selectTag:(id)sender {
	id tagName;
	if (_autocompleteTableView.selectedRow == 0) {
		// First item CREATES A NEW TAG
		tagName = [self.textStorage.string substringWithRange:self.selectedRange];
	} else {
		// This was selected from the list of existing tags
		tagName = [self.matches objectAtIndex:self.autocompleteTableView.selectedRow];
	}
	
	id def = [self.tagging definitionWithName:(NSString*)tagName type:_currentTagType];
	
	if (def) {
		// Definition was selected
		[self.tagging tagRange:self.selectedRange withDefinition:def];
	} else {
		// No existing definition selected
		[self.tagging tagRange:self.selectedRange withType:_currentTagType];
	}
	
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
		[self.window makeFirstResponder:self];
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
	if (row >= self.matches.count) return cellView; // Return an empty view if something is wrong
	
	if (cellView == nil) {
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
		[textField setBezeled:NO];
		[textField setDrawsBackground:NO];
		[textField setEditable:NO];
		[textField setSelectable:NO];
		
		cellView = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
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
		[as addAttribute:NSFontAttributeName value:BeatFonts.sharedFonts.courier range:NSMakeRange(0, as.string.length)];
	} else {
		as = [[NSMutableAttributedString alloc] initWithString:(NSString*)label attributes:@{NSFontAttributeName:BeatFonts.sharedFonts.courier, NSForegroundColorAttributeName:POPOVER_TEXTCOLOR}];
	}
	
	if (self.substring) {
		NSRange range = [as.string rangeOfString:self.substring options:NSAnchoredSearch|NSCaseInsensitiveSearch];
		[as addAttribute:NSFontAttributeName value:BeatFonts.sharedFonts.boldCourier range:range];
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
	NSRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];

	return rect;
}


-(void)viewDidEndLiveResize {
	//[super viewDidEndLiveResize];
	[self setInsets];
}

- (void)drawRect:(NSRect)dirtyRect {
	NSGraphicsContext *ctx = NSGraphicsContext.currentContext;
	if (!ctx) return;
	
	[super drawRect:dirtyRect];
}

-(void)redrawUI {
	[self displayRect:self.frame];
	[self.layoutManager ensureLayoutForTextContainer:self.textContainer];
}


#pragma mark - Page numbering

- (void)updatePagination:(NSArray<BeatPaginationPage*>*)pages {
	NSMutableArray* breakPositions = NSMutableArray.new;
	
	CGFloat lineHeight = BeatPagination.lineHeight; // Line height from pagination
	CGFloat UIlineHeight = BeatEditorFormatting.editorLineHeight; // Line height in UI
	
	for (BeatPaginationPage* page in pages) {
		BeatPageBreak* pageBreak = page.pageBreak;
		
		Line* line = pageBreak.element;
		CGFloat position = pageBreak.y;
		
		NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:line.textRange actualCharacterRange:nil];
		NSRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
				
		if (position >= 0) {
			position = round(position / lineHeight) * UIlineHeight;
			position = rect.origin.y + position;
		} else {
			// Position -1 from pagination means that we'll position the line break after this element
			position = rect.origin.y;
		}
		
		[breakPositions addObject:@(position)];
	}
	
	[self updatePageNumbers:breakPositions];
}

- (void)updatePageBreaks:(NSArray<NSDictionary*>*)pageBreaks {
	// Sort page breaks based on their position
	NSMutableArray *breakPositions = NSMutableArray.new;
	NSArray<NSDictionary*>* sortedPageBreaks = [pageBreaks sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		NSDictionary *pageBreak1 = obj1;
		NSDictionary *pageBreak2 = obj2;
		
		NSNumber *pos1 = @(((Line*)pageBreak1[@"line"]).position);
		NSNumber *pos2 = @(((Line*)pageBreak2[@"line"]).position);
		
		return [pos1 compare:pos2];
	}];
	
	// We could add exclusion paths at page breaks:
	// NSMutableArray* exclusionPaths = NSMutableArray.new;
	
	for (NSDictionary *pageBreak in sortedPageBreaks) { @autoreleasepool {
		CGFloat lineHeight = BeatPagination.lineHeight; // Line height from pagination
		CGFloat UIlineHeight = BeatEditorFormatting.editorLineHeight; // Line height in UI
		CGFloat y;
		
		Line *line = pageBreak[@"line"];
		CGFloat position = [pageBreak[@"position"] floatValue];
		
		NSRange characterRange = NSMakeRange(line.position, line.string.length);
		NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
		
		NSRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
		
		// We return -1 for elements that should have page break after them
		if (position >= 0) {
			y =  rect.origin.y + (position / lineHeight) * UIlineHeight;
		}
		else y = rect.origin.y + rect.size.height;
	
		// This is how you add the exclusion paths, while also continuously laying out the text:
		//NSRect exclusion = NSMakeRect(0, y, self.frame.size.width, 50);
		//NSBezierPath* path = [NSBezierPath bezierPathWithRect:exclusion];
		//[exclusionPaths addObject:path];
		//self.textContainer.exclusionPaths = exclusionPaths;
		
		[breakPositions addObject:@(y)];
	} }
	
	[self updatePageNumbers:breakPositions];
	[self setNeedsDisplay:YES];
}

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

	CGFloat rightEdge = self.enclosingScrollView.frame.size.width * factor - self.textContainerInset.width - 30;
	// Compact page numbers if needed
	if (rightEdge + 70 > self.enclosingScrollView.frame.size.width * factor) {
		rightEdge = self.enclosingScrollView.frame.size.width * factor - 70;
	}

	for (NSNumber *pageBreakPosition in self.pageBreaks) {
		NSTextField *label;
		NSString *page = @(pageNumber).stringValue;
		
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

- (NSTextField *)createPageLabel: (NSString*) numberStr {
	NSTextField * label;
	label = NSTextField.new;
	
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


#pragma mark - Rect for line

CGRect cachedRect;
Line *cachedRectLine;
-(CGRect)rectForLine:(Line*)line {
	if (cachedRectLine.position == line.position && cachedRectLine.length == line.length) return cachedRect;
	
	CGRect charRect = [self rectForRange:line.textRange];
	CGRect rect = CGRectMake(charRect.origin.x + self.textContainerInset.width,
							 fabs(charRect.origin.y + self.textContainerInset.height),
							 charRect.size.width,
							 charRect.size.height
							 );
	
	cachedRectLine = line.copy;
	cachedRect = rect;
	
	return rect;
}



#pragma mark - Draw custom caret

- (void)drawInsertionPointInRect:(NSRect)aRect color:(NSColor *)aColor turnedOn:(BOOL)flag {
	aRect.size.width = CARET_WIDTH;
	[super drawInsertionPointInRect:aRect color:aColor turnedOn:flag];
}

- (void)setNeedsDisplayInRect:(NSRect)invalidRect {
	invalidRect = NSMakeRect(invalidRect.origin.x, invalidRect.origin.y, invalidRect.size.width + CARET_WIDTH - 1, invalidRect.size.height);
	[super setNeedsDisplayInRect:invalidRect];
}

#pragma mark - Update layout elements

- (void)refreshLayoutElements {
	[self refreshLayoutElementsFrom:0];
}
- (void)refreshLayoutElementsFrom:(NSInteger)location {
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

- (CGFloat)documentWidth {
	CGFloat width = 0.0;
	CGFloat padding = self.textContainer.lineFragmentPadding;
	
	if (_editorDelegate.pageSize == BeatA4) {
		width = BeatFonts.characterWidth * 59;
	} else {
		width = BeatFonts.characterWidth * 61;
	}
	
	return width + padding * 2;
}

- (CGFloat)setInsets {
	// Top/bottom insets
	if (_editorDelegate.typewriterMode) {
		CGFloat insetY = (self.enclosingScrollView.contentView.frame.size.height / 2 - _editorDelegate.fontSize / 2) * (1 + (1 - _editorDelegate.magnification));
		self.textInsetY = insetY;
	} else {
		self.textInsetY = TEXT_INSET_TOP;
	}
	
	// Left/right insets
	CGFloat width = (self.enclosingScrollView.frame.size.width / 2 - self.documentWidth * _editorDelegate.magnification / 2) / _editorDelegate.magnification;
	
	self.textContainerInset = NSMakeSize(width, _textInsetY);
	self.textContainer.size = NSMakeSize(self.documentWidth, self.textContainer.size.height);

	[self resetCursorRects];
	[self addCursorRect:(NSRect){0,0, 200, 2500} cursor:NSCursor.crosshairCursor];
	[self addCursorRect:(NSRect){self.frame.size.width * .5,0, self.frame.size.width * .5, self.frame.size.height} cursor:NSCursor.crosshairCursor];
	
	return width;
}

-(void)resetCursorRects {
	[super resetCursorRects];
}

-(void)cursorUpdate:(NSEvent *)event {
	[NSCursor.IBeamCursor set];
}

#pragma mark - Context Menu

-(NSMenu *)menu {
	return self.contextMenu.copy;
}

#pragma mark - Scrolling interface

/// Non-animated scrolling
- (void)scrollToRange:(NSRange)range {
	NSRect rect = [self rectForRange:range];
	CGFloat y = _zoomLevel * (rect.origin.y + rect.size.height) + self.textContainerInset.height * (_zoomLevel) - self.enclosingScrollView.contentView.bounds.size.height / 2;
	
	[self.enclosingScrollView.contentView.animator setBoundsOrigin:NSMakePoint(0, y)];
}

- (void)ensureRangeIsVisible:(NSRange)range {
	NSRect rect = [self rectForRange:range];
	
	CGFloat changeY = rect.origin.y - rect.size.height;
	if (changeY < self.visibleRect.origin.y || changeY > self.visibleRect.origin.y + self.visibleRect.size.height) {
		[self scrollToRange:range];
	}
}

/// Animated scrolling with a callback
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock {
	NSRect rect = [self rectForRange:range];
	CGFloat y = _zoomLevel * (rect.origin.y + rect.size.height) + self.textContainerInset.height * (_zoomLevel) - self.enclosingScrollView.contentView.bounds.size.height / 2;
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
		// Start some animations.
		[self.enclosingScrollView.contentView.animator setBoundsOrigin:NSMakePoint(0, y)];
	} completionHandler:^{
		if (callbackBlock != nil) callbackBlock();
	}];
}


#pragma mark - Zooming

- (void)setupZoom {
	// This resets the zoom to the saved setting
	self.zoomLevel = [BeatUserDefaults.sharedDefaults getFloat:BeatSettingMagnification];
	
	_scaleFactor = 1.0;
	[self setScaleFactor:_zoomLevel adjustPopup:false];
	[self.editorDelegate updateLayout];
}

- (void)resetZoom {
	[BeatUserDefaults.sharedDefaults resetToDefault:BeatSettingMagnification];
	CGFloat zoomLevel = [BeatUserDefaults.sharedDefaults getFloat:BeatSettingMagnification];
	[self adjustZoomLevel:zoomLevel];
}


/// Adjust zoom by a delta value
- (void)adjustZoomLevelBy:(CGFloat)value {
	CGFloat newMagnification = _zoomLevel + value;
	[self adjustZoomLevel:newMagnification];
}

double clamp(double d, double min, double max) {
	const double t = d < min ? min : d;
	return t > max ? max : t;
}

- (void)setZoomLevel:(CGFloat)zoomLevel {
	_zoomLevel = clamp(zoomLevel, 0.9, 2.1);
}

/// Set zoom level for the editor view, automatically clamped
- (void)adjustZoomLevel:(CGFloat)level {
	if (_scaleFactor == 0) _scaleFactor = _zoomLevel;
	CGFloat oldMagnification = _zoomLevel;
		
	if (oldMagnification != level) {
		self.zoomLevel = level;
		
		// Save scroll position
		NSPoint scrollPosition = self.enclosingScrollView.contentView.documentVisibleRect.origin;
		
		[self setScaleFactor:_zoomLevel adjustPopup:false];
		[self.editorDelegate updateLayout];
		
		// Scale and apply the scroll position
		scrollPosition.y = scrollPosition.y * _zoomLevel;
		[self.enclosingScrollView.contentView scrollToPoint:scrollPosition];
		[self.editorDelegate ensureLayout];
		
		[self setNeedsDisplay:YES];
		[self.enclosingScrollView setNeedsDisplay:YES];
		
		// For some reason, clip view might get the wrong height after magnifying. No idea what's going on.
		NSRect clipFrame = self.enclosingScrollView.contentView.frame;
		clipFrame.size.height = self.enclosingScrollView.contentView.superview.frame.size.height * _zoomLevel;
		self.enclosingScrollView.contentView.frame = clipFrame;
		
		[self.editorDelegate ensureLayout];
	}
		
	[self setInsets];
	[_editorDelegate updateLayout];
	[_editorDelegate ensureLayout];
	[_editorDelegate ensureCaret];
}

/// `zoom:true` zooms in, `zoom:false` zooms out
- (void)zoom:(bool)zoomIn {
	// For some reason, setting 1.0 scale for NSTextView causes weird sizing bugs, so we will use something that will never produce 1.0...... omg lol help
	CGFloat newMagnification = _zoomLevel;
	if (zoomIn) newMagnification += 0.04;
	else newMagnification -= 0.04;

	[self adjustZoomLevel:newMagnification];
	
	// Save adjusted zoom level
	[BeatUserDefaults.sharedDefaults saveFloat:_zoomLevel forKey:BeatSettingMagnification];
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag
{
	CGFloat oldScaleFactor = _scaleFactor;
	
	if (_scaleFactor != newScaleFactor)
	{
		NSSize curDocFrameSize, newDocBoundsSize;
		NSView *clipView = self.superview;
		
		_scaleFactor = newScaleFactor;
		
		// Get the frame.  The frame must stay the same.
		curDocFrameSize = clipView.frame.size;
		
		// The new bounds will be frame divided by scale factor
		newDocBoundsSize.width = curDocFrameSize.width;
		newDocBoundsSize.height = curDocFrameSize.height / newScaleFactor;
		
		NSRect newFrame = NSMakeRect(0, 0, newDocBoundsSize.width, newDocBoundsSize.height);
		clipView.frame = newFrame;
	}
	
	[self scaleChanged:oldScaleFactor newScale:newScaleFactor];
	
	// Set minimum size for text view when Outline view size is dragged
	[_editorDelegate setSplitHandleMinSize:self.documentWidth * _zoomLevel];
}

- (void)scaleChanged:(CGFloat)oldScale newScale:(CGFloat)newScale
{
	// Thank you, Mark Munz @ stackoverflow
	CGFloat scaler = newScale / oldScale;
	
	[self scaleUnitSquareToSize:NSMakeSize(scaler, scaler)];
	[self.layoutManager ensureLayoutForTextContainer:self.textContainer];
	
	_scaleFactor = newScale;
}


#pragma mark - Copy-paste

-(void)copy:(id)sender {
	NSPasteboard *pasteBoard = NSPasteboard.generalPasteboard;
	[pasteBoard clearContents];
	
	// We create both a plaintext string & a custom pasteboard object
	NSString *string = [self.string substringWithRange:self.selectedRange];
	NSMutableAttributedString* attrString = [self.attributedString attributedSubstringFromRange:self.selectedRange].mutableCopy;
	
	// Remove the represented line, because it can't be encoded
	if (attrString.length) [attrString removeAttribute:@"representedLine" range:NSMakeRange(0, attrString.length)];
	
	BeatPasteboardItem *item = [[BeatPasteboardItem alloc] initWithAttrString:attrString];
	
	// Copy them on pasteboard
	NSArray *copiedObjects = @[item, string];
	[pasteBoard writeObjects:copiedObjects];
}

-(NSArray<NSPasteboardType> *)writablePasteboardTypes {
	return @[NSBundle.mainBundle.bundleIdentifier];
}
-(NSArray<NSPasteboardType> *)readablePasteboardTypes {
	return [NSArray arrayWithObjects:NSBundle.mainBundle.bundleIdentifier, NSPasteboardTypeString, nil];
}

-(void)paste:(id)sender {
	
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSArray *classArray = @[NSString.class, BeatPasteboardItem.class];
	NSDictionary *options = [NSDictionary dictionary];
	
	// See if we can read anything from the pasteboard
	BOOL ok = [pasteboard canReadItemWithDataConformingToTypes:[self readablePasteboardTypes]];

	if (ok) {
		// We know for a fact that if the data originated from beat, the FIRST item will be
		// the custom object we created when copying. So let's just pick the first one of the
		// readable objects.
		
		NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
		
		id obj = objectsToPaste[0];
		
		if ([obj isKindOfClass:NSString.class]) {
			NSString* result = [BeatPasteboardItem sanitizeString:obj];
			[self.editorDelegate replaceRange:self.selectedRange withString:result];
			return;

		}
		else if ([obj isKindOfClass:BeatPasteboardItem.class]) {
			// Paste custom Beat pasteboard data
			BeatPasteboardItem *pastedItem = obj;
			NSAttributedString *str = pastedItem.attrString;
			
			// Replace string content with an undoable method
			NSInteger pos = self.selectedRange.location;
			[self.editorDelegate replaceRange:self.selectedRange withString:str.string];
			
			// Enumerate custom attributes from copied text and render backgrounds as needed
			NSMutableSet *linesToRender = NSMutableSet.new;
			[str enumerateAttributesInRange:(NSRange){0, str.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
				// Copy *any* stored attributes
				if ([BeatAttributes containsCustomAttributes:attrs]) {
					[self.textStorage addAttributes:attrs range:NSMakeRange(pos + range.location, range.length)];
					Line *l = [self.parser lineAtPosition:pos + range.location];
					[linesToRender addObject:l];
				}
				/*
				if (attrs[BeatReview.attributeKey] != nil || attrs[BeatRevisions.attributeKey] != nil || attrs[BeatTagging.attributeKey] != nil) {
					
				}
				*/
			}];
			
			// Render background for pasted text where needed
			for (Line* l in linesToRender) {
				[self.editorDelegate renderBackgroundForLine:l clearFirst:YES];
			}
		}
		else {
			[super paste:sender];
		}
	}
}

#pragma mark - Layout Manager delegation

-(void)redrawAllGlyphs {
	[self.layoutManager invalidateGlyphsForCharacterRange:(NSRange){0, self.string.length} changeInLength:0 actualCharacterRange:nil];
	[self.layoutManager invalidateLayoutForCharacterRange:(NSRange){0, self.string.length} actualCharacterRange:nil];
}

-(void)updateMarkupVisibility {
	if (!_editorDelegate.hideFountainMarkup || _editorDelegate.documentIsLoading) return;
	if (!self.string.length) return;
	
	Line* line = self.editorDelegate.currentLine;
	static Line* prevLine;
		
	if (line != prevLine) {
		// If the line changed, let's redraw the range
		bool lineInRange = (NSMaxRange(line.textRange) <= self.string.length);
		bool prevLineInRange = (NSMaxRange(prevLine.textRange) <= self.string.length);
		
		if (lineInRange) [self.layoutManager invalidateGlyphsForCharacterRange:line.textRange changeInLength:0 actualCharacterRange:nil];
		if (prevLineInRange) [self.layoutManager invalidateGlyphsForCharacterRange:prevLine.textRange changeInLength:0 actualCharacterRange:nil];
		if (prevLineInRange) [self.layoutManager invalidateLayoutForCharacterRange:prevLine.textRange actualCharacterRange:nil];
		if (lineInRange) [self.layoutManager invalidateLayoutForCharacterRange:line.textRange actualCharacterRange:nil];
	}
	
	prevLine = line;
}

-(void)toggleHideFountainMarkup
{
	[self.layoutManager invalidateGlyphsForCharacterRange:(NSRange){ 0, self.string.length } changeInLength:0 actualCharacterRange:nil];
	[self updateMarkupVisibility];
}

-(NSDictionary<NSAttributedStringKey,id> *)layoutManager:(NSLayoutManager *)layoutManager shouldUseTemporaryAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs forDrawingToScreen:(BOOL)toScreen atCharacterIndex:(NSUInteger)charIndex effectiveRange:(NSRangePointer)effectiveCharRange
{
	return attrs;
}

-(NSUInteger)layoutManager:(NSLayoutManager *)layoutManager shouldGenerateGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props characterIndexes:(const NSUInteger *)charIndexes font:(NSFont *)aFont forGlyphRange:(NSRange)glyphRange
{
	
	Line *line = [self.editorDelegate.parser lineAtPosition:charIndexes[0]];
	if (line == nil) return 0;
	
	LineType type = line.type;
	bool currentlyEditing = NSLocationInRange(self.selectedRange.location, line.range);

	// Ignore story markers
	if (line.type == section || line.type == synopse) return 0;
	
	// Clear formatting characters etc.
	NSMutableIndexSet *muIndices = [line formattingRangesWithGlobalRange:YES includeNotes:NO].mutableCopy;
	[muIndices addIndexesInRange:(NSRange){ line.position + line.sceneNumberRange.location, line.sceneNumberRange.length }];
	if (line.colorRange.length) [muIndices addIndexesInRange:(NSRange){ line.position + line.colorRange.location, line.colorRange.length }];
	
	// Marker indices
	NSIndexSet *markerIndices = [NSIndexSet indexSetWithIndexesInRange:(NSRange){ line.position + line.markerRange.location, line.markerRange.length }];
	
	// Nothing to do
	if (muIndices.count == 0 && markerIndices.count == 0 &&
		!(type == heading || type == transitionLine || type == character) &&
		!(line.string.containsOnlyWhitespace && line.string.length > 1)
		) return 0;
	
	// Get string reference
	NSUInteger location = charIndexes[0];
	NSUInteger length = glyphRange.length;
	CFStringRef str = (__bridge CFStringRef)[self.textStorage.string substringWithRange:(NSRange){ location, length }];
	
	// Create a mutable copy
	CFMutableStringRef modifiedStr = CFStringCreateMutable(NULL, CFStringGetLength(str));
	CFStringAppend(modifiedStr, str);
	
	// If it's a heading or transition, render it uppercase
	if (type == heading || type == transitionLine || type == shot) {
		CFStringUppercase(modifiedStr, NULL);
	}
	
	// Modified properties
	NSGlyphProperty *modifiedProps;
	
	if (line.string.containsOnlyWhitespace && line.string.length >= 2) {
		// Show bullets instead of spaces on lines which are only whitespace
		
		CFStringFindAndReplace(modifiedStr, CFSTR(" "), CFSTR("•"), CFRangeMake(0, CFStringGetLength(modifiedStr)), 0);
		CGGlyph *newGlyphs = GetGlyphsForCharacters((__bridge CTFontRef)(aFont), modifiedStr);
		[self.layoutManager setGlyphs:newGlyphs properties:props characterIndexes:charIndexes font:aFont forGlyphRange:glyphRange];
		free(newGlyphs);
	}
	
	else if (_editorDelegate.hideFountainMarkup && !currentlyEditing) {
		// Hide markdown characters for the line we're not currently editing
		
		modifiedProps = (NSGlyphProperty *)malloc(sizeof(NSGlyphProperty) * glyphRange.length);
				
		for (NSInteger i = 0; i < glyphRange.length; i++) {
			NSUInteger index = charIndexes[i];
			NSGlyphProperty prop = props[i];
			
			if ([muIndices containsIndex:index]) {
				prop |= NSGlyphPropertyNull;
			}
			
			modifiedProps[i] = prop;
		}
		
		// Create the new glyphs
		CGGlyph *newGlyphs = GetGlyphsForCharacters((__bridge CTFontRef)(aFont), modifiedStr);
		
		[self.layoutManager setGlyphs:newGlyphs properties:modifiedProps characterIndexes:charIndexes font:aFont forGlyphRange:glyphRange];
		free(newGlyphs);
		free(modifiedProps);
		
	} else {
		// Create the new glyphs
		CGGlyph *newGlyphs = GetGlyphsForCharacters((__bridge CTFontRef)(aFont), modifiedStr);
		[self.layoutManager setGlyphs:newGlyphs properties:props characterIndexes:charIndexes font:aFont forGlyphRange:glyphRange];
		free(newGlyphs);
	}
		
	CFRelease(modifiedStr);
	return glyphRange.length;
}

CGGlyph* GetGlyphsForCharacters(CTFontRef font, CFStringRef string)
{
	// Get the string length.
	CFIndex count = CFStringGetLength(string);
 
	// Allocate our buffers for characters and glyphs.
	unichar *characters = (UniChar *)malloc(sizeof(UniChar) * count);
	CGGlyph *glyphs = (CGGlyph *)malloc(sizeof(CGGlyph) * count);
 
	// Get the characters from the string.
	CFStringGetCharacters(string, CFRangeMake(0, count), characters);
 
	// Get the glyphs for the characters.
	CTFontGetGlyphsForCharacters(font, characters, glyphs, count);
	
	free(characters);
	
	return glyphs;
}


#pragma mark - Text Storage delegation

-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
	[_editorDelegate textStorage:textStorage didProcessEditing:editedMask range:editedRange changeInLength:delta];
}

- (void)layoutManagerDidInvalidateLayout:(NSLayoutManager *)sender {
	//if (_editorDelegate.documentIsLoading) return;
	//[self refreshLayoutElementsFrom:self.editorDelegate.lastChangedRange.location];
	/*
	if (_editorDelegate.documentIsLoading) return;
	
	NSInteger numberOfLines = [self numberOfLines];
	
	if (self.linesBeforeLayout != numberOfLines || self.editorDelegate.lastChangedRange.length > 2 ||
		self.editorDelegate.currentLine.type == heading) {
		[self refreshLayoutElementsFrom:self.editorDelegate.lastChangedRange.location];
	}
	else if (_editorDelegate.revisionMode) {
		// If the user is revising stuff, let's enforce refreshing the elements.
		[self refreshLayoutElementsFrom:self.editorDelegate.lastChangedRange.location];
	}
	
	self.linesBeforeLayout = numberOfLines;
	 */
}

- (NSInteger)numberOfLines {
	// This causes jitter. Unusable.
	
	NSLayoutManager *layoutManager = self.layoutManager;
	NSString *string = self.string;
	NSUInteger numberOfLines, index, stringLength = string.length;
		
	for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++) {
		NSRange tmpRange;
		
		[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&tmpRange withoutAdditionalLayout:YES];
		index = NSMaxRange(tmpRange);
	}
	
	return numberOfLines;
}

- (NSRange)lineFragmentRangeAtLocation:(NSUInteger)location {
	NSRange tmpRange;
	[self.layoutManager lineFragmentRectForGlyphAtIndex:location
										 effectiveRange:&tmpRange];
	return tmpRange;
}
- (NSMutableSet*)lineFragmentRangesFrom:(NSUInteger)location {
	NSMutableSet *lineFragments = NSMutableSet.new;
	for (NSInteger index = location; index < self.string.length;) {
		NSRange fragmentRange = [self lineFragmentRangeAtLocation:index];
		[lineFragments addObject:[NSNumber valueWithRange:fragmentRange]];
		index = NSMaxRange(fragmentRange);
	}
	return lineFragments;
}


/*
- (nullable NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange {
	<#code#>
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange {
	<#code#>
}
*/


#pragma mark - Spell Checking

- (void)handleTextCheckingResults:(NSArray<NSTextCheckingResult *> *)results forRange:(NSRange)range types:(NSTextCheckingTypes)checkingTypes options:(NSDictionary<NSTextCheckingOptionKey,id> *)options orthography:(NSOrthography *)orthography wordCount:(NSInteger)wordCount {
	
	//Line *currentLine = _editorDelegate.currentLine;
	Line *line = [self.editorDelegate.parser lineAtIndex:range.location];
	
	// Avoid capitalizing parentheticals
	if (line.isAnyParenthetical) {
		NSMutableArray<NSTextCheckingResult*> *newResults;
		
		NSString *textToChange = [self.textStorage.string substringWithRange:range].uppercaseString;
		
		for (NSTextCheckingResult *result in results) {
			// If the result type is NOT correction and the replacement IS NOT EQUAL to the original string, save for case,
			// add the result. Otherwise we'll just skip it.
			if (!(result.resultType == NSTextCheckingTypeCorrection && [textToChange isEqualToString:result.replacementString.uppercaseString])) {
				[newResults addObject:result];
			}
		}
		[super handleTextCheckingResults:newResults forRange:range types:checkingTypes options:options orthography:orthography wordCount:wordCount];
	} else if ((line.isAnyCharacter || line.type == heading) && self.popupMode == Autocomplete) {
		// Do nothing when heading autocomplete is visible
	} else {
		// default behaviors, including auto-correct
		[super handleTextCheckingResults:results forRange:range types:checkingTypes options:options orthography:orthography wordCount:wordCount];
	}
}


#pragma mark - Text storage delegation

- (ContinuousFountainParser*)parser {
	return self.editorDelegate.parser;
}

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
