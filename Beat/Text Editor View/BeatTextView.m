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

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2-Swift.h>

#import <Carbon/Carbon.h> // For keyboard input source functions

#import "BeatTextView.h"
#import "BeatTextView+Popovers.h"
#import "BeatTextView+MouseEvents.h"
#import "BeatTextView+FocusMode.h"
#import "BeatTextView+TypewriterMode.h"
#import "BeatTextView+SelectionEvents.h"

#import "BeatPasteboardItem.h"
#import "Beat-Swift.h"
#import "BeatClipView.h"

// Maximum results for autocomplete
#define MAX_RESULTS 10

// Autocomplete popover settings
#define INTERCELL_SPACING NSMakeSize(20.0, 3.0)
#define POPOVER_WIDTH 300.0
#define POPOVER_PADDING 0.0
#define POPOVER_APPEARANCE NSAppearanceNameVibrantDark
#define POPOVER_TEXTCOLOR [NSColor whiteColor]

// Word boundaries for autocompletion suggestions
#define WORD_BOUNDARY_CHARS [NSCharacterSet newlineCharacterSet]

// Default inset for text view
#define TEXT_INSET_TOP 50


static NSTouchBarItemIdentifier ColorPickerItemIdentifier = @"com.TouchBarCatalog.colorPicker";

#pragma mark - Autocompleting
@interface BeatTextView () <NSTextFinderClient, BeatTextEditor>

/// Touch bar view
@property (nonatomic, weak) IBOutlet NSTouchBar *touchBar;

/// Text container tracking area
@property (nonatomic) NSTrackingArea *trackingArea;

@property (nonatomic) bool updatingSceneNumberLabels; /// YES if scene number labels are being updated

/// Validated menu items
@property (nonatomic) NSArray<BeatValidationItem*>* validatedMenuItems;

@property (weak, nonatomic) IBOutlet NSScrollView* minimapContainer;
@property (nonatomic) IBOutlet MinimapTextView* minimapView;

@end

@implementation BeatTextView

+ (CGFloat)linePadding {
	return 100.0;
}

-(instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	[self layoutSetup];
	
	/*
	self.textFinder = NSTextFinder.new;
	self.textFinder.client = self;
	[self.textFinder setIncrementalSearchingEnabled:true];
	*/
	
	return self;
}

/// Basic text view setup
- (void)layoutSetup
{
	[self setupLayoutManager];
	
	// Does this break anything?
	self.baseWritingDirection = NSWritingDirectionNatural;
	
	// Setup magnification
	[self setupZoom];
	
	// Restore spell checking setting. A hack to see if the system returns a different value.
	if (self.continuousSpellCheckingEnabled) {
		self.continuousSpellCheckingEnabled = [BeatUserDefaults.sharedDefaults getBool:BeatSettingContinuousSpellChecking];
	}
	
	self.editable = YES;
	self.textContainer.widthTracksTextView = NO;
	self.textContainer.heightTracksTextView = NO;
	
	self.automaticDataDetectionEnabled = NO;
	self.automaticQuoteSubstitutionEnabled = NO;
	self.automaticDashSubstitutionEnabled = NO;
	
	self.usesFindBar = true;
	self.usesFindPanel = false;
}

/// Loads and sets up our custom layout manager, `BeatLayoutManager`
- (void)setupLayoutManager
{	
	// Set text storage delegate
	self.textStorage.delegate = self;
	
	// Load custom layout manager and set a bit bigger line fragment padding
	// to fit our revision markers in the margin
	BeatLayoutManager *layoutMgr = BeatLayoutManager.new;
	[self.textContainer replaceLayoutManager:layoutMgr];
	
	self.textContainer.lineFragmentPadding = BeatTextView.linePadding;
}

