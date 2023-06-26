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
 
 Beat has been cooked up by using lots of trial and error, and this file has become a 5000-line monster.  I've started fixing some of my silliest coding practices, but it's still a WIP. About a quarter of the code has its origins in Writer, an open source Fountain editor by Hendrik Noeller. I am a filmmaker and musician, with no real coding experience prior to this project.
 
 Some structures are legacy from Writer and original Fountain repository, and while most have since been replaced with a totally different approach, some variable names and complimentary methods still linger around. You can find some *very* shady stuff lying around here and there, with no real purpose. I built some very convoluted UI methods on top of legacy code from Writer before getting a grip on AppKit & Objective-C programming. I have since made it much more sensible, but dismantling those weird solutions is still WIP.
 
 As I started this project, I had close to zero knowledge on Objective-C, and it really shows. I have gotten gradually better at writing code, and there is even some multi-threading, omg. Some clumsy stuff is still lingering around, unfortunately. I'll keep on fixing that stuff when I have the time.
 
 This particular class (Document) should be split into multiple chunks, as it's 4500-line monster. I've moved a ton of stuff into their respective classes, but as Objective C clases can't really be extended as easily as in Swift, I'm conflicted about how to actually modularize this mess.
 
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

#import "Document.h"
#import "ScrollView.h"
#import "FDXInterface.h"
#import "ColorView.h"
#import "BeatAppDelegate.h"
#import "FountainAnalysis.h"
#import "ColorCheckbox.h"
#import "SceneFiltering.h"
#import "FDXImport.h"
#import "OutlineExtractor.h"
#import "SceneCards.h"
#import "MarginView.h"
#import "OutlineViewItem.h"
#import "BeatModalInput.h"
#import "ThemeEditor.h"
#import "BeatFDXExport.h"
#import "ITSwitch.h"
#import "BeatTitlePageEditor.h"
#import "BeatLockButton.h"
#import "BeatColorMenuItem.h"
#import "BeatPlugin.h"
#import "BeatPluginManager.h"
#import "BeatWidgetView.h"
#import "BeatSegmentedControl.h"
#import "BeatNotepad.h"
#import "BeatCharacterList.h"
#import "BeatEditorFormatting.h"
#import "BeatPrintDialog.h"
#import "Beat-Swift.h"
#import "BeatEditorButton.h"


@interface Document () <BeatNativePreviewDelegate, BeatThemeManagedDocument, BeatTextIODelegate>

// Window
@property (weak) NSWindow *documentWindow;
@property (weak) IBOutlet TKSplitHandle *splitHandle;
@property (nonatomic) NSArray *itemsToValidate; // Menu items

// Cached
@property (atomic) NSData* dataCache;
@property (nonatomic) NSString* bufferedText;

// Autosave
@property (nonatomic) bool autosave;
@property (weak) NSTimer *autosaveTimer;
@property (nonatomic) NSString *contentCache;
@property (nonatomic) NSAttributedString *attributedContentCache;
//@property (nonatomic) NSURL *mostRecentlySavedFileURL;

// Plugin support
@property (weak) BeatPluginManager *pluginManager;

// Quick Settings
@property (nonatomic) NSPopover *quickSettingsPopover;
@property (nonatomic, weak) IBOutlet NSView *quickSettingsView;
@property (nonatomic, weak) IBOutlet ITSwitch *sceneNumbersSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *pageNumbersSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *revisionModeSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *taggingModeSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *darkModeSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *reviewModeSwitch;
@property (nonatomic, weak) IBOutlet NSPopUpButton *revisionColorPopup;
@property (nonatomic, weak) IBOutlet NSPopUpButton *pageSizePopup;

// Editor buttons
@property (nonatomic, weak) IBOutlet NSButton *outlineButton;
@property (nonatomic, weak) IBOutlet NSButton *previewButton;
@property (nonatomic, weak) IBOutlet NSButton *timelineButton;
@property (nonatomic, weak) IBOutlet NSButton *quickSettingsButton;
@property (nonatomic, weak) IBOutlet NSButton *cardsButton;
@property (nonatomic, weak) IBOutlet BeatLockButton *lockButton;

// Text view
@property (weak, nonatomic) IBOutlet BeatTextView *textView;
@property (nonatomic) IBOutlet BeatTextIO* textActions;
@property (weak, nonatomic) IBOutlet ScrollView *textScrollView;
@property (weak, nonatomic) IBOutlet MarginView *marginView;
@property (weak, nonatomic) IBOutlet NSClipView *textClipView;
@property (nonatomic) NSLayoutManager *layoutManager;
@property (nonatomic) bool documentIsLoading;

@property (nonatomic) bool autocomplete;
@property (nonatomic) bool autoLineBreaks;
@property (nonatomic) bool automaticContd;
@property (nonatomic) NSDictionary *postEditAction;
@property (nonatomic) bool typewriterMode;
@property (nonatomic) bool hideFountainMarkup;
@property (nonatomic) NSMutableArray *recentCharacters;

/// The last **change** range which was parsed, **not** the last edited range.
@property (nonatomic) NSRange lastChangedRange;

/// The range where last actual edit happened in text storage
@property (nonatomic) NSRange lastEditedRange;

@property (nonatomic) bool disableFormatting;
@property (nonatomic, weak) IBOutlet BeatAutocomplete *autocompletion;

@property (nonatomic) bool headingStyleBold;
@property (nonatomic) bool headingStyleUnderline;

// Views
@property (nonatomic) NSMutableSet *registeredViews;

// Sidebar & Outline view
@property (weak) IBOutlet BeatSegmentedControl *sideBarTabControl;
@property (weak) IBOutlet NSTabView *sideBarTabs;
@property (weak) IBOutlet BeatOutlineView *outlineView;
@property (weak) NSArray *draggedNodes;
@property (weak) OutlineScene *draggedScene; // Drag & drop for outline view
@property (nonatomic, weak) IBOutlet NSSearchField *outlineSearchField;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property (nonatomic) BOOL sidebarVisible;
@property (nonatomic) NSMutableArray *outlineClosedSections;
@property (nonatomic, weak) IBOutlet NSMenu *colorMenu;

@property (nonatomic, weak) IBOutlet BeatCharacterList *characterList;

// Right side view
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *rightSidebarConstraint;

// Outline view filtering
@property (nonatomic, weak) IBOutlet NSPopUpButton *characterBox;

// Notepad
@property (nonatomic, weak) IBOutlet BeatNotepad *notepad;

// Views
@property (weak) IBOutlet NSTabView *tabView; // Master tab view (holds edit/print/card views)
@property (weak) IBOutlet ColorView *backgroundView; // Master background
@property (weak) IBOutlet ColorView *outlineBackgroundView; // Background for outline

@property (weak) IBOutlet NSTabViewItem *editorTab;
@property (weak) IBOutlet NSTabViewItem *previewTab;
@property (weak) IBOutlet NSTabViewItem *cardsTab;
@property (weak) IBOutlet NSTabViewItem *nativePreviewTab;

@property (nonatomic) BeatPrintDialog *printDialog;

// Print preview
@property (nonatomic) NSString *htmlString;
//@property (nonatomic) IBOutlet BeatPreview *preview;
@property (nonatomic) IBOutlet BeatPreviewController *previewController;

// Analysis
@property (nonatomic) BeatStatisticsPanel *analysisWindow;

// Card view
@property (nonatomic, weak) IBOutlet SceneCards *cardView;
@property (nonatomic) bool cardsVisible;

// Mode display
@property (weak) IBOutlet BeatModeDisplay *modeIndicator;

// Timeline view
@property (weak) IBOutlet NSLayoutConstraint *timelineViewHeight;
@property (weak) IBOutlet NSTouchBar *touchBar;
@property (weak) IBOutlet NSTouchBar *timelineBar;
@property (weak) IBOutlet TouchTimelineView *touchbarTimeline;
@property (weak) IBOutlet TouchTimelinePopover *touchbarTimelineButton;

@property (weak) IBOutlet BeatTimeline *timeline;

// Scene number labels
@property (nonatomic) bool sceneNumberLabelUpdateOff;

// Scene number settings
@property (weak) IBOutlet NSPanel *sceneNumberingPanel;
@property (weak) IBOutlet NSTextField *sceneNumberStartInput;

// Content buffer
@property (strong, nonatomic) NSString *contentBuffer; //Keeps the text until the text view is initialized

// Fonts
@property (nonatomic) bool useSansSerif;
@property (nonatomic) NSUInteger fontSize;
@property (strong, nonatomic) NSFont *sectionFont;
@property (strong, nonatomic) NSMutableDictionary *sectionFonts;
@property (strong, nonatomic) NSFont *synopsisFont;

// Printing
@property (nonatomic) bool printPreview;
@property (nonatomic, readwrite) NSString *preprocessedText;

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

// Current line / scene
@property (nonatomic) Line *currentLine;
@property (nonatomic) Line *previouslySelectedLine;

// Autocompletion
@property (nonatomic) bool isAutoCompleting;
@property (readwrite, nonatomic) bool darkPopup;

// Touch bar
@property (nonatomic) NSColorPickerTouchBarItem *colorPicker;

// Parser
@property (strong, nonatomic) ContinuousFountainParser* parser;

// Title page editor
@property (nonatomic) BeatTitlePageEditor *titlePageEditor;

// Theme settings
@property (nonatomic) ThemeManager* themeManager;

// Timer
@property (weak) IBOutlet BeatTimer *beatTimer;

// Tagging
@property (weak) IBOutlet NSTextView *tagTextView;

@property (nonatomic) NSDate *executionTime;
@property (nonatomic) NSTimeInterval executionTimeCache;
@property (nonatomic) Line* lineCache;

@property (nonatomic) NSPanel* progressPanel;
@property (nonatomic) NSProgressIndicator *progressIndicator;

@property (nonatomic) BeatEditorFormatting *formatting;
@property (nonatomic, weak) IBOutlet BeatEditorFormattingActions *formattingActions;


// Sidebar tabs
@property (nonatomic, weak) IBOutlet NSTabViewItem *tabOutline;
@property (nonatomic, weak) IBOutlet NSTabViewItem *tabNotepad;
@property (nonatomic, weak) IBOutlet NSTabViewItem *tabDialogue;
@property (nonatomic, weak) IBOutlet NSTabViewItem *tabReviews;
@property (nonatomic, weak) IBOutlet NSTabViewItem *tabWidgets;

// Closing flag
@property (nonatomic) bool closing;

// Debug flags
@property (nonatomic) bool debug;


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

#pragma mark - Document Initialization

/// **Warning**: This is used for returning the actual document through editor delegate. Handle with care.
-(Document*)document {
	return self;
}

- (instancetype)init {
	self = [super init];
	return self;
}

- (void)close {
	self.closing = true;
	
	if (!self.hasUnautosavedChanges) {
		[self.documentWindow saveFrameUsingName:self.fileNameString];
	}
	
	// Avoid retain cycles with WKWebView
	// [self.preview deallocPreview];
	[self.cardView removeHandlers];
	
	
	// Terminate running plugins
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatPlugin* plugin = _runningPlugins[pluginName];
		[plugin end];
		[_runningPlugins removeObjectForKey:pluginName];
	}
	
	// This stuff is here to fix some strange memory issues.
	// it might be unnecessary, but I'm unfamiliar with both ARC & manual memory management
	[self.previewController.timer invalidate];
	[self.beatTimer.timer invalidate];
	self.beatTimer = nil;
	
	self.formatting = nil;
	
	for (NSView* view in _registeredViews) {
		[view removeFromSuperview];
	}
	[_registeredViews removeAllObjects];
	
	[self.textScrollView.mouseMoveTimer invalidate];
	[self.textScrollView.timerMouseMoveTimer invalidate];
	self.textScrollView.mouseMoveTimer = nil;
	self.textScrollView.timerMouseMoveTimer = nil;
	
	// Null other stuff, just in case
	_currentLine = nil;
	self.parser = nil;
	self.outlineView = nil;
	self.documentWindow = nil;
	self.contentBuffer = nil;
	self.analysisWindow = nil;
	self.currentScene = nil;
	self.cardView = nil;
	self.outlineView.filters = nil;
	self.outline = nil;
	self.outlineView.filteredOutline = nil;
	self.tagging = nil;
	self.itemsToValidate = nil;
	self.documentSettings = nil;
	self.review = nil;
	
	// Terminate autosave timer
	if (_autosaveTimer) [self.autosaveTimer invalidate];
	self.autosaveTimer = nil;
	
	// Kill observers
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[NSNotificationCenter.defaultCenter removeObserver:self.marginView];
	[NSNotificationCenter.defaultCenter removeObserver:self.widgetView];
	[NSDistributedNotificationCenter.defaultCenter removeObserver:self];
	
	// ApplicationDelegate will show welcome screen when no documents are open
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document close" object:nil];
	
	[super close];
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

static BeatAppDelegate *appDelegate;

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	// Hide the welcome screen
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document open" object:nil];
	
	[super windowControllerDidLoadNib:aController];
	
	_documentWindow = aController.window;
	_documentWindow.delegate = self;
	
	// Setup formatting
	_formatting = BeatEditorFormatting.new;
	_formatting.delegate = self;
	
	// Initialize document settings if needed
	if (!self.documentSettings) self.documentSettings = BeatDocumentSettings.new;
	
	// Initialize Theme Manager
	// (before formatting the content, because we need the colors for formatting!)
	self.themeManager = [ThemeManager sharedManager];
	[self loadSelectedTheme:false];
	
	// Setup views
	[self setupWindow];
	[self readUserSettings];
	[self setupMenuItems];
	
	// Load font set
	if (self.useSansSerif) [self loadSansSerifFonts];
	else [self loadSerifFonts];
	
	// Setup views
	[self setupResponderChain];
	[self setupTextView];
	[self setupTouchTimeline];
	[self setupAnalysis];
	[self setupColorPicker];
	[self.outlineView setup];
	[self.cardView setup];
	
	// Setup layout here first, but don't paginate
	[self setupLayoutWithPagination:NO];
	
	// Setup plugin management
	[self setupPlugins];
	
	// Print dialog
	self.printDialog.document = nil;
	
	//Put any previously loaded data into the text view
	self.documentIsLoading = YES;
	
	if (self.contentBuffer) {
		[self setText:self.contentBuffer];
	} else {
		self.contentBuffer = @"";
		[self setText:@""];
	}
	
	self.textView.alphaValue = 0;
	
	[self parseAndRenderDocument];
}

