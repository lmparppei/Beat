//  Document.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei
//  Based on Writer, copyright © 2016 Hendrik Noeller

/*
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 
 THIS IS AN ANTI-CAPITALIST VENTURE.
 No ethical consumption under capitalism.
 
 N.B.
 
 Beat has been cooked up by using lots of trial and error, and this file has become a monster. I am a filmmaker and musician, with no real coding experience prior to this project. I've started fixing some of my silliest coding practices, but it's still a WIP. Parts of the code originally came from Writer, an open source Fountain editor by Hendrik Noeller.
 
 Some structures are legacy from Writer and original Fountain repository, and while most have since been replaced with a totally different approach, some variable names and complimentary methods still linger around. You can find some *very* shady stuff lying around here and there, with no real purpose. I built some very convoluted UI methods on top of legacy code from Writer before getting a grip on AppKit & Objective-C programming. I have since made it much more sensible, but dismantling those weird solutions is still WIP.
 
 As I started this project, I had close to zero knowledge on Objective-C, and it really shows. I have gotten gradually better at writing code, and there is even some multi-threading, omg. Some clumsy stuff is still lingering around, unfortunately. I'll keep on fixing that stuff when I have the time.
 
 I originally started the project to combat a creative block, while overcoming some difficult PTSD symptoms. Coding helped to escape those feelings. If you are in an abusive relationship, leave RIGHT NOW. You might love that person, but it's not your job to try and help them. I wish I could have gotten this sort of advice back then from a random source code file.
 
 Beat is released under GNU General Public License, so all of this code will remain open forever - even if I'd make a commercial version to finance the development. Beat has become a real app with a dedicated user base, which I'm thankful for. If you find this code or the app useful, you can always send some currency through PayPal or hide bunch of coins in an old oak tree. Or, even better, donate to a NGO helping less fortunate people. I'm already on the top of Maslow hierarchy.


 Anyway, may this be of some use to you, dear friend.
 The abandoned git repository will be my monument when I'm gone.
 
 You who will emerge from the flood
 In which we have gone under
 Remember
 When you speak of our failings
 The dark time too
 Which you have escaped.
 
 
 Lauri-Matti Parppei
 Helsinki/Kokemäki
 Finland
 2019-2021
 
 
 
 = = = = = = = = = = = = = = = = = = = = = = = =
 
 I plant my hands in the garden soil—
 I will sprout,
              I know, I know, I know.
 And in the hollow of my ink-stained palms
 swallows will make their nest.
 
 = = = = = = = = = = = = = = = = = = = = = = = =
 
*/

#import <os/log.h>
#import <QuartzCore/QuartzCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore.h>
#import <BeatCore/BeatCore-Swift.h>
#import "Beat-Swift.h"

#import "Document.h"
#import "Document+WindowManagement.h"
#import "Document+SceneActions.h"
#import "Document+Menus.h"
#import "Document+AdditionalActions.h"
#import "Document+ThemesAndAppearance.h"
#import "Document+Sidebar.h"
#import "Document+Lock.h"

#import "ScrollView.h"
#import "BeatAppDelegate.h"
#import "ColorCheckbox.h"
#import "SceneFiltering.h"
#import "SceneCards.h"
#import "MarginView.h"
#import "BeatLockButton.h"
#import "BeatColorMenuItem.h"
#import "BeatSegmentedControl.h"
#import "BeatNotepad.h"
#import "BeatPrintDialog.h"
#import "BeatEditorButton.h"
#import "BeatTextView.h"
#import "BeatTextView+Popovers.h"

@interface Document () <BeatPreviewManagerDelegate, BeatTextIODelegate, BeatQuickSettingsDelegate, NSPopoverDelegate, BeatExportSettingDelegate, BeatTextViewDelegate>

// Window
@property (weak) NSWindow *documentWindow;

// Cached
@property (atomic) NSData* dataCache;
@property (nonatomic) NSString* bufferedText;

// Autosave
@property (weak) NSTimer *autosaveTimer;

// Quick settings
@property (nonatomic, weak) IBOutlet NSButton *quickSettingsButton;
@property (nonatomic) NSPopover *quickSettingsPopover;

// Text view
@property (weak, nonatomic) IBOutlet BeatTextView *textView;

@property (nonatomic) bool hideFountainMarkup;
@property (nonatomic) NSDictionary *postEditAction;
@property (nonatomic) NSMutableArray *recentCharacters;

/// The range where last actual edit happened in text storage
@property (nonatomic) NSRange lastEditedRange;

@property (nonatomic) bool disableFormatting;
@property (nonatomic, weak) IBOutlet BeatAutocomplete *autocompletion;

@property (nonatomic) bool headingStyleBold;
@property (nonatomic) bool headingStyleUnderline;

// Views
//@property (nonatomic) NSMutableArray<BeatPluginContainerView*>* registeredPluginContainers;

// Sidebar & Outline view
@property (nonatomic, weak) IBOutlet NSSearchField *outlineSearchField;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property (nonatomic) NSMutableArray *outlineClosedSections;
@property (nonatomic, weak) IBOutlet NSMenu *colorMenu;

// Right side view
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *rightSidebarConstraint;

// Outline view filtering
@property (nonatomic, weak) IBOutlet NSPopUpButton *characterBox;

// Notepad
@property (nonatomic, weak) IBOutlet BeatNotepad *notepad;

@property (nonatomic) BeatPrintDialog *printDialog;

// Print preview
@property (nonatomic) IBOutlet BeatPreviewController *previewController;
@property (nonatomic) NSPopover* previewOptionsPopover;

// Card view
@property (nonatomic) bool cardsVisible;

// Mode display
@property (weak) IBOutlet BeatModeDisplay *modeIndicator;

// Timeline view
@property (weak) IBOutlet NSLayoutConstraint *timelineViewHeight;
@property (weak) IBOutlet NSTouchBar *touchBar;
@property (weak) IBOutlet NSTouchBar *timelineBar;
@property (weak) IBOutlet TouchTimelineView *touchbarTimeline;

// Scene number labels
@property (nonatomic) bool sceneNumberLabelUpdateOff;

// Scene number settings
@property (weak) IBOutlet NSPanel *sceneNumberingPanel;
@property (weak) IBOutlet NSTextField *sceneNumberStartInput;

// Printing
@property (nonatomic) bool printPreview;

// Some settings for edit view behaviour
@property (nonatomic) bool matchParentheses;

// View sizing
@property (nonatomic) CGFloat documentWidth;
@property (nonatomic) NSUInteger characterIndent;
@property (nonatomic) NSUInteger parentheticalIndent;
@property (nonatomic) NSUInteger dialogueIndent;
@property (nonatomic) NSUInteger dialogueIndentRight;
@property (nonatomic) NSUInteger ddCharacterIndent;
@property (nonatomic) NSUInteger ddParentheticalIndent;
@property (nonatomic) NSUInteger dualDialogueIndent;
@property (nonatomic) NSUInteger ddRight;


// Autocompletion
@property (nonatomic) bool isAutoCompleting;

// Touch bar
@property (nonatomic) NSColorPickerTouchBarItem *colorPicker;

// Parser
//@property (strong, nonatomic) ContinuousFountainParser* parser;

/// Tagging view on the right side of the screen
@property (weak) IBOutlet NSTextView *tagTextView;

/// When loading longer documents, we need to show a progress panel
@property (nonatomic) NSPanel* progressPanel;
/// The indicator for above panel
@property (nonatomic) NSProgressIndicator *progressIndicator;

/// A collection of all sorts of formatting-related `IBAction`s. A cross-platform class.
@property (nonatomic, weak) IBOutlet BeatEditorFormattingActions *formattingActions;

@end

#define MIN_WINDOW_HEIGHT 400
#define MIN_OUTLINE_WIDTH 270

#define AUTOSAVE_INTERVAL 10.0
#define AUTOSAVE_INPLACE_INTERVAL 60.0

#define FONT_SIZE 12.0
#define LINE_HEIGHT 1.1

#define CHR_WIDTH 7.25
#define DOCUMENT_WIDTH_MODIFIER 61 * CHR_WIDTH
#define CHARACTER_INDENT_P 18 * CHR_WIDTH