- (void)setupMinimap
{
	/*
	_minimapView = [MinimapTextView.alloc initWithTextStorage:self.textStorage scrollView:_minimapContainer connectedScrollView:self.enclosingScrollView];
	_minimapView.drawsBackground = true;
	_minimapView.backgroundColor = [ThemeManager.sharedManager.marginColor colorWithAlphaComponent:0.5];

	//_minimap = [BeatMinimapView createMinimapWithEditorDelegate:self.editorDelegate textStorage:self.textStorage editorView:self];
	
	[_minimapContainer setDocumentView:_minimapView];
	_minimapView.frame = CGRectMake(0.0, 0.0, _minimapContainer.frame.size.width, _minimapView.frame.size.height);
	_minimapView.autoresizingMask = NSViewHeightSizable | NSViewMinXMargin;
	*/
	//[_minimap resizeMinimap];
}

- (void)awakeFromNib
{
	// We are connecting the editor delegate via IBOutlet, so we need to forward it to layout manager here.
	if ([self.layoutManager isKindOfClass:BeatLayoutManager.class]) {
		((BeatLayoutManager*)self.layoutManager).editorDelegate = self.editorDelegate;
		self.layoutManager.delegate = (id<NSLayoutManagerDelegate>)self.layoutManager;
	}

	
	self.matches = NSMutableArray.array;
	self.pageBreaks = NSArray.new;
	
	// The previous position of caret
	self.lastPos = -1;
		
	// Register dragged types
	[self registerForDraggedTypes:@[BeatPasteboardItem.pasteboardType]];
		
	// Observer for selection change. It's posted to text view delegate as well, but we'll handle
	// popovers etc. here.
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didChangeSelection:) name:@"NSTextViewDidChangeSelectionNotification" object:self];
	
	// For future generations
	[self setupMinimap];
}

/// General setup. Call from editor instance.
-(void)setup
{
	// Style
	self.font = _editorDelegate.fonts.regular;
	[self.textStorage setFont:_editorDelegate.fonts.regular];
		
	self.layoutManager.allowsNonContiguousLayout = YES;
	NSSpellChecker.sharedSpellChecker.automaticallyIdentifiesLanguages = true;
	
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	paragraphStyle.maximumLineHeight = self.editorDelegate.editorStyles.page.lineHeight;
	paragraphStyle.minimumLineHeight = self.editorDelegate.editorStyles.page.lineHeight;
	paragraphStyle.lineSpacing = 1.0;
	[self setDefaultParagraphStyle:paragraphStyle];
	
	// Setup mouse cursor positions
	_trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];
	[self.window setAcceptsMouseMovedEvents:YES];
	[self addTrackingArea:_trackingArea];
	
	[self setInsets];
	
	// Setup popovers for autocomplete, tagging, etc.
	[self setupPopovers];
	
	// Make the text view first responder at start
	[self.editorDelegate.documentWindow makeFirstResponder:self];
	
	// Setup focus mode
	[self setupFocusMode];
	
	// Setup validated menu items
	[self setupValidationItems];
}

-(void)removeFromSuperview
{
	[self.popoverController.tableView removeFromSuperview];
	self.popoverController.items = @[];
	self.popoverController = nil;

	[NSNotificationCenter.defaultCenter removeObserver:self];
	[super removeFromSuperview];
}


#pragma mark - Window interactions

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

NSString *keyCodeToString(uint16_t keyCode) {
	// Get the current keyboard layout
	TISInputSourceRef inputSource = TISCopyCurrentKeyboardLayoutInputSource();
	if (!inputSource) return nil;

	// Get the layout data
	CFDataRef layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData);
	if (!layoutData) return nil;

	const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
	if (!keyboardLayout) return nil;

	// Translate the keycode to a string
	UInt32 deadKeyState = 0;
	UniChar chars[4]; // Supports up to 4 characters (e.g., accented keys)
	UniCharCount realLength;
	OSStatus status = UCKeyTranslate(keyboardLayout,
									 keyCode,
									 kUCKeyActionDisplay,
									 0, // No modifiers
									 LMGetKbdType(),
									 kUCKeyTranslateNoDeadKeysBit,
									 &deadKeyState,
									 sizeof(chars) / sizeof(UniChar),
									 &realLength,
									 chars);

	if (status != noErr) return nil;

	return [NSString stringWithCharacters:chars length:realLength];
}