-(void)parseAndRenderDocument {
	// Initialize parser
	self.parser = [[ContinuousFountainParser alloc] initWithString:self.contentBuffer delegate:self];
	[self.revisionTracking setup]; // Initialize edit tracking
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		// Show a progress bar for longer documents
		if (self.parser.lines.count > 1000) {
			self.progressPanel = [[NSPanel alloc] initWithContentRect:(NSRect){(self.documentWindow.screen.frame.size.width - 300) / 2, (self.documentWindow.screen.frame.size.height - 50) / 2,300,50} styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
			
			// Dark mode
			if (@available(macOS 10.14, *)) {
				NSAppearance *appr = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
				[self.progressPanel setAppearance:appr];
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
	if (self.progressPanel != nil) [self.documentWindow endSheet:self.progressPanel];
	self.progressPanel = nil;
	
	[_parser.changedIndices removeAllIndexes];
	_attrTextCache = self.textView.attributedString;
	
	[self.review setup]; // Setup review system
	[self.tagging setup]; // Setup tagging
	
	// Document loading has ended
	self.documentIsLoading = NO;
	
	self.textActions = [BeatTextIO.alloc initWithDelegate:self];
	
	// Ensure layout with pagination
	[self setupLayoutWithPagination:YES];
	
	// Init autosave
	[self initAutosave];
	
	// Lock status
	if ([self.documentSettings getBool:@"Locked"]) [self lock];
	
	// Notepad
	if ([self.documentSettings getString:@"Notes"].length) [self.notepad loadString:[self.documentSettings getString:@"Notes"]];
	
	// If this a recovered autosave, the file might changed when it opens, so let's save this info
	bool saved = YES;
	if (self.hasUnautosavedChanges) saved = NO;
	
	// Sidebar
	[self restoreSidebar];
	
	// Setup page size
	[self.undoManager disableUndoRegistration]; // (We'll disable undo registration here, so the doc won't appear as edited on open)
	NSPrintInfo *printInfo = NSPrintInfo.sharedPrintInfo;
	self.printInfo = [BeatPaperSizing setSize:self.pageSize printInfo:printInfo];
	[self.undoManager enableUndoRegistration]; // Enable undo registration and clear any changes to the document (if needed)
	
	if (saved) [self updateChangeCount:NSChangeCleared];
	
	// Reveal text view
	[self.textView.animator setAlphaValue:1.0];
	
	// Update quick settings
	[self updateQuickSettings];
	
	// Hide Fountain markup if needed
	if (self.hideFountainMarkup) [self.textView redrawAllGlyphs];
	
	[_documentWindow layoutIfNeeded];
	[self updateLayout];
	
	// Open all plugins
	if (NSEvent.modifierFlags & NSEventModifierFlagShift) {
		// Pressing shift stops plugins from loading and stores and empty array instead
		[self.documentSettings set:DocSettingActivePlugins as:@[]];
	} else {
		NSDictionary* plugins = [self.documentSettings get:DocSettingActivePlugins];
		for (NSString* pluginName in plugins) {
			@try {
				[self runPluginWithName:pluginName];
			} @catch (NSException *exception) {
				NSLog(@"Plugin error: %@", exception);
			}
		}
	}
}

-(BeatExportSettings*)exportSettings {
	BeatExportSettings* settings = [BeatExportSettings operation:ForPreview document:self header:@"" printSceneNumbers:self.showSceneNumberLabels];

	settings.paperSize = self.pageSize;
	settings.revisions = BeatRevisions.revisionColors;
	
	return settings;
}

-(void)awakeFromNib {
	// Set up recovery file saving
	[NSDocumentController.sharedDocumentController setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
	
	[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(didChangeAppearance) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}

	
#pragma mark - Misc document stuff

- (NSString *)displayName {
	if (!self.fileURL) return @"Untitled";
	return [super displayName];
}

-(void)setValue:(id)value forUndefinedKey:(NSString *)key {
	NSLog(@"Document: Undefined key (%@) set. This might be intentional.", key);
}
-(id)valueForUndefinedKey:(NSString *)key {
	NSLog(@"Document: Undefined key (%@) requested. This might be intentional.", key);
	return nil;
}


#pragma mark - Handling user settings

- (void)readUserSettings {
	[BeatUserDefaults.sharedDefaults readUserDefaultsFor:self];
	
	// Do some additional setup if needed
	self.printSceneNumbers = self.showSceneNumberLabels;
	
	return;
}

- (void)applyUserSettings {
	// Apply settings from user preferences panel, some things have to be applied in every document.
	// This should be implemented as a singleton/protocol.
	
	bool oldHeadingStyleBold = self.headingStyleBold;
	bool oldHeadingStyleUnderline = self.headingStyleUnderline;
	bool oldSansSerif = self.useSansSerif;
	bool oldShowSceneNumbers = self.showSceneNumberLabels;
	bool oldHideFountainMarkup = self.hideFountainMarkup;
	bool oldShowPageNumbers = self.showPageNumbers;
	
	BeatUserDefaults *defaults = BeatUserDefaults.sharedDefaults;
	[defaults readUserDefaultsFor:self];
	
	if (oldHeadingStyleBold != self.headingStyleBold || oldHeadingStyleUnderline != self.headingStyleUnderline) {
		[self formatAllLinesOfType:heading];
		[self.previewController resetPreview];
	}
	
	if (oldSansSerif != self.useSansSerif) {
		if (self.useSansSerif) {
			[self loadSansSerifFonts];
			[self formatAllLines];
		} else {
			[self loadSerifFonts];
			[self formatAllLines];
		}
	}
	
	if (oldHideFountainMarkup != self.hideFountainMarkup) {
		[self.textView toggleHideFountainMarkup];
		[self ensureLayout];
	}
	
	if (oldShowPageNumbers != self.showPageNumbers) {
		if (self.showPageNumbers) [self paginateAt:(NSRange){ 0,0 } sync:YES];
		else {
			self.textView.pageBreaks = nil;
			[self.textView deletePageNumbers];
		}
	}
	
	if (oldShowSceneNumbers != self.showSceneNumberLabels) {
		if (self.showSceneNumberLabels) [self ensureLayout];
		//else [self.textView deleteSceneNumberLabels];
		
		// Update the print preview accordingly
		[self.previewController resetPreview];
	}
	
	[self updateQuickSettings];
}


#pragma mark - Window setup

/// Sets up the custom responder chain
- (void)setupResponderChain {
	// Our desired responder chain, add more custom responders when needed
	NSArray *chain = @[_formattingActions, _revisionTracking];
	
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
	NSSize size = NSMakeSize([_documentSettings getFloat:DocSettingWindowWidth], [_documentSettings getFloat:DocSettingWindowHeight]);
	
	CGFloat preferredWidth = self.documentWindow.minSize.width + BeatTextView.linePadding * 2 + 300;
	
	if (size.width < 1) {
		// Default size for new windows
		size.width = preferredWidth;
		origin.x = (screen.size.width - size.width) / 2;
	}
	else if (size.width < self.documentWindow.minSize.width || origin.x > screen.size.width || origin.x < 0) {
		// This window had a size saved. Let's make sure it stays inside screen bounds or is larger than minimum size.
		size.width = self.documentWindow.minSize.width;
		origin.x = (screen.size.width - size.width) / 2;
	}
	
	if (size.height < MIN_WINDOW_HEIGHT || origin.y + size.height > screen.size.height) {
		size.height = screen.size.height - 100;
		
		if (size.height < MIN_WINDOW_HEIGHT) size.height = MIN_WINDOW_HEIGHT;
		
		origin.y = (screen.size.height - size.height) / 2;
	}
	
	NSRect newFrame = NSMakeRect(origin.x, origin.y, size.width, size.height);
	[_documentWindow setFrame:newFrame display:YES];
}

-(void)setupLayoutWithPagination:(bool)paginate {
	// Apply layout
	
	[self updateLayout];
	[self ensureLayout];
	
	[self loadCaret];
	[self ensureCaret];
	//[self.preview updatePreviewInSync:NO];
	
	[self paginateAt:(NSRange){0,0} sync:YES];
}

// Can I come over, I need to rest
// lay down for a while, disconnect
// the night was so long, the day even longer
// lay down for a while, recollect

# pragma mark - Window interactions

/// Returns the index of current view
- (NSUInteger)selectedTab
{
	return [self.tabView indexOfTabViewItem:self.tabView.selectedTabViewItem];
}

/// Returns `true` when the editor view is visible
- (bool)editorTabVisible {
	if (self.currentTab == _editorTab) return YES;
	else return NO;
}

/// Move to another editor view
- (void)showTab:(NSTabViewItem*)tab {
	[self.tabView selectTabViewItem:tab];
	[tab.view.subviews.firstObject becomeFirstResponder];
}

/// Returns the currently visible "tab" in main window (meaning editor, preview, index cards, etc.)
- (NSTabViewItem*)currentTab {
	return self.tabView.selectedTabViewItem;
}

/// Returns `true` if the document window is full screen
- (bool)isFullscreen
{
	return ((_documentWindow.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

- (void)windowDidResize:(NSNotification *)notification
{
	CGFloat width = _documentWindow.frame.size.width;
	
	[_documentSettings setFloat:DocSettingWindowWidth as:width];
	[_documentSettings setFloat:DocSettingWindowHeight as:_documentWindow.frame.size.height];
	[self updateLayout];
}
- (void)updateLayout
{
	/*
	 I have no idea what this method does. I'm sorry.
	 */
	[self setMinimumWindowSize];

	[_textView setInsets];
	[self.textScrollView setNeedsDisplay:YES];
	[self.marginView setNeedsDisplay:YES];
	
	[self ensureLayout];
	[self ensureCaret];
}

- (void)setMinimumWindowSize {
	CGFloat width = (self.textView.documentWidth - (2 * BeatTextView.linePadding)) * self.magnification + 30;
	if (_sidebarVisible) width += _outlineView.frame.size.width;

	// Clamp the value. I can't use max methods.
	if (width > self.documentWindow.screen.frame.size.width) width = self.documentWindow.screen.frame.size.width;
	
	[self.documentWindow setMinSize:NSMakeSize(width, MIN_WINDOW_HEIGHT)];
}
- (CGFloat)documentWidth { return self.textView.documentWidth; }

/// Restores sidebar on launch
- (void)restoreSidebar {
	if ([self.documentSettings getBool:DocSettingSidebarVisible]) {
		self.sidebarVisible = YES;
		[_splitHandle restoreBottomOrLeftView];
		
		NSInteger sidebarWidth = [self.documentSettings getInt:DocSettingSidebarWidth];
		if (sidebarWidth == 0) sidebarWidth = MIN_OUTLINE_WIDTH;
		_splitHandle.mainConstraint.constant = sidebarWidth;
	}
}

/// Focuses the editor window
- (void)focusEditor {
	[self.documentWindow makeKeyWindow];
}

#pragma mark - Update Editor View by Mode

- (void)updateEditorMode {
	/// This updates the window by editor mode. When adding new modes, remember to call this method and add new conditionals.
	if (_mode == TaggingMode) [self.tagging open];
	else [self.tagging close];
	
	// Show mode indicator
	if (_mode != EditMode) {
		NSString *modeName = @"";
		if (_mode == TaggingMode) modeName = [BeatLocalization localizedStringForKey:@"mode.taggingMode"];
		else if (_mode == ReviewMode) modeName = [BeatLocalization localizedStringForKey:@"mode.reviewMode"];
		
		[_modeIndicator showModeWithModeName:modeName];
		
		_modeIndicator.hidden = NO;
		
	} else {
		_modeIndicator.hidden = YES;
	}
	
	[_documentWindow layoutIfNeeded];
	[self updateLayout];
	[self updateQuickSettings];
}

#pragma mark - Window delegate

static NSWindow __weak *currentKeyWindow;

-(void)windowWillBeginSheet:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	[self.documentWindow makeKeyAndOrderFront:self];
	[self hideAllPluginWindows];
}

-(void)windowDidEndSheet:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	[self showPluginWindowsForCurrentDocument];
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
	// Show all plugin windows associated with the current document
	[self showPluginWindowsForCurrentDocument];
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document changed" object:self];
	
	if (currentKeyWindow != nil && currentKeyWindow.visible) {
		[currentKeyWindow makeKeyAndOrderFront:nil];
	}
}
-(void)windowDidBecomeKey:(NSNotification *)notification {
	currentKeyWindow = nil;
	// Show all plugin windows associated with the current document
	if (notification.object == self.documentWindow && self.documentWindow.sheets.count == 0) {
		[self showPluginWindowsForCurrentDocument];
	}
}
-(void)windowDidResignKey:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	currentKeyWindow = NSApp.keyWindow;
	
	if ([currentKeyWindow isKindOfClass:NSOpenPanel.class]) {
		[self hideAllPluginWindows];
	} else if ([currentKeyWindow isKindOfClass:NSSavePanel.class] || self.documentWindow.sheets.count > 0) {
		[self hideAllPluginWindows];
		[self.documentWindow makeKeyAndOrderFront:nil];
	}
}

- (void)windowDidResignMain:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	// When window resigns it main status, we'll have to hide possible floating windows
	NSWindow *mainWindow = NSApp.mainWindow;
	if (self.documentWindow.isVisible) [self hidePluginWindowsWithMain:mainWindow];
}

- (void)hidePluginWindowsWithMain:(NSWindow*)mainWindow {
	for (NSString *pluginName in _runningPlugins.allKeys) {
		[_runningPlugins[pluginName] hideAllWindows];
		[_runningPlugins[pluginName] documentDidResignMain];
	}
	
	if (!mainWindow.isMainWindow && _runningPlugins.count > 0) {
		[mainWindow makeKeyAndOrderFront:nil];
	}
}


- (void)showPluginWindowsForCurrentDocument {
	// When document becomes main window, iterate through all documents.
	// If they have plugin windows open, hide those windows behind the current document window.
	for (Document *doc in NSDocumentController.sharedDocumentController.documents) {
		if (doc == self) continue;
		for (NSString *pluginName in doc.runningPlugins.allKeys) {
			[doc.runningPlugins[pluginName] hideAllWindows];
		}
	}
	
	// Reveal all plugin windows for the current document
	for (NSString *pluginName in _runningPlugins.allKeys) {
		[_runningPlugins[pluginName] showAllWindows];
	}
	
	[self.documentWindow orderFront:nil];
	
	// Notify running plugins that the window became main after the document *actually* is main window
	[self notifyPluginsThatWindowBecameMain];
}

- (void)hideAllPluginWindows {
	for (Document *doc in NSDocumentController.sharedDocumentController.documents) {
		for (NSString *pluginName in doc.runningPlugins.allKeys) {
			[(BeatPlugin*)doc.runningPlugins[pluginName] hideAllWindows];
		}
	}
}

-(void)spaceDidChange {
	if (!self.documentWindow.onActiveSpace) [self.documentWindow resignMainWindow];
}


#pragma mark - Quick Settings Popup

- (IBAction)showQuickSettings:(id)sender {
	if (!_quickSettingsPopover) {
		_quickSettingsPopover = [[NSPopover alloc] init];
		
		NSViewController *viewController = [[NSViewController alloc] init];
		[viewController setView:_quickSettingsView];
		
		[_quickSettingsPopover setContentViewController:viewController];
	}
	
	[self updateQuickSettings];
	
	NSButton *button = sender;
	
	if (!_quickSettingsPopover.shown) {
		[_quickSettingsPopover showRelativeToRect:NSMakeRect(0, 0, 0, 0) ofView:button preferredEdge:NSMaxYEdge];
		[_quickSettingsButton setState:NSOnState];
	}
	else {
		[self closeQuickSettings];
	}
}
- (void)closeQuickSettings {
	[_quickSettingsPopover close];
	[_quickSettingsButton setState:NSOffState];
}
- (void)updateQuickSettings {
	[_sceneNumbersSwitch setChecked:self.showSceneNumberLabels];
	[_pageNumbersSwitch setChecked:self.showPageNumbers];
	[_revisionModeSwitch setChecked:self.revisionMode];
	[_darkModeSwitch setChecked:self.isDark];
	
	NSInteger paperSize = [self.documentSettings getInt:DocSettingPageSize];
	
	if (paperSize == BeatA4) [_pageSizePopup selectItemWithTitle:@"A4"];
	else [_pageSizePopup selectItemWithTitle:@"US Letter"];
	
	if (self.mode == TaggingMode) [_taggingModeSwitch setChecked:YES]; else [_taggingModeSwitch setChecked:NO];
	
	for (BeatColorMenuItem* item in _revisionColorPopup.itemArray) {
		if ([item.colorKey.lowercaseString isEqualToString:self.revisionColor.lowercaseString]) [_revisionColorPopup selectItem:item];
	}
	
	if (self.mode == TaggingMode) {
		[_revisionColorPopup setEnabled:NO];
		[_revisionModeSwitch setEnabled:NO];
	} else {
		[_revisionColorPopup setEnabled:YES];
		[_revisionModeSwitch setEnabled:YES];
	}
	
	if (self.mode == ReviewMode) {
		[_reviewModeSwitch setChecked:YES];
	} else {
		[_reviewModeSwitch setChecked:NO];
	}
}

- (IBAction)toggleQuickSetting:(id)sender {
	ITSwitch *button = sender;
	
	if (button == _sceneNumbersSwitch) [self toggleSceneLabels:nil];
	else if (button == _pageNumbersSwitch) [self togglePageNumbers:nil];
	else if (button == _revisionModeSwitch) [self toggleRevisionMode:nil];
	else if (button == _taggingModeSwitch) [self toggleTagging:nil];
	else if (button == _darkModeSwitch) [self toggleDarkMode:nil];
	else if (button == _reviewModeSwitch) [self toggleReview:nil];
	
	[self updateQuickSettings];
}


#pragma mark - Zooming & layout

- (IBAction)zoomIn:(id)sender {
	if (self.currentTab == _editorTab) [self.textView zoom:YES];
	
	// Web preview zoom
	
	if (self.currentTab == _nativePreviewTab) {
		self.previewController.scrollView.magnification += .05;
	}
}
- (IBAction)zoomOut:(id)sender {
	if (self.currentTab == _editorTab) [self.textView zoom:NO];
	
	if (self.currentTab == _nativePreviewTab) {
		self.previewController.scrollView.magnification -= .05;
	}
}

- (IBAction)resetZoom:(id)sender {
	if (self.currentTab != _editorTab) return;
	[self.textView resetZoom];
}

- (CGFloat)magnification {
	return _textView.zoomLevel;
}

- (void)setSplitHandleMinSize:(CGFloat)value {
	self.splitHandle.topOrRightMinSize = value;
}

- (void)ensureLayout {
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
	// When ensuring layout, we'll update all scene number labels
	if (self.showPageNumbers) [self.textView updatePageNumbers];
	//if (self.showSceneNumberLabels) [self.textView resetSceneNumberLabels];
	
	self.textView.needsDisplay = true;
	self.textView.needsLayout = true;
	
	[self.marginView updateBackground];
}

- (void)ensureCaret {
	[self.textView updateInsertionPointStateAndRestartTimer:YES];
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

- (NSString*)createDocumentFile {
	return [self createDocumentFileWithAdditionalSettings:nil];
}
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings {
	// This puts together string content & settings block. It is returned to dataOfType:
	
	// Save tagged ranges
	// [self saveTags];
	
	// For async saving & thread safety, make a copy of the lines array
	NSAttributedString *attrStr = self.getAttributedText;
	NSString *content = self.parser.screenplayForSaving;
	if (content == nil) {
		NSLog(@"ERROR: Something went horribly wrong, trying to crash the app to avoid data loss.");
		@throw NSInternalInconsistencyException;
	}
	
	// Resort to content buffer if needed
	if (content == nil) content = self.contentCache;
	
	// Save added/removed ranges
	// This saves the revised ranges into Document Settings
	NSDictionary *revisions = [BeatRevisions rangesForSaving:attrStr];
	[_documentSettings set:DocSettingRevisions as:revisions];
	
	// Save current revision color
	[_documentSettings setString:DocSettingRevisionColor as:self.revisionColor];
	
	// Save changed indices (why do we need this? asking for myself. -these are lines that had something removed rather than added, a later response)
	[_documentSettings set:DocSettingChangedIndices as:[BeatRevisions changedLinesForSaving:self.lines]];
	
	// Store currently running plugins
	[_documentSettings set:DocSettingActivePlugins as:self.runningPlugins.allKeys];
	
	// Save reviewed ranges
	NSArray *reviews = [_review rangesForSavingWithString:attrStr];
	[_documentSettings set:DocSettingReviews as:reviews];
	
	// Save caret position
	[self.documentSettings setInt:DocSettingCaretPosition as:self.textView.selectedRange.location];
	
	[self unblockUserInteraction];
	
	NSString * settingsString = [self.documentSettings getSettingsStringWithAdditionalSettings:additionalSettings];
	NSString * result = [NSString stringWithFormat:@"%@%@", content, (settingsString) ? settingsString : @""];
	
	if (_runningPlugins.count) {
		for (NSString *pluginName in _runningPlugins.allKeys) {
			// Don't save the console instance
			if ([pluginName isEqualTo:@"Console"]) continue;
			
			BeatPlugin *plugin = _runningPlugins[pluginName];
			[plugin documentWasSaved];
		}
	}
	
	return result;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
	if (![url checkResourceIsReachableAndReturnError:outError]) return NO;
	return [super readFromURL:url ofType:typeName error:outError];
}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	return [self readFromData:data ofType:typeName error:outError reverting:NO];
}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError reverting:(BOOL)reverting {
	// Read settings
	if (!_documentSettings) _documentSettings = BeatDocumentSettings.new;
	
	// Load text & remove settings block
	NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
	NSRange settingsRange = [_documentSettings readSettingsAndReturnRange:text];
	text = [text stringByReplacingCharactersInRange:settingsRange withString:@""];

	// Remove unwanted control characters
	NSArray* t = [text componentsSeparatedByCharactersInSet:NSCharacterSet.badControlCharacters];
	text = [t componentsJoinedByString:@""];
	
	if (!reverting)	[self setText:text];
	else _contentBuffer = text; // When reverting, we only set the content buffer
	
	return YES;
}

- (void)registerEditorView:(id<BeatEditorView>)view {
	if (_registeredViews == nil) _registeredViews = NSMutableSet.set;;
	if (![_registeredViews containsObject:view]) [_registeredViews addObject:view];
}

- (NSDictionary*)revisedRanges {
	NSDictionary *revisions = [BeatRevisions rangesForSaving:self.getAttributedText];
	return revisions;
}
- (void)bakeRevisions {
	[BeatRevisions bakeRevisionsIntoLines:self.parser.lines text:self.getAttributedText];
}
- (NSArray*)shownRevisions {
	return BeatRevisions.revisionColors;
}

/*
 
 But if the while I think on thee,
 dear friend,
 All losses are restor'd,
 and sorrows end.
 
 */


# pragma mark - TextView interface

- (void)setupTextView {
	// Set insets on load
	[self.textView setup];
	[self.textView setInsets];
	
	// Make the text view first responder
	[_documentWindow makeFirstResponder:self.textView];
}

/// These are separate getters for easier iOS and Swift integration.
- (NSTextView*)getTextView {
	return self.textView;
}
- (NSMutableAttributedString*)textStorage {
	return self.textView.textStorage;
}
- (NSLayoutManager*)layoutManager {
	return self.textView.layoutManager;
}

- (NSString *)text {
	return self.textView.string;
}

- (void)loadCaret {
	NSInteger position = [self.documentSettings getInt:DocSettingCaretPosition];
	
	if (position < self.textView.string.length && position >= 0) {
		[self.textView setSelectedRange:NSMakeRange(position, 0)];
		[self.textView scrollRangeToVisible:NSMakeRange(position, 0)];
	}
}


#pragma mark - Reverting to versions

-(void)revertDocumentToSaved:(id)sender {
	if (!self.fileURL) return;
	
	NSData *data = [NSData dataWithContentsOfURL:self.fileURL];
	
	[self readFromData:data ofType:NSPlainTextDocumentType error:nil reverting:YES];
	[self.textView setString:_contentBuffer];
	[self.parser parseText:_contentBuffer];
	[self formatAllLines];
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
	_documentIsLoading = YES;
	
	[self readFromData:data ofType:typeName error:nil reverting:YES];
	
	//[self.textView deleteSceneNumberLabels];
	[self.textView deletePageNumbers];
	
	self.textView.alphaValue = 0.0;
	[self setText:_contentBuffer];
	[self parseAndRenderDocument];
	
	[self updateChangeCount:NSChangeCleared];
	[self updateChangeCount:NSChangeDone];
	[self.undoManager removeAllActions];
	
	return YES;
}


#pragma mark - Print & Export

- (NSUUID*)uuid {
	if (_uuid == nil) _uuid = NSUUID.new;
	return _uuid;
}

- (NSString*)fileNameString
{
	NSString* fileName = [self lastComponentOfFileName];
	NSUInteger lastDotIndex = [fileName rangeOfString:@"." options:NSBackwardsSearch].location;
	if (lastDotIndex != NSNotFound) fileName = [fileName substringToIndex:lastDotIndex];
	
	return fileName;
}

- (IBAction)openPrintPanel:(id)sender {
	_attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPrinting:self];
}
- (IBAction)openPDFPanel:(id)sender {
	_attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPDF:self];
}

- (void)releasePrintDialog {
	_printDialog = nil;
}

- (void)printDialogDidFinishPreview:(void (^)(void))block {
	block();
}


- (IBAction)exportFDX:(id)sender
{
	NSSavePanel *saveDialog = [NSSavePanel savePanel];
	[saveDialog setAllowedFileTypes:@[@"fdx"]];
	[saveDialog setNameFieldStringValue:[self fileNameString]];
	
	[saveDialog beginSheetModalForWindow:self.windowControllers[0].window completionHandler:^(NSInteger result) {
		if (result == NSModalResponseOK) {
			NSString* string = (self.text) ? self.text : @"";
			NSAttributedString* attrString = (self.textView.attributedString) ? self.textView.attributedString : NSAttributedString.new;
			
			BeatFDXExport *fdxExport = [[BeatFDXExport alloc] initWithString:string attributedString:attrString includeTags:YES includeRevisions:YES paperSize:[self.documentSettings getInt:DocSettingPageSize]];
			[fdxExport.fdxString writeToURL:saveDialog.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
		}
	}];
}

- (IBAction)exportOutline:(id)sender
{
	NSSavePanel *saveDialog = [NSSavePanel savePanel];
	[saveDialog setAllowedFileTypes:@[@"fountain"]];
	[saveDialog setNameFieldStringValue:[[self fileNameString] stringByAppendingString:@" Outline"]];
	[saveDialog beginSheetModalForWindow:self.windowControllers[0].window completionHandler:^(NSInteger result) {
		if (result == NSModalResponseOK) {
			NSString* outlineString = [OutlineExtractor outlineFromParse:self.parser];
			[outlineString writeToURL:saveDialog.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
		}
	}];
}


# pragma mark - Undo

- (IBAction)undoEdit:(id)sender {
	
	[self.undoManager undo];
	if (_cardsVisible) [self.cardView refreshCards:YES];
	
	// To avoid some graphical glitches
	[self ensureLayout];
}
- (IBAction)redoEdit:(id)sender {
	[self.undoManager redo];
	if (_cardsVisible) [self.cardView refreshCards:YES];
	
	// To avoid some graphical glitches
	[self ensureLayout];
}

/*
 
 and in a darkened underpass
 I thought, oh god, my chance has come at last
 but then
 a strange fear gripped me
 and I just couldn't ask
 
 */

#pragma mark - Text input settings

- (IBAction)toggleAutoLineBreaks:(id)sender {
	self.autoLineBreaks = !self.autoLineBreaks;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
}

- (IBAction)toggleMatchParentheses:(id)sender
{
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	for (Document* doc in openDocuments) doc.matchParentheses = !doc.matchParentheses;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
}


# pragma mark - Text events

#pragma mark Text should change
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	// Don't allow editing the script while tagging
	if (_mode != EditMode || self.contentLocked) return NO;
	Line* currentLine = self.currentLine;
	
	// Don't allow certain symbols
	if (replacementString.length == 1) {
		unichar c = [replacementString characterAtIndex:0];
		if ([NSCharacterSet.badControlCharacters characterIsMember:c]) {
			return false;
		}
	}
	
	// This shouldn't be here :-)
	if (replacementString.length == 1 && affectedCharRange.length == 0 && self.beatTimer.running) {
		if (![replacementString isEqualToString:@"\n"]) self.beatTimer.charactersTyped++;
	}
	
	// Check for character input trouble
	if (_characterInput && replacementString.length == 0 && NSMaxRange(affectedCharRange) == _characterInputForLine.position) {
		[self cancelCharacterInput];
		return NO;
	}
	
	// Don't repeat ) or ]
	if ([self.textActions shouldJumpOverParentheses:replacementString range:affectedCharRange] &&
		!self.undoManager.redoing && !self.undoManager.undoing) {
		return NO;
	}
	
	// Handle new line breaks (when actually typed)
	if ([replacementString isEqualToString:@"\n"] && affectedCharRange.length == 0 && !self.undoManager.isRedoing && !self.undoManager.isUndoing && !self.documentIsLoading) {
		
		// Line break after character cue
		if (currentLine.isAnyCharacter && self.automaticContd) {
			// Look back to see if we should add (cont'd), and if the CONT'D got added, don't run this method any longer
			if ([self shouldAddContdIn:affectedCharRange string:replacementString]) {
				return NO;
			}
		}
		
		// When on a parenthetical, don't split it when pressing enter, but move downwards to next dialogue block element
		// Note: This logic is a bit faulty. We should probably just move on next line regardless of next character
		else if (currentLine.isAnyParenthetical && self.selectedRange.length == 0) {
			if (self.textView.string.length >= affectedCharRange.location + 1) {
				unichar chr = [self.textView.string characterAtIndex:affectedCharRange.location];
				if (chr == ')') {
					NSInteger lineIndex = [self.lines indexOfObject:currentLine];
					[self addString:@"\n" atIndex:affectedCharRange.location + 1];
					if (lineIndex < self.lines.count) [_formatting formatLine:self.lines[lineIndex]];
					
					[self.textView setSelectedRange:(NSRange){ affectedCharRange.location + 2, 0 }];
					return NO;
				}
			}
		}
		
		// Handle automatic line breaks
		else if (self.autoLineBreaks) {
			if ([self.textActions shouldAddLineBreaks:currentLine range:affectedCharRange]) {
				return NO;
			}
		}
		
		// Process line break after a forced character input
		if (_characterInput && _characterInputForLine) {
			// Don't go out of range
			if (NSMaxRange(_characterInputForLine.textRange) <= self.textView.string.length) {
				// If the cue is empty, reset it
				if (_characterInputForLine.string.length == 0) {
					_characterInputForLine.type = empty;
					[_formatting formatLine:_characterInputForLine];
				}
				else {
					_characterInputForLine.forcedCharacterCue = YES;
				}
			}
		}
	}
	
	// Some checks for single characters
	else if (replacementString.length == 1 && !self.undoManager.isUndoing && !self.undoManager.isRedoing) {
		// Auto-close () and [[]]
		if (self.matchParentheses) [self.textActions matchParenthesesIn:affectedCharRange string:replacementString];
		
		// When adding to a dialogue block, add an extra line break
		if (self.currentLine.length == 0 && ![replacementString isEqualToString:@" "]) {
			NSInteger lineIndex = [self.parser indexOfLine:self.currentLine];
			if (lineIndex != NSNotFound && lineIndex > 0 && self.currentLine != self.parser.lines.lastObject) {
				Line *prevLine = self.parser.lines[lineIndex-1];
				Line *nextLine = self.parser.lines[lineIndex+1];
				if ((prevLine.isDialogueElement || prevLine.isDualDialogueElement) && prevLine.string.length > 0 && nextLine.isAnyCharacter) {
					NSString *stringAndLineBreak = [NSString stringWithFormat:@"%@\n", replacementString];
					[self addString:stringAndLineBreak atIndex:affectedCharRange.location];
					self.selectedRange = NSMakeRange(affectedCharRange.location+1, 0);
					return NO;
				}
			}
		}
	}
	
	// Make the replacement string uppercase in parser
	if (_characterInput) replacementString = replacementString.uppercaseString;
	
	// Parse changes so far
	[self.parser parseChangeInRange:affectedCharRange withString:replacementString];
	
	// Get current line after parsing
	_currentLine = [self getCurrentLine];
	
	_lastChangedRange = (NSRange){ affectedCharRange.location, replacementString.length };
	return YES;
}


- (BOOL)shouldAddContdIn:(NSRange)affectedCharRange string:(NSString*)replacementString {
	Line *currentLine = self.currentLine;
	NSInteger lineIndex = [self.parser indexOfLine:currentLine] - 1;
	
	// Don't add CONT'D when not editing this line
	if (!NSLocationInRange(lineIndex, NSMakeRange(0, self.parser.lines.count))) return NO;
		
	NSString *charName = currentLine.characterName;
		
	while (lineIndex > 0) {
		Line * prevLine = self.parser.lines[lineIndex];
		
		// Stop at headings
		if (prevLine.type == heading) break;
		
		if (prevLine.type == character) {
			// Stop if the previous character is not the current one
			if (![prevLine.characterName isEqualToString:charName]) break;
			
			// This is the character. Put in CONT'D and a line break and return NO
			NSString *contd = [BeatUserDefaults.sharedDefaults get:BeatSettingScreenplayItemContd];
			NSString *contdString = [NSString stringWithFormat:@" (%@)\n", contd];
			
			if (![currentLine.string containsString:[NSString stringWithFormat:@"(%@)", contd]]) {
				[self addString:contdString atIndex:currentLine.position + currentLine.length];
				return YES;
			}
		}
		
		lineIndex--;
	}

	return NO;
}

#pragma mark Text did change
- (void)textDidChange:(NSNotification *)notification
{
	// Begin from top if no last changed range was set
	if (_lastChangedRange.location == NSNotFound) _lastChangedRange = NSMakeRange(0, 0);
	
	// Save attributed text to cache
	_attrTextCache = [self getAttributedText];
	
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;
	
	// Update formatting
	[self applyFormatChanges];
	
	// If outline has changed, we will rebuild outline & timeline if needed
	//bool changeInOutline = [self.parser getAndResetChangeInOutline];
	
	// NOTE: calling this method removes the outline changes from parser
	// NSSet* changesInOutline = self.parser.changesInOutline;
	OutlineChanges* changesInOutline = self.parser.changesInOutline;

	// Update scene numbers
	for (OutlineScene* scene in changesInOutline.updated) {
		if (self.currentLine != scene.line) [self.layoutManager invalidateDisplayForCharacterRange:scene.line.textRange];
	}
	
	//if (changeInOutline == YES) {
	if (changesInOutline.hasChanges == YES) {
		// if (self.sidebarVisible && self.sideBarTabs.selectedTabViewItem == _tabOutline) [self.outlineView reloadOutline:changesInOutline.updatedElements];
		if (self.sidebarVisible && self.sideBarTabs.selectedTabViewItem == _tabOutline) [self.outlineView reloadOutlineWithChanges:changesInOutline];
		if (self.timeline.visible) [self.timeline reload];
		if (self.timelineBar.visible) [self reloadTouchTimeline];
		if (self.runningPlugins.count) [self updatePluginsWithOutline:self.parser.outline changes:changesInOutline];
	} else {
		if (self.timeline.visible) [_timeline refreshWithDelay];
	}
	
	// Editor views can register themselves and have to conform to BeatEditorView protocol,
	// which includes methods for reloading both in sync and async
	for (id<BeatEditorView> view in _registeredViews) {
		if (view.visible) [view reloadInBackground];
	}
		
	// Paginate
	[self paginateAt:_lastChangedRange sync:NO];
	
	// Update scene number labels
	// A larger chunk of text was pasted or there was a change in outline. Ensure layout.
	if (_lastChangedRange.length > 5) [self ensureLayout];
	
	// Update any running plugins
	if (_runningPlugins.count) [self updatePlugins:_lastChangedRange];
	
	// Save to buffer
	_contentCache = self.textView.string.copy;
	
	// Fire up autocomplete at the end of string and create cached lists of scene headings / character names
	if (self.autocomplete) [self.autocompletion autocompleteOnCurrentLine];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) {
		//[self.textView scrollToRange:NSMakeRange(_lastChangedRange.location, 0)];
		[self.textView ensureRangeIsVisible:_lastChangedRange];
	}
	
	// Reset last changed range
	_lastChangedRange = NSMakeRange(NSNotFound, 0);
	
	
}

-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
	// Faux delegate method forwarded from NSTextView.
	// Use if needed.
	if (_documentIsLoading) return;
	
	if (editedMask & NSTextStorageEditedCharacters) {
		self.lastEditedRange = NSMakeRange(editedRange.location, delta);
		
		// Register changes
		if (_revisionMode && _lastChangedRange.location != NSNotFound) {
			[self.revisionTracking registerChangesWithLocation:editedRange.location length:_lastChangedRange.length delta:delta];
		}
	}
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;
	
	// Close any popups
	if (_quickSettingsPopover.shown) [self closeQuickSettings];
	
	// Reset forced character input
	if (self.characterInputForLine != self.currentLine && self.characterInput) {
		self.characterInput = NO;
		if (_characterInputForLine.string.length == 0) {
			[self setTypeAndFormat:_characterInputForLine type:empty];
			_characterInputForLine = nil;
		}
	}
	
	// Correct parsing for character cues (we need to move this to parser somehow)
	Line *previouslySelectedLine = self.previouslySelectedLine;
	__weak static Line *previousCue;
	
	if (previouslySelectedLine.isAnyCharacter) {
		previousCue = previouslySelectedLine;
	}
	if (previouslySelectedLine != self.currentLine && previousCue.isAnyCharacter) {
		[_parser ensureDialogueParsingFor:previousCue];
	}
	
	// Update hidden Fountain markup
	[_textView updateMarkupVisibility];
	
	// Scroll to view if needed
	if (self.selectedRange.length == 0) {
		[self.textView scrollRangeToVisible:self.selectedRange];
	}
	
	// We REALLY REALLY should make some sort of cache for these, or optimize outline creation
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		// Update all views which are affected by the caret position
		if (self.sidebarVisible || self.timeline.visible || self.runningPlugins) {
			self.outline = [self getOutlineItems];
		}
		
		[self updateUIwithCurrentScene];
		
		// Update tag view
		if (self.mode == TaggingMode) [self.tagging updateTaggingData];
		
		// Update running plugins
		if (self.runningPlugins.count) [self updatePluginsWithSelection:self.selectedRange];
	});
}