// DOCUMENT LAYOUT SETTINGS
#define INITIAL_WIDTH 900
#define INITIAL_HEIGHT 700

#define NATIVE_RENDERING true

@implementation Document

@dynamic textView;
@dynamic previewController;

#pragma mark - Document Initialization

/// **Warning**: This is used for returning the actual document object through editor delegate. Handle with care. 
-(Document*)document { return self; }

/// A paranoid method to actually null every-fucking-thing.
- (void)close
{
	// Save frame IF the document was saved
	if (!self.hasUnautosavedChanges) [self.documentWindow saveFrameUsingName:self.fileNameString];

	// Null page break map to avoid memory leaks of line data
	((BeatLayoutManager*)self.layoutManager).pageBreaksMap = nil;
	
	// Unload all plugins
	[self.pluginAgent unloadPlugins];
		
	// This stuff is here to fix some strange memory issues.
	// Most of these might be unnecessary, but I'm unfamiliar with both ARC & manual memory management. Better safe than sorry.
	[self.previewController.timer invalidate];
	[self.beatTimer.timer invalidate];
	self.beatTimer = nil;
		
	// Remove all registered views
	for (NSView* view in self.registeredViews) [view removeFromSuperview];
	[self.registeredViews removeAllObjects];
	[self.registeredSelectionObservers removeAllObjects];
	
	// Invalidate all view timers
	[self.textScrollView.mouseMoveTimer invalidate];
	[self.textScrollView.timerMouseMoveTimer invalidate];
	self.textScrollView.mouseMoveTimer = nil;
	self.textScrollView.timerMouseMoveTimer = nil;
	
	// Invalidate autosave timer
	[self.autosaveTimer invalidate];
	self.autosaveTimer = nil;

	
	// Null other stuff, just in case
	self.formatting = nil;
	self.runningPlugins = nil;
	self.currentLine = nil;
	self.parser = nil;
	self.outlineView = nil;
	self.documentWindow = nil;
	self.contentBuffer = nil;
	self.currentScene = nil;
	self.outlineView.filters = nil;
	
	self.outlineView.filteredOutline = nil;
	self.tagging = nil;
	self.review = nil;
	
	self.previewController = nil;
		
	// Kill observers
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[NSNotificationCenter.defaultCenter removeObserver:self.marginView];
	[NSNotificationCenter.defaultCenter removeObserver:self.widgetView];
	[NSDistributedNotificationCenter.defaultCenter removeObserver:self];
		
	[super close];
	
	// ApplicationDelegate will show welcome screen when no documents are open
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document close" object:nil];
}

-(void)restoreDocumentWindowWithIdentifier:(NSUserInterfaceItemIdentifier)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler {
	if (NSEvent.modifierFlags & NSEventModifierFlagShift) {
		completionHandler(nil, nil);
		[self close];
	} else {
		[super restoreDocumentWindowWithIdentifier:identifier state:state completionHandler:completionHandler];
		[self updateChangeCount:NSChangeDone];
	}
}

- (void)windowControllerWillLoadNib:(NSWindowController *)windowController {
	[super windowControllerWillLoadNib:windowController];

	// Initialize parser
	self.documentIsLoading = YES;
	self.parser = [[ContinuousFountainParser alloc] initWithString:self.contentBuffer delegate:self];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	// Hide the welcome screen
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document open" object:nil];
	
	// If there's a tab group, add this window to the tabbed window
	Document* currentDoc = NSDocumentController.sharedDocumentController.currentDocument;
	if (currentDoc.windowControllers.firstObject.window.tabGroup.tabBarVisible) {
		[currentDoc.documentWindow addTabbedWindow:aController.window ordered:NSWindowAbove];
	}
	
	[super windowControllerDidLoadNib:aController];
		
	_documentWindow = aController.window;
	_documentWindow.delegate = self; // The conformance is provided by Swift, don't worry
	
	// Setup plugins
	self.runningPlugins = NSMutableDictionary.new;
	self.pluginAgent = [BeatPluginAgent.alloc initWithDelegate:self];
	
	// Setup formatting
	self.formatting = BeatEditorFormatting.new;
	self.formatting.delegate = self;
	
	// Initialize document settings if needed
	if (!self.documentSettings) self.documentSettings = BeatDocumentSettings.new;
	
	// Initialize theme
	[self loadSelectedTheme:false];
	
	// Setup views
	[self setupWindow];
	[self readUserSettings];
	
	// Load font set
	[self loadFonts];
	
	// Setup views
	[self setupResponderChain];
	[self.textView setup];
	[self setupColorPicker];
	[self.outlineView setup];
		
	// Print dialog
	self.printDialog.document = nil;
	
	// Put any previously loaded text into the text view when it's loaded
	self.textView.alphaValue = 0;
	if (self.contentBuffer) {
		self.text = self.contentBuffer;
		[self setText:self.contentBuffer];
	} else {
		self.contentBuffer = @"";
		[self setText:@""];
	}
		
	// Paginate the whole document at load
	[self.previewController createPreviewWithChangedRange:NSMakeRange(0,1) sync:true];
		
	// Perform first-time rendering
	[self renderDocument];
	
	// Update selection to any views or objects that might require it.
	[self updateSelectionObservers];
}

-(void)renderDocument
{
	// Initialize revision tracing here, so revisions are loaded before formatting.
	[self.revisionTracking setup];

	// Begin formatting lines after load
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		if (self.parser.lines.count > 1000) {
			// Show a progress bar for longer documents
			self.progressPanel = [[NSPanel alloc] initWithContentRect:(NSRect){(self.documentWindow.screen.frame.size.width - 300) / 2, (self.documentWindow.screen.frame.size.height - 50) / 2,300,50} styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
			
			// Dark mode
			if (@available(macOS 10.14, *)) {
				[self.progressPanel setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
			}
			
			self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:(NSRect){  25, 20, 250, 10}];
			self.progressIndicator.indeterminate = NO;
			
			[self.progressPanel.contentView addSubview:self.progressIndicator];
			
			[self.documentWindow beginSheet:self.progressPanel completionHandler:^(NSModalResponse returnCode) { }];
		}
		
		// Apply document formatting
		[self applyInitialFormatting];
	});
}

-(void)loadingComplete {
	// Close progress panel and nil the reference
	if (self.progressPanel != nil) [self.documentWindow endSheet:self.progressPanel];
	self.progressPanel = nil;
	
	// Reset parser and cache attributed content after load
	[self.parser.changedIndices removeAllIndexes];
	self.attrTextCache = self.textView.attributedString;
	
	// Setup reviews and tagging
	[self.review setup];
	[self.tagging setup];

	// Setup text IO
	self.textActions = [BeatTextIO.alloc initWithDelegate:self];
	
	// Document loading has ended. This has to be done after reviews and tagging are loaded.
	self.documentIsLoading = NO;
			
	// Init autosave
	[self initAutosave];
	
	// Lock status
	if ([self.documentSettings getBool:DocSettingLocked]) [self lock];
	
	// Notepad
	[self.notepad setup];
	
	// If this a recovered autosave, the file might be changed when it opens, so let's save this info
	bool saved = (self.hasUnautosavedChanges) ? NO : YES;
	
	// Sidebar
	[self restoreSidebar];

	/*
	// Setup page size
	[self.undoManager disableUndoRegistration]; // (We'll disable undo registration here, so the doc won't appear as edited on open)
	
	// Uh, is this legacy from the old printing system?
	NSPrintInfo *printInfo = NSPrintInfo.sharedPrintInfo;
	self.printInfo = [BeatPaperSizing setSize:self.pageSize printInfo:printInfo];
	[self.undoManager enableUndoRegistration]; // Enable undo registration and clear any changes to the document (if needed)
	*/
	
	if (saved) [self updateChangeCount:NSChangeCleared];
	
	// Reveal text view
	[self.textView.animator setAlphaValue:1.0];
	
	// Hide Fountain markup if needed
	if (self.hideFountainMarkup) [self.textView redrawAllGlyphs];
	
	// Setup layout
	[self setupLayout];
		
	// Restore previously running plugins
	[self.pluginAgent restorePlugins];
	
	// Reload editor views in background
	[self updateEditorViewsInBackground];
	
	// Load plugin containers
	for (id<BeatPluginContainer> container in self.registeredPluginContainers) {
		[container load];
	}
}