-(void)keyUp:(NSEvent *)event
{
	if (self.typewriterMode) [self typewriterScroll];
}

- (void)keyDown:(NSEvent *)event
{
	//NSString* key = [NSString stringWithFormat:@"'%@'", keyCodeToString(event.keyCode)];
	//[BeatConsole.shared logToConsole:key pluginName:@"DEBUG" context:self.editorDelegate];
	
	// Close info popover when typing
	if (self.infoPopover.isShown) [self.infoPopover close];

	if (self.editorDelegate.contentLocked) {
		// Show lock status for alphabet keys
		NSString * const character = [event charactersIgnoringModifiers];
		if (character.length > 0) {
			unichar c = [character characterAtIndex:0];
			if ([NSCharacterSet.letterCharacterSet characterIsMember:c]) [self.editorDelegate showLockStatus];
		}
	}

	BOOL shouldComplete = YES;
	BOOL preventDefault = NO;

	if ((self.popoverController.isShown || self.infoPopover.isShown) && event.keyCode == 53) {
		// Esc key pressed when popovers are visible
		[self closePopovers];
		preventDefault = true;
	} else if (self.popoverController.isShown) {
		// Forward events to popover
		preventDefault = [self.popoverController keyPressedWithKeyCode:event.keyCode];
	} else {
		switch (event.keyCode) {
			case 51:
				// Delete
				[self closePopovers];
				shouldComplete = NO;
				break;
				
			case 53:
				// Esc
				[self.editorDelegate cancelOperation:self];
				preventDefault = YES;
				break;
				
			case 48: {
				// If there are no flags, we'll send the tab key to delegate. It should rather be handled here though.
				NSUInteger flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
				if (flags == 0 || flags == NSEventModifierFlagCapsLock) [self.editorDelegate handleTabPress];
				
				// We'll never allow tab to be inserted
				preventDefault = YES;
				break;
			}
				
			case 36:
				// Return key
				if (event.modifierFlags) {
					NSUInteger flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
					
					// Alt was pressed, show force element menu
					// Uh... wouldn't it be more sensible to have this as an IBAction?
					if (flags == NSEventModifierFlagOption) {
						[self showForceElementMenu];
						preventDefault = YES;
						break;
					}
				}
				break;
		}
	}
		
	// Skip super methods when needed
	if (preventDefault) return;
	
	// Run superclass method for the event (ie. do what the keyboard says)
	[super keyDown:event];
	
	// Run completion block
	if (shouldComplete && self.editorDelegate.mode != TaggingMode) {
		if (self.automaticTextCompletionEnabled) [self showAutocompletions];
	} else if (!shouldComplete && self.popoverController.isShown) {
		[self.popoverController close];
	}
}


-(NSRect)adjustScroll:(NSRect)newVisible
{
	if (self.typewriterMode && !_scrolling && self.selectionAtEnd) {
		if (self.selectedRange.location == self.string.length) {
			return self.enclosingScrollView.documentVisibleRect;
		}
	}
	
	return [super adjustScroll:newVisible];
}


#pragma mark - Autocomplete & data source

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	if ([self.delegate respondsToSelector:@selector(textView:completions:forPartialWordRange:indexOfSelectedItem:)]) {
		return [self.delegate textView:self completions:@[] forPartialWordRange:charRange indexOfSelectedItem:index];
	}
	return @[];
}



#pragma mark - Setting insets on resize

-(void)viewDidEndLiveResize {
	//[super viewDidEndLiveResize];
	[self setInsets];
}


#pragma mark - Custom drawing

/// Redraws both the view AND ensures layout for text container. Used to refresh appearance.
-(void)redrawUI
{
	[self displayRect:self.frame];
	[self.layoutManager ensureLayoutForTextContainer:self.textContainer];
}