#pragma mark - Line lookup

- (Line*)getPreviousLine:(Line*)line {
	NSInteger i = [self.parser indexOfLine:line];
	if (i > 0) return self.parser.lines[i - 1];
	else return nil;
}
- (Line*)getNextLine:(Line*)line {
	NSInteger i = [self.parser indexOfLine:line];
	if (i < self.parser.lines.count - 1 && i != NSNotFound) {
		return self.parser.lines[i + 1];
	} else {
		return nil;
	}
}

- (Line*)currentLine {
	_previouslySelectedLine = _currentLine;
	
	NSInteger location = self.selectedRange.location;
	if (location >= self.text.length) return self.parser.lines.lastObject;
	
	// Don't fetch the line if we already know it
	if (NSLocationInRange(location, _currentLine.range) && _currentLine != nil) {
		return _currentLine;
	}
	else {
		Line *line = [_parser lineAtPosition:location];
		_currentLine = line;
		return _currentLine;
	}
}

- (Line*)getCurrentLine {
	NSInteger location = self.selectedRange.location;
	if (location >= self.text.length) return self.parser.lines.lastObject;
	
	// Don't fetch the line if we already know it
	if (NSLocationInRange(location, _currentLine.range)) return _currentLine;
	else return [_parser lineAtPosition:location];
}