-(void)awakeFromNib
{
	// Set up recovery file saving
	[NSDocumentController.sharedDocumentController setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
	
	// Set up listener for appearance change. Handled in Document+ThemesAndAppearance.h.
	[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(didChangeAppearance) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}


#pragma mark - Misc document stuff

- (NSString *)displayName
{
	if (!self.fileURL) return @"Untitled";
	return self.fileURL.URLByDeletingPathExtension.lastPathComponent;
}

- (NSString*)fileNameString
{
	NSString* fileName = [self lastComponentOfFileName];
	NSUInteger lastDotIndex = [fileName rangeOfString:@"." options:NSBackwardsSearch].location;
	if (lastDotIndex != NSNotFound) fileName = [fileName substringToIndex:lastDotIndex];
	
	return fileName;
}

	
#pragma mark - Misc document stuff

-(void)setValue:(id)value forUndefinedKey:(NSString *)key {
	//NSLog(@"Document: Undefined key (%@) set. This might be intentional.", key);
}

-(id)valueForUndefinedKey:(NSString *)key {
	//NSLog(@"Document: Undefined key (%@) requested. This might be intentional.", key);
	return nil;
}


#pragma mark - Handling user settings

- (void)readUserSettings
{
	[BeatUserDefaults.sharedDefaults readUserDefaultsFor:self];
}

- (void)applyUserSettings
{
	// Apply settings from user preferences panel, some things have to be applied in every document.
	// This should be implemented as a singleton/protocol.
	bool oldShowSceneNumbers = self.showSceneNumberLabels;
	bool oldHideFountainMarkup = self.hideFountainMarkup;
	bool oldShowPageNumbers = self.showPageNumbers;
	
	BeatUserDefaults *defaults = BeatUserDefaults.sharedDefaults;
	[defaults readUserDefaultsFor:self];
		
	// Reload fonts (if needed)
	[self reloadFonts];
	
	if (oldHideFountainMarkup != self.hideFountainMarkup) {
		[self.textView toggleHideFountainMarkup];
		[self ensureLayout];
	}
	
	if (oldShowPageNumbers != self.showPageNumbers) {
		[self.textView setNeedsDisplay:true];
	}
	
	if (oldShowSceneNumbers != self.showSceneNumberLabels) {
		if (self.showSceneNumberLabels) [self ensureLayout];
		//else [self.textView deleteSceneNumberLabels];
		
		// Update the print preview accordingly
		[self.previewController resetPreview];
	}
	
	self.textView.needsDisplay = true;
}


#pragma mark - Window setup

/// Sets up the custom responder chain
- (void)setupResponderChain {
	// Our desired responder chain, add more custom responders when needed
	NSArray *chain = @[_formattingActions, self.revisionTracking, self.notepad, self.timeline];
	
	// Store the original responder after text view
	NSResponder *prev = self.textView;
	NSResponder *originalResponder = prev.nextResponder;
	
	for (NSResponder *responder in chain) {
		prev.nextResponder = responder;
		prev = responder;
	}
	
	prev.nextResponder = originalResponder;
}

- (void)setupWindow {
	[self updateUIColors];
	
	[_tagTextView.enclosingScrollView setHasHorizontalScroller:NO];
	[_tagTextView.enclosingScrollView setHasVerticalScroller:NO];
	
	self.rightSidebarConstraint.constant = 0;
	
	// Split view
	_splitHandle.bottomOrLeftMinSize = MIN_OUTLINE_WIDTH;
	_splitHandle.delegate = self;
	[_splitHandle collapseBottomOrLeftView];
	
	// Set minimum window size
	[self setMinimumWindowSize];
	
	// Recall window position for saved documents
	if (![self.fileNameString isEqualToString:@"Untitled"]) _documentWindow.frameAutosaveName = self.fileNameString;
	
	NSRect screen = _documentWindow.screen.frame;
	NSPoint origin =_documentWindow.frame.origin;
	NSSize size = NSMakeSize([self.documentSettings getFloat:DocSettingWindowWidth], [self.documentSettings getFloat:DocSettingWindowHeight]);
	
	CGFloat preferredWidth = self.textView.documentWidth * self.textView.zoomLevel + 200;
	
	if (size.width < 1) {
		// Default size for new windows
		size.width = preferredWidth;
		origin.x = (screen.size.width - size.width) / 2;
	} else if (size.width < self.documentWindow.minSize.width || origin.x > screen.size.width || origin.x < 0) {
		// This window had a size saved. Let's make sure it stays inside screen bounds or is larger than minimum size.
		size.width = self.documentWindow.minSize.width;
		origin.x = (screen.size.width - size.width) / 2;
	}
	
	if (size.height < MIN_WINDOW_HEIGHT || origin.y + size.height > screen.size.height) {
		size.height = MAX(MIN_WINDOW_HEIGHT, screen.size.height - 100.0);
		origin.y = (screen.size.height - size.height) / 2;
	}
	
	NSRect newFrame = NSMakeRect(origin.x, origin.y, size.width, size.height);
	[_documentWindow setFrame:newFrame display:YES];
}

-(void)setupLayout
{
	// Apply layout
	[_documentWindow layoutIfNeeded];
	[self updateLayout];
	
	[self.textView loadCaret];
}

// Can I come over, I need to rest
// lay down for a while, disconnect
// the night was so long, the day even longer
// lay down for a while, recollect


# pragma mark - Window interactions

/// Returns the currently visible "tab" in main window (meaning editor, preview, index cards, etc.)
- (NSTabViewItem*)currentTab
{
	return self.tabView.selectedTabViewItem;
}

/// Returns `true` when the editor view is visible
- (bool)editorTabVisible { return (self.currentTab == _editorTab); }

/// Move to another editor view
- (void)showTab:(NSTabViewItem*)tab
{
	[self.tabView selectTabViewItem:tab];
	[tab.view.subviews.firstObject becomeFirstResponder];
	
	// Update containers in tabs
	for (id<BeatPluginContainer> view in self.registeredPluginContainers) {
		if (![tab.view.subviews containsObject:(NSView*)view]) [view containerViewDidHide];
	}
}

/// Returns `true` if the document window is full screen
- (bool)isFullscreen
{
	return ((_documentWindow.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

/// Update sizes and layout on resize
- (void)windowDidResize:(NSNotification *)notification
{
	CGFloat width = _documentWindow.frame.size.width;
	
	[self.documentSettings setFloat:DocSettingWindowWidth as:width];
	[self.documentSettings setFloat:DocSettingWindowHeight as:_documentWindow.frame.size.height];
	[self updateLayout];
}

/// Ensures minimum window size, sets text view insets and forces editor views to be displayed. After that, ensures text view layout.
- (void)updateLayout
{
	[self setMinimumWindowSize];

	[self.textView setInsets];
	
	self.textView.enclosingScrollView.needsDisplay = true;
	self.marginView.needsDisplay = true;
	
	[self ensureLayout];
}

- (void)setMinimumWindowSize
{
	CGFloat width = (self.textView.textContainer.size.width - (2 * BeatTextView.linePadding)) * self.magnification + 30;
	if (self.sidebarVisible) width += _outlineView.frame.size.width;

	// Clamp the value. I can't use max methods.
	if (width > self.documentWindow.screen.frame.size.width) width = self.documentWindow.screen.frame.size.width;
	
	[self.documentWindow setMinSize:NSMakeSize(width, MIN_WINDOW_HEIGHT)];
}

- (CGFloat)documentWidth { return self.textView.documentWidth; }

/// Restores sidebar status on launch
- (void)restoreSidebar
{
	if ([self.documentSettings getBool:DocSettingSidebarVisible]) {
		self.sidebarVisible = YES;
		[_splitHandle restoreBottomOrLeftView];
		_splitHandle.mainConstraint.constant = MAX([self.documentSettings getInt:DocSettingSidebarWidth], MIN_OUTLINE_WIDTH);
	}
}


#pragma mark - Update Editor View by Mode

/// Updates the window by editor mode. When adding new modes, remember to call this method and add new conditionals.
- (void)updateEditorMode
{
	if (_mode == TaggingMode) [self.tagging open];
	else [self.tagging close];
	
	_modeIndicator.hidden = (_mode == EditMode);
	
	// Show mode indicator
	if (_mode != EditMode) {
		NSString *modeName = @"";
		
		if (_mode == TaggingMode) modeName = [BeatLocalization localizedStringForKey:@"mode.taggingMode"];
		else if (_mode == ReviewMode) modeName = [BeatLocalization localizedStringForKey:@"mode.reviewMode"];
		
		[_modeIndicator showModeWithModeName:modeName];
	}
	
	[_documentWindow layoutIfNeeded];
	[self updateLayout];
}



#pragma mark - Quick Settings Popover

- (IBAction)showQuickSettings:(NSButton*)sender
{
	if (sender == nil) return;
	
	NSPopover* popover = NSPopover.new;
	BeatDesktopQuickSettings* settings = BeatDesktopQuickSettings.new;
	settings.delegate = self;
	
	popover.contentViewController = settings;
	popover.behavior = NSPopoverBehaviorTransient;
	[popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
	
	popover.delegate = self;
	
	_quickSettingsPopover = popover;
}

- (void)popoverWillClose:(NSNotification *)notification
{
	if (notification.object == _quickSettingsPopover) {
		_quickSettingsButton.state = NSOffState;
		_quickSettingsPopover = nil;
	}
}


#pragma mark - Zooming & layout

- (IBAction)zoomIn:(id)sender {
	if (self.currentTab == _editorTab) {
		[self.textView zoom:YES];
	} else if (self.currentTab == _nativePreviewTab) {
		self.previewController.scrollView.magnification += .05;
	}
}
- (IBAction)zoomOut:(id)sender {
	if (self.currentTab == _editorTab) {
		[self.textView zoom:NO];
	} else if (self.currentTab == _nativePreviewTab) {
		self.previewController.scrollView.magnification -= .05;
	}
}

- (IBAction)resetZoom:(id)sender
{
	if (self.currentTab == _editorTab) {
		[self.textView resetZoom];
	} else if (self.currentTab == _nativePreviewTab) {
		self.previewController.scrollView.magnification = 1.0;
	}
}

- (CGFloat)magnification
{
	return self.textView.zoomLevel;
}

- (void)setSplitHandleMinSize:(CGFloat)value {
	self.splitHandle.topOrRightMinSize = value;
}

- (void)ensureLayout
{
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
	self.textView.needsDisplay = true;
	self.textView.needsLayout = true;
	
	[self.marginView updateBackground];
	
	[self.textView ensureCaret];
}



/*
 
 Man up / Sit down / Chin up / Pipe down
 Socks up /  Don't cry /  Drink up / Just lie
 Grow some balls he said /  Grow some balls
 
 I'm a real boy, boy, and I cry
 I love myself and I want to try
 
 This is why you never
 see your father cry.
 
 */


#pragma mark - Window & data handling

// I have no idea what these are or do.
- (NSString *)windowNibName {
	return @"Document";
}

- (void)documentWasSaved
{
	if (self.runningPlugins.count) {
		for (NSString *pluginName in self.runningPlugins.allKeys) {
			// Don't save the console instance
			if ([pluginName isEqualTo:@"Console"]) continue;
			
			BeatPlugin *plugin = self.runningPlugins[pluginName];
			[plugin documentWasSaved];
		}
	}
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
	// This method can crash the app in some instances, so I've tried to solve the issue
	// by wrapping it in try-catch block. Let's see if it helps.
	
	NSData *dataRepresentation;
	bool success = NO;
	@try {
		dataRepresentation = [[self createDocumentFile] dataUsingEncoding:NSUTF8StringEncoding];
		success = YES;
	} @catch (NSException *exception) {
		os_log(OS_LOG_DEFAULT, "Error (auto)saving file: %@", exception);
		
		// If there is data in the cache, return it
		if (_dataCache != nil) return _dataCache;
		else dataRepresentation = [self.textView.string dataUsingEncoding:NSUTF8StringEncoding];
		
		// Everything is terrible, crash and don't overwrite anything.
		if (dataRepresentation == nil) @throw NSInternalInconsistencyException;
	} @finally {
		// If saving was successful, let's store the data into cache
		if (success) _dataCache = dataRepresentation.copy;
	}
	
	if (dataRepresentation == nil) {
		NSLog(@"ERROR: Something went horribly wrong. Trying to crash the app to avoid data loss.");
		@throw NSInternalInconsistencyException;
	}
	
	return dataRepresentation;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
	if (![url checkResourceIsReachableAndReturnError:outError]) return NO;
	return [super readFromURL:url ofType:typeName error:outError];
}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	return [self readFromData:data ofType:typeName error:outError reverting:NO];
}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError reverting:(BOOL)reverting {
	if (!self.documentSettings) self.documentSettings = BeatDocumentSettings.new;

	__block NSString* text = @"";
	/*
	if ([typeName isEqualToString:@"Final Draft"]) {
		// FINAL DRAFT
		__block FDXImport* import;
		import = [FDXImport.alloc initWithData:data importNotes:true completion:^{
			text = import.scriptAsString;
		}];
	} else {
	 */
		// Fountain
		// Load text & remove settings block from Fountain
		text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
		
		NSRange settingsRange = [self.documentSettings readSettingsAndReturnRange:text];
		text = [text stringByReplacingCharactersInRange:settingsRange withString:@""];
	//}

	// Remove unwanted control characters
	NSArray* t = [text componentsSeparatedByCharactersInSet:NSCharacterSet.badControlCharacters];
	text = [t componentsJoinedByString:@""];
	
	if (!reverting)	[self setText:text];
	else self.contentBuffer = text; // When reverting, we only set the content buffer
	
	return YES;
}


/*
 
 But if the while I think on thee,
 dear friend,
 All losses are restor'd,
 and sorrows end.
 
 */



#pragma mark - Reverting to versions

-(void)revertDocumentToSaved:(id)sender {
	if (!self.fileURL) return;
	
	NSData *data = [NSData dataWithContentsOfURL:self.fileURL];
	
	[self readFromData:data ofType:NSPlainTextDocumentType error:nil reverting:YES];
	[self.textView setString:self.contentBuffer];
	[self.parser parseText:self.contentBuffer];
	[self.formatting formatAllLines];
	[self updateLayout];
	
	_revertedTo = self.fileURL;
	
	[self updateChangeCount:NSChangeCleared];
	[self.undoManager removeAllActions];
}

-(BOOL)revertToContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
	// Don't allow wrong document contents
	if (![typeName isEqualToString:@"com.kapitanFI.fountain"] && ![typeName isEqualToString:NSPlainTextDocumentType] && ![typeName isEqualToString:@"Fountain script"]) {
		NSLog(@"Error: wrong file type");
		return NO;
	}
	
	NSData *data = [NSData dataWithContentsOfURL:url];
	_revertedTo = url;
	self.documentIsLoading = YES;
	
	[self readFromData:data ofType:typeName error:nil reverting:YES];
	
	[self.textView setNeedsDisplay:true];
	
	self.textView.alphaValue = 0.0;
	[self setText:self.contentBuffer];
	
	self.parser = [ContinuousFountainParser.alloc initWithString:self.contentBuffer delegate:self];
	[self renderDocument];
	
	[self updateChangeCount:NSChangeCleared];
	[self updateChangeCount:NSChangeDone];
	[self.undoManager removeAllActions];
	
	return YES;
}


#pragma mark - Print & Export

- (IBAction)openPrintPanel:(id)sender {
	self.attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPrinting:self];
}
- (IBAction)openPDFPanel:(id)sender {
	self.attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPDF:self];
}
- (void)releasePrintDialog { _printDialog = nil; }

- (void)printDialogDidFinishPreview:(void (^)(void))block {
	block();
}

- (IBAction)exportOutline:(id)sender
{
	NSSavePanel *saveDialog = [NSSavePanel savePanel];
	[saveDialog setAllowedFileTypes:@[@"fountain"]];
	[saveDialog setNameFieldStringValue:[self.fileNameString stringByAppendingString:@" Outline"]];
	[saveDialog beginSheetModalForWindow:self.windowControllers[0].window completionHandler:^(NSInteger result) {
		if (result == NSModalResponseOK) {
			NSString* outlineString = [OutlineExtractor outlineFromParse:self.parser];
			[outlineString writeToURL:saveDialog.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
		}
	}];
}

- (IBAction)exportFile:(id)sender
{
	BeatFileExportMenuItem* menuItem = sender;
	[BeatFileExportManager.shared exportWithDelegate:self format:menuItem.format];
}


# pragma mark - Undo

- (IBAction)undoEdit:(id)sender {
	[self.undoManager undo];
	[self ensureLayout];
}
- (IBAction)redoEdit:(id)sender {
	[self.undoManager redo];
	[self ensureLayout];
}

/*
 
 and in a darkened underpass
 I thought, oh god, my chance has come at last
 but then
 a strange fear gripped me
 and I just couldn't ask
 
 */


#pragma mark - Toggling user default settings on/off

/// Toggles user default or document setting value on or off. Requires `BeatOnOffMenuItem` with a defined `settingKey`.
- (IBAction)toggleSetting:(BeatOnOffMenuItem*)menuItem
{
	if (menuItem == nil || menuItem.settingKey.length == 0) return;
	
	if (menuItem.documentSetting) [self.documentSettings toggleBool:menuItem.settingKey];
	else [BeatUserDefaults.sharedDefaults toggleBool:menuItem.settingKey];
	
	[self ensureLayout];
}


# pragma mark - Text events

#pragma mark If text should change
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	// Don't allow editing the script while tagging
	if (_mode != EditMode || self.contentLocked) return NO;
	
	Line* currentLine = self.currentLine;
	
	bool change = true;
	bool undoOperation = self.undoManager.isRedoing || self.undoManager.isUndoing;
	
	// This shouldn't be here :-)
	if (replacementString.length == 1 && affectedCharRange.length == 0 && self.beatTimer.running) {
		if (![replacementString isEqualToString:@"\n"]) self.beatTimer.charactersTyped++;
	}
		
	// Don't allow certain symbols
	if (replacementString.length == 1) {
		unichar c = [replacementString characterAtIndex:0];
		if ([NSCharacterSet.badControlCharacters characterIsMember:c]) return false;
	}
	
	
	// Check for character input trouble
	if (self.characterInput && replacementString.length == 0 && NSMaxRange(affectedCharRange) == self.characterInputForLine.position) {
		[self cancelCharacterInput];
		//return NO;
		change = false;
	}
	
	// Don't repeat ) or ]
	else if ([self.textActions shouldJumpOverParentheses:replacementString range:affectedCharRange] &&
		!self.undoManager.redoing && !self.undoManager.undoing) {
		change = false;
	}
	
	// Handle new line breaks (when actually typed)
	else if ([replacementString isEqualToString:@"\n"] && affectedCharRange.length == 0 && !undoOperation) {
		// Line break after character cue
		// Look back to see if we should add (cont'd), and if the CONT'D got added, don't run this method any longer
		if (currentLine.isAnyCharacter && self.automaticContd && [self.textActions shouldAddContdIn:affectedCharRange string:replacementString])
		{
			change = false;
		}
		
		// When on a parenthetical, don't split it when pressing enter, but move downwards to next dialogue block element
		// Note: This logic is a bit faulty. We should probably just move on next line regardless of next character
		else if (currentLine.isAnyParenthetical && self.selectedRange.length == 0) {
			if (self.text.length >= affectedCharRange.location + 1) {
				unichar chr = [self.text characterAtIndex:affectedCharRange.location];
				if (chr == ')') {
					NSInteger lineIndex = [self.lines indexOfObject:currentLine];
					[self addString:@"\n" atIndex:affectedCharRange.location + 1];
					if (lineIndex < self.lines.count) [self.formatting formatLine:self.lines[lineIndex]];
					
					[self.textView setSelectedRange:(NSRange){ affectedCharRange.location + 2, 0 }];
					change = false;
				}
			}
		}
		// Process line break after a forced character input
		else if (self.characterInput && self.characterInputForLine && NSMaxRange(self.characterInputForLine.textRange) <= self.text.length) {
			// If the cue is empty, reset it
			if (self.characterInputForLine.string.length == 0) {
				[self setTypeAndFormat:self.characterInputForLine type:empty];
			} else {
				self.characterInputForLine.forcedCharacterCue = YES;
			}
		}
		// Handle automatic line breaks
		else if ([self.textActions shouldAddLineBreaks:currentLine range:affectedCharRange]) {
			change = false;
		}
	}
	
	// Single characters
	else if (replacementString.length == 1 && !undoOperation) {
		// Auto-close () and [[]]
		if (self.matchParentheses) [self.textActions matchParenthesesIn:affectedCharRange string:replacementString];
	}
	
	// If change is true, we can safely add the string (and parse the addition)
	if (change) {
		// Make the replacement string uppercase in parser
		if (self.characterInput) replacementString = replacementString.uppercaseString;
		
		// Parse changes so far
		[self.parser parseChangeInRange:affectedCharRange withString:replacementString];
		
		self.lastChangedRange = (NSRange){ affectedCharRange.location, replacementString.length };
	}
	
	return change;
}


#pragma mark Text did change

- (void)textDidChange:(NSNotification *)notification
{
	[super textDidChange];
		
	// Fire up autocomplete at the end of string and create cached lists of scene headings / character names
	if (self.autocomplete) [self.autocompletion autocompleteOnCurrentLine];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) [self.textView ensureRangeIsVisible:self.lastChangedRange];
		
	[self updateChangeCount:NSChangeDone];
	
	// Apply any revisions
	[self.revisionTracking applyQueuedChanges];
	
	// Finally, reset last changed range
	self.lastChangedRange = NSMakeRange(NSNotFound, 0);
}

-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
	if (self.documentIsLoading) return;
	
	if (editedMask & NSTextStorageEditedCharacters) {
		self.lastEditedRange = NSMakeRange(editedRange.location, delta);
		
		// Register changes. Because macOS Sonoma somehow changed attribute handling, we need to _queue_ those changes and
		// then release them when text has changed
		if (_revisionMode && self.lastChangedRange.location != NSNotFound && !self.undoManager.isUndoing) {
			[self.revisionTracking queueRegisteringChangesInRange:NSMakeRange(editedRange.location, editedRange.length) delta:delta];
		}
	}
}