/// Redraws all glyphs in the text view. Used when loading the text view with markup hiding on.
-(void)redrawAllGlyphs
{
	[self.layoutManager invalidateGlyphsForCharacterRange:(NSRange){0, self.string.length} changeInLength:0 actualCharacterRange:nil];
	[self.layoutManager invalidateLayoutForCharacterRange:(NSRange){0, self.string.length} actualCharacterRange:nil];
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


#pragma mark - Scaling

- (void)scaleUnitSquareToSize:(NSSize)newUnitSize
{
	[super scaleUnitSquareToSize:newUnitSize];
}

- (CGFloat)documentWidth
{
	CGFloat width = [_editorDelegate.editorStyles.page defaultWidthWithPageSize:_editorDelegate.pageSize];
	CGFloat padding = self.textContainer.lineFragmentPadding;
	
	return width + padding * 2 + 1.0;
}

- (CGFloat)setInsets
{
	// Top/bottom insets
	if (self.typewriterMode) {
		// Calculate half of the viewport minus font size
		self.textInsetY = self.enclosingScrollView.documentVisibleRect.size.height / 2 - _editorDelegate.fonts.regular.pointSize;
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


#pragma mark - Context Menu

-(NSMenu *)menu
{
	static NSMenu* menu;
	if (menu == nil) {
		menu = [super menu];
		[menu addItem:NSMenuItem.separatorItem];
		
		for (NSMenuItem* item in self.contextMenu.itemArray) [menu addItem:item.copy];
	}
	
	return menu;
}


#pragma mark - Scrolling

- (void)scrollPoint:(NSPoint)point
{
	[super scrollPoint:point];
}

- (void)scrollRangeToVisible:(NSRange)range
{
	if (self.editorDelegate.formatting.formatting) return;
	[super scrollRangeToVisible:range];
}

/// Non-animated scrolling
- (void)scrollToRange:(NSRange)range
{
	NSRect rect = [self rectForRange:range];
	CGFloat y = _zoomLevel * (rect.origin.y + rect.size.height) + self.textContainerInset.height * (_zoomLevel) - self.enclosingScrollView.contentView.bounds.size.height / 2;
	
	[self.enclosingScrollView.contentView.animator setBoundsOrigin:NSMakePoint(0, y)];
}

- (void)ensureRangeIsVisible:(NSRange)range
{
	NSRect rect = [self rectForRange:range];
	
	CGFloat changeY = rect.origin.y - rect.size.height;
	if (changeY < self.visibleRect.origin.y || changeY > self.visibleRect.origin.y + self.visibleRect.size.height) {
		[self scrollToRange:range];
	}
}

/// Animated scrolling with a callback
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock
{
	NSRect rect = [self rectForRange:range];
	CGFloat y = _zoomLevel * (rect.origin.y + rect.size.height) + self.textContainerInset.height * (_zoomLevel) - self.enclosingScrollView.contentView.bounds.size.height / 2;
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
		// Start some animations.
		[self.enclosingScrollView.contentView.animator setBoundsOrigin:NSMakePoint(0, y)];
	} completionHandler:^{
		if (callbackBlock != nil) callbackBlock();
	}];
}

- (void)scrollToLine:(Line *)line
{
	if (line == nil) return;
	
	self.selectedRange = line.textRange;
	[self scrollToRange:line.textRange];
}


- (void)scrollToScene:(OutlineScene *)scene
{
	if (scene == nil) return;
	
	self.selectedRange = scene.line.textRange;
	[self scrollToRange:scene.line.textRange];
}



#pragma mark - Zooming
/**
 We are using `scaleUnitSquareToSize:` rather than magnifying the scroll view, because this way, we can avoid positioning weirdness when zooming very close.
 It's a bit convoluted, but works.
 */

- (void)setupZoom
{
	// This resets the zoom to the saved setting
	self.zoomLevel = [BeatUserDefaults.sharedDefaults getFloat:BeatSettingMagnification];
	
	_scaleFactor = 1.0;
	[self setScaleFactor:_zoomLevel adjustPopup:false];
	[self.editorDelegate updateLayout];
}

- (void)resetZoom
{
	[BeatUserDefaults.sharedDefaults resetToDefault:BeatSettingMagnification];
	CGFloat zoomLevel = [BeatUserDefaults.sharedDefaults getFloat:BeatSettingMagnification];
	[self adjustZoomLevel:zoomLevel];
}


/// Adjust zoom by a delta value
- (void)adjustZoomLevelBy:(CGFloat)value
{
	CGFloat newMagnification = _zoomLevel + value;
	[self adjustZoomLevel:newMagnification];
}

/// Sets the `zoomLevel` ivar. Does NOT enforce redrawing and layout.
- (void)setZoomLevel:(CGFloat)zoomLevel
{
	_zoomLevel = clamp(zoomLevel, 0.8, 3.2);
}

/// Set zoom level for the editor view, automatically clamped
- (void)adjustZoomLevel:(CGFloat)level
{
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
	[self ensureCaret];
}

/// `zoom:true` zooms in, `zoom:false` zooms out
- (void)zoom:(bool)zoomIn
{
	CGFloat newMagnification = _zoomLevel;
	if (zoomIn) newMagnification += 0.05;
	else newMagnification -= 0.05;
	
	[self adjustZoomLevel:newMagnification];
	
	// Save adjusted zoom level
	[BeatUserDefaults.sharedDefaults saveFloat:_zoomLevel forKey:BeatSettingMagnification];
}

/// Sets a new scale factor
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
	[_editorDelegate setSplitHandleMinSize:(self.documentWidth - BeatTextView.linePadding * 2) * _zoomLevel];
}