- (bool)inRange:(NSRange)range {
	NSRange intersection = NSIntersectionRange(range, (NSRange){0, _textView.string.length  });
	if (intersection.length == range.length) return YES;
	else return NO;
}

/// When the current scene has changed, some UI elements need to be updated. Add any required updates here.
/// TODO: Register the views which need scene index udpate.
- (void)updateUIwithCurrentScene
{
	__block NSInteger sceneIndex = [self.outline indexOfObject:self.currentScene];
	
	OutlineScene *currentScene = self.currentScene;
	
	// Update Timeline & TouchBar Timeline
	if (self.timeline.visible) [_timeline scrollToScene:sceneIndex];
	if (self.timelineBar.visible) [_touchbarTimeline selectItem:[_outline indexOfObject:currentScene]];
	
	// Locate current scene & reload outline without building it in parser
	if (self.sidebarVisible && !self.outlineView.dragging && !self.outlineView.editing) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self.outlineView scrollToScene:currentScene];
			self.outlineView.needsDisplay = true;
		});
	}

	self.sideBarTabs.needsDisplay = true;
	
	// Update touch bar color if needed
	if (currentScene.color) {
		NSColor* color = [BeatColors color:currentScene.color];
		if (color != nil) [_colorPicker setColor:[BeatColors color:currentScene.color]];
	}
		
	if (_runningPlugins) [self updatePluginsWithSceneIndex:sceneIndex];
}

# pragma mark - Scene lookup

- (OutlineScene*)currentScene
{
	// If we are not on the main thread, return the latest known scene
	if (!NSThread.isMainThread) return _currentScene;
	
	OutlineScene* scene = [self getCurrentSceneWithPosition:self.selectedRange.location];
	_currentScene = scene;
	return scene;
}

- (OutlineScene*)getCurrentSceneWithPosition:(NSInteger)position
{
	// If the position is inside the stored current scene, just return that.
	if (_currentScene && NSLocationInRange(position, _currentScene.range) && [self.parser.outline containsObject:_currentScene]) {
		return _currentScene;
	}
	
	// At the end, return last scene
	if (position >= self.text.length) return self.parser.outline.lastObject;
	
	OutlineScene *prevScene;
	for (OutlineScene *scene in self.outline) {
		if (NSLocationInRange(position, scene.range))  {
			return scene;
		}
		else if (position >= NSMaxRange(prevScene.range) && position < scene.position && prevScene) {
			return prevScene;
		}
		
		prevScene = scene;
	}
	
	return nil;
}

- (OutlineScene*)getPreviousScene {
	NSArray *outline = [self getOutlineItems];
	if (outline.count == 0) return nil;
	
	Line * currentLine = [self getCurrentLine];
	NSInteger lineIndex = [self.parser indexOfLine:currentLine] ;
	if (lineIndex == NSNotFound || lineIndex >= self.parser.lines.count - 1) return nil;
	
	for (NSInteger i = lineIndex - 1; i >= 0; i--) {
		Line* line = self.parser.lines[i];
		
		if (line.type == heading || line.type == section) {
			for (OutlineScene *scene in outline) {
				if (scene.line == line) return scene;
			}
		}
	}
	
	return nil;
}
- (OutlineScene*)getNextScene {
	NSArray *outline = [self getOutlineItems];
	if (outline.count == 0) return nil;
	
	Line * currentLine = [self getCurrentLine];
	NSInteger lineIndex = [self.parser indexOfLine:currentLine] ;
	if (lineIndex == NSNotFound || lineIndex >= self.parser.lines.count - 1) return nil;
	
	for (NSInteger i = lineIndex + 1; i < self.parser.lines.count; i++) {
		Line* line = self.parser.lines[i];
		
		if (line.type == heading || line.type == section) {
			for (OutlineScene *scene in outline) {
				if (scene.line == line) return scene;
			}
		}
	}
	
	return nil;
}


/*
 
 FREE ABORTIONS.
 CLEAN WATER.
 
 */


#pragma mark - Text I/O

/*
 TODO: Harmonize _attrTextCache, preferrably as a getter
 */
- (NSAttributedString *)getAttributedText
{
	if (NSThread.isMainThread) {
		_attrTextCache = [[NSAttributedString alloc] initWithAttributedString:self.textView.textStorage];
		return _attrTextCache;
	} else {
		return _attrTextCache;
	}
}
- (NSAttributedString*)attributedString {
	return [self getAttributedText];
}

- (void)setText:(NSString *)text
{
	if (!self.textView) {
		// View is not ready yet, set text to buffer
		self.contentBuffer = text;
	} else {
		// Set text on screen
		[self.textView setString:text];
	}
}

- (void)setTypingAttributes:(NSDictionary*)attrs {
	self.textView.typingAttributes = attrs;
}

/**
 Main method for adding text to editor view.  Forces added text to be parsed. Does NOT invoke undo manager.
 */
FORWARD_TO(self.textActions, void, replaceCharactersInRange:(NSRange)range withString:(NSString*)string);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks);
FORWARD_TO(self.textActions, void, replaceRange:(NSRange)range withString:(NSString*)newString);
FORWARD_TO(self.textActions, void, replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, removeRange:(NSRange)range);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position);
FORWARD_TO(self.textActions, void, moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to);
FORWARD_TO(self.textActions, void, removeTextOnLine:(Line*)line inLocalIndexSet:(NSIndexSet*)indexSet);

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
	return NSMakeRange(range->location + position, range->length);
}

- (void)removeAttribute:(NSString*)key range:(NSRange)range {
	if (key == nil) return;
	[self.textView.textStorage removeAttribute:key range:range];
}
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range {
	if (value == nil) return;
	[self.textView.textStorage addAttribute:key value:value range:range];
}
- (void)addAttributes:(NSDictionary*)attributes range:(NSRange)range {
	if (attributes == nil) return;
	[self.textView.textStorage addAttributes:attributes range:range];
}

- (void)setAutomaticTextCompletionEnabled:(BOOL)value {
	self.textView.automaticTextCompletionEnabled = value;
}

// There is no shortage of ugliness in the world.
// If a person closed their eyes to it,
// there would be even more.

#pragma mark - Block / paragraph methods

- (IBAction)moveSelectedLinesUp:(id)sender {
	//NSArray *lines = [self.parser blockFor:[self.parser lineAtIndex:self.selectedRange.location]];
	NSArray *lines = [self.parser blockForRange:self.selectedRange];
	[self moveBlockUp:lines];
}
- (IBAction)moveSelectedLinesDown:(id)sender {
	//NSArray *lines = [self.parser blockFor:[self.parser lineAtIndex:self.selectedRange.location]];
	NSArray *lines = [self.parser blockForRange:self.selectedRange];
	[self moveBlockDown:lines];
}

- (void)moveBlockUp:(NSArray<Line*>*)lines {
	if (lines.firstObject == self.lines.firstObject) return;
	
	NSUInteger prevIndex = [self.parser indexOfLine:lines.firstObject] - 1;
	Line* prevLine = self.lines[prevIndex];
	
	NSArray *prevBlock = [self.parser blockFor:prevLine];
	
	Line *firstLine = prevBlock.firstObject;
	NSInteger position = firstLine.position; // Save the position so we don't move the block at the wrong position
	
	// If the block doesn't have an empty line at the end, create one
	if (lines.lastObject.length > 0) [self addString:@"\n" atIndex:position];
	
	NSRange blockRange = [self rangeForBlock:lines];
	[self moveStringFrom:blockRange to:position];
	if (blockRange.length > 0) [self setSelectedRange:NSMakeRange(position, blockRange.length - 1)];
}

- (void)moveBlockDown:(NSArray<Line*>*)lines {
	// Don't move downward if we're already at the last object
	if (lines.lastObject == self.lines.lastObject ||
		lines.count == 0) return;
	
	NSUInteger nextIndex = [self.parser indexOfLine:lines.lastObject] + 1;
	Line* nextLine = self.lines[nextIndex];
	
	// Get the next block (paragraph/dialogue block)
	NSArray* nextBlock = [self.parser blockFor:nextLine];
	Line *endLine = nextBlock.lastObject;
	if (endLine == nil) return;
	
	NSRange blockRange = [self rangeForBlock:lines];
	
	if (endLine.string.length > 0) {
		// Add a line break if we're moving a block at the end
		[self addString:@"" atIndex:NSMaxRange(endLine.textRange)];
	}
	
	[self moveStringFrom:blockRange to:NSMaxRange(endLine.range)];
	
	if (![_parser.lines containsObject:endLine]) {
		// The last line was deleted in the process, so let's find the one that's still there.
		NSInteger i = lines.count;
		while (i > 0) {
			i--;
			if ([_parser.lines containsObject:lines[i]]) {
				endLine = lines[i];
				break;
			}
		}
	}
	
	// Select the moved line
	if (blockRange.length > 0) {
		[self setSelectedRange:NSMakeRange(NSMaxRange(endLine.range), blockRange.length - 1)];
	}
}

- (IBAction)copyBlock:(id)sender {
	NSArray *block = [_parser blockForRange:self.selectedRange];
	NSRange range = [self rangeForBlock:block];
	
	[self setSelectedRange:range];
	[self.textView copy:self];
}
- (IBAction)cutBlock:(id)sender {
	NSArray *block = [_parser blockForRange:self.selectedRange];
	NSRange range = [self rangeForBlock:block];
	
	[self setSelectedRange:range];
	[self.textView cut:self];
}

- (NSRange)rangeForBlock:(NSArray<Line*>*)block {
	NSRange range = NSMakeRange(block.firstObject.position, NSMaxRange(block.lastObject.range) - block.firstObject.position);
	return range;
}


# pragma mark - Autocomplete stub

/// Forwarding method for autocompletion
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	return [_autocompletion completions:words forPartialWordRange:charRange indexOfSelectedItem:index];
}

#pragma mark - Character input

- (void)handleTabPress {
	// Force character if the line is suitable
	Line *currentLine = self.currentLine;
	
	if (currentLine.isAnyCharacter && currentLine.string.length > 0) {
		[self addCharacterExtension];
	} else {
		[self forceCharacterInput];
	}
}