- (void)textViewDidChangeSelection:(NSNotification *)notification
{
	// If we are just opening the document, do nothing
	if (self.documentIsLoading) return;
	
	// Reset forced character input
	if (self.characterInputForLine != self.currentLine && self.characterInput) {
		self.characterInput = NO;
		if (self.characterInputForLine.string.length == 0) {
			[self setTypeAndFormat:self.characterInputForLine type:empty];
			self.characterInputForLine = nil;
		}
	}
	
	// Correct parsing for character cues (we need to move this to parser somehow)
	Line *previouslySelectedLine = self.previouslySelectedLine;
	__weak static Line *previousCue;
	
	if (previouslySelectedLine.isAnyCharacter) {
		previousCue = previouslySelectedLine;
	}
	if (previouslySelectedLine != self.currentLine && previousCue.isAnyCharacter) {
		[self.parser ensureDialogueParsingFor:previousCue];
	}
	
	// Update hidden Fountain markup
	[self.textView updateMarkupVisibility];
		
	// Scroll to view if needed
	if (self.selectedRange.length == 0) {
		[self.textView scrollRangeToVisible:self.selectedRange];
	}
	
	// Notify observers
	[self updateSelectionObservers];
	
	// We REALLY REALLY should make some sort of cache for these, or optimize outline creation
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		// Update all views which are affected by the caret position
		[self updateUIwithCurrentScene];
		
		// Update tag view
		if (self.mode == TaggingMode) [self.tagging updateTaggingData];
		
		// Update running plugins
		[self.pluginAgent updatePluginsWithSelection:self.selectedRange];
	});
}