/// Actually scales the view
- (void)scaleChanged:(CGFloat)oldScale newScale:(CGFloat)newScale
{
	// Thank you, Mark Munz @ stackoverflow
	CGFloat scaler = newScale / oldScale;
	
	[self scaleUnitSquareToSize:NSMakeSize(scaler, scaler)];
	[self.layoutManager ensureLayoutForTextContainer:self.textContainer];
	
	_scaleFactor = newScale;
}

double clamp(double d, double min, double max)
{
	const double t = d < min ? min : d;
	return t > max ? max : t;
}


#pragma mark - Copy-paste

- (NSAttributedString*)attributedStringForPasteboardFromRange:(NSRange)range
{
	// We create both a plaintext string & a custom pasteboard object
	NSMutableAttributedString* attrString = [self.attributedString attributedSubstringFromRange:range].mutableCopy;
	
	// Remove the represented line, because it can't be encoded
	if (attrString.length) [attrString removeAttribute:@"representedLine" range:NSMakeRange(0, attrString.length)];
	
	return attrString;
}

-(void)copy:(id)sender {
	NSPasteboard* pboard = NSPasteboard.generalPasteboard;
	[pboard clearContents];
	
	NSAttributedString* attrString = [self attributedStringForPasteboardFromRange:self.selectedRange];
	
	BeatPasteboardItem *item = [[BeatPasteboardItem alloc] initWithAttrString:attrString];
	[pboard writeObjects:@[item, attrString.string]];
}

- (NSArray<NSPasteboardType>*)acceptableDragTypes
{
	NSMutableArray* types = [NSMutableArray arrayWithArray:[super acceptableDragTypes]];
	[types insertObject:BeatPasteboardItem.pasteboardType atIndex:0];
	return types;
}

-(NSArray<NSPasteboardType>*)writablePasteboardTypes
{
	NSMutableArray* types = [NSMutableArray arrayWithArray:[super writablePasteboardTypes]];
	[types insertObject:BeatPasteboardItem.pasteboardType atIndex:0];
	return types;
}