- (void)addCharacterExtension {
	Line * currentLine = self.currentLine;
	
	if (currentLine.hasExtension) {
		// Move the caret to extension
		NSInteger loc = [currentLine.string rangeOfString:@"("].location;
		self.textView.selectedRange = NSMakeRange(loc + currentLine.position + 1, 0);
	} else {
		// Add a new extension placeholder
		NSInteger loc = currentLine.string.length;
		[self addString:@" ()" atIndex:NSMaxRange(currentLine.textRange)];
		self.textView.selectedRange = NSMakeRange(currentLine.position + loc + 2, 0);
	}
}

- (void)forceCharacterInput {
	// Don't allow this to happen twice
	if (_characterInput) return;
	
	[self.formattingActions addCue];
	[self.formatting forceEmptyCharacterCue];
}

- (void)cancelCharacterInput {
	// TODO: Move this to text view
	_characterInput = NO;
	_characterInputForLine = nil;
	
	NSMutableDictionary *attributes = NSMutableDictionary.dictionary;
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	[attributes setValue:self.courier forKey:NSFontAttributeName];
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[paragraphStyle setFirstLineHeadIndent:0];
	[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
	[self.textView setTypingAttributes:attributes];
	self.textView.needsDisplay = YES;
	self.textView.needsLayout = YES;
	
	[self setTypeAndFormat:_characterInputForLine type:empty];
}

- (void)addRecentCharacter:(NSString*)name {
	// Update 2022/03: WTF is this?
	
	// Init array if needed
	if (_recentCharacters == nil) _recentCharacters = NSMutableArray.new;
	
	// Remove any suffixes
	name = [name replace:RX(@"\\((.*)\\)") with:@""];
	name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	if ([_recentCharacters indexOfObject:name] != NSNotFound) {
		[_recentCharacters removeObject:name];
		[_recentCharacters insertObject:name atIndex:0];
	}
}


#pragma mark - Formatting

/**
 Actual formatting is handled in BeatFormatting, and these methods either forward there or handle specific tasks, such as formatting all lines etc.
 */

- (CGFloat)editorLineHeight { return BeatEditorFormatting.editorLineHeight; }

- (void)formatLine:(Line*)line {
	// Forwarding for delegation
	[_formatting formatLine:line];
}

- (IBAction)reformatEverything:(id)sender {
	[self.parser resetParsing];
	[self applyFormatChanges];
	[self formatAllLines];
}

- (void)formatAllLinesOfType:(LineType)type
{
	for (Line* line in self.parser.lines) {
		if (line.type == type) [_formatting formatLine:line];
	}
	
	[self ensureLayout];
}

- (void)formatAllLines
{

	for (Line* line in self.parser.lines) {
		@autoreleasepool { [_formatting formatLine:line]; }
	}
	
	[self.parser.changedIndices removeAllIndexes];
	[self ensureLayout];
}

/// When something was changed, this method takes care of reformatting every line
- (void)applyFormatChanges
{
	[self.parser.changedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		[_formatting formatLine:self.parser.lines[idx]];
	}];
	
	[self.parser.changedIndices removeAllIndexes];
}

/// Forces reformatting of a range
- (void)forceFormatChangesInRange:(NSRange)range
{
	[self.textView.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor forCharacterRange:range];
	
	NSArray *lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		[_formatting formatLine:line];
	}
}

/// Applies the initial formatting while document is loading
-(void)applyInitialFormatting {
	if (self.parser.lines.count == 0) { // addition
		[self loadingComplete];
		return;
	}
	
	self.progressIndicator.maxValue =  1.0;
	[self formatAllWithDelayFrom:0];
}

/// Formats all lines while loading the document
- (void)formatAllWithDelayFrom:(NSInteger)idx {
	// We split the document into chunks of 400 lines and render them asynchronously
	// to throttle the initial loading of document a bit
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		Line *line;
		NSInteger lastIndex = idx;
		
		for (NSInteger i = 0; i < 400; i++) {
			// After 400 lines, hand off the process
			if (i + idx >= self.parser.lines.count) break;
			
			line = self.parser.lines[i + idx];
			lastIndex = i + idx;
			[self.formatting formatLine:line firstTime:YES];
		}
		
		[self.progressIndicator incrementBy:400.0 / self.parser.lines.count];
		
		if (line == self.parser.lines.lastObject || lastIndex >= self.parser.lines.count) {
			// If the document is done formatting, complete the loading process.
			[self loadingComplete];
		} else {
			// Else render 400 more lines
			[self formatAllWithDelayFrom:lastIndex + 1];
		}
	});
}


- (IBAction)reformatRange:(id)sender {
	if (self.textView.selectedRange.length > 0) {
		NSArray *lines = [self.parser linesInRange:self.textView.selectedRange];
		if (lines) [self.parser correctParsesForLines:lines];
		[self.parser createOutline];
		[self ensureLayout];
	}
}

- (IBAction)toggleDisableFormatting:(id)sender {
	_disableFormatting = !_disableFormatting;
	[self formatAllLines];
}

- (void)renderBackgroundForLines {
	for (Line* line in self.lines) {
		// Invalidate layout
		[self.layoutManager invalidateDisplayForCharacterRange:line.textRange];
	}
}

- (void)renderBackgroundForRange:(NSRange)range {
	NSArray *lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		// Invalidate layout
		[self.layoutManager invalidateDisplayForCharacterRange:line.textRange];
	}
}

- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear {
	// Invalidate layout
	[self.layoutManager invalidateDisplayForCharacterRange:line.textRange];
}

/// Forces a type on a line and formats it accordingly. Can be abused for doing strange and esoteric stuff.
- (void)setTypeAndFormat:(Line*)line type:(LineType)type {
	line.type = type;
	[self formatLine:line];
}


#pragma mark - Parser delegation

- (NSRange)selectedRange {
	return self.textView.selectedRange;
}
- (void)setSelectedRange:(NSRange)range {
	[self setSelectedRange:range withoutTriggeringChangedEvent:NO];
}
/// Set selected range but DO NOT trigger the didChangeSelection: event
- (void)setSelectedRange:(NSRange)range withoutTriggeringChangedEvent:(bool)triggerChangedEvent {
	_skipSelectionChangeEvent = triggerChangedEvent;
	
	@try {
		[self.textView setSelectedRange:range];
	}
	@catch (NSException *e) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"Selection out of range";
	}
}

- (bool)caretAtEnd {
	return (self.textView.selectedRange.location == self.textView.string.length);
}

- (void)reformatLinesAtIndices:(NSMutableIndexSet *)indices {
	[indices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		NSMutableString *str = [NSMutableString string];
		
		Line *line = _parser.lines[idx];
		
		[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			[str appendString:[line.string substringWithRange:range]];
		}];
		
		[_formatting formatLine:line];
	}];
}

#pragma mark - Caret methods

- (void)resetCaret {
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
	
	[paragraphStyle setFirstLineHeadIndent:0];
	[paragraphStyle setHeadIndent:0];
	[paragraphStyle setTailIndent:0];
	
	[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	[self.textView setTypingAttributes:attributes];
}

- (bool)caretOnLine:(Line*)line {
	if (self.textView.selectedRange.location >= line.position && self.textView.selectedRange.location <= line.position + line.string.length) return YES;
	else return NO;
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

- (void)loadSerifFonts {
	_courier = BeatFonts.sharedFonts.courier;
	[self loadFont];
}
- (void)loadSansSerifFonts {
	_courier = BeatFonts.sharedSansSerifFonts.courier;
	[self loadFont];
}
- (void)loadFont {
	_boldCourier = [_courier withTraits:NSFontDescriptorTraitBold];
	_italicCourier = [_courier withTraits:NSFontDescriptorTraitItalic];
	_boldItalicCourier = [_courier withTraits:NSFontDescriptorTraitBold | NSFontDescriptorTraitItalic];
	self.textView.font = _courier;
}

- (IBAction)selectSerif:(id)sender {
	NSMenuItem* item = sender;
	if (item.state != NSOnState) self.useSansSerif = NO;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc loadSerifFonts];
		[doc formatAllLines];
	}
}
- (IBAction)selectSansSerif:(id)sender {
	NSMenuItem* item = sender;
	if (item.state != NSOnState) self.useSansSerif = YES;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc loadSansSerifFonts];
		[doc formatAllLines];
	}
}
- (void)reloadFonts {
	[self formatAllLines];
}

- (NSFont*)sectionFont
{
	if (!_sectionFont) {
		_sectionFont = [NSFont boldSystemFontOfSize:17.0];
	}
	return _sectionFont;
}

- (NSFont*)sectionFontWithSize:(CGFloat)size
{
	// Init dictionary if it's unset
	if (!_sectionFonts) _sectionFonts = [NSMutableDictionary dictionary];
	
	// We'll store fonts of varying sizes on the go, because why not?
	// No, really, why shouldn't we?
	NSString *sizeKey = [NSString stringWithFormat:@"%f", size];
	if (!_sectionFonts[sizeKey]) {
		[_sectionFonts setValue:[NSFont boldSystemFontOfSize:size] forKey:sizeKey];
	}
	
	return (NSFont*)_sectionFonts[sizeKey];
}

- (NSFont*)synopsisFont
{
	if (!_synopsisFont) {
		_synopsisFont = [NSFont systemFontOfSize:11.0];
		NSFontManager *fontManager = [[NSFontManager alloc] init];
		_synopsisFont = [fontManager convertFont:_synopsisFont toHaveTrait:NSFontItalicTrait];
	}
	return _synopsisFont;
}

// This is here for legacy reasons
- (NSUInteger)fontSize
{
	return BeatFonts.sharedFonts.courier.pointSize;
}
- (CGFloat)lineHeight { return LINE_HEIGHT; }


#pragma mark - Formatting Buttons

- (IBAction)showForceMenu:(id)sender {
	[self.textView forceElement:self];
}

- (void)forceElement:(LineType)lineType {
	[self.formattingActions forceElement:lineType];
}

#pragma mark - Revision Tracking

// UI side

-(IBAction)toggleShowRevisions:(id)sender {
	_showRevisions = !_showRevisions;
	
	// Refresh layout + settings
	[self.textView refreshLayoutElements];
	self.textView.needsLayout = true;
	self.textView.needsDisplay = true;
	[self updateQuickSettings];
	
	// Save user default
	[BeatUserDefaults.sharedDefaults saveBool:_showRevisions forKey:@"showRevisions"];
}

-(IBAction)toggleShowRevisedTextColor:(id)sender {
	bool revisedText = [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisedTextColor];
	[BeatUserDefaults.sharedDefaults saveBool:!revisedText forKey:BeatSettingShowRevisedTextColor];
	
	[self.formatting refreshRevisionTextColors];
}
- (bool)showRevisedTextColor {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisedTextColor];
}

-(IBAction)toggleRevisionMode:(id)sender {
	_revisionMode = !_revisionMode;
	
	[self updateQuickSettings];
	
	// Save document setting
	[_documentSettings setBool:DocSettingRevisionMode as:_revisionMode];
}
- (IBAction)markAddition:(id)sender
{
	if (!self.contentLocked) {
		NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
		[self.revisionTracking markerAction:RevisionAddition];
		[self.formatting refreshRevisionTextColorsInRange:range];
	}
}
- (IBAction)markRemoval:(id)sender
{
	if (!self.contentLocked) {
		NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
		[self.revisionTracking markerAction:RevisionRemovalSuggestion];
		[self.formatting formatLinesInRange:range];
	}
}
- (IBAction)clearMarkings:(id)sender
{
	// Remove markers
	if (!self.contentLocked) {
		NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
		[self.revisionTracking markerAction:RevisionNone];
		[self.formatting refreshRevisionTextColorsInRange:range];
	}
}

- (IBAction)commitRevisions:(id)sender {
	[self.revisionTracking commitRevisions];
	[self.formatting refreshRevisionTextColors];
}

- (IBAction)selectRevisionColor:(id)sender {
	NSPopUpButton *button = sender;
	BeatColorMenuItem *item = (BeatColorMenuItem *)button.selectedItem;
	NSString* revisionColor = item.colorKey;
	
	[_documentSettings setString:DocSettingRevisionColor as:revisionColor];
}

- (NSString*)revisionColor {
	NSString* revisionColor = [_documentSettings getString:DocSettingRevisionColor];
	if (revisionColor == nil) revisionColor = BeatRevisions.defaultRevisionColor;
	return revisionColor;
}



#pragma mark - Lock & Force Scene Numbering

- (IBAction)unlockSceneNumbers:(id)sender
{
	_sceneNumberLabelUpdateOff = YES;
	for (Line *line in self.lines) {
		if (line.type != heading) continue;
		
		NSRange sceneNumberRange = line.sceneNumberRange;
		if (sceneNumberRange.length) {
			// Scene number range is only the range of the actual number (no idea why, I was young
			// and naive), so we need to expand it.
			sceneNumberRange.location -= 1;
			sceneNumberRange.length += 2;
			NSIndexSet *sceneNumberIndices = [NSIndexSet indexSetWithIndexesInRange:sceneNumberRange];
			[self removeTextOnLine:line inLocalIndexSet:sceneNumberIndices];
		}
	}
	
	_sceneNumberLabelUpdateOff = false;
	[self ensureLayout];
}


- (IBAction)lockSceneNumbers:(id)sender
{
	NSInteger sceneNumber = [self.documentSettings getInt:@"Scene Numbering Starts From"];
	if (sceneNumber == 0) sceneNumber = 1;
	
	for (Line* line in self.parser.lines) {
		if (line.type != heading) continue;
		
		if (line.sceneNumberRange.length == 0) {
			NSString * sn = [NSString stringWithFormat:@" #%lu#", sceneNumber];
			[self addString:sn atIndex:line.textRange.location + line.textRange.length];
			sceneNumber++;
		} else {
			
		}
	}
	[self ensureLayout];
	[self.textView refreshLayoutElements];
}

- (void)undoSceneNumbering:(NSString*)rawText
{
	self.documentIsLoading = YES;
	[self.textView replaceCharactersInRange:NSMakeRange(0, self.textView.string.length) withString:rawText];
	[self.parser parseText:rawText];
	[self applyFormatChanges];
	self.documentIsLoading = NO;
	
	[self ensureLayout];
	
	[self.textView refreshLayoutElements];
}

- (IBAction)forceSceneNumberForScene:(id)sender
{
	BeatModalInput *input = BeatModalInput.new;
	
	[input inputBoxWithMessage:[BeatLocalization localizedStringForKey:@"editor.setSceneNumber"]
						  text:[BeatLocalization localizedStringForKey:@"editor.setSceneNumber.info"]
				   placeholder:@"123A" forWindow:_documentWindow
					completion:^(NSString * _Nonnull result) {
						if (result.length > 0) {
							OutlineScene *scene = self.currentScene;
							
							if (scene) {
								if (scene.line.sceneNumberRange.length) {
									// Remove existing scene number
									[self replaceRange:(NSRange){ scene.line.position + scene.line.sceneNumberRange.location, scene.line.sceneNumberRange.length } withString:result];
								} else {
									// Add empty scene number
									[self addString:[NSString stringWithFormat:@" #%@#", result] atIndex:scene.line.position + scene.line.string.length];
								}
							}
						}
	}];
}


#pragma mark - Menus

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}
- (IBAction)export:(id)sender {}