#pragma mark Update UI with current scene

/// When the current scene has changed, some UI elements need to be updated. Add any required updates here.
/// TODO: Register the views which need scene index update. This is a mess.
- (void)updateUIwithCurrentScene
{
	OutlineScene *currentScene = self.currentScene;
	__block NSInteger sceneIndex = [self.parser.outline indexOfObject:currentScene];
	
	// Do nothing if no index found
	if (sceneIndex == NSNotFound) return;
	
	// Update any registered outline views
	for (id<BeatSceneOutlineView>view in self.registeredOutlineViews) {
		if (view.visible) [view didMoveToSceneIndex:sceneIndex];
	}
		
	// Update touch bar color if needed
	if (currentScene.color) {
		NSColor* color = [BeatColors color:currentScene.color];
		if (color != nil) [_colorPicker setColor:[BeatColors color:currentScene.color]];
	}
		
	[self.pluginAgent updatePluginsWithSceneIndex:sceneIndex];
}



#pragma mark - Text I/O

- (void)setAutomaticTextCompletionEnabled:(BOOL)value
{
	self.textView.automaticTextCompletionEnabled = value;
}

- (void)setZoom:(CGFloat)zoomLevel
{
	[self.textView adjustZoomLevel:zoomLevel];
}


// There is no shortage of ugliness in the world.
// If a person closed their eyes to it,
// there would be even more.