-(NSArray<NSPasteboardType>*)readablePasteboardTypes
{
	NSMutableArray* types = [NSMutableArray arrayWithArray:[super readablePasteboardTypes]];
	[types insertObject:BeatPasteboardItem.pasteboardType atIndex:0];
	// No idea why these are not availableby default
	[types insertObject:@"public.utf16-plain-text" atIndex:1];
	[types insertObject:@"public.utf8-plain-text" atIndex:2];
	return types;
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard type:(NSPasteboardType)type
{
	if ([type isEqualToString:BeatPasteboardItem.pasteboardType]) {
		[pboard clearContents];
		
		// Get attributed string
		NSAttributedString* attrStr = [self attributedStringForPasteboardFromRange:self.selectedRange];
		
		BeatPasteboardItem* item = [BeatPasteboardItem.alloc initWithAttrString:attrStr];
		[pboard writeObjects:@[item]];
		return true;
	}
	
	return [super writeSelectionToPasteboard:pboard type:type];
}

- (void)draggingEnded:(id<NSDraggingInfo>)sender
{
	NSPasteboard *pasteboard = [sender draggingPasteboard];
	NSArray<NSPasteboardType> *types = [pasteboard types];
	
	// If we've dragged a Beat pasteboard value, let's replace our selection with the correct attributed string.
	if ([types containsObject:BeatPasteboardItem.pasteboardType]) {
		BeatPasteboardItem *item = [pasteboard readObjectsForClasses:@[BeatPasteboardItem.class] options:nil][0];
		if (item.attrString) {
			[self.textStorage replaceCharactersInRange:self.selectedRange withAttributedString:item.attrString];
		}
	}
}

-(void)paste:(id)sender
{
	NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
	NSArray *classArray = @[NSString.class, BeatPasteboardItem.class];
	
	NSInteger length = 0;
	
	// See if we can read anything from the pasteboard
	if ([pasteboard canReadItemWithDataConformingToTypes:[self readablePasteboardTypes]]) {
		// We know for a fact that if the data originated from beat, the FIRST item will be
		// the custom object we created when copying. So let's just pick the first one of the
		// readable objects.
		
		NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:@{}];
		id obj = objectsToPaste[0];
				
		if ([obj isKindOfClass:NSString.class]) {
			// Plain text
			NSString* result = [BeatPasteboardItem sanitizeString:obj];
			[self.editorDelegate.textActions replaceRange:self.selectedRange withString:result];
			length = result.length;
		} else if ([obj isKindOfClass:BeatPasteboardItem.class]) {
			// Paste custom Beat pasteboard data
			BeatPasteboardItem *pastedItem = obj;
			NSAttributedString *str = pastedItem.attrString;
			
			[self.editorDelegate.textActions replaceRange:self.selectedRange withAttributedString:str];
			length = str.length;
		} else {
			// If everything else fails, try normal paste
			[super paste:sender];
		}
	}
	
	//[(BeatLayoutManager*)self.layoutManager ensureLayoutForLinesInRange:NSMakeRange(location, length)];
	
	// If we didn't call super, the text view might not scroll back to caret
	[self scrollRangeToVisible:self.selectedRange];
}

/*
/// This is a bit convoluted method. It checks the current pasteboard items and prioritizes the internal Beat type.
- (id)readablePasteboardItem
{
	NSArray *classArray = @[NSString.class, BeatPasteboardItem.class];
	NSArray *objects = [NSPasteboard.generalPasteboard readObjectsForClasses:classArray options:@{}];
	
	id itemToPaste;
	
	// Iterate from first to last if we can see a Beat-compatible pasteboard item in the board
	for (NSInteger i=objects.count-1; i>=0; i--) {
		id item = objects[i];
		
		if ([item isKindOfClass:BeatPasteboardItem.class]) {
			itemToPaste = item; break;
		} else if ([item isKindOfClass:NSString.class]) {
			itemToPaste = item;
		}
	}
	
	if (itemToPaste == nil) itemToPaste = objects[0];
	return itemToPaste;
}
 */


#pragma mark - Validate menu items