- (void)setupMenuItems {
	// Menu items which need to check their on/off state against bool properties in this class
	_itemsToValidate = @[
		// Swift class alternative:
		// [BeatValidationItem.alloc initWithAction:@selector(toggleMatchParentheses:) setting:@"matchParentheses" target:self],
		
		[BeatValidationItem.alloc initWithAction:@selector(toggleMatchParentheses:) setting:BeatSettingMatchParentheses target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleAutoLineBreaks:) setting:BeatSettingAutomaticLineBreaks target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleSceneLabels:) setting:BeatSettingShowSceneNumbers target:self],
		[BeatValidationItem.alloc initWithAction:@selector(togglePageNumbers:) setting:BeatSettingShowPageNumbers target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleTypewriterMode:) setting:BeatSettingTypewriterMode target:self],
		[BeatValidationItem.alloc initWithAction:@selector(togglePrintSceneNumbers:) setting:BeatSettingPrintSceneNumbers target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleAutosave:) setting:BeatSettingAutosave target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleHideFountainMarkup:) setting:BeatSettingHideFountainMarkup target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleDisableFormatting:) setting:BeatSettingDisableFormatting target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleShowRevisions:) setting:BeatSettingShowRevisions target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleShowRevisedTextColor:) setting:BeatSettingShowRevisedTextColor target:self],
		
		[BeatValidationItem.alloc initWithAction:@selector(toggleRevisionMode:) setting:@"revisionMode" target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleTimeline:) setting:@"timelineVisible" target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleSidebarView:) setting:@"sidebarVisible" target:self],
		
		[BeatValidationItem.alloc initWithAction:@selector(lockContent:) setting:@"Locked" target:self.documentSettings],
	];
}
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Special conditions for other than normal edit view
	if (self.currentTab != _editorTab) {
		// If PRINT PREVIEW is enabled
		if (self.currentTab == _previewTab || self.currentTab == _nativePreviewTab) {
			if (menuItem.action == @selector(preview:)) {
				[menuItem setState:NSOnState];
				return YES;
			}
			
			if (menuItem.action == @selector(zoomIn:) ||
				menuItem.action == @selector(zoomOut:) ||
				menuItem.action == @selector(openPrintPanel:) ||
				menuItem.action == @selector(openPDFPanel:)
				) return YES;
		}
		
		// If CARD VIEW is enabled
		if (self.currentTab == _cardsTab) {
			//
			if (menuItem.action == @selector(toggleCards:)) {
				menuItem.state = NSOnState;
				return YES;
			}
			
			// Allow undoing scene move in card view, but nothing else
			if (menuItem.action == @selector(undoEdit:)) {
				//if ([menuItem.title rangeOfString:@"Undo"].location != NSNotFound) {
				if ([self.undoManager.undoActionName isEqualToString:@"Move Scene"]) {
					NSString *title = NSLocalizedString(@"general.undo", nil);
					menuItem.title = [NSString stringWithFormat:@"%@ %@", title, [self.undoManager undoActionName]];
					return YES;
				}
			}
			
			// Allow redoing, too
			if (menuItem.action == @selector(redoEdit:)) {
				//if ([menuItem.title rangeOfString:@"Redo"].location != NSNotFound) {
				if ([self.undoManager.redoActionName isEqualToString:@"Move Scene"]) {
					NSString *title = NSLocalizedString(@"general.redo", nil);
					menuItem.title = [NSString stringWithFormat:@"%@ %@", title, [self.undoManager redoActionName]];
					return YES;
				}
			}
		}
		
		// Rest of the items are disabled for non-editor views
		return NO;
	}
	
	
	// Validate ALL on/of items
	// This is a specific class which matches given methods against a property in this class, ie. toggleSomething -> .something
	for (BeatValidationItem *item in _itemsToValidate) {
		if (menuItem.action == item.selector) {
			bool on = [item validate];
			if (on) [menuItem setState:NSOnState];
			else [menuItem setState:NSOffState];
		}
	}
	
	if (menuItem.action == @selector(toggleTagging:)) {
		if (_mode == TaggingMode) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	
	else if (menuItem.action == @selector(toggleReview:)) {
		if (_mode == ReviewMode) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(reviewSelectedRange:)) {
		if (self.selectedRange.length == 0) return NO;
		else return YES;
	}
	
	else if (menuItem.action == @selector(toggleAutosave:)) {
		if (_autosave) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
		
	}
	else if (menuItem.action == @selector(selectSansSerif:)) {
		bool sansSerif = [BeatUserDefaults.sharedDefaults getBool:BeatSettingUseSansSerif];
		if (sansSerif) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(selectSerif:)) {
		bool sansSerif = [BeatUserDefaults.sharedDefaults getBool:BeatSettingUseSansSerif];
		if (!sansSerif) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
		
	}
	else if (menuItem.action == @selector(toggleDarkMode:)) {
		if ([(BeatAppDelegate *)[NSApp delegate] isDark]) [menuItem setState:NSOnState];
		else [menuItem setState:NSOffState];
		
	}
	else if (menuItem.submenu.itemArray.firstObject.action == @selector(shareFromService:)) {
		[menuItem.submenu removeAllItems];
		NSArray *services = @[];
		
		if (self.fileURL) {
			// This produces an error, but still works. Why?
			services = [NSSharingService sharingServicesForItems:@[self.fileURL]];
			
			for (NSSharingService *service in services) {
				NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:service.title action:@selector(shareFromService:) keyEquivalent:@""];
				item.image = service.image;
				service.subject = [self.fileURL lastPathComponent];
				item.representedObject = service;
				[menuItem.submenu addItem:item];
			}
		}
		if (services.count == 0) {
			NSMenuItem *noThingPleaseSaveItem = [[NSMenuItem alloc] initWithTitle:@"Please save the file to share" action:nil keyEquivalent:@""];
			noThingPleaseSaveItem.enabled = NO;
			[menuItem.submenu addItem:noThingPleaseSaveItem];
		}
		
	}
	else if (menuItem.action == @selector(openPrintPanel:) || menuItem.action == @selector(openPDFPanel:)) {
		// Don't allow printing empty documents
		NSArray* words = [self.text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
		NSString* visibleCharacters = [words componentsJoinedByString:@""];
		if (visibleCharacters.length == 0) return NO;
	}
	
	else if (menuItem.action == @selector(toggleCards:)) {
		menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(showWidgets:)) {
		// Don't show menu item for widget view, if no widgets are visible
		if (self.widgetView.subviews.count > 0) {
			menuItem.hidden = NO;
			return YES;
		} else {
			menuItem.state = NSOffState;
			menuItem.hidden = YES;
			return NO;
		}
	}
	
	// So, I have overriden everything regarding undo (because I couldn't figure it out)
	// That's why we need to handle enabling/disabling undo manually. This sucks.
	else if (menuItem.action == @selector(undoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.undo", nil), [self.undoManager undoActionName]];
		if (!self.undoManager.canUndo) return NO;
	}
	else if (menuItem.action == @selector(redoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.redo", nil), [self.undoManager redoActionName]];
		if (!self.undoManager.canRedo) return NO;
	}
	
	return YES;
}

- (IBAction)shareFromService:(id)sender
{
	[[sender representedObject] performWithItems:@[self.fileURL]];
}

/*
-(NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex {
	return [self.textView menu];
	//return self.textView.contextMenu;
}
*/

#pragma mark - Themes & UI

- (IBAction)toggleDarkMode:(id)sender {
	[(BeatAppDelegate *)NSApp.delegate toggleDarkMode];
	
	[self updateUIColors];
	
	[self.textView toggleDarkPopup:nil];
	_darkPopup = [self isDark];
	
	NSArray* openDocuments = NSDocumentController.sharedDocumentController.documents;
	for (Document* doc in openDocuments) {
		if (doc != self) [doc updateUIColors];
	}
	
	[self.textView refreshLayoutElements];
}

- (void)didChangeAppearance {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self updateUIColors];
		[self.textView refreshLayoutElements];
	});
}
- (bool)isDark {
	return [(BeatAppDelegate *)[NSApp delegate] isDark];
}

- (void)updateUIColors {
	if (_documentWindow.frame.size.height == 0 || _documentWindow.frame.size.width == 0) return;

	if (@available(macOS 10.14, *)) {
		// Force the whole window into dark mode if possible.
		// This redraws everything by default.
		if ([self isDark]) self.documentWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
		else self.documentWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
		self.documentWindow.viewsNeedDisplay = true;
	} else {
		// Else, we need to force everything to redraw, in a very clunky way
		[self.documentWindow setViewsNeedDisplay:true];
		
		[self.documentWindow.contentView setNeedsDisplay:true];
		[self.backgroundView setNeedsDisplay:true];
		[self.textScrollView setNeedsDisplay:true];
		[self.marginView setNeedsDisplay:true];
		
		[self.textScrollView layoutButtons];
		
		[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
		
		[self.textView drawViewBackgroundInRect:self.textView.bounds];
		
		self.textView.needsDisplay = true;
		self.textView.needsLayout = true;
	}
	
	if (_sidebarVisible) {
		self.outlineBackgroundView.needsDisplay = true;
		
		self.sideBarTabs.needsDisplay = true;
		self.sideBarTabs.needsLayout = true;
		self.sideBarTabControl.needsDisplay = true;
		self.sideBarTabControl.needsLayout = true;
		
		[self.outlineView reloadOutline];
	}
	
	// Set global background
	NSColor *bgColor = ([self isDark]) ? self.themeManager.outlineBackground.darkAquaColor : self.themeManager.outlineBackground.aquaColor;
	self.backgroundView.layer.backgroundColor = bgColor.CGColor;
	
	[self.textScrollView layoutButtons];
	[self.documentWindow setViewsNeedDisplay:true];
	[self.textView redrawUI];


	// Update background layers
	[_marginView updateBackground];
}


// Some weirdness because of the Writer legacy. Writer had real themes, and this function loaded the selected theme for every open window. We only have day/night, but the method names remain.
- (void)updateTheme {
	[self setThemeFor:self setTextColor:NO];
}

- (void)setThemeFor:(Document*)doc setTextColor:(bool)setTextColor {
	if (!doc) doc = self;
	
	doc.textView.textColor = self.themeManager.textColor;
	doc.textView.marginColor = self.themeManager.marginColor;
	doc.textScrollView.marginColor = self.themeManager.marginColor;
	
	[doc.textView setSelectedTextAttributes:@{
		NSBackgroundColorAttributeName: self.themeManager.selectionColor,
		NSForegroundColorAttributeName: self.themeManager.backgroundColor
	}];
	
	if (setTextColor) [doc.textView setTextColor:self.themeManager.textColor];
	else {
		[self.textView setNeedsLayout:YES];
		[self.textView setNeedsDisplayInRect:self.textView.frame avoidAdditionalLayout:YES];
	}
	[doc.textView setInsertionPointColor:self.themeManager.caretColor];
		
	[doc updateUIColors];
	
	[doc.documentWindow setViewsNeedDisplay:YES];
	[doc.textView setNeedsDisplay:YES];
}
- (void)loadSelectedTheme:(bool)forAll
{
	NSArray* openDocuments;
	
	if (forAll) openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	else openDocuments = @[self];
	
	for (Document* doc in openDocuments) {
		[self setThemeFor:doc setTextColor:YES];
	}
}

#pragma mark - Typewriter mode

// Typewriter mode
- (IBAction)toggleTypewriterMode:(id)sender {
	self.typewriterMode = !self.typewriterMode;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
	
	[self updateLayout];
}

#pragma mark - Hiding markup

- (IBAction)toggleHideFountainMarkup:(id)sender {
	self.hideFountainMarkup = !self.hideFountainMarkup;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
	
	[self.textView toggleHideFountainMarkup];
	//[self resetSceneNumberLabels];
	self.textView.needsDisplay = true;
	self.textView.needsLayout = true;
	
	[self updateLayout];
}

#pragma mark - Return to editor from any subview

- (void)returnToEditor {
	[self showTab:_editorTab];
	[self updateLayout];
	[self ensureCaret];
}

#pragma mark - Preview

- (void)createPreviewAt:(NSInteger)location {
	[self.previewController createPreviewWithChangeAt:location sync:false];
}

- (void)resetPreview {
	[self.previewController resetPreview];
}

- (void)invalidatePreview {
	[self.previewController resetPreview];
	return;
}

- (void)invalidatePreviewAt:(NSInteger)index {
	[self.previewController invalidatePreviewAt:index];
}

- (IBAction)preview:(id)sender
{
	if (self.currentTab != _nativePreviewTab) {
		[self.previewController renderOnScreen];
		[self showTab:_nativePreviewTab];
	} else {
		[self returnToEditor];
	}
	return;
}
- (BOOL)previewVisible {
	return (self.currentTab == _nativePreviewTab);
}

- (void)cancelOperation:(id) sender
{
	// ESCAPE KEY pressed
	if (self.currentTab == _previewTab) [self preview:nil];
	else if (self.currentTab == _nativePreviewTab) [self preview:nil];
	else if (self.currentTab == _cardsTab) [self toggleCards:nil];
	else {
		for (NSString* pluginName in _runningPlugins.allKeys) {
			BeatPlugin* plugin = _runningPlugins[pluginName];
			[plugin escapePressed];
		}
	}
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

- (CGFloat)sidebarWidth {
	return self.splitHandle.bottomOrLeftView.frame.size.width;
}

- (IBAction)toggleSidebarView:(id)sender
{
	self.sidebarVisible = !self.sidebarVisible;
	
	// Save sidebar state to settings
	[self.documentSettings setBool:DocSettingSidebarVisible as:self.sidebarVisible];
	
	if (_sidebarVisible) {
		[_outlineButton setState:NSOnState];
		
		// Show outline
		[self.outlineView reloadOutline];
		
		self.outlineView.enclosingScrollView.hasVerticalScroller = YES;
		
		if (![self isFullscreen] && !self.documentWindow.isZoomed) {
			CGFloat sidebarWidth = self.outlineView.enclosingScrollView.frame.size.width;
			CGFloat newWidth = _documentWindow.frame.size.width + sidebarWidth;
			CGFloat newX = _documentWindow.frame.origin.x - sidebarWidth / 2;
			CGFloat screenWidth = [NSScreen mainScreen].frame.size.width;
			
			// Ensure the main document won't go out of screen bounds when opening the sidebar
			if (newWidth > screenWidth) {
				newWidth = screenWidth;
				newX = screenWidth / 2 - newWidth / 2;
			}
			
			if (newX + newWidth > screenWidth) {
				newX = newX - (newX + newWidth - screenWidth);
			}
			
			if (newX < 0) newX = 0;
			
			NSRect newFrame = NSMakeRect(newX,
										 _documentWindow.frame.origin.y,
										 newWidth,
										 _documentWindow.frame.size.height);
			[_documentWindow setFrame:newFrame display:YES];
		}
		
		// Show sidebar
		[_splitHandle restoreBottomOrLeftView];
	} else {
		[_outlineButton setState:NSOffState];
		
		// Hide outline
		self.outlineView.enclosingScrollView.hasVerticalScroller = NO;
		
		if (![self isFullscreen] && !self.documentWindow.isZoomed) {
			CGFloat sidebarWidth = self.outlineView.enclosingScrollView.frame.size.width;
			CGFloat newX = _documentWindow.frame.origin.x + sidebarWidth / 2;
			NSRect newFrame = NSMakeRect(newX,
										 _documentWindow.frame.origin.y,
										 _documentWindow.frame.size.width - sidebarWidth,
										 _documentWindow.frame.size.height);
			
			[_documentWindow setFrame:newFrame display:YES];
		}
		
		[_splitHandle collapseBottomOrLeftView];
	}
	
	// Fix layout
	[_documentWindow layoutIfNeeded];
	
	[self updateLayout];
}

- (IBAction)showOutline:(id)sender {
	if (!_sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:_tabOutline];
}
- (IBAction)showNotepad:(id)sender {
	if (!_sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:_tabNotepad];
}
- (IBAction)showCharactersAndDialogue:(id)sender {
	if (!_sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:_tabDialogue];
}
- (IBAction)showReviews:(id)sender {
	if (!_sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:_tabReviews];
}
- (IBAction)showWidgets:(id)sender {
	if (!_sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:_tabWidgets];
}


#pragma mark - Outline View

- (NSArray<OutlineScene*>*)outline
{
	if (self.parser.outline == nil) return @[];
	else return self.parser.outline.copy;
}

- (NSArray*)getOutlineItems
{
	return self.outline;
}

- (NSMutableArray*)filteredOutline
{
	return self.outlineView.filteredOutline;
}

-(IBAction)addSection:(id)sender {
	if (self.outlineView.clickedRow > -1) {
		id selectedScene = nil;
		selectedScene = [self.outlineView itemAtRow:self.outlineView.clickedRow];
		
		if (selectedScene != nil && [selectedScene isKindOfClass:[OutlineScene class]]) {
			OutlineScene *scene = selectedScene;
			
			NSInteger pos = scene.position + scene.length;
			NSString *newSection = @"\n# Section \n\n";
			[self addString:newSection atIndex:pos];
		}
		
		_timeline.clickedItem = nil;
	}
}

- (void)reloadOutline
{
	[self.outlineView reloadOutline];
}

/*
 
 you say: it's gonna happen soon
 well, when exactly do you mean????
 see, I've already waited too long
 and most of my life is gone
 
 */

#pragma mark - Outline/timeline context menu, including setting colors

/*
 
 Color context menu
 
 Note: Some weird stuff can linger around here and there from the old JavaScript-based timeline.
 The context menu checks in a clunky way if the selected item is coming from Outline view or the Timeline before making the changes.
 
 You are still young
 and free
 (in a way, anyway)
 don't let it
 waste away.
 
 */

// Note from 2022: Why is this here and not in the associated class?

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
	
	for (NSString *color in self.colors) {
		if ([_colorPicker.color isEqualTo:[BeatColors color:color]]) pickedColor = color;
	}
	
	if ([_colorPicker.color isEqualTo:NSColor.blackColor]) pickedColor = @"none"; // THE HOUSE IS BLACK.
	
	if (self.currentScene == nil) return;
	
	if (pickedColor != nil) [self setColor:pickedColor forScene:self.currentScene];
}

- (IBAction)setSceneColorForRange:(id)sender {
	// Called from text view context menu
	BeatColorMenuItem *item = sender;
	NSString *color = item.colorKey;
	
	NSRange range = self.selectedRange;
	NSArray *scenes = [_parser scenesInRange:range];
		
	for (OutlineScene* scene in scenes) {
		[self setColor:color forScene:scene];
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
			[self setColor:colorName forScene:scene];
			if (_timeline.clickedItem != nil) [_timeline reload];
			if (self.timelineBar.visible) [self reloadTouchTimeline];
		}
		
		_timeline.clickedItem = nil;
	}
}