# pragma mark - Autocomplete stub

/// Forwarding method for autocompletion (why don't we set the autocompletion as the deleg.... oh well, I won't ask.)
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	return [_autocompletion completions:words forPartialWordRange:charRange indexOfSelectedItem:index];
}


#pragma mark - Character input
// TODO: Move these to text view

- (void)handleTabPress {
	// TODO: Move this to text view
	// Force character if the line is suitable
	Line *currentLine = self.currentLine;
	
	if (currentLine.isAnyCharacter && currentLine.string.length > 0) {
		[self.formattingActions addOrEditCharacterExtension];
	} else {
		[self forceCharacterInput];
	}
}

- (void)forceCharacterInput {
	// TODO: Move this to text view
	// Don't allow this to happen twice
	if (self.characterInput) return;
	
	[self.formattingActions addCue];
}

- (void)cancelCharacterInput {
	// TODO: Move this to text view
	self.characterInput = NO;
	self.characterInputForLine = nil;
	
	NSMutableDictionary *attributes = NSMutableDictionary.dictionary;
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	[attributes setValue:self.fonts.regular forKey:NSFontAttributeName];
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[paragraphStyle setFirstLineHeadIndent:0];
	[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	[self.textView setTypingAttributes:attributes];
	self.textView.needsDisplay = YES;
	self.textView.needsLayout = YES;
	
	[self setTypeAndFormat:self.characterInputForLine type:empty];
}


#pragma mark - Formatting

/// Applies the initial formatting while document is loading
-(void)applyInitialFormatting
{
	if (self.parser.lines.count == 0) {
		// Empty document, do nothing.
		[self loadingComplete];
		return;
	}
	
	// Start rendering
	self.progressIndicator.maxValue =  1.0;
	[self formatAllWithDelayFrom:0];

}

/// Formats all lines while loading the document
- (void)formatAllWithDelayFrom:(NSInteger)idx
{
	// We split the document into chunks of 1000 lines and render them asynchronously
	// to throttle the initial loading of document a bit
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		Line *line;
		NSInteger lastIndex = idx;
		
		[self.textStorage beginEditing];
		for (NSInteger i = 0; i < 1000; i++) {
			// After 1000 lines, hand off the process
			if (i + idx >= self.parser.lines.count) break;
			
			line = self.parser.lines[i + idx];
			lastIndex = i + idx;
			[self.formatting formatLine:line firstTime:YES];
		}
		[self.textStorage endEditing];
		
		[self.progressIndicator incrementBy:1000.0 / (CGFloat)self.parser.lines.count];
		
		if (line == self.parser.lines.lastObject || lastIndex >= self.parser.lines.count) {
			// If the document is done formatting, complete the loading process.
			[self loadingComplete];
		} else {
			// Else render 1000 more lines
			[self formatAllWithDelayFrom:lastIndex + 1];
		}
	});
}

- (IBAction)toggleDisableFormatting:(id)sender {
	_disableFormatting = !_disableFormatting;
	[self.formatting formatAllLines];
}


/*
 
 hei
 saanko jäädä yöksi, mun tarvii levätä
 ennen kuin se alkaa taas
 saanko jäädä yöksi, mun tarvii levätä
 en mä voi mennä enää kotiinkaan
 enkä tiedä onko mulla sellaista ollenkaan
 
 */


# pragma  mark - Fonts

/// Called for any OS-specific stuff after fonts were loaded
- (void)fontDidLoad
{
	self.textView.font = self.fonts.regular;
}

- (IBAction)selectSerif:(id)sender {
	NSMenuItem* item = sender;
	[BeatUserDefaults.sharedDefaults saveBool:(item.state == NSOnState) forKey:BeatSettingUseSansSerif];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc reloadFonts];
	}
}

- (IBAction)selectSansSerif:(id)sender {
	NSMenuItem* item = sender;
	bool sansSerif = (item.state != NSOnState);

	[BeatUserDefaults.sharedDefaults saveBool:sansSerif forKey:BeatSettingUseSansSerif];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc reloadFonts];
	}
}


#pragma mark - Select stylesheet

- (IBAction)selectStylesheet:(BeatMenuItemWithStylesheet*)sender
{
	[self setStylesheetAndReformat:sender.stylesheet];
}


#pragma mark - Revision Tracking

// UI side

-(IBAction)toggleShowRevisions:(id)sender
{
	// Save user default
	[BeatUserDefaults.sharedDefaults toggleBool:BeatSettingShowRevisions];

	// Refresh layout + settings
	self.textView.needsLayout = true;
	self.textView.needsDisplay = true;
}

-(IBAction)toggleShowRevisedTextColor:(id)sender
{
	[BeatUserDefaults.sharedDefaults toggleBool:BeatSettingShowRevisedTextColor];
	[self.formatting refreshRevisionTextColorsInRange:NSMakeRange(0, self.text.length)];
}

-(IBAction)toggleRevisionMode:(id)sender {
	_revisionMode = !_revisionMode;
	
	// Save document setting
	[self.documentSettings setBool:DocSettingRevisionMode as:_revisionMode];
}
- (IBAction)markAddition:(id)sender
{
	if (self.contentLocked) return;
	
	NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
	[self.revisionTracking markerAction:RevisionAddition];
	[self.formatting refreshRevisionTextColorsInRange:range];
}
- (IBAction)markRemoval:(id)sender
{
	if (self.contentLocked) return;
	
	NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
	[self.revisionTracking markerAction:RevisionRemovalSuggestion];
	[self.formatting formatLinesInRange:range];
}
- (IBAction)clearMarkings:(id)sender
{
	// Remove markers
	if (self.contentLocked) return;
	
	NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
	[self.revisionTracking markerAction:RevisionNone];
	[self.formatting refreshRevisionTextColorsInRange:range];
}

- (IBAction)commitRevisions:(id)sender {
	[self.revisionTracking commitRevisions];
	[self.formatting refreshRevisionTextColors];
}

- (IBAction)selectRevisionColor:(id)sender {
	NSPopUpButton *button = sender;
	BeatColorMenuItem *item = (BeatColorMenuItem *)button.selectedItem;
	NSString* revisionColor = item.colorKey;
	
	self.revisionColor = revisionColor;
}



#pragma mark - Hiding markup

- (IBAction)toggleHideFountainMarkup:(id)sender {
	[BeatUserDefaults.sharedDefaults toggleBool:BeatSettingHideFountainMarkup];
	[self.textView toggleHideFountainMarkup];
	
	self.textView.needsDisplay = true;
	self.textView.needsLayout = true;
	
	[self updateLayout];
}


#pragma mark - Return to editor from any subview

- (void)returnToEditor {
	[self showTab:_editorTab];
	[self updateLayout];
}


#pragma mark - Preview

- (IBAction)preview:(id)sender
{
	if (self.currentTab != _nativePreviewTab) {
		[self.previewController renderOnScreen];
		[self showTab:_nativePreviewTab];
	} else {
		[self returnToEditor];
	}
}
- (BOOL)previewVisible { return (self.currentTab == _nativePreviewTab); }