- (void)setupValidationItems
{
	self.validatedMenuItems = @[
		[BeatValidationItem.alloc initWithAction:@selector(toggleTypewriterMode:) setting:BeatSettingTypewriterMode target:BeatUserDefaults.sharedDefaults],
	];
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	for (BeatValidationItem *item in self.validatedMenuItems) {
		if (menuItem.action == item.selector) {
			bool on = [item validate];
			if (on) [menuItem setState:NSOnState];
			else [menuItem setState:NSOffState];
		}
	}
	
	if (menuItem.action == @selector(toggleFocusMode:)) {
		return [self validateFocusMode:menuItem];
	}
	
	return [super validateMenuItem:menuItem];
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem {
	// Remove context menu for layout orientation change
	if (anItem.action == @selector(changeLayoutOrientation:)) return NO;
	return [super validateUserInterfaceItem:anItem];
}


#pragma mark - Hiding markup

/// Updates the markup based on caret position.
-(void)updateMarkupVisibility
{
	if (!_editorDelegate.hideFountainMarkup || _editorDelegate.documentIsLoading || self.string.length == 0) return;
	
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

/// Toggles markup hiding on/off
-(void)toggleHideFountainMarkup
{
	[self.layoutManager invalidateGlyphsForCharacterRange:(NSRange){ 0, self.string.length } changeInLength:0 actualCharacterRange:nil];
	[self updateMarkupVisibility];
	
	self.needsDisplay = true;
	self.needsLayout = true;
}


#pragma mark - Layout manager convenience methods

- (NSRect)rectForRange:(NSRange)range
{
	NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:nil];
	NSRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
	
	return rect;
}

- (NSRange)lineFragmentRangeAtLocation:(NSUInteger)location
{
	NSRange tmpRange;
	[self.layoutManager lineFragmentRectForGlyphAtIndex:location
										 effectiveRange:&tmpRange];
	return tmpRange;
}

- (NSMutableSet*)lineFragmentRangesFrom:(NSUInteger)location
{
	NSMutableSet *lineFragments = NSMutableSet.new;
	for (NSInteger index = location; index < self.string.length;) {
		NSRange fragmentRange = [self lineFragmentRangeAtLocation:index];
		[lineFragments addObject:[NSNumber valueWithRange:fragmentRange]];
		index = NSMaxRange(fragmentRange);
	}
	return lineFragments;
}


#pragma mark - Text Storage delegation

-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
	// What?
	[_editorDelegate textStorage:textStorage didProcessEditing:editedMask range:editedRange changeInLength:delta];
}



#pragma mark - Make compatible with iOS stuff

-(NSString *)text { return self.string; }
- (void)setText:(NSString *)text { self.string = text; }
@synthesize typingAttributes;


#pragma mark - Caret

- (void)loadCaret
{
	NSInteger position = [self.editorDelegate.documentSettings getInt:DocSettingCaretPosition];
	
	if (position < self.text.length && position >= 0) {
		[self setSelectedRange:NSMakeRange(position, 0)];
		[self scrollRangeToVisible:NSMakeRange(position, 0)];
	}
	
	[self ensureCaret];
}

- (void)ensureCaret
{
	[self updateInsertionPointStateAndRestartTimer:true];
}


#pragma mark - Markers

- (NSArray*)markersAndPositions
{
	NSMutableArray * markers = NSMutableArray.new;
	
	CGSize containerSize = [self.layoutManager usedRectForTextContainer:self.textContainer].size;
	if (containerSize.height == 0.0) return @[];
	
	
	NSArray* lines = self.editorDelegate.parser.lines;
	
	for (Line* line in lines) {
		if (line.marker.length == 0 && line.color.length == 0) continue;
		
		NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:line.textRange actualCharacterRange:nil];
		
		CGFloat yPosition = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer].origin.y;
		CGFloat relativeY = yPosition / containerSize.height;
		
		// Ignore faulty values
		if (relativeY > 1.0) continue;
		
		if (line.isOutlineElement) [markers addObject:@{ @"color": line.color, @"y": @(relativeY), @"scene": @(true) }];
		else [markers addObject:@{ @"color": line.marker, @"y": @(relativeY) }];
	}
	
	return markers;
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