- (void)setColor:(NSString *)color forLine:(Line *)line {
	if (line == nil) return;
	
	// First replace the existing color range (if it exists)
	if (line.colorRange.length > 0) {
		NSRange localRange = line.colorRange;
		NSRange globalRange = [self globalRangeFromLocalRange:&localRange inLineAtPosition:line.position];
		[self removeRange:globalRange];
	}
	
	// Do nothing else if color is set to none
	if ([color.lowercaseString isEqualToString:@"none"]) return;
	
	// Create color string and add a space at the end of heading if needed
	NSString *colorStr = [NSString stringWithFormat:@"[[color %@]]", color.lowercaseString];
	if ([line.string characterAtIndex:line.string.length - 1] != ' ') {
		colorStr = [NSString stringWithFormat:@" %@", colorStr];
	}
	
	[self addString:colorStr atIndex:NSMaxRange(line.textRange)];
}

- (void)setColor:(NSString *)color forScene:(OutlineScene *) scene {
	if (scene == nil) return;
	[self setColor:color forLine:scene.line];
}

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene {
	NSMutableArray *storylines = scene.storylines.copy;
	
	// Do nothing if the storyline is already there
	if ([storylines containsObject:storyline]) return;
	
	if (storylines.count > 0) {
		// If the scene already has any storylines, we'll have to add the beat somewhere.
		// Check if scene heading has note ranges, and if not, add it. Otherwise stack into that range.
		if (!scene.line.beatRanges.count) {
			// No beat note in heading yet
			NSString *beatStr = [Storybeat stringWithStorylineNames:@[storyline]];
			beatStr = [@" " stringByAppendingString:beatStr];
			[self addString:beatStr atIndex:NSMaxRange(scene.line.textRange)];
		} else {
			NSMutableArray <Storybeat*>*beats = scene.line.beats.mutableCopy;
			NSRange replaceRange = beats.firstObject.rangeInLine;
			
			// This is fake storybeat object to handle the string creation correctly.
			[beats addObject:[Storybeat line:scene.line scene:scene string:storyline range:replaceRange]];
			NSString *beatStr = [Storybeat stringWithBeats:beats];
			
			[self replaceRange:[self globalRangeFromLocalRange:&replaceRange inLineAtPosition:scene.line.position] withString:beatStr];
		}
		
	} else {
		// There are no storylines yet. Create a beat note and add it at the end of scene heading.
		NSString *beatStr = [Storybeat stringWithStorylineNames:@[storyline]];
		beatStr = [@" " stringByAppendingString:beatStr];
		[self addString:beatStr atIndex:NSMaxRange(scene.line.textRange)];
	}
}
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene {
	// This is unnecessarily complicated.
	
	NSMutableArray *storylines = scene.storylines.copy;
	
	if (storylines.count > 0) {
		if ([storylines containsObject:storyline]) 		// Is the storyline really there?
		{
			if (storylines.count - 1 <= 0) {
				// No storylines left. Clear ALL storyline notes.
				for (Line *line in [self.parser linesForScene:scene]) {
					[self removeTextOnLine:line inLocalIndexSet:line.beatRanges];
				}
			}
			else {
				// Find the specified beat note
				Line *lineWithBeat;
				for (Line *line in [self.parser linesForScene:scene]) {
					if ([line hasBeatForStoryline:storyline]) {
						lineWithBeat = line;
						break;
					}
				}
				if (!lineWithBeat) return;
				
				NSMutableArray *beats = lineWithBeat.beats.mutableCopy;
				Storybeat *beatToRemove = [lineWithBeat storyBeatWithStoryline:storyline];
				[beats removeObject:beatToRemove];
				
				// Multiple beats can be tucked into a single note. Store the other beats.
				NSMutableArray *stackedBeats = NSMutableArray.new;
				for (Storybeat *beat in beats) {
					if (NSEqualRanges(beat.rangeInLine, beatToRemove.rangeInLine)) [stackedBeats addObject:beat];
				}
				
				// If any beats were left, recreate the beat note with the leftovers.
				// Otherwise, just remove it.
				NSString *beatStr = @"";
				if (stackedBeats.count) beatStr = [Storybeat stringWithBeats:stackedBeats];
				
				NSRange removalRange = beatToRemove.rangeInLine;
				[self replaceRange:[self globalRangeFromLocalRange:&removalRange inLineAtPosition:lineWithBeat.position] withString:beatStr];
			}
		}
	}
}

/*
 
 I'm very good with plants
 while my friends are away
 they let me keep the soil moist.
 
 */

#pragma mark - Colors

- (NSDictionary *) colors {
	return @{
		@"red" : [self colorWithRed:239 green:0 blue:73],
		@"blue" : [self colorWithRed:0 green:129 blue:239],
		@"green": [self colorWithRed:0 green:223 blue:121],
		@"pink": [self colorWithRed:250 green:111 blue:193],
		@"magenta": [self colorWithRed:236 green:0 blue:140],
		@"gray": NSColor.grayColor,
		@"grey": NSColor.grayColor, // for the illiterate
		@"purple": [self colorWithRed:181 green:32 blue:218],
		@"prince": [self colorWithRed:181 green:32 blue:218], // for the purple one
		@"yellow": [self colorWithRed:251 green:193 blue:35],
		@"cyan": [self colorWithRed:7 green:189 blue:235],
		@"teal": [self colorWithRed:12 green:224 blue:227], // gotta have teal & orange
		@"orange": [self colorWithRed:255 green:161 blue:13],
		@"brown": [self colorWithRed:169 green:106 blue:7],
		@"darkGray": [self colorWithRed:170 green:170 blue:170],
		@"veryDarkGray": [self colorWithRed:100 green:100 blue:100]
	};
}
- (NSColor *) colorWithRed: (CGFloat) red green:(CGFloat)green blue:(CGFloat)blue {
	return [NSColor colorWithDeviceRed:(red / 255) green:(green / 255) blue:(blue / 255) alpha:1.0f];
}

#pragma mark - Editor Delegate methods

- (NSMutableArray<Line*>*)lines {
	return self.parser.lines;
}

- (NSArray *)scenes {
	return [self getOutlineItems];
}

- (NSArray*)linesForScene:(OutlineScene*)scene {
	return [self.parser linesForScene:scene];
}

- (Line*)lineAt:(NSInteger)index {
	return [self.parser lineAtPosition:index];
}

- (LineType)lineTypeAt:(NSInteger)index {
	return [self.parser lineTypeAt:index];
}

#pragma mark - Card view

- (IBAction)toggleCards: (id)sender {
	if (self.currentTab != _cardsTab) {
		_cardsVisible = YES;
		
		[self.cardView refreshCards];
		[self showTab:_cardsTab];
	} else {
		_cardsVisible = NO;
		
		// Reload outline + timeline (in case there were any changes in outline while in card view)
		[self refreshAllOutlineViews];
		[self returnToEditor];
	}
}

#pragma mark - Refresh any outline views

- (void)refreshAllOutlineViews {
	if (_sidebarVisible) [self.outlineView reloadOutline];
	if (_timeline.visible) [self.timeline reload];
	if (self.timelineBar.visible) [self reloadTouchTimeline];
	if (_cardsVisible) [self.cardView refreshCards];
}


#pragma mark - JavaScript message listeners

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *) message{
	if ([message.name isEqualToString:@"selectSceneFromScript"]) {
		NSInteger sceneIndex = [message.body integerValue];
		
		[self preview:nil];
		if (sceneIndex < self.getOutlineItems.count) {
			OutlineScene *scene = [self.getOutlineItems objectAtIndex:sceneIndex];
			if (scene) [self scrollToScene:scene];
		}
	}
	
	if ([message.name isEqualToString:@"jumpToScene"]) {
		OutlineScene *scene = [self.getOutlineItems objectAtIndex:[message.body intValue]];
		[self scrollToScene:scene];
		return;
	}
	
	if ([message.name isEqualToString:@"cardClick"]) {
		[self toggleCards:nil];
		OutlineScene *scene = [[self getOutlineItems] objectAtIndex:[message.body intValue]];
		[self scrollToScene:scene];
		
		return;
	}
}


#pragma mark - Scene numbering

- (void)setPrintSceneNumbers:(bool)value {
	_printSceneNumbers = value;
	[BeatUserDefaults.sharedDefaults saveBool:value forKey:@"printSceneNumbers"];
}
- (IBAction)togglePrintSceneNumbers:(id)sender
{
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	for (Document* doc in openDocuments) {
		doc.printSceneNumbers = !doc.printSceneNumbers;
	}
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
}

- (IBAction)showSceneNumberStart:(id)sender {
	// Load previous setting
	
	if ([_documentSettings getInt:DocSettingSceneNumberStart] > 0) {
		[_sceneNumberStartInput setIntegerValue:[_documentSettings getInt:DocSettingSceneNumberStart]];
	}
	[_documentWindow beginSheet:_sceneNumberingPanel completionHandler:nil];
}

- (IBAction)closeSceneNumberStart:(id)sender {
	[_documentWindow endSheet:_sceneNumberingPanel];
}

- (IBAction)applySceneNumberStart:(id)sender {
	if (_sceneNumberStartInput.integerValue > 1) {
		[_documentSettings setInt:DocSettingSceneNumberStart as:_sceneNumberStartInput.integerValue];
	} else {
		[_documentSettings remove:DocSettingSceneNumberStart];
	}
	
	// Rebuild outline everywhere
	[self.parser createOutline];
	[self.outlineView reloadOutline];
	[self.timeline reload];
	
	self.textView.needsDisplay = true;
	[self.textView refreshLayoutElements];
	[self updateChangeCount:NSChangeDone];
	
	[_documentWindow endSheet:_sceneNumberingPanel];
}

- (NSInteger)sceneNumberingStartsFrom {
	return [self.documentSettings getInt:DocSettingSceneNumberStart];
}

- (IBAction)toggleSceneLabels: (id) sender {
	self.showSceneNumberLabels = !self.showSceneNumberLabels;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
	
	//if (self.showSceneNumberLabels) [self ensureLayout];
	//else [self.textView deleteSceneNumberLabels];
	[self ensureLayout];
	
	// Update the print preview accordingly
	[self.previewController resetPreview];
	
	[self updateQuickSettings];
}

- (void)refreshTextViewLayoutElements {
	[_textView refreshLayoutElements];
}

- (void)refreshTextViewLayoutElementsFrom:(NSInteger)location {
	[_textView refreshLayoutElementsFrom:location];
}


#pragma mark - Markers

- (NSArray*)markers {
	// This could be inquired from the text view, too.
	// Also, rename the method, because this doesn't return actually markers, but marker+scene positions and colors
	NSMutableArray * markers = NSMutableArray.new;
	
	for (Line* line in self.parser.lines) { @autoreleasepool {
		if (line.marker.length == 0 && line.color.length == 0) continue;
		
		NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:line.textRange actualCharacterRange:nil];
		CGFloat yPosition = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer].origin.y;
		CGFloat relativeY = yPosition / [self.textView.layoutManager usedRectForTextContainer:_textView.textContainer].size.height;
		
		if (line.isOutlineElement) [markers addObject:@{ @"color": line.color, @"y": @(relativeY), @"scene": @(true) }];
		else [markers addObject:@{ @"color": line.marker, @"y": @(relativeY) }];
	} }
	
	return markers;
}

#pragma mark - Timeline + chronometry

- (IBAction)toggleTimeline:(id)sender
{
	NSPoint scrollPosition = self.textScrollView.contentView.documentVisibleRect.origin;
	
	if (!_timeline.visible) {
		
		[_timeline show];
		[self ensureLayout];
		[_timelineButton setState:NSOnState];
		
		// ???
		// For some reason the NSTextView scrolls into some weird position when the view
		// height is changed. Restoring scroll position does NOT fix this.
		//[self.textScrollView.contentView scrollToPoint:scrollPosition];
		
	} else {
		[_timeline hide];
		scrollPosition.y = scrollPosition.y * self.magnification;
		[self.textScrollView.contentView scrollToPoint:scrollPosition];
		[_timelineButton setState:NSOffState];
	}
}

- (void)setupTouchTimeline {
	self.touchbarTimeline.delegate = self;
	self.touchbarTimelineButton.delegate = self;
}

/*
 
 nyt tulevaisuus
 on musta aukko
 nyt tulevaisuus
 on musta aukko
 
 */


#pragma mark - Timeline Delegation

- (bool)timelineVisible { return self.timeline.visible; }

- (void)reloadTouchTimeline {
	[_touchbarTimeline setData:[self getOutlineItems].mutableCopy];
}
- (void)didSelectTouchTimelineItem:(NSInteger)index {
	OutlineScene *scene = [[self getOutlineItems] objectAtIndex:index];
	[self scrollToScene:scene];
}
- (void) touchPopoverDidShow {
	[self reloadTouchTimeline];
}
- (void) touchPopoverDidHide {
}
- (void)didSelectTimelineItem:(NSInteger)index {
	OutlineScene *scene = [[self getOutlineItems] objectAtIndex:index];
	[self scrollToScene:scene];
}

- (nonnull NSArray *)getOutline {
	return [self getOutlineItems];
}


#pragma mark - Analysis

// This is a horrible mess, but whatever

- (IBAction)showAnalysis:(id)sender {
	_analysisWindow = [[BeatStatisticsPanel alloc] initWithParser:self.parser delegate:self];
	[_documentWindow beginSheet:_analysisWindow.window completionHandler:^(NSModalResponse returnCode) {
		self.analysisWindow = nil;
	}];
}

- (NSDictionary<NSString*, NSString*>*)characterGenders {
	NSDictionary * genders = [self.documentSettings get:DocSettingCharacterGenders];
	if (genders != nil) return genders;
	return @{};
}
-(void)setCharacterGenders:(NSDictionary<NSString *,NSString *> *)characterGenders {
	[self.documentSettings set:DocSettingCharacterGenders as:characterGenders];
}

- (void)setupAnalysis {
}

/*
 
 5am
 out again
 triangle walks
 
 */


#pragma mark - Pagination

/*
 
 Pagination was a dream of mine which I managed to make happen.
 Live pagination should still be optimized so that we only paginate
 from a given index.
 
 What matters most is how well you walk through the fire.
 
 */

- (BeatPaginationManager*)pagination {
	return self.previewController.pagination;
}
- (BeatPaginationManager*)paginator {
	return self.previewController.pagination;
}

- (IBAction)togglePageNumbers:(id)sender {
	self.showPageNumbers = !self.showPageNumbers;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
	
	if (self.showPageNumbers) [self paginateAt:(NSRange){ 0,0 } sync:YES];
	else {
		self.textView.pageBreaks = nil;
		[self.textView deletePageNumbers];
	}
	
	[self updateQuickSettings];
}

- (void)paginate {
	[self paginateAt:(NSRange){0,0} sync:NO];
}