- (void)cancelOperation:(id) sender
{
	// ESCAPE KEY pressed
	if (self.currentTab == _nativePreviewTab) [self preview:nil];
	else if (self.currentTab == _cardsTab) [self toggleCards:nil];
	else {
		for (NSString* pluginName in self.runningPlugins.allKeys) {
			BeatPlugin* plugin = self.runningPlugins[pluginName];
			[plugin escapePressed];
		}
	}
}

/// TODO: Move this to preview view
- (IBAction)showPreviewOptions:(id)sender
{
	NSButton* button = (NSButton*)sender;
	
	self.previewOptionsPopover = NSPopover.new;
	BeatPreviewOptions* previewOptions = BeatPreviewOptions.new;
	previewOptions.editorDelegate = self;
	
	self.previewOptionsPopover.contentViewController = previewOptions;
	self.previewOptionsPopover.behavior = NSPopoverBehaviorTransient;
	[self.previewOptionsPopover showRelativeToRect:button.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}

/*
 
 Oh, table, on which I write!
 I thank you with all my heart:
 You’ve given a trunk to me –
 With goal a table to be –
 
 But keep being the living trunk! –
 With – over my head – your leaf, young,
 With fresh bark and hot pitch’s tears,
 With roots – till the bottom of Earth!
 
 */

#pragma  mark - Sidebar methods
// Move all of this into a separate sidebar handler class

- (BOOL)sidebarVisible
{
	return !self.splitHandle.bottomOrLeftViewIsCollapsed;
}

- (CGFloat)sidebarWidth
{
	return self.splitHandle.bottomOrLeftView.frame.size.width;
}


/*
 
 you say: it's gonna happen soon
 well, when exactly do you mean????
 see, I've already waited too long
 and most of my life is gone
 
 */


#pragma mark - Sidebar

/// The rest of sidebar methods are found in `Document+Sidebar`. These are just here to conform to editor delegate protocol. Oh well, oh fuck.

- (IBAction)toggleSidebar:(id)sender
{
	[self toggleSidebarView:sender];
}

- (IBAction)showWidgets:(id)sender {
	if (!self.sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:self.tabWidgets];
}



#pragma mark - Outline/timeline context menu, including setting colors

// Note from 2022: Why is this here and not in their associated classes?
// We could just change the target of every menu item, but maybe that would be too easy.

// We are using this same menu for both outline & timeline view
- (void)menuDidClose:(NSMenu*)menu {
	// Reset timeline selection, to be on the safe side
	_timeline.clickedItem = nil;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	if (!NSThread.isMainThread) return;
	
	id item = nil;
	
	if (self.outlineView.clickedRow >= 0) {
		item = [self.outlineView itemAtRow:self.outlineView.clickedRow];
	}
	else if (_timeline.clickedItem != nil) {
		item = _timeline.clickedItem;
	}
	
	if (item != nil && [item isKindOfClass:[OutlineScene class]]) {
		// Show context menu
		for (NSMenuItem * menuItem in menu.itemArray) {
			menuItem.hidden = NO;
		}
	} else {
		// Hide every item
		for (NSMenuItem * menuItem in menu.itemArray) {
			menuItem.hidden = YES;
		}
	}
}

- (void)setupColorPicker {
	for (NSTouchBarItem *item in [self.textView.touchBar templateItems]) {
		if ([item.className isEqualTo:@"NSColorPickerTouchBarItem"]) {
			NSColorPickerTouchBarItem *picker = (NSColorPickerTouchBarItem*)item;
			
			_colorPicker = picker;
			picker.showsAlpha = NO;
			picker.colorList = [[NSColorList alloc] init];
			
			[picker.colorList setColor:NSColor.blackColor forKey:@"none"];
			[picker.colorList setColor:[BeatColors color:@"red"] forKey:@"red"];
			[picker.colorList setColor:[BeatColors color:@"blue"] forKey:@"blue"];
			[picker.colorList setColor:[BeatColors color:@"green"] forKey:@"green"];
			[picker.colorList setColor:[BeatColors color:@"cyan"] forKey:@"cyan"];
			[picker.colorList setColor:[BeatColors color:@"orange"] forKey:@"orange"];
			[picker.colorList setColor:[BeatColors color:@"pink"] forKey:@"pink"];
			[picker.colorList setColor:[BeatColors color:@"gray"] forKey:@"gray"];
			[picker.colorList setColor:[BeatColors color:@"magenta"] forKey:@"magenta"];
		}
	}
}

- (IBAction)pickColor:(id)sender {
	NSString *pickedColor;
	
	for (NSString *color in BeatColors.colors) {
		if ([_colorPicker.color isEqualTo:[BeatColors color:color]]) pickedColor = color;
	}
	
	if ([_colorPicker.color isEqualTo:NSColor.blackColor]) pickedColor = @"none"; // THE HOUSE IS BLACK.
	
	if (self.currentScene == nil) return;
	
	if (pickedColor != nil) [self.textActions setColor:pickedColor forScene:self.currentScene];
}

- (IBAction)setSceneColorForRange:(id)sender {
	// Called from text view context menu
	BeatColorMenuItem *item = sender;
	NSString *color = item.colorKey;
	
	NSRange range = self.selectedRange;
	NSArray *scenes = [self.parser scenesInRange:range];
		
	for (OutlineScene* scene in scenes) {
		[self.textActions setColor:color forScene:scene];
	}
}

- (IBAction)setSceneColor:(id)sender {
	BeatColorMenuItem *item = sender;
	NSString *colorName = item.colorKey;
	
	if (self.outlineView.clickedRow > -1) {
		id selectedScene = nil;
		selectedScene = [self.outlineView itemAtRow:self.outlineView.clickedRow];
		
		if (selectedScene != nil && [selectedScene isKindOfClass:[OutlineScene class]]) {
			OutlineScene *scene = selectedScene;
			[self.textActions setColor:colorName forScene:scene];
		}
		
		_timeline.clickedItem = nil;
	}
}


/*
 
 I'm very good with plants
 while my friends are away
 they let me keep the soil moist.
 
 */


#pragma mark - Card view

- (IBAction)toggleCards: (id)sender {
	if (self.currentTab != _cardsTab) {
		[self showTab:_cardsTab];
	} else {
		// Reload outline + timeline (in case there were any changes in outline while in card view)
		[self refreshAllOutlineViews];
		[self returnToEditor];
	}
}

#pragma mark - Refresh any outline views

- (void)refreshAllOutlineViews
{
	for (id<BeatSceneOutlineView> view in self.registeredOutlineViews) {
		[view reloadView];
	}
}


#pragma mark - Scene numbering
// TODO: What the actual hell is this stuff

- (IBAction)showSceneNumberStart:(id)sender {
	// Load previous setting
	if ([self.documentSettings getInt:DocSettingSceneNumberStart] > 0) {
		[_sceneNumberStartInput setIntegerValue:[self.documentSettings getInt:DocSettingSceneNumberStart]];
	}
	[_documentWindow beginSheet:_sceneNumberingPanel completionHandler:nil];
}

- (IBAction)closeSceneNumberStart:(id)sender {
	[_documentWindow endSheet:_sceneNumberingPanel];
}

- (IBAction)applySceneNumberStart:(id)sender {
	if (_sceneNumberStartInput.integerValue > 1 && _sceneNumberStartInput.integerValue != NSNotFound) {
		[self.documentSettings setInt:DocSettingSceneNumberStart as:_sceneNumberStartInput.integerValue];
	} else {
		[self.documentSettings remove:DocSettingSceneNumberStart];
	}
	
	// Rebuild outline everywhere
	[self.parser updateOutline];

	[self ensureLayout];
	[self updateChangeCount:NSChangeDone];
	
	[_documentWindow endSheet:_sceneNumberingPanel];
}


#pragma mark - Character gender getter

/// Quick access to gender list.
- (NSDictionary<NSString*, NSString*>*)characterGenders
{
	NSDictionary * genders = [self.documentSettings get:DocSettingCharacterGenders];
	return (genders != nil) ? genders : @{};
}


#pragma mark - Pagination manager methods

- (IBAction)togglePageNumbers:(id)sender
{
	self.showPageNumbers = !self.showPageNumbers;
	
	((BeatLayoutManager*)self.layoutManager).pageBreaksMap = nil;
	[self.previewController resetPreview];
	
	self.textView.needsDisplay = true;
}


#pragma mark - Paper size

- (void)setPageSize:(BeatPaperSize)pageSize
{
	[super setPageSize:pageSize];
	[self updateLayout];
}


#pragma mark - Autosave

/*
 
 Beat has *three* kinds of autosave: autosave vault, saving in place and automatic macOS autosave.
  
 */

- (BOOL)autosave
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingAutosave];
}