static NSArray<Line*>* cachedTitlePage;
- (void)paginateAt:(NSRange)range sync:(bool)sync {
	[self.previewController createPreviewWithChangeAt:range.location sync:sync];
	return;
}

/// Pagination finished — called when preview controller has finished creating pagination
-(void)paginationFinished:(BeatPagination *)operation indices:(NSIndexSet *)indices {
	__block NSIndexSet* changedIndices = indices.copy;
	
	// We might be in a background thread, so make sure to dispach this call to main thread
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		// Update pagination in text view
		if (self.showPageNumbers) {
			[self.textView updatePagination:operation.pages];
		}
		
		// Tell plugins the preview has been finished
		for (NSString *name in self.runningPlugins.allKeys) {
			BeatPlugin *plugin = self.runningPlugins[name];
			[plugin previewDidFinish:operation indices:changedIndices];
		}
	});
}

- (void)setPrintInfo:(NSPrintInfo *)printInfo {
	[super setPrintInfo:printInfo];
		
	[self updateLayout];
}
- (IBAction)selectPaperSize:(id)sender {
	//NSPopUpButton *button = (NSPopUpButton*)sender;
	NSMenuItem *item;
	if ([sender isKindOfClass:NSPopUpButton.class]) item = [(NSPopUpButton*)sender selectedItem];
	else item = (NSMenuItem*)sender;
	
	BeatPaperSize size;
	if ([item.title isEqualToString:@"A4"]) size = BeatA4;
	else size = BeatUSLetter;
	
	self.pageSize = size;
}

- (BeatPaperSize)pageSize {
	if ([self.documentSettings has:DocSettingPageSize]) {
		return [self.documentSettings getInt:DocSettingPageSize];
	} else {
		return [BeatUserDefaults.sharedDefaults getInteger:@"defaultPageSize"];
	}
}

- (void)setPageSize:(BeatPaperSize)pageSize {
	[self.documentSettings setInt:DocSettingPageSize as:pageSize];
	[self updateLayout];
	[self paginate];
	[self.previewController resetPreview];
}

- (NSInteger)numberOfPages {
	return self.previewController.pagination.numberOfPages;
}

- (NSInteger)getPageNumberAt:(NSInteger)location {
	return [self.previewController.pagination pageNumberAt:location];
}


/*
 
 mä haluun sut edelleen
 haluun sun kanssa perheen
 haluun nähdä miten lapset kasvaa
 haluun kukkii ja rakkautta
 
 haluun kasvaa sun mukana
 haluun rypistyy ja harmaantua
 haluun uupuu ja kaljuuntua
 ja pysyy sun rinnalla
 
 mut et voi lyödä mua enää
 et saa lyödä mua enää
 et uhata polttaa mun kotia
 et enää nimitellä ja haukkua
 
 koska haluun sut edelleen
 haluun sun kanssa perheen
 haluun herätä sun läheltä
 sanoo etten mee pois ikinä
 
 keitän sulle aamuisin kahvia
 hoidan aina meidän lapsia
 pidän huolta niistä kasveista
 kun sä oot taas matkoilla
 
 sanon joka päivä et oot ihana
 teen sulle upeita ruokia
 mut et saa heittää niitä lattioille
 etkä kuumaa kahvii mun kasvoille...
 
 et saa lyödä mua enää
 et saa lyödä mua enää
 et tuhota mun kotia
 ei enää huutoo ja uhkailua
 
 mut mä haluun sut koska
 tiedän mitä oot sisältä
 haluut vaan kontrollii, haluut varmuutta
 ja lupaan auttaa sua aina ja ihan kaikessa
 
 mut ei väkivaltaa enää
 ei väkivaltaa enää
 ehkä seuraavan kerran
 et nää mua enää ikinä
 
 ja mä odotan
 odotan
 odotan
 niin kauan kuin haluat
 
 
 */

#pragma mark - Title page editor

/*
 Move most of this to the title page editor class.
 Should be easy using BeatEditorDelegate.
 */

- (IBAction)editTitlePage:(id)sender {
	_titlePageEditor = [[BeatTitlePageEditor alloc] initWithDelegate:self];
	
	[_documentWindow beginSheet:_titlePageEditor.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSModalResponseOK) {
			// User pressed cancel, dealloc the sheet
			self.titlePageEditor = nil;
			return;
		}
		
		NSString *titlePage = self.titlePageEditor.result;
		
		// Find the range
		if (self.text.length < 6) {
			// If there is not much text in the script, just add the title page in the beginning of the document, followed by newlines
			[self addString:[NSString stringWithFormat:@"%@\n\n", titlePage] atIndex:0];
		} else if (![[self.text substringWithRange:NSMakeRange(0, 6)] isEqualToString:@"Title:"]) {
			// There is no title page present here either. We're just careful not to cause errors with ranges
			[self addString:[NSString stringWithFormat:@"%@\n\n", titlePage] atIndex:0];
		} else {
			// There IS a title page, so we need to find out its range to replace it.
			NSInteger titlePageEnd = -1;
			for (Line* line in self.parser.lines) {
				if (line.type == empty) {
					titlePageEnd = line.position;
					break;
				}
			}
			if (titlePageEnd < 0) titlePageEnd = self.text.length;
			
			NSRange titlePageRange = NSMakeRange(0, titlePageEnd);
			NSString *oldTitlePage = [self.text substringWithRange:titlePageRange];
			
			[self replaceString:oldTitlePage withString:titlePage atIndex:0];
		}
		
		// Dealloc
		self.titlePageEditor = nil;
	}];
}


#pragma mark - Timer

- (IBAction)showTimer:(id)sender {
	_beatTimer.delegate = self;
	[_beatTimer showTimer];
}


#pragma mark - touchbar buttons

- (IBAction)nextScene:(id)sender {
	Line* line = [self.parser nextOutlineItemOfType:heading from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}
- (IBAction)previousScene:(id)sender {
	Line* line = [self.parser previousOutlineItemOfType:heading from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)nextSection:(id)sender {
	Line* line = [self.parser nextOutlineItemOfType:section from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)previousSection:(id)sender {
	Line* line = [self.parser previousOutlineItemOfType:section from:self.selectedRange.location];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)nextSectionOfSameDepth:(id)sender {
	Line* line = self.currentLine;
	if (line.type != section) {
		line = [self.parser previousOutlineItemOfType:section from:line.position];
	}
	
	line = [self.parser nextOutlineItemOfType:section from:line.position depth:line.sectionDepth];
	if (line != nil) [self scrollToLine:line];
}

- (IBAction)previousSectionOfSameDepth:(id)sender {
	Line* line = self.currentLine;
	if (line.type != section) {
		line = [self.parser previousOutlineItemOfType:section from:line.position];
	}
	
	Line * sectionLine = [self.parser previousOutlineItemOfType:section from:self.selectedRange.location depth:line.sectionDepth];
	if (sectionLine != nil) [self scrollToLine:sectionLine];
	else if (line != nil) [self scrollToLine:line];
}


#pragma mark - Autosave

/*
 
 Beat has *three* kinds of autosave: autosave vault, saving in place and automatic macOS autosave.
  
 */

+ (BOOL)autosavesInPlace {
	return NO;
}

+ (BOOL)autosavesDrafts {
	return YES;
}

+ (BOOL)preservesVersions {
	return NO;
}

- (IBAction)toggleAutosave:(id)sender {
	self.autosave = !self.autosave;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
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

- (NSURL*)backupPath {
	return [BeatAppDelegate appDataPath:@"Backup"];
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
	// Delete old drafts when saving under a new name
	NSString *previousName = self.fileNameString;
	
	[super saveDocumentAs:sender];
	
	NSURL *url = [BeatAppDelegate appDataPath:@"Autosave"];
	url = [url URLByAppendingPathComponent:previousName];
	url = [url URLByAppendingPathExtension:@"fountain"];
	
	NSFileManager *fileManager = NSFileManager.defaultManager;
	
	if ([fileManager fileExistsAtPath:url.path]) {
		[fileManager removeItemAtURL:url error:nil];
	}
}

-(void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
	[super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}


#pragma mark - split view listener

- (void)splitViewDidResize {
	[self.documentSettings setInt:DocSettingSidebarWidth as:(NSInteger)self.splitHandle.bottomOrLeftView.frame.size.width];
	[self updateLayout];
}
- (void)leftViewDidShow {
	self.sidebarVisible = YES;
	[_outlineButton setState:NSOnState];
	[self.outlineView reloadOutline];
}
- (void)leftViewDidHide {
	// unused for now
}


#pragma mark - Color Customization

- (IBAction)customizeColors:(id)sender {
	ThemeEditor* editor = ThemeEditor.sharedEditor;
	[editor showWindow:editor.window];
}

#pragma mark - Review Mode

- (IBAction)toggleReview:(id)sender {
	if (_mode == ReviewMode) self.mode = EditMode;
	else self.mode = ReviewMode;
	[self updateQuickSettings];
}

-(void)toggleMode:(BeatEditorMode)mode {
	if (_mode != mode) _mode = EditMode;
	else _mode = mode;
	[self updateEditorMode];
}
-(void)setMode:(BeatEditorMode)mode {
	_mode = mode;
	[self updateEditorMode];
}

- (IBAction)reviewSelectedRange:(id)sender {
	if (self.selectedRange.length == 0) return;
	[_review showReviewItemWithRange:self.selectedRange forEditing:YES];
}

#pragma mark - Tagging Mode

// NOTE: Move all of this into BeatTagging class

- (IBAction)toggleTagging:(id)sender {
	if (_mode == TaggingMode) _mode = EditMode;
	else _mode = TaggingMode;
	
	[self updateEditorMode];
}

#pragma mark - Locking The Document

-(IBAction)lockContent:(id)sender {
	[self toggleLock];
}

- (void)toggleLock {
	bool locked = [self.documentSettings getBool:@"Locked"];
	
	if (locked) [self unlock];
	else {
		[self updateChangeCount:NSChangeDone];
		[self lock];
	}
}
- (bool)screenplayLocked {
	if ([self.documentSettings getBool:@"Locked"]) return YES;
	else return NO;
}
- (void)lock {
	self.textView.editable = NO;
	[self.documentSettings setBool:@"Locked" as:YES];
	
	[self.lockButton show];
}
- (void)unlock {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"unlock_document.title", nil);
	alert.informativeText = NSLocalizedString(@"unlock_document.confirm", nil);
	
	[alert addButtonWithTitle:NSLocalizedString(@"general.yes", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"general.no", nil)];
	
	NSModalResponse response = [alert runModal];
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		self.textView.editable = YES;
		[self.documentSettings setBool:@"Locked" as:NO];
		[self updateChangeCount:NSChangeDone];
		
		[self.lockButton hide];
	}
}
- (void)showLockStatus {
	[self.lockButton displayLabel];
}

-(bool)contentLocked {
	return [self.documentSettings getBool:@"Locked"];
}


#pragma mark - Plugin support

/*
 
 Some explanation:
 
 Plugins are run inside document scope, unless they are standalone tools.
 If the plugins are "resident" (can be left running in the background),
 they are registered and deregistered when launching and shutting down.
 
 Some changes made to the document are sent to all of the running plugins,
 if they have any change listeners.
 
 This should be separated to its own class, something like PluginAgent or something.
 
 */

- (void)setupPlugins {
	self.pluginManager = BeatPluginManager.sharedManager;
}
- (IBAction)runPlugin:(id)sender {
	// Get plugin filename from menu item
	BeatPluginMenuItem *menuItem = (BeatPluginMenuItem*)sender;
	NSString *pluginName = menuItem.pluginName;
	
	[self runPluginWithName:pluginName];
}
- (void)runPluginWithName:(NSString*)pluginName {
	os_log(OS_LOG_DEFAULT, "# Run plugin: %@", pluginName);
	
	// See if the plugin is running and disable it if needed
	if (self.runningPlugins[pluginName]) {
		[(BeatPlugin*)self.runningPlugins[pluginName] forceEnd];
		[self.runningPlugins removeObjectForKey:pluginName];
		return;
	}

	// Run a new plugin
	BeatPlugin *pluginParser = [[BeatPlugin alloc] init];
	pluginParser.delegate = self;
	
	BeatPluginData *pluginData = [self.pluginManager pluginWithName:pluginName];
	[pluginParser loadPlugin:pluginData];
		
	// Null the local variable just in case.
	// If the plugin wants to stay in memory, it should call registerPlugin:
	pluginParser = nil;
}

- (BeatPlugin*)loadPluginWithName:(NSString*)pluginName script:(NSString*)script {
	if (self.runningPlugins[pluginName] != nil) return self.runningPlugins[pluginName];
	
	BeatPlugin* pluginParser = BeatPlugin.new;
	pluginParser.delegate = self;
	
	BeatPluginData* pluginData = BeatPluginData.new;
	pluginData.name = pluginName;
	pluginData.script = script;
	[pluginParser loadPlugin:pluginData];
	
	return pluginParser;
}

- (void)call:(NSString*)script context:(NSString*)pluginName {
	BeatPlugin* plugin = [self pluginContextWithName:pluginName];
	[plugin call:script];
}

- (BeatPlugin*)pluginContextWithName:(NSString*)pluginName {
	return self.runningPlugins[pluginName];
}

- (void)runGenericPlugin:(NSString*)script {
	
}

- (void)registerPlugin:(id)plugin {
	BeatPlugin *parser = (BeatPlugin*)plugin;
	if (!self.runningPlugins) self.runningPlugins = NSMutableDictionary.new;
	
	self.runningPlugins[parser.pluginName] = parser;
}
- (void)deregisterPlugin:(id)plugin {
	BeatPlugin *parser = (BeatPlugin*)plugin;
	[self.runningPlugins removeObjectForKey:parser.pluginName];
	parser = nil;
}

- (void)updatePlugins:(NSRange)range {
	// Run resident plugins
	if (!self.runningPlugins || _documentIsLoading) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin update:range];
	}
}

- (void)updatePluginsWithSelection:(NSRange)range {
	// Run resident plugins which are listening for selection changes
	if (!self.runningPlugins || _documentIsLoading) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin updateSelection:range];
	}
}

- (void)updatePluginsWithSceneIndex:(NSInteger)index {
	// Run resident plugins which are listening for selection changes
	if (!self.runningPlugins || _documentIsLoading) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin updateSceneIndex:index];
	}
}

- (void)updatePluginsWithOutline:(NSArray*)outline changes:(OutlineChanges* _Nullable)changes {
	// Run resident plugins which are listening for selection changes
	if (!self.runningPlugins) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin updateOutline:changes];
	}
}

- (void)notifyPluginsThatWindowBecameMain {
	if (!self.runningPlugins || _documentIsLoading) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin documentDidBecomeMain];
	}
}

- (void)addWidget:(id)widget {
	[self.widgetView addWidget:widget];
	[self showWidgets:nil];
}

// For those who REALLY, REALLY know what the fuck they are doing
- (void)setPropertyValue:(NSString*)key value:(id)value {
	[self setValue:value forKey:key];
}
- (id)getPropertyValue:(NSString*)key {
	return [self valueForKey:key];
}


#pragma mark - Search for scene

- (IBAction)goToScene:(id)sender {
	BeatSceneHeadingSearch *search = [BeatSceneHeadingSearch.alloc init];
	search.delegate = self;
	
	[self.documentWindow beginSheet:search.window completionHandler:^(NSModalResponse returnCode) {
	}];
}


#pragma mark - Scrolling

- (void)scrollToSceneNumber:(NSString*)sceneNumber {
	// Note: scene numbers are STRINGS, because they can be anything (2B, EXTRA, etc.)
	OutlineScene *scene = [self.parser sceneWithNumber:sceneNumber];
	if (scene != nil) [self scrollToScene:scene];
}
- (void)scrollToScene:(OutlineScene*)scene {
	[self selectAndScrollTo:scene.line.textRange];
	[self.documentWindow makeFirstResponder:self.textView];
}
/// Legacy method. Use selectAndScrollToRange
- (void)scrollToRange:(NSRange)range {
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
	OutlineScene *scene = [[self getOutlineItems] objectAtIndex:index];
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
	else {
		_bufferedText = [NSString stringWithString:self.textView.string];
		return YES;
	}
}

@end

/*
 
 some moments are nice, some are
 nicer, some are even worth
 writing
 about
 
 */