+ (BOOL)autosavesInPlace {
	return NO;
}

+ (BOOL)autosavesDrafts {
	return YES;
}

+ (BOOL)preservesVersions {
	// Versions are only supported from 12.0+ because of a strange bug in older macOSs
	// WHY IS THIS BUGGY? It works but produces weird error messages.
	//if (@available(macOS 13.0, *)) return YES;
	// else return NO;
	return NO;
}

- (BOOL)writeSafelyToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError *__autoreleasing  _Nullable *)outError {
	bool result = [super writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
	
	if (result && (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)) {
		bool backup = [BeatBackup backupWithDocumentURL:url name:[self fileNameString] autosave:false];
		if (!backup) NSLog(@"Backup failed");
	}
	
	return result;
}

- (NSURL *)mostRecentlySavedFileURL;
{
	// Before the user chooses where to place a new document, it has an autosaved URL only
	// On 10.6-, autosaves save newer versions of the document *separate* from the original doc
	NSURL *result = [self autosavedContentsFileURL];
	if (!result) result = [self fileURL];
	return result;
}

// Custom autosave in place
- (void)autosaveInPlace {	
	if (_autosave && self.documentEdited && self.fileURL) {
		[self saveDocument:nil];
	} else {
		if ([NSFileManager.defaultManager fileExistsAtPath:self.autosavedContentsFileURL.path]) {
			bool autosave = [BeatBackup backupWithDocumentURL:self.autosavedContentsFileURL name:self.fileNameString autosave:true];
			if (!autosave) NSLog(@"AUTOSAVE ERROR");
		}
	}
}

- (NSURL *)autosavedContentsFileURL {
	NSString *filename = [self fileNameString];
	if (!filename) filename = @"Untitled";
	
	NSURL *autosavePath = [self autosavePath];
	autosavePath = [autosavePath URLByAppendingPathComponent:filename];
	autosavePath = [autosavePath URLByAppendingPathExtension:@"fountain"];
	
	return autosavePath;
}

- (NSURL*)autosavePath {
	return [BeatAppDelegate appDataPath:@"Autosave"];
}

- (void)autosaveDocumentWithDelegate:(id)delegate didAutosaveSelector:(SEL)didAutosaveSelector contextInfo:(void *)contextInfo {
	self.autosavedContentsFileURL = [self autosavedContentsFileURL];
	[super autosaveDocumentWithDelegate:delegate didAutosaveSelector:didAutosaveSelector contextInfo:contextInfo];
	
	[NSDocumentController.sharedDocumentController setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
}

- (BOOL)hasUnautosavedChanges {
	// Always return YES if the file is a draft
	if (self.fileURL == nil) return YES;
	else { return [super hasUnautosavedChanges]; }
}

- (void)initAutosave {
	_autosaveTimer = [NSTimer scheduledTimerWithTimeInterval:AUTOSAVE_INPLACE_INTERVAL target:self selector:@selector(autosaveInPlace) userInfo:nil repeats:YES];
}

- (void)saveDocumentAs:(id)sender {
	[super saveDocumentAs:sender];
}

-(void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
	[super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}


#pragma mark - split view listener

- (void)splitViewDidResize
{
	[self.documentSettings setInt:DocSettingSidebarWidth as:(NSInteger)self.splitHandle.bottomOrLeftView.frame.size.width];
	[self updateLayout];
}

- (void)leftViewDidShow
{
	self.sidebarVisible = YES;
	[_outlineButton setState:NSOnState];
	[self.outlineView reloadOutline];
}

- (void)leftViewDidHide
{
	self.sidebarVisible = NO;
}


#pragma mark - Review Mode

- (IBAction)toggleReview:(id)sender
{
	if (_mode == ReviewMode) self.mode = EditMode;
	else self.mode = ReviewMode;
}

-(void)toggleMode:(BeatEditorMode)mode
{
	if (_mode != mode) _mode = EditMode;
	else _mode = mode;
	[self updateEditorMode];
}

-(void)setMode:(BeatEditorMode)mode
{
	_mode = mode;
	[self updateEditorMode];
}

- (IBAction)reviewSelectedRange:(id)sender
{
	if (self.selectedRange.length == 0) return;
	[self.review showReviewIfNeededWithRange:self.selectedRange forEditing:YES];
}


#pragma mark - Tagging Mode

- (IBAction)toggleTagging:(id)sender
{
	if (_mode == TaggingMode) _mode = EditMode;
	else _mode = TaggingMode;
	
	[self updateEditorMode];
}


#pragma mark - Widgets

- (void)addWidget:(id)widget {
	[self.widgetView addWidget:widget];
	[self showWidgets:nil];
}


#pragma mark - Scrolling

// TODO: How do I move these into a category?

- (void)scrollToSceneNumber:(NSString*)sceneNumber
{
	// Note: scene numbers are STRINGS, because they can be anything (2B, EXTRA, etc.)
	OutlineScene *scene = [self.parser sceneWithNumber:sceneNumber];
	if (scene != nil) [self scrollToScene:scene];
}
- (void)scrollToScene:(OutlineScene*)scene
{
	[self selectAndScrollTo:scene.line.textRange];
	[self.documentWindow makeFirstResponder:self.textView];
}
/// Legacy method. Use selectAndScrollToRange
- (void)scrollToRange:(NSRange)range
{
	[self selectAndScrollTo:range];
}

- (void)scrollToRange:(NSRange)range callback:(nullable void (^)(void))callbackBlock {
	BeatTextView *textView = (BeatTextView*)self.textView;
	[textView scrollToRange:range callback:callbackBlock];
}

/// Scrolls the given position into view
- (void)scrollTo:(NSInteger)location {
	NSRange range = NSMakeRange(location, 0);
	[self selectAndScrollTo:range];
}
/// Selects the given line and scrolls it into view
- (void)scrollToLine:(Line*)line {
	if (line != nil) [self selectAndScrollTo:line.textRange];
}
/// Selects the line at given index and scrolls it into view
- (void)scrollToLineIndex:(NSInteger)index {
	Line *line = [self.parser.lines objectAtIndex:index];
	if (line != nil) [self selectAndScrollTo:line.textRange];
}
/// Selects the scene at given index and scrolls it into view
- (void)scrollToSceneIndex:(NSInteger)index {
	OutlineScene *scene = [self.parser.outline objectAtIndex:index];
	if (!scene) return;
	
	NSRange range = NSMakeRange(scene.line.position, scene.string.length);
	[self selectAndScrollTo:range];
}


/// Selects the given range and scrolls it into view
- (void)selectAndScrollTo:(NSRange)range {
	BeatTextView *textView = (BeatTextView*)self.textView;
	[textView setSelectedRange:range];
	[textView scrollToRange:range callback:nil];
}


#pragma mark - For avoiding throttling

- (bool)hasChanged {
	if ([self.textView.string isEqualToString:_bufferedText]) return NO;
	
	_bufferedText = [NSString stringWithString:self.textView.string];
	return YES;
}


#pragma mark - Appearance

/// Because we are supporting forced light/dark mode even on pre-10.14 systems, you can reliably check the appearance with this method.
- (bool)isDark { return [(BeatAppDelegate *)[NSApp delegate] isDark]; }


#pragma mark - Copy

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	return [Document.alloc initWithContentsOfURL:self.fileURL ofType:self.fileType error:nil];
}


#pragma mark - Lock

- (void)showLockStatus
{
	[self.lockButton displayLabel];
}


@end

/*
 
 some moments are nice, some are
 nicer, some are even worth
 writing
 about
 
 */
