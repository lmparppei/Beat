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
 
 I originally started the project to combat a creative block, while overcoming some difficult PTSD symptoms. Coding helped to escape those feelings. If you are in an abusive relationship, leave RIGHT NOW. You might love that person, but it's not your job to try and help them. I wish I could have gotten this sort of advice back then from a random source code file.
 
 Beat is released under GNU General Public License, so all of this code will remain open forever - even if I'd make a commercial version to finance the development. Beat has since become a real app with a real user base, which I'm thankful for. If you find this code or the app useful, you can always send some currency through PayPal or hide bunch of coins in an old oak tree. Or, even better, donate to a NGO helping less fortunate people. I'm already on the top of Maslow hierarchy.
 
 I am in the process of modularizing the code so that it could be ported more easily to iOS.

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
#import "Document.h"
#import "ScrollView.h"
#import "FDXInterface.h"
#import "BeatPrintView.h"
#import "ColorView.h"
#import "ThemeManager.h"
#import "OutlineScene.h"
#import "DynamicColor.h"
#import "BeatAppDelegate.h"
#import "NSString+CharacterControl.h"
#import "FountainAnalysis.h"
#import "ColorCheckbox.h"
#import "SceneFiltering.h"
#import "FDXImport.h"
#import "BeatPaginator.h"
#import "MasterView.h"
#import "OutlineExtractor.h"
#import "SceneCards.h"
#import "RegExCategories.h"
#import "MarginView.h"
#import "BeatColors.h"
#import "OutlineViewItem.h"
#import "BeatPaperSizing.h"
#import "BeatModalInput.h"
#import "ThemeEditor.h"
#import "BeatTagging.h"
#import "BeatTagItem.h"
#import "BeatTag.h"
#import "TagDefinition.h"
#import "BeatFDXExport.h"
#import "ValidationItem.h"
#import "ITSwitch.h"
#import "BeatTitlePageEditor.h"
#import "BeatLockButton.h"
#import "BeatMeasure.h"
#import "BeatColorMenuItem.h"
#import "BeatPlugin.h"
#import "BeatPluginManager.h"
#import "BeatWidgetView.h"
#import "BeatSegmentedControl.h"
#import "BeatNotepad.h"
#import "BeatUserDefaults.h"
#import "BeatCharacterList.h"
#import "BeatEditorFormatting.h"
#import "BeatEditorFormattingActions.h"
#import "BeatPrintDialog.h"
#import "Beat-Swift.h"
#import "BeatEditorButton.h"
#import "BeatAutocomplete.h"

@interface Document () {
	NSString *bufferedText;
	NSData *dataCache;
	NSMutableArray *autocompleteCharacterNames;
	NSMutableArray *autocompleteSceneHeadings;
}

// Window
@property (weak) NSWindow *documentWindow;
@property (weak) IBOutlet TKSplitHandle *splitHandle;
@property (nonatomic) NSArray *itemsToValidate; // Menu items

// Autosave
@property (nonatomic) bool autosave;
@property (weak) NSTimer *autosaveTimer;
@property (nonatomic) NSString *contentCache;
@property (nonatomic) NSAttributedString *attributedContentCache;
//@property (nonatomic) NSURL *mostRecentlySavedFileURL;

// Plugin support
@property (weak) BeatPluginManager *pluginManager;
@property (weak) IBOutlet BeatWidgetView *widgetView;

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
@property (weak, nonatomic) IBOutlet ScrollView *textScrollView;
@property (weak, nonatomic) IBOutlet MarginView *marginView;
@property (weak, nonatomic) IBOutlet NSClipView *textClipView;
@property (nonatomic) NSLayoutManager *layoutManager;
@property (nonatomic) bool documentIsLoading;
@property (nonatomic) BeatPaginator *paginator;
@property (nonatomic) NSTimer *paginationTimer;
@property (nonatomic) bool autocomplete;
@property (nonatomic) bool moving;
@property (nonatomic) bool showPageNumbers;
@property (nonatomic) bool autoLineBreaks;
@property (nonatomic) bool automaticContd;
@property (nonatomic) bool characterInput;
@property (nonatomic) NSDictionary *postEditAction;
@property (nonatomic) bool typewriterMode;
@property (nonatomic) bool hideFountainMarkup;
@property (nonatomic) NSMutableArray *recentCharacters;
@property (nonatomic) NSRange lastChangedRange;
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
@property (weak) IBOutlet NSScrollView *outlineScrollView;
@property (weak) NSArray *draggedNodes;
@property (weak) OutlineScene *draggedScene; // Drag & drop for outline view
@property (nonatomic) NSMutableArray *outline;
@property (nonatomic, weak) IBOutlet NSSearchField *outlineSearchField;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property (nonatomic) BOOL sidebarVisible;
@property (nonatomic) NSMutableArray *outlineClosedSections;
@property (nonatomic, weak) IBOutlet NSMenu *colorMenu;

@property (nonatomic, weak) IBOutlet BeatCharacterList *characterList;

// Outline view filtering
@property (nonatomic, weak) IBOutlet NSPopUpButton *characterBox;

// Notepad
@property (nonatomic, weak) IBOutlet BeatNotepad *notepad;

// Views
@property (weak) IBOutlet NSTabView *tabView; // Master tab view (holds edit/print/card views)
@property (weak) IBOutlet ColorView *backgroundView; // Master background
@property (weak) IBOutlet ColorView *outlineBackgroundView; // Background for outline
@property (weak) IBOutlet MasterView *masterView; // View which contains every other view

@property (weak) IBOutlet NSTabViewItem *editorTab;
@property (weak) IBOutlet NSTabViewItem *previewTab;
@property (weak) IBOutlet NSTabViewItem *cardsTab;

@property (nonatomic) BeatPrintDialog *printDialog;

// Print preview
@property (weak) IBOutlet WKWebView *printWebView; // Print preview
@property (nonatomic) NSString *htmlString;
@property (nonatomic) bool previewUpdated;
@property (nonatomic) bool previewCanceled;
@property (nonatomic) NSTimer *previewTimer;
@property (nonatomic) BeatPreview *preview;

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
@property (nonatomic) bool showSceneNumberLabels;
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

// Magnification
@property (nonatomic) CGFloat scaleFactor;
@property (nonatomic) CGFloat scale;

// Printing
@property (nonatomic) bool printPreview;
@property (nonatomic, readwrite) NSString *preprocessedText;

// Some settings for edit view behaviour
@property (nonatomic) bool matchParentheses;

// View sizing
@property (nonatomic) NSUInteger documentWidth;
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
@property (nonatomic) bool nightMode; // THE HOUSE IS BLACK.

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

// Debug flags
@property (nonatomic) bool debug;


@end

#define APP_NAME @"Beat"

#define MIN_WINDOW_HEIGHT 400
#define MIN_OUTLINE_WIDTH 270

#define AUTOSAVE_INTERVAL 10.0
#define AUTOSAVE_INPLACE_INTERVAL 60.0

#define SECTION_FONT_SIZE 20.0 // base value for section sizes
#define FONT_SIZE 17.92
#define LINE_HEIGHT 1.1

#define DOCUMENT_WIDTH_MODIFIER 630
#define DOCUMENT_WIDTH_A4 610
#define DOCUMENT_WIDTH_US 630
#define TEXT_INSET_TOP 80

// Magnifying stuff
#define MAGNIFYLEVEL_KEY @"Magnifylevel"
#define DEFAULT_MAGNIFY 0.98
#define MAGNIFY YES

// User preferences key names
#define OFFSET_SCENE_NUMBERS_KEY @"Offset Scene Numbers From First Custom Number"
#define MATCH_PARENTHESES_KEY @"Match Parentheses"
#define SHOW_PAGENUMBERS_KEY @"Show Page Numbers"
#define SHOW_SCENE_LABELS_KEY @"Show Scene Number Labels"
#define FONTSIZE_KEY @"Fontsize"
#define PRINT_SCENE_NUMBERS_KEY @"Print scene numbers"
#define DARKMODE_KEY @"Dark Mode"
#define AUTOMATIC_LINEBREAKS_KEY @"Automatic Line Breaks"
#define TYPERWITER_KEY @"Typewriter Mode"
#define FONT_STYLE_KEY @"Sans Serif"
#define HIDE_FOUNTAIN_MARKUP_KEY @"Hide Fountain Markup"

// DOCUMENT LAYOUT SETTINGS
// The 0.?? values represent percentages of view width
#define INITIAL_WIDTH 900
#define INITIAL_HEIGHT 700

#define DD_CHARACTER_INDENT_P 0.56
#define DD_PARENTHETICAL_INDENT_P 0.50
#define DUAL_DIALOGUE_INDENT_P 0.40
#define DD_RIGHT 650
#define DD_RIGHT_P .95

// Title page element indent
#define TITLE_INDENT .15

#define CHARACTER_INDENT_P 0.34
#define PARENTHETICAL_INDENT_P 0.27
#define DIALOGUE_INDENT_P 0.164
#define DIALOGUE_RIGHT_P 0.735

@implementation Document

#pragma mark - Document Initialization

-(Document*)document {
	// WARNING: This is only for transferring the document from a delegate to another place.
	// Handle with care.
	return self;
}

- (instancetype)init {
    self = [super init];
    return self;
}
- (void)close {
	if (!self.hasUnautosavedChanges) {
		/*
		if (self.sidebarVisible) {
			// Don't save sidebar width
			NSRect frame = self.documentWindow.frame;
			frame.size.width -= self.splitHandle.bottomOrLeftView.frame.size.width;
			[self.documentWindow setFrame:frame display:NO];
		}
		*/
		[self.documentWindow saveFrameUsingName:self.fileNameString];
	}
	
	// Avoid retain cycles with WKWebView
	[self deallocPreview];
	[self.cardView removeHandlers];
	
		
	// Terminate running plugins
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatPlugin* plugin = _runningPlugins[pluginName];
		[plugin end];
		[_runningPlugins removeObjectForKey:pluginName];
	}
	
	// This stuff is here to fix some strange memory issues.
	// it might be unnecessary, but I'm unfamiliar with both ARC & manual memory management
	[self.previewTimer invalidate];
	[self.paginationTimer invalidate];
	self.paginationTimer = nil;
	[self.beatTimer.timer invalidate];
	self.beatTimer = nil;
	
	self.preview = nil;
	
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
	self.parser = nil;
	self.outlineView = nil;
	self.documentWindow = nil;
	self.contentBuffer = nil;
	self.printView = nil;
	self.analysisWindow = nil;
	self.currentScene = nil;
	//self.currentLine = nil;
	self.cardView = nil;
	self.paginator = nil;
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
	}
}

static BeatAppDelegate *appDelegate;

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	[super windowControllerDidLoadNib:aController];
		
	_documentWindow = aController.window;
	_documentWindow.delegate = self;
	
	// Setup formatting
	_formatting = BeatEditorFormatting.new;
	_formatting.delegate = self;
	
	// Hide the welcome screen
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document open" object:nil];
		
	// Initialize document settings if needed
	if (!self.documentSettings) self.documentSettings = BeatDocumentSettings.new;
	
	// Initialize Theme Manager
	// (before formatting the content, because we need the colors for formatting!)
	self.themeManager = [ThemeManager sharedManager];
	[self loadSelectedTheme:false];
	self.nightMode = [self isDark];
	
	// Setup views
	[self setupWindow];
	[self readUserSettings];
	[self setupMenuItems];
	
	// Load font set
	if (self.useSansSerif) [self loadSansSerifFonts];
	else [self loadSerifFonts];
	
	// Setup views
	[self setupTextView];
	[self setupOutlineView];
	[self setupPreview];
	[self setupTouchTimeline];
	[self setupAnalysis];
	[self setupColorPicker];
	[self.cardView setup];
	
	// Setup layout here first, but don't paginate
	[self setupLayoutWithPagination:NO];
		
	// Setup plugin management
	[self setupPlugins];
			
	// Pagination etc.
	self.paginator = [[BeatPaginator alloc] initForLivePagination:self];
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
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
		// Initialize parser
		self.parser = [[ContinuousFountainParser alloc] initWithString:self.contentBuffer delegate:self];
		
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
	});
}

-(void)loadingComplete {
	[_parser.changedIndices removeAllIndexes];
	[self.formatting initialTextBackgroundRender];
		
	[CATransaction begin];
	if (self.progressPanel != nil) [self.documentWindow endSheet:self.progressPanel];
	[CATransaction commit];

	self.progressPanel = nil;
	
	[self updateLayout];
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];

	// Initialize edit tracking
	[self.revisionTracking setupRevisions];
			
	// Load tagging & review systems
	[self.tagging setup];
	[self setupReview];
		
	// Document loading has ended
	self.documentIsLoading = NO;
	
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
	if ([self.documentSettings getBool:DocSettingSidebarVisible]) {
		self.sidebarVisible = YES;
		[_splitHandle restoreBottomOrLeftView];
		NSInteger sidebarWidth = [self.documentSettings getInt:DocSettingSidebarWidth];
		_splitHandle.mainConstraint.constant = sidebarWidth;
		
		[_documentWindow layoutIfNeeded];
		[self updateLayout];
		
	}
	
	// Setup page size
	// (We'll disable undo registration here, so the doc won't appear as edited on open)
	[self.undoManager disableUndoRegistration];
	
	NSPrintInfo *printInfo = NSPrintInfo.sharedPrintInfo;
	self.printInfo = [BeatPaperSizing setSize:self.pageSize printInfo:printInfo];

	// Enable undo registration and clear any changes to the document (if needed)
	[self.undoManager enableUndoRegistration];
	if (saved) [self updateChangeCount:NSChangeCleared];
	
	// Reveal text view
	[self.textView.animator setAlphaValue:1.0];
	
	// Update quick settings 
	[self updateQuickSettings];

	// Hide Fountain markup if needed
	if (self.hideFountainMarkup) [self.textView redrawAllGlyphs];
}

-(void)awakeFromNib {
	// Set up recovery file saving
	[NSDocumentController.sharedDocumentController setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
	
	[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(didChangeAppearance) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}
-(void)setValue:(id)value forUndefinedKey:(NSString *)key {
	NSLog(@"Document: Undefined key (%@) set. This might be intentional.", key);
}
-(id)valueForUndefinedKey:(NSString *)key {
	NSLog(@"Document: Undefined key (%@) requested. This might be intentional.", key);
	return nil;
}

- (void)readUserSettings {
	[BeatUserDefaults.sharedDefaults readUserDefaultsFor:self];
		
	// Do some additional setup if needed
	self.printSceneNumbers = self.showSceneNumberLabels;
	
	return;
}

- (void)applyUserSettings {
	// Apply settings from user preferences panel, some things have to be applied in every document
	
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
		self.previewUpdated = NO;
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
		else [self.textView deleteSceneNumberLabels];
		
		// Update the print preview accordingly
		self.previewUpdated = NO;
	}
	
	[self updateQuickSettings];
}

- (NSUInteger)documentWidth {
	if (self.pageSize == BeatA4) return DOCUMENT_WIDTH_A4 + BeatTextView.linePadding * 2;
	else return DOCUMENT_WIDTH_US + BeatTextView.linePadding * 2;
}

- (void)setupWindow {
	[_tagTextView.enclosingScrollView setHasHorizontalScroller:NO];
	[_tagTextView.enclosingScrollView setHasVerticalScroller:NO];
	
	// Reset zoom
	[self setZoom];

	// Split view
	_splitHandle.bottomOrLeftMinSize = MIN_OUTLINE_WIDTH;
	_splitHandle.delegate = self;
	[_splitHandle collapseBottomOrLeftView];
	
	// Recall window position for saved documents
	if (![self.fileNameString isEqualToString:@"Untitled"]) _documentWindow.frameAutosaveName = self.fileNameString;
	
	CGFloat x = _documentWindow.frame.origin.x;
	CGFloat y = _documentWindow.frame.origin.y;
	CGFloat width = [_documentSettings getFloat:DocSettingWindowWidth];
	CGFloat height = [_documentSettings getFloat:DocSettingWindowHeight];
	
	// Default size for new windows or those going over screen bounds
	if (width < self.documentWidth || x > _documentWindow.screen.frame.size.width) {
		width = self.documentWidth * 1.6;
		x = (_documentWindow.screen.frame.size.width - width) / 2;
	}
	if (height < MIN_WINDOW_HEIGHT || y + height > _documentWindow.screen.frame.size.height) {
		height = _documentWindow.screen.frame.size.height * .85;
		
		if (height < MIN_WINDOW_HEIGHT) height = MIN_WINDOW_HEIGHT;
		if (height > self.documentWidth * 2.5) height = self.documentWidth * 1.75;
		
		y = (_documentWindow.screen.frame.size.height - height) / 2;
	}
	
	// Set the width programmatically since we've got the outline visible in IB to work on it, but don't want it visible on launch
	[_documentWindow setMinSize:CGSizeMake(_documentWindow.minSize.width, MIN_WINDOW_HEIGHT)];
	NSRect newFrame = NSMakeRect(x,
								 y,
								 width,
								 height);
	[_documentWindow setFrame:newFrame display:YES];
}

-(void)setupLayoutWithPagination:(bool)paginate {
	// Apply layout
	
	[self updateLayout];
	[self ensureLayout];
	
	[self loadCaret];
	[self ensureCaret];
	[self updatePreview];
	if (paginate) [self paginateAt:(NSRange){0,0} sync:YES];
}


- (void)setFileURL:(NSURL *)fileURL {
	//NSString *oldName = [NSString stringWithString:[self fileNameString]];
	[super setFileURL:fileURL];
	//NSString *newName = [NSString stringWithString:[self fileNameString]];
}
- (NSString *)displayName {
	if (!self.fileURL) return @"Untitled";
	return [super displayName];
}

// Can I come over, I need to rest
// lay down for a while, disconnect
// the night was so long, the day even longer
// lay down for a while, recollect

# pragma mark - Window interactions

- (NSUInteger)selectedTab
{
	return [self.tabView indexOfTabViewItem:self.tabView.selectedTabViewItem];
}

- (bool)editorTabVisible {
	if (self.currentTab == _editorTab) return YES;
	else return NO;
}

- (void)showTab:(NSTabViewItem*)tab {
	[self.tabView selectTabViewItem:tab];
}

- (NSTabViewItem*)currentTab {
	return self.tabView.selectedTabViewItem;
}

- (bool)isFullscreen
{
	return (([_documentWindow styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
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
	[self setMinimumWindowSize];
	
	CGFloat width = (self.textView.frame.size.width / 2 - self.documentWidth * _magnification / 2) / _magnification;
	
	// Set global variable for top inset, if it's unset
	// For typewriter mode, we set the top & bottom bounds a bit differently
	// (this math must be wrong, now that I'm lookign at it, but won't fix it yet)
	
	if (width < 100000) { // Some arbitrary number to see that there is some sort of width set & view has loaded
		_inset = [_textView setInsets];
		[self.textScrollView setNeedsDisplay:YES];
		[self.marginView setNeedsDisplay:YES];
	}
	 
	[self ensureLayout];
	[self ensureCaret];
}


- (void)setMinimumWindowSize {
	// These are arbitratry values. Sorry, anyone reading this.
	if (!_sidebarVisible) {
		[self.documentWindow setMinSize:NSMakeSize(self.documentWidth * _magnification + 150, MIN_WINDOW_HEIGHT)];
	} else {
		[self.documentWindow setMinSize:NSMakeSize(self.documentWidth * _magnification + 150 + _outlineView.frame.size.width, MIN_WINDOW_HEIGHT)];
	}
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

static NSWindow *currentKeyWindow;

- (void)windowDidBecomeMain:(NSNotification *)notification {
	// Show all plugin windows associated with the current document
	[self showPluginWindowsForCurrentDocument];
	
	if (currentKeyWindow != nil && currentKeyWindow.visible) [currentKeyWindow makeKeyAndOrderFront:nil];
}
-(void)windowDidBecomeKey:(NSNotification *)notification {
	currentKeyWindow = nil;
}
-(void)windowDidResignKey:(NSNotification *)notification {
	currentKeyWindow = NSApp.keyWindow;
}

- (void)windowDidResignMain:(NSNotification *)notification {
	NSWindow *mainWindow = NSApp.mainWindow;
	
	// If main window is nil, we probably are in another app, so let's change the style of every plugin window
	if (mainWindow != nil) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		[_runningPlugins[pluginName] hideAllWindows];
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
	
	if (_revisionColor) {
		for (BeatColorMenuItem* item in _revisionColorPopup.itemArray) {
			if ([item.colorKey.lowercaseString isEqualToString:_revisionColor.lowercaseString]) [_revisionColorPopup selectItem:item];
		}
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
	if (self.currentTab == _editorTab) [self zoom:YES];
	
	// Web preview zoom
	if (@available(macOS 11.0, *)) {
		if (self.currentTab == _previewTab) self.printWebView.pageZoom += .1;
	}
}
- (IBAction)zoomOut:(id)sender {
	if (self.currentTab == _editorTab) [self zoom:NO];
	
	// Web preview zoom
	if (@available(macOS 11.0, *)) {
		if (self.currentTab == _previewTab) self.printWebView.pageZoom -= .1;
	}
}
- (IBAction)resetZoom:(id)sender {
	_magnification = DEFAULT_MAGNIFY;
	[self setScaleFactor:_magnification adjustPopup:false];
	[self updateLayout];
}

- (void)zoom:(bool)zoomIn {
	if (!_scaleFactor) _scaleFactor = _magnification;
	CGFloat oldMagnification = _magnification;
	
	// Save scroll position
	NSPoint scrollPosition = self.textScrollView.contentView.documentVisibleRect.origin;
	
	// For some reason, setting 1.0 scale for NSTextView causes weird sizing bugs, so we will use something that will never produce 1.0...... omg lol help
	if (zoomIn) {
		if (_magnification < 1.5) _magnification += 0.04;
	} else {
		if (_magnification > 0.8) _magnification -= 0.04;
	}

	// If magnification did change, scale the view
	if (oldMagnification != _magnification) {
		[self setScaleFactor:_magnification adjustPopup:false];
		[self updateLayout];
		
		// Scale and apply the scroll position
		scrollPosition.y = scrollPosition.y * _magnification;
		[self.textScrollView.contentView scrollToPoint:scrollPosition];
		[self ensureLayout];
		
		[self.textView setNeedsDisplay:YES];
		[self.textScrollView setNeedsDisplay:YES];
		
		// For some reason, clip view might get the wrong height after magnifying. No idea what's going on.
		NSRect clipFrame = _textClipView.frame;
		clipFrame.size.height = _textClipView.superview.frame.size.height * _magnification;
		_textClipView.frame = clipFrame;
		
		[self ensureLayout];
		
		[[NSUserDefaults standardUserDefaults] setFloat:_magnification forKey:MAGNIFYLEVEL_KEY];
	}
	
	[self.textView setInsets];
	[self updateLayout];
	[self ensureLayout];
	[self ensureCaret];
}

- (CGFloat)magnification { return _magnification; }

- (void)ensureCaret {
	[self.textView updateInsertionPointStateAndRestartTimer:YES];
}

- (void)ensureLayout {
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
	// When ensuring layout, we'll update all scene number labels
	if (self.showPageNumbers) [self.textView updatePageNumbers];
	if (self.showSceneNumberLabels) [self.textView resetSceneNumberLabels];
	[self.textView setNeedsDisplay:YES];
	[self.marginView updateBackground];
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag
{
	self.textView.zoomLevel = newScaleFactor;
	
	CGFloat oldScaleFactor = _scaleFactor;
	if (_scaleFactor != newScaleFactor)
	{
		NSSize curDocFrameSize, newDocBoundsSize;
		NSView *clipView = self.textView.superview;
		
		_scaleFactor = newScaleFactor;
		
		// Get the frame.  The frame must stay the same.
		curDocFrameSize = clipView.frame.size;
		
		// The new bounds will be frame divided by scale factor
		newDocBoundsSize.width = curDocFrameSize.width;
		newDocBoundsSize.height = curDocFrameSize.height / _scaleFactor;
		
		NSRect newFrame = NSMakeRect(0, 0, newDocBoundsSize.width, newDocBoundsSize.height);
		clipView.frame = newFrame;
	}
	_scaleFactor = newScaleFactor;
	[self scaleChanged:oldScaleFactor newScale:newScaleFactor];
	
	// Set minimum size for text view when Outline view size is dragged
	self.splitHandle.topOrRightMinSize = self.documentWidth * _magnification;
}

- (void)scaleChanged:(CGFloat)oldScale newScale:(CGFloat)newScale
{
	// Thank you, Mark Munz @ stackoverflow
	CGFloat scaler = newScale / oldScale;
	[self.textView scaleUnitSquareToSize:NSMakeSize(scaler, scaler)];
	
	NSLayoutManager* lm = self.textView.layoutManager;
	NSTextContainer* tc = self.textView.textContainer;
	[lm ensureLayoutForTextContainer:tc];
}

- (void)setZoom {
	// This resets the zoom to the saved setting
	if (![[NSUserDefaults standardUserDefaults] floatForKey:MAGNIFYLEVEL_KEY]) {
		_magnification = DEFAULT_MAGNIFY;
	} else {
		_magnification = [[NSUserDefaults standardUserDefaults] floatForKey:MAGNIFYLEVEL_KEY];
			  
		// Some limits for magnification, if something changes between app versions
		if (_magnification < .7 || _magnification > 1.19) _magnification = DEFAULT_MAGNIFY;
	}
	
	_scaleFactor = 1.0;
	[self setScaleFactor:_magnification adjustPopup:false];
	//[self setScaleFactor:_magnification adjustPopup:false];

	[self updateLayout];
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
		if (dataCache != nil) return dataCache;
		else dataRepresentation = [self.textView.string dataUsingEncoding:NSUTF8StringEncoding];
		
		// Everything is terrible, crash and don't overwrite anything.
		if (dataRepresentation == nil) @throw NSInternalInconsistencyException;
	} @finally {
		// If saving was successful, let's store the data into cache
		if (success) dataCache = dataRepresentation.copy;
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
	NSString *content = self.parser.screenplayForSaving;
		
	// Resort to content buffer if needed
	if (content == nil) content = self.contentCache;
	
	// Save added/removed ranges
	// This saves the revised ranges into Document Settings
	NSDictionary *revisions = [BeatRevisionTracking rangesForSaving:_attrTextCache];
	[_documentSettings set:DocSettingRevisions as:revisions];

	// Save current revision color
	[_documentSettings setString:DocSettingRevisionColor as:_revisionColor];
	
	// Save changed indices (why do we need this? asking for myself. -these are lines that had something removed rather than added, a later response)
	[_documentSettings set:DocSettingChangedIndices as:[BeatRevisionTracking changedLinesForSaving:self.lines]];
	
	// [_documentSettings set:@"Running Plugins" as:self.runningPlugins.allKeys];
	
	// Save reviewed ranges
	NSArray *reviews = [_review rangesForSavingWithString:_attrTextCache];
	[_documentSettings set:DocSettingReviews as:reviews];
	
	// Save caret position
	[self.documentSettings setInt:DocSettingCaretPosition as:self.textView.selectedRange.location];
	
	// Save character genders (if set)
	if (_characterGenders) [self.documentSettings set:@"CharacterGenders" as:_characterGenders];
	
	[self unblockUserInteraction];
	
	NSString * settingsString = [self.documentSettings getSettingsStringWithAdditionalSettings:additionalSettings];
	NSString * result = [NSString stringWithFormat:@"%@%@", content, (settingsString) ? settingsString : @""];
	
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
	NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
	NSRange settingsRange = [_documentSettings readSettingsAndReturnRange:text];
	text = [text stringByReplacingCharactersInRange:settingsRange withString:@""];
    	
	if (!reverting)	[self setText:text];
	else _contentBuffer = text; // When reverting, we only set the content buffer
	
    return YES;
}

- (void)registerEditorView:(id<BeatEditorView>)view {
	if (_registeredViews == nil) _registeredViews = NSMutableSet.set;;
	if (![_registeredViews containsObject:view]) [_registeredViews addObject:view];
}

/*
 
 But if the while I think on thee,
 dear friend,
 All losses are restor'd,
 and sorrows end.
 
 */


# pragma mark - Text I/O

- (void)setupTextView {
	// Set up the responder chain
	id originalResponder = self.textView.nextResponder;
	self.textView.nextResponder = _formattingActions;
	self.formattingActions.nextResponder = originalResponder;
	
	// Set insets on load
	[self.textView setup];
	[self.textView setInsets];
	
	// Make the text view first responder
	[_documentWindow makeFirstResponder:self.textView];
}

- (NSString *)text {
    return self.textView.string;
}

- (NSAttributedString *)getAttributedText
{
	return [[NSAttributedString alloc] initWithAttributedString:self.textView.attributedString];
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
	
	[self.textView deleteSceneNumberLabels];
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
			BeatFDXExport *fdxExport = [[BeatFDXExport alloc] initWithString:self.text attributedString:self.textView.attributedString includeTags:YES includeRevisions:YES paperSize:[self.documentSettings getInt:DocSettingPageSize]];
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


# pragma mark - Scene Data

- (OutlineScene*)currentScene {
	// If we are not on the main thread, return the latest known scene
	if (!NSThread.isMainThread) return _currentScene;
	
	OutlineScene *scene = [self getCurrentSceneWithPosition:self.textView.selectedRange.location];

	_currentScene = scene;
	return scene;
}

- (OutlineScene*)getCurrentSceneWithPosition:(NSInteger)position {
	if (_currentScene && NSLocationInRange(position, _currentScene.range)) {
		return _currentScene;
	}
	
	if (position >= self.text.length) {
		return self.parser.outline.lastObject;
	}
	
	NSInteger lastPosition = -1;
	OutlineScene *lastScene;
	
	// Remember to create outline first
	for (OutlineScene *scene in self.outline) {
		if (NSLocationInRange(position, scene.range)) {
			return scene;
		}
		else if (position >= lastPosition && position < scene.position && lastScene) {
			return lastScene;
		}
		
		lastPosition = scene.position + scene.length;
		lastScene = scene;
	}

	return nil;
}

- (OutlineScene*)getPreviousScene {
	NSArray *outline = [self getOutlineItems];
	if (outline.count == 0) return nil;
	
	Line * currentLine = [self getCurrentLine];
	NSInteger lineIndex = [self.parser.lines indexOfObject:currentLine] ;
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
	NSInteger lineIndex = [self.parser.lines indexOfObject:currentLine] ;
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
 
 DESTROY NUCLEAR.

 DESTROY BORING.

*/

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

# pragma mark - Text events

- (IBAction)toggleAutoLineBreaks:(id)sender {
	self.autoLineBreaks = !self.autoLineBreaks;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	// Don't allow editing the script while tagging
	if (_mode != EditMode || self.contentLocked) return NO;
	
	Line* currentLine = self.currentLine;
	
	// This shouldn't be here :-)
	if (replacementString.length == 1 && affectedCharRange.length == 0 && self.beatTimer.running) {
		if (![replacementString isEqualToString:@"\n"]) self.beatTimer.charactersTyped++;
	}
	
	// Check for character input trouble
	if (_characterInput && replacementString.length == 0 && NSMaxRange(affectedCharRange) == _characterInputForLine.position) {
		[self cancelCharacterInput];
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
				char chr = [self.textView.string characterAtIndex:affectedCharRange.location];
				if (chr == ')') {
					[self addString:@"\n" atIndex:affectedCharRange.location + 1];
					Line *nextLine = [self getNextLine:currentLine];
					[_formatting formatLine:nextLine];
					[self.textView setSelectedRange:(NSRange){ affectedCharRange.location + 2, 0 }];
					return NO;
				}
			}
		}
		
		// Handle automatic line breaks
		else if (self.autoLineBreaks) {
			if ([self shouldAddLineBreaks:currentLine range:affectedCharRange]) return NO;
		}
		
		// If something is being inserted, check whether it is a "(" or a "[[" and auto close it
		else if (self.matchParentheses) {
			[self matchParenthesesIn:affectedCharRange string:replacementString];
		}
		
		
		// Process line break after a forced character input
		if (_characterInput && _characterInputForLine) {
			// Don't go out of range
			if (_characterInputForLine.position + _characterInputForLine.string.length <= self.textView.string.length) {
				
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
		
		if ([self shouldJumpOverParentheses:replacementString range:affectedCharRange]) {
			return NO;;
		}
	}

	// Make the replacement string uppercase in parser
	if (_characterInput) replacementString = replacementString.uppercaseString;
	
	// Parse changes so far
	[self.parser parseChangeInRange:affectedCharRange withString:replacementString];
	
	// Get current line after parsing
	_currentLine = [self getCurrentLine];
		
	_lastChangedRange = (NSRange){ affectedCharRange.location, replacementString.length };
	_previewUpdated = NO;
	
    return YES;
}


- (bool)shouldAddLineBreaks:(Line*)currentLine range:(NSRange)affectedCharRange {
	// Don't add a dual line break if shift is pressed
	if (currentLine.string.length > 0 && !(NSEvent.modifierFlags & NSEventModifierFlagShift)) {
		
		// Add double breaks for outline element lines
		if (currentLine.isOutlineElement || currentLine.isAnyDialogue) {
			[self addString:@"\n\n" atIndex:affectedCharRange.location];
			return YES;
		}
		
		// Action lines need to perform some checks
		else if (currentLine.type == action) {
			NSUInteger currentIndex = [self.parser.lines indexOfObject:currentLine];
			
			// Perform a double-check if there is a next line
			if (currentIndex < self.parser.lines.count - 2 && currentIndex != NSNotFound) {
				Line* nextLine = [self.parser.lines objectAtIndex:currentIndex + 1];
				if (nextLine.string.length == 0) {
					[self addString:@"\n\n" atIndex:affectedCharRange.location];
					return YES;
				}
			} else {
				[self addString:@"\n\n" atIndex:affectedCharRange.location];
				return YES;
			}
		}
	}
	
	return NO;
}

- (bool)shouldJumpOverParentheses:(NSString*)replacementString range:(NSRange)affectedCharRange {
	// Jump over matched parentheses
	if ([replacementString isEqualToString:@")"] || [replacementString isEqualToString:@"]"]) {
		if (affectedCharRange.location < self.text.length) {
			unichar currentCharacter = [self.textView.string characterAtIndex:affectedCharRange.location];
			if ((currentCharacter == ')' && [replacementString isEqualToString:@")"]) ||
				(currentCharacter == ']' && [replacementString isEqualToString:@"]"])) {
				[self.textView setSelectedRange:NSMakeRange(affectedCharRange.location + 1, 0)];
				return YES;
			}
		}
	}
	
	return NO;
}

- (void)matchParenthesesIn:(NSRange)affectedCharRange string:(NSString*)replacementString {
	/**
	 This method finds a matching closure for parenthesis, notes and omissions.
	 It works by checking the entered symbol and if the previous symbol in text
	 matches its counterpart (like with *, if the previous is /, terminator is appended.
	 */
	
	if (replacementString.length > 1) return;;
	
	static NSDictionary *matches;
	if (matches == nil) matches = @{
		@"(" : @")",
		@"[[" : @"]]",
		@"/*" : @"*/",
		@"<<" : @">>",
		@"{{" : @"}}"
	};
		
	// Find match for the parenthesis symbol
	NSString *match = nil;
	for (NSString* key in matches.allKeys) {
		NSString *lastSymbol = [key substringWithRange:NSMakeRange(key.length - 1, 1)];
		
		if ([replacementString isEqualToString:lastSymbol]) {
			match = key;
			break;
		}
	}
	
	if (matches[match] == nil) {
		// No match for this parenthesis
		return;
	}
	else if (match.length > 1) {
		if (affectedCharRange.location == 0) return;
		
		// Check for dual symbol matches, and don't allow them if the previous character doesn't match
		unichar characterBefore = [self.textView.string characterAtIndex:affectedCharRange.location-1];
		if (characterBefore != [match characterAtIndex:0]) {
			return;
		}
	}
	
	[self addString:matches[match] atIndex:affectedCharRange.location];
	[self.textView setSelectedRange:affectedCharRange];
}

- (BOOL)shouldAddContdIn:(NSRange)affectedCharRange string:(NSString*)replacementString {
	Line *currentLine = self.currentLine;
	
	NSInteger lineIndex = [self.parser.lines indexOfObject:currentLine] - 1;
	if (lineIndex != NSNotFound) {
		NSString *charName = currentLine.characterName;
		
		while (lineIndex > 0) {
			Line * prevLine = self.parser.lines[lineIndex];
			
			// Stop at headings
			if (prevLine.type == heading) break;

			if (prevLine.type == character) {
				// Stop if the previous character is not the current one
				if (![prevLine.characterName isEqualToString:charName]) break;
				
				// This is the character. Put in CONT'D and a line break and return NO
				NSString *contd = [BeatUserDefaults.sharedDefaults get:@"screenplayItemContd"];
				NSString *contdString = [NSString stringWithFormat:@" (%@)\n", contd];
				
				if (![currentLine.string containsString:[NSString stringWithFormat:@"(%@)", contd]]) {
					[self addString:contdString atIndex:currentLine.position + currentLine.length];
					return YES;
				}
			}
			
			lineIndex--;
		}
	}
	return NO;
}


- (Line*)getPreviousLine:(Line*)line {
	NSInteger i = [self.parser.lines indexOfObject:line];
	if (i > 0) return self.parser.lines[i - 1];
	else return nil;
}
- (Line*)getNextLine:(Line*)line {
	NSInteger i = [self.parser.lines indexOfObject:line];
	if (i < self.parser.lines.count - 1 && i != NSNotFound) {
		return self.parser.lines[i + 1];
	} else {
		return nil;
	}
}

- (Line*)currentLine {
	NSInteger location = self.selectedRange.location;
	if (location >= self.text.length) return self.parser.lines.lastObject;
	
	// Don't fetch the line if we already know it
	if (NSLocationInRange(location, _currentLine.range)) return _currentLine;
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

- (IBAction)reformatRange:(id)sender {
	if (self.textView.selectedRange.length > 0) {
		NSArray *lines = [self.parser linesInRange:self.textView.selectedRange];
		if (lines) [self.parser correctParsesForLines:lines];
		[self.parser createOutline];
		[self ensureLayout];
	}
}

- (bool)inRange:(NSRange)range {
	NSRange intersection = NSIntersectionRange(range, (NSRange){0, _textView.string.length  });
	if (intersection.length == range.length) return YES;
	else return NO;
}

- (void)textDidChange:(NSNotification *)notification
{
	// Begin from top if no last changed range was set
	if (_lastChangedRange.location == NSNotFound) _lastChangedRange = NSMakeRange(0, 0);
		
	// Save attributed text to cache
	_attrTextCache = [self getAttributedText];
	
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;
		
	// Register changes
	if (_revisionMode) [self registerChangesInRange:_lastChangedRange];
	
	// Update formatting
	[self applyFormatChanges];
	
	// If outline has changed, we will rebuild outline & timeline if needed
	bool changeInOutline = [self.parser getAndResetChangeInOutline];
	
	// NOTE: calling this method removes the outline changes from parser
	NSArray *changesInOutline = self.parser.changesInOutline;
	
	if (changeInOutline == YES) {
		[self.parser updateOutlineWithChangeInRange:_lastChangedRange];
		
		if (self.sidebarVisible && self.sideBarTabs.selectedTabViewItem == _tabOutline) [self.outlineView reloadOutline:changesInOutline];
		if (self.timeline.visible) [self.timeline reload];
		if (self.timelineBar.visible) [self reloadTouchTimeline];
		if (self.runningPlugins.count) [self updatePluginsWithOutline:self.parser.outline];
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
		
	// If the outline has changed, update all labels
	[self.textView updateSceneLabelsFrom:self.lastChangedRange.location];
	//[self.textView updateChangeMarkersFrom:self.lastChangedRange.location];
	
	// Update preview screen
	[self updatePreview];
	
	// Draw masks again if text did change
	if (_outlineView.filteredOutline.count) [self maskScenes];
	
	// Update any currently running plugins
	if (_runningPlugins.count) [self updatePlugins:_lastChangedRange];
	
	// Save to buffer
	_contentCache = [NSString stringWithString:self.textView.string];
	
	// A larger chunk of text was pasted. Ensure layout.
	if (_lastChangedRange.length > 3) {
		[self ensureLayout];
	}
	
	// Fire up autocomplete at the end of string and create cached lists of scene headings / character names
	if (self.autocomplete) [self.autocompletion autocompleteOnCurrentLine];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) {
		[self.textView scrollToRange:NSMakeRange(_lastChangedRange.location, 0)];
	}
	
	// Reset last changed range
	_lastChangedRange = NSMakeRange(NSNotFound, 0);
}

-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
	// Faux delegate method forwarded from NSTextView.
	// Use if needed.
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
	
	// We REALLY REALLY should make some sort of cache for these
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		// Update all views which are affected by the caret position
		if (self.sidebarVisible || self.timeline.visible || self.runningPlugins) {
			self.outline = [self getOutlineItems];
			self.currentScene = [self getCurrentSceneWithPosition:self.selectedRange.location];
		}
		
		[self updateUIwithCurrentScene];
		
		// Update tag view
		if (self.mode == TaggingMode) [self.tagging updateTaggingData];
		
		// Update running plugins
		if (self.runningPlugins.count) [self updatePluginsWithSelection:self.selectedRange];
	});
	
	[_textView updateMarkdownView];
}

- (void)updateUIwithCurrentScene {
	__block NSInteger sceneIndex = [self.outline indexOfObject:self.currentScene];
	
	OutlineScene *currentScene = self.currentScene;
	
	// Update Timeline & TouchBar Timeline
	if (self.timeline.visible) [_timeline scrollToScene:sceneIndex];
	if (self.timelineBar.visible) [_touchbarTimeline selectItem:[_outline indexOfObject:currentScene]];
	
	// Locate current scene & reload outline without building it in parser
	// I don't know what this is, to be honest
	if (_sidebarVisible && !_outlineEdit) {
		
		if (self.sidebarVisible) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				if (currentScene) [self.outlineView scrollToScene:currentScene];
			});
		}
	}
	
	// Update touch bar color if needed
	if (currentScene.color) {
		if ([BeatColors color:currentScene.color.lowercaseString]) {
			[_colorPicker setColor:[BeatColors color:currentScene.color.lowercaseString]];
		}
	}
	
	if (_runningPlugins) [self updatePluginsWithSceneIndex:sceneIndex];
}


#pragma mark - TextView actions

- (IBAction)showInfo:(id)sender {
	[self.textView showInfo:self];
}

#pragma mark - Text I/O

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string
{
	/**
	 Main method for adding text to editor view.  Forces added text to be parsed.
	 */
	
	// If range is over bounds (this can happen with certain undo operations for some reason), let's fix it
	if (range.length + range.location > self.textView.string.length) {
		NSLog(@"replacement over bounds: %lu / %lu", range.location + range.length, self.textView.string.length);
		
		NSInteger length = self.textView.string.length - range.location;
		range = NSMakeRange(range.location, length);
		
		NSLog(@"fixed to: %lu / %lu", range.location + range.length, self.textView.string.length);
	}

	// Text view fires up shouldChangeTextInRange only when the text is changed by the user.
	// When replacing stuff directly in the view, we need to call it manually.
	if ([self textView:self.textView shouldChangeTextInRange:range replacementString:string]) {
		[self.textView replaceCharactersInRange:range withString:string];
		[self textDidChange:[NSNotification notificationWithName:@"" object:nil]];
	}
}


- (void)addString:(NSString*)string atIndex:(NSUInteger)index
{
	[self replaceCharactersInRange:NSMakeRange(index, 0) withString:string];
	[[self.undoManager prepareWithInvocationTarget:self] removeString:string atIndex:index];
}

- (void)removeString:(NSString*)string atIndex:(NSUInteger)index
{
	[self replaceCharactersInRange:NSMakeRange(index, string.length) withString:@""];
	[[self.undoManager prepareWithInvocationTarget:self] addString:string atIndex:index];
}
- (void)replaceRange:(NSRange)range withString:(NSString*)newString
{
	// Replace with undo registration
	NSString *oldString = [self.textView.string substringWithRange:range];
	[self replaceCharactersInRange:range withString:newString];
	[[self.undoManager prepareWithInvocationTarget:self] replaceString:newString withString:oldString atIndex:range.location];
}
- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index
{
	// Replace with undo registration
	NSRange range = NSMakeRange(index, string.length);
	[self replaceCharactersInRange:range withString:newString];
	[[self.undoManager prepareWithInvocationTarget:self] replaceString:newString withString:string atIndex:index];
}
- (void)removeRange:(NSRange)range {
	NSString *string = [self.text substringWithRange:range];
	[self replaceCharactersInRange:range withString:@""];
	[[self.undoManager prepareWithInvocationTarget:self] addString:string atIndex:range.location];
}
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string {
	_moving = YES;
	NSString *oldString = [self.text substringWithRange:range];
	
	NSString *stringToMove = string;
	NSInteger length = self.text.length;
	
	if (position > length) position = length;
	
	[self replaceCharactersInRange:range withString:@""];
	
	NSInteger newPosition = position;
	if (range.location < position) {
		newPosition = position - range.length;
	}
	if (newPosition < 0) newPosition = 0;
	
	[self replaceCharactersInRange:NSMakeRange(newPosition, 0) withString:stringToMove];
	
	NSRange undoingRange;
	NSInteger undoPosition;
		
	if (range.location > position) {
		undoPosition = range.location + stringToMove.length;
		undoingRange = NSMakeRange(position, stringToMove.length);
	} else {
		undoingRange = NSMakeRange(newPosition, stringToMove.length);
		undoPosition = range.location;
	}
	
	[[self.undoManager prepareWithInvocationTarget:self] moveStringFrom:undoingRange to:undoPosition actualString:oldString];
	[self.undoManager setActionName:@"Move Scene"];
	
	_moving = NO;
}
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position {
	NSString *stringToMove = [self.text substringWithRange:range];
	[self moveStringFrom:range to:position actualString:stringToMove];
}

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
	return NSMakeRange(range->location + position, range->length);
}

- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to {
	// FOLLOWING CODE IS A MESS. Dread lightly.
	// Thanks for the heads up, past me, but I'll just dive right in
	
	// NOTE FROM BEAT 1.1 r4:
	// The scenes know if they miss omission begin / terminator. The trouble is, I have no idea how to put that information into use without dwelving into an endless labyrinth of string indexes... soooo... do it later?
	
	// On to the very dangerous stuff :-) fuck me :----)
	NSRange range = NSMakeRange(sceneToMove.position, sceneToMove.length);
	NSString *string = [self.text substringWithRange:range];
	
	NSInteger omissionStartsAt = NSNotFound;
	NSInteger omissionEndsAt = NSNotFound;
	
	if (sceneToMove.omitted) {
		// We need to find out where the omission begins & ends
		NSInteger idx = [self.parser.lines indexOfObject:sceneToMove.line];
		if (idx == NSNotFound) return; // Shouldn't happen
		
		if (idx > 0) {
			// Look for start of omission, but break when encountering an outline item
			for (NSInteger i = idx - 1; i >= 0; i++) {
				Line *prevLine = self.lines[i];
				if (prevLine.type == heading || prevLine.type == synopse || prevLine.type == section) break;
				else if (prevLine.omitOut && [prevLine.string rangeOfString:@"/*"].location != NSNotFound) {
					omissionStartsAt = prevLine.position + [prevLine.string rangeOfString:@"/*"].location;
					break;
				}
			}
			
			// Look for end of omission
			for (NSInteger i = idx + 1; i < self.lines.count; i++) {
				Line *nextLine = self.lines[i];
				if (nextLine.type == heading || nextLine.type == section) break;
				else if (nextLine.omitIn && [nextLine.string rangeOfString:@"*/"].location != NSNotFound) {
					omissionEndsAt = nextLine.position + [nextLine.string rangeOfString:@"*/"].location + 2;
				}
			}
		}
		
	
		// Recreate range to represent the actual range with omission symbols
		// (if applicable)
		NSInteger loc = (omissionStartsAt == NSNotFound) ? sceneToMove.position : omissionStartsAt;
		NSInteger len = (omissionEndsAt == NSNotFound) ? (sceneToMove.position + sceneToMove.length) - loc : omissionEndsAt - loc;
		
		range = (NSRange){ loc, len };
		
		string = [self.text substringWithRange:range];
		
		// Add omission markup if needed
		if (omissionStartsAt == NSNotFound) string = [NSString stringWithFormat:@"\n/*\n\n%@", string];
		if (omissionEndsAt == NSNotFound) string = [string stringByAppendingString:@"\n*/\n\n"];
		
		// Normal omitted blocks end with */, so add some line breaks if needed
		if ([[string substringFromIndex:string.length - 2] isEqualToString:@"*/"]) string = [string stringByAppendingString:@"\n\n"];
	}
	
	// Create a new outline before trusting it
	NSMutableArray *outline = [self getOutlineItems];
	
	// When an item is dropped at the end, its target index will be +1 from the last item
	bool moveToEnd = false;
	if (to >= outline.count) {
		to = outline.count - 1;
		moveToEnd = true;
	}
		
	if (sceneToMove.type == synopse) {
		// We need to add a line break for synopsis lines, because they only span for a single line.
		// Moving them around could possibly break parsing.
		string = [string stringByAppendingString:@"\n"];
	}
	
	// Scene before which this scene will be moved, if not moved to the end
	OutlineScene *sceneAfter;
	if (!moveToEnd) sceneAfter = [outline objectAtIndex:to];
	
	if (!moveToEnd) {
		[self moveStringFrom:range to:sceneAfter.position actualString:string];
	} else {
		[self moveStringFrom:range to:self.text.length actualString:string];
	}
}

- (void)removeTextOnLine:(Line*)line inLocalIndexSet:(NSIndexSet*)indexSet {
	__block NSUInteger offset = 0;
	[indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		// Remove beats on any line
		NSRange globalRange = [self globalRangeFromLocalRange:&range inLineAtPosition:line.position];
		[self removeRange:(NSRange){ globalRange.location - offset, globalRange.length }];
		offset += range.length;
	}];
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
	
	NSUInteger prevIndex = [self.lines indexOfObject:lines.firstObject] - 1;
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
		
	NSUInteger nextIndex = [self.lines indexOfObject:lines.lastObject] + 1;
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


# pragma mark - Autocomplete and character input

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	return [_autocompletion textView:textView completions:words forPartialWordRange:charRange indexOfSelectedItem:index];
}

- (void)handleTabPress {
	// Force character if the line is suitable
	Line *currentLine = self.currentLine;
	
	if (currentLine.type == empty) {
		NSInteger index = [self.parser.lines indexOfObject:currentLine];
		
		if (index > 0) {
			Line* previousLine = [self.parser.lines objectAtIndex:index - 1];
			if (previousLine.type == empty ||
				(previousLine.type == action && previousLine.string.length == 0)) {
				[self forceCharacterInput];
			}
		}
	}
	else if (currentLine.isAnyCharacter) {
		[_autocompletion autocompleteOnCurrentLine];
	} else {
		// Don't allow this to happen twice
		if (_characterInput) return;

		// Else see if we could force the character cue
		Line* prevLine = [self.parser previousLine:currentLine];
		Line* nextLine = [self.parser nextLine:currentLine];
		
		// A convoluted conditional, but the rules are:
		// Previous line is empty, current line is not already part of a dialogue block,
		// next line is not a heading OR is already formatted as dialogue (can happen rarely)
		if (prevLine.type == empty &&
			!currentLine.isDialogueElement &&
			((nextLine.type != character &&
			 nextLine.type != heading) ||
			nextLine.isDialogue)) {
			[self replaceString:currentLine.string withString:currentLine.string.uppercaseString atIndex:currentLine.position];
		}
		else {
			// Default behaviour: add tab
			// nope
			// [self replaceCharactersInRange:self.textView.selectedRange withString:@"\t"];
		}
	}
}

- (void)forceCharacterInput {
	// Don't allow this to happen twice
	if (_characterInput) return;
	
	// If no line is selected, return
	Line *currentLine = self.currentLine;
	if (currentLine == nil) return;
	
	currentLine.type = character;
	_characterInputForLine = currentLine;
	
	_characterInput = YES;
	
	// Format the line (if mid-screenplay)
	[_formatting formatLine:currentLine];
	
	// Set typing attributes (just in case, and if at the end)
	NSMutableDictionary *attributes = NSMutableDictionary.dictionary;
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[paragraphStyle setFirstLineHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
	[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	[self.textView setTypingAttributes:attributes];
	
	NSLog(@"Forced successfully");
}
- (void)cancelCharacterInput {
	_characterInput = NO;
	
	NSMutableDictionary *attributes = NSMutableDictionary.dictionary;
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
	[attributes setValue:self.courier forKey:NSFontAttributeName];
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[paragraphStyle setFirstLineHeadIndent:400];
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
		[_formatting formatLine:line];
	}
	
	[self ensureLayout];
}
- (void)applyFormatChanges
{
	[self.parser.changedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		[_formatting formatLine:self.parser.lines[idx]];
	}];
	
    [self.parser.changedIndices removeAllIndexes];
}
- (void)forceFormatChangesInRange:(NSRange)range
{
	[self.textView.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor forCharacterRange:range];
	
	NSArray *lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		[_formatting formatLine:line];
	}
}

-(void)applyInitialFormatting {
	if (self.parser.lines.count == 0) {
		[self loadingComplete];
		return;
	}
	
	// This is optimization for first-time format with no lookbacks (with a look-forward, though)
	self.progressIndicator.maxValue =  1.0;
	
	[self formatAllWithDelay:0];
}
- (void)formatAllWithDelay:(NSInteger)idx {
	// We split the document into chunks of 400 lines and render them asynchronously
	// to throttle the initial loading of document a bit
	
	dispatch_async(dispatch_get_main_queue(), ^(void){
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
		
		// If the document is done formatting, complete the loading process.
		// Else render 400 more lines
		if (line == self.parser.lines.lastObject || lastIndex >= self.parser.lines.count) {
			[self loadingComplete];
		}
		else [self formatAllWithDelay:lastIndex + 1];
	});
}

- (IBAction)toggleDisableFormatting:(id)sender {
	_disableFormatting = !_disableFormatting;
	[self formatAllLines];
}

- (void)renderBackgroundForLines {
	for (Line* line in self.lines) {
		[_formatting renderBackgroundForLine:line clearFirst:YES];
	}
}

- (void)renderBackgroundForRange:(NSRange)range {
	NSArray *lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		[self renderBackgroundForLine:line clearFirst:YES];
	}
}

- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear {
	// Forward (for delegation)
	[_formatting renderBackgroundForLine:line clearFirst:clear];
}


- (void)setTypeAndFormat:(Line*)line type:(LineType)type {
	line.type = type;
	[self formatLine:line];
}

#pragma mark - Revisions

- (void)registerChangesInRange:(NSRange)range {
	NSString * change = [self.text substringWithRange:range];

	if (range.length < 2) {
		Line * line = [self.parser lineAtPosition:range.location];
		
		if ([change isEqualToString:@"\n"]) {
			// This was a line break. If it was at the end of a line, reduce that line from the range.
			if (NSMaxRange(range) == NSMaxRange(line.range)) return;
		}
	}
	
	[_textView.textStorage addAttribute:revisionAttribute value:[BeatRevisionItem type:RevisionAddition color:_revisionColor] range:range];
}

- (IBAction)nextRevision:(id)sender {
	[self.revisionTracking nextRevision];
}
- (IBAction)previousRevision:(id)sender {
	[self.revisionTracking previousRevision];
}


#pragma mark - Scrolling

- (IBAction)goToScene:(id)sender {
	BeatModalInput *input = [[BeatModalInput alloc] init];
	[input inputBoxWithMessage:@"Go to scene number..." text:@"" placeholder:@"e.g. 123" forWindow:_documentWindow completion:^(NSString * _Nonnull result) {
		[self scrollToSceneNumber:result];
	}];
}

- (void)scrollToSceneNumber:(NSString*)sceneNumber {
	// Note: scene numbers are STRINGS, because they can be anything (2B, EXTRA, etc.)
	
	for (OutlineScene *scene in self.parser.outline) {
		if ([scene.sceneNumber isEqualTo:sceneNumber]) {
			[self scrollToScene:scene];
			return;
		}
	}
}
- (void)scrollToScene:(OutlineScene*)scene {
	NSRange lineRange = NSMakeRange(scene.line.position, scene.line.string.length);
	[self.textView setSelectedRange:lineRange];
	[self.textView scrollToRange:lineRange];
	[_documentWindow makeFirstResponder:_textView];
}
- (void)scrollToRange:(NSRange)range {
	[self.textView setSelectedRange:range];
	[self.textView scrollRangeToVisible:range];
}

/* Helper functions for the imagined scripting module */
- (void)scrollTo:(NSInteger)location {
	NSRange range = NSMakeRange(location, 0);
	[self.textView setSelectedRange:range];
	[self.textView scrollRangeToVisible:range];
}
- (void)scrollToLine:(Line*)line {
	NSRange range = NSMakeRange(line.position, line.string.length);
	[self.textView setSelectedRange:range];
	[self.textView scrollRangeToVisible:range];
}
- (void)scrollToLineIndex:(NSInteger)index {
	Line *line = [self.parser.lines objectAtIndex:index];
	if (!line) return;
	
	NSRange range = NSMakeRange(line.position, line.string.length);
	[self.textView setSelectedRange:range];
	[self.textView scrollRangeToVisible:range];
}
- (void)scrollToSceneIndex:(NSInteger)index {
	OutlineScene *scene = [[self getOutlineItems] objectAtIndex:index];
	if (!scene) return;
	
	NSRange range = NSMakeRange(scene.line.position, scene.string.length);
	[self.textView setSelectedRange:range];
	[self.textView scrollRangeToVisible:range];
}

- (void)focusEditor {
	[_documentWindow makeKeyWindow];
}


#pragma mark - Parser delegation

- (NSRange)selectedRange {
	return self.textView.selectedRange;
}
- (void)setSelectedRange:(NSRange)range {
	[self setSelectedRange:range withoutTriggeringChangedEvent:NO];
}
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
	if (self.textView.selectedRange.location == self.textView.string.length) return YES;
	else return NO;
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
	_courier = [NSFont fontWithName:@"Courier Prime" size:[self fontSize]];
	_boldCourier = [NSFont fontWithName:@"Courier Prime Bold" size:[self fontSize]];
	_boldItalicCourier = [NSFont fontWithName:@"Courier Prime Bold Italic" size:[self fontSize]];
	_italicCourier = [NSFont fontWithName:@"Courier Prime Italic" size:[self fontSize]];
}
- (void)loadSansSerifFonts {
	_courier = [NSFont fontWithName:@"Courier Prime Sans" size:[self fontSize]];
	_boldCourier = [NSFont fontWithName:@"Courier Prime Sans Bold" size:[self fontSize]];
	_boldItalicCourier = [NSFont fontWithName:@"Courier Prime Sans Bold Italic" size:[self fontSize]];
	_italicCourier = [NSFont fontWithName:@"Courier Prime Sans Italic" size:[self fontSize]];
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
		_synopsisFont = [NSFont systemFontOfSize:15.5];
		NSFontManager *fontManager = [[NSFontManager alloc] init];
		_synopsisFont = [fontManager convertFont:_synopsisFont toHaveTrait:NSFontItalicTrait];
	}
	return _synopsisFont;
}

// This is here for legacy reasons
- (NSUInteger)fontSize
{
	_fontSize = FONT_SIZE;
	return _fontSize;
}


#pragma mark - Formatting Buttons

//static NSString *lineBreak = @"\n\n===\n\n";
//static NSString *boldSymbol = @"**";
//static NSString *italicSymbol = @"*";
//static NSString *underlinedSymbol = @"_";
//static NSString *noteOpen = @"[[";
//static NSString *noteClose= @"]]";
//static NSString *omitOpen = @"/*";
//static NSString *omitClose= @"*/";
//static NSString *forceHeadingSymbol = @".";
//static NSString *forceActionSymbol = @"!";
//static NSString *forceCharacterSymbol = @"@";
//static NSString *forcetransitionLineSymbol = @">";
//static NSString *forceLyricsSymbol = @"~";
//static NSString *forceDualDialogueSymbol = @"^";
//
//static NSString *highlightSymbolOpen = @"<<";
//static NSString *highlightSymbolClose = @">>";
//static NSString *strikeoutSymbolOpen = @"{{";
//static NSString *strikeoutSymbolClose = @"}}";

static NSString *tagAttribute = @"BeatTag";
static NSString *revisionAttribute = @"Revision";

- (void)forceElement:(LineType)lineType {
	[self.formattingActions forceElement:lineType];
}

- (CGFloat)lineHeight { return LINE_HEIGHT; }

#pragma mark - Revision Tracking

// UI side

-(IBAction)toggleShowRevisions:(id)sender {
	_showRevisions = !_showRevisions;
	
	if (_showRevisions) {
		// Show revisions
		[self.formatting initialTextBackgroundRender];
		[self.textView refreshLayoutElements];
	} else {
		// Hide revisions
		for (Line* line in self.parser.lines) [self renderBackgroundForLine:line clearFirst:YES];
	}
	
	[self updateQuickSettings];
	
	// Save user default
	[BeatUserDefaults.sharedDefaults saveBool:_showRevisions forKey:@"showRevisions"];
}

-(IBAction)toggleRevisionMode:(id)sender {
	_revisionMode = !_revisionMode;
	
	if (!_showRevisions) {
		// Revisions were hidden, bring them back
		_showRevisions = YES;
		for (Line* line in self.parser.lines) [self renderBackgroundForLine:line clearFirst:YES];
	}
	
	[self updateQuickSettings];
	
	// Save user default + document setting
	[BeatUserDefaults.sharedDefaults saveBool:YES forKey:@"showRevisions"];
	[_documentSettings setBool:DocSettingRevisionMode as:_revisionMode];
}
- (IBAction)markAddition:(id)sender
{
	if (!self.contentLocked) [self.revisionTracking markerAction:RevisionAddition];
}
- (IBAction)markRemoval:(id)sender
{
	if (!self.contentLocked) [self.revisionTracking markerAction:RevisionRemovalSuggestion];
}
- (IBAction)clearMarkings:(id)sender
{
	// Remove markers
	if (!self.contentLocked) [self.revisionTracking markerAction:RevisionNone];
}

- (IBAction)commitRevisions:(id)sender {
	[self.revisionTracking commitRevisions];
}

/*
 
 WIP: Make the following code more functional
 
 */


- (IBAction)selectRevisionColor:(id)sender {
	NSPopUpButton *button = sender;
	BeatColorMenuItem *item = (BeatColorMenuItem *)button.selectedItem;
	_revisionColor = item.colorKey;
	
	[_documentSettings setString:DocSettingRevisionColor as:_revisionColor];
}



#pragma mark - Lock & Force Scene Numbering

// Preprocessing was apparently a bottleneck. Redone in 1.1.0f
- (NSString*) preprocessSceneNumbers
{
	// This is horrible shit and should be fixed ASAP
	NSString *sceneNumberPattern = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPattern];
	NSMutableString *fullText = [NSMutableString stringWithString:@""];
	
	NSUInteger sceneCount = 1; // Track scene amount
	
	// Make a copy of the array if this is called in a background thread
	NSArray *lines = [NSArray arrayWithArray:[self.parser lines]];
	for (Line *line in lines) { @autoreleasepool {
		//NSString *cleanedLine = [line.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		NSString *cleanedLine = [NSString stringWithString:line.string];
		
		// If the heading already has a forced number, skip it
		if (line.type == heading && ![testSceneNumber evaluateWithObject: cleanedLine]) {
			// Check if the scene heading is omited
			if (!line.omitted) {
				[fullText appendFormat:@"%@ #%lu#\n", cleanedLine, sceneCount];
				sceneCount++;
			} else {
				// We will still append the heading into the raw text … this is a dirty fix
				// to keep indexing of scenes intact
				[fullText appendFormat:@"%@\n", cleanedLine];
			}
		} else {
			[fullText appendFormat:@"%@\n", cleanedLine];
		}
		
		// Add a line break after the scene heading if it doesn't have one
		// If the user relies on this feature, it breaks the file's compatibility with other Fountain editors, but they have no one else to blame than themselves I guess. And my friendliness and hospitality allowing them to break the syntax.
		if (line.type == heading && line != [lines lastObject]) {
			NSInteger lineIndex = [lines indexOfObject:line];
			if ([(Line*)[lines objectAtIndex:lineIndex + 1] type] != empty) {
				[fullText appendFormat:@"\n"];
			}
		}
	} }
	
	return fullText;
}

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
	[self.parser createOutline];
	
	[self.textView refreshLayoutElements];
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
		[ValidationItem withAction:@selector(toggleMatchParentheses:) setting:@"matchParentheses" target:self],
		[ValidationItem withAction:@selector(toggleAutoLineBreaks:) setting:@"autoLineBreaks" target:self],
		[ValidationItem withAction:@selector(toggleSceneLabels:) setting:@"showSceneNumberLabels" target:self],
		[ValidationItem withAction:@selector(togglePageNumbers:) setting:@"showPageNumbers" target:self],
		[ValidationItem withAction:@selector(toggleTypewriterMode:) setting:@"typewriterMode" target:self],
		[ValidationItem withAction:@selector(togglePrintSceneNumbers:) setting:@"printSceneNumbers" target:self],
		[ValidationItem withAction:@selector(toggleSidebarView:) setting:@"sidebarVisible" target:self],
		[ValidationItem withAction:@selector(toggleTimeline:) setting:@"timelineVisible" target:self],
		[ValidationItem withAction:@selector(toggleAutosave:) setting:@"autosave" target:self],
		[ValidationItem withAction:@selector(toggleRevisionMode:) setting:@"revisionMode" target:self],
		[ValidationItem withAction:@selector(lockContent:) setting:@"Locked" target:self.documentSettings],
		[ValidationItem withAction:@selector(toggleHideFountainMarkup:) setting:@"hideFountainMarkup" target:self],
		[ValidationItem withAction:@selector(toggleDisableFormatting:) setting:@"disableFormatting" target:self],
		[ValidationItem withAction:@selector(toggleShowRevisions:) setting:@"showRevisions" target:self],
	];
}
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Special conditions for other than normal edit view
	if (self.currentTab != _editorTab) {
		// If PRINT PREVIEW is enabled
		if (self.currentTab == _previewTab) {
			
			if (menuItem.action == @selector(preview:)) {
				[menuItem setState:NSOnState];
				return YES;
			}
			if (menuItem.action == @selector(zoomIn:)) return YES;
			if (menuItem.action == @selector(zoomOut:)) return YES;
		}

		// If CARD VIEW is enabled
		if (_currentTab == _cardsTab) {
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
	
	// Normal editor view items
	bool uneditable = NO;
	if (_mode == TaggingMode || _mode == ReviewMode) uneditable = YES;
	
	if ([_formattingActions respondsToSelector:menuItem.action]) {
		NSLog(@"OK %@", menuItem.title);
	}
	
	// Validate ALL on/of items
	// This is a specific class which matches given methods against a property in this class, ie. toggleSomething -> .something
	for (ValidationItem *item in _itemsToValidate) {
		if (menuItem.action == item.selector) {
			bool on = [item validate];
			if (on) [menuItem setState:NSOnState];
			else [menuItem setState:NSOffState];
		}
	}
	
	// Settings for EDIT MODE
	if (_mode != EditMode) {
		/*
		 // Move these to revision class
		if (menuItem.action == @selector(markRangeForRemoval:) ||
			menuItem.action == @selector(markRangeAsAddition:) ||
			menuItem.action == @selector(clearMarkings:)) return NO;
		 */
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
		bool sansSerif = [BeatUserDefaults.sharedDefaults getBool:@"useSansSerif"];
		if (sansSerif) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(selectSerif:)) {
		bool sansSerif = [BeatUserDefaults.sharedDefaults getBool:@"useSansSerif"];
		if (!sansSerif) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
		
	}
	else if (menuItem.action == @selector(toggleDarkMode:)) {
		if ([(BeatAppDelegate *)[NSApp delegate] isDark]) [menuItem setState:NSOnState];
		else [menuItem setState:NSOffState];
	
	}
	else if (menuItem.submenu.itemArray.firstObject.action == @selector(shareFromService:)) {
	//else if ([menuItem.title isEqualToString:@"Share"]) {
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
	
	// So, I have overriden everything regarding undo (because I couldn't figure it out).
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

- (IBAction)toggleMatchParentheses:(id)sender
{
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
    
    for (Document* doc in openDocuments) {
        doc.matchParentheses = !doc.matchParentheses;
    }
	
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
}



-(NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex {
	return self.textView.contextMenu;
}


#pragma mark - Themes & UI

- (IBAction)toggleDarkMode:(id)sender {
	[(BeatAppDelegate *)NSApp.delegate toggleDarkMode];
	
	[self updateUIColors];

	[self.textView toggleDarkPopup:nil];
	_darkPopup = [self isDark];
	
	NSArray* openDocuments = NSDocumentController.sharedDocumentController.documents;
	
	for (Document* doc in openDocuments) {
		[doc updateUIColors];
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
	} else {
		// Else, we need to force everything to redraw, in a very clunky way
		[self.documentWindow setViewsNeedDisplay:true];
		
		[self.masterView setNeedsDisplayInRect:_masterView.frame];
		[self.backgroundView setNeedsDisplay:true];
		[self.textScrollView setNeedsDisplay:true];
		[self.marginView setNeedsDisplay:true];
		
		[self.textScrollView layoutButtons];
		
		[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
		
		[self.textView drawViewBackgroundInRect:self.textView.bounds];
		[self.textView setNeedsDisplay:true];

		[self resetSceneNumberLabels];
		
		if (_sidebarVisible) [self.outlineView setNeedsDisplay:YES];
	}
	
	//[self.textView setNeedsDisplay:true];
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
	
	doc.textView.textColor = self.themeManager.currentTextColor;
	doc.textView.marginColor = self.themeManager.currentMarginColor;
	doc.textScrollView.marginColor = self.themeManager.currentMarginColor;
	
	[doc.textView setSelectedTextAttributes:@{
										  NSBackgroundColorAttributeName: self.themeManager.currentSelectionColor,
										  NSForegroundColorAttributeName: self.themeManager.currentBackgroundColor
	}];
	
	if (setTextColor) [doc.textView setTextColor:self.themeManager.currentTextColor];
	else {
		[self.textView setNeedsLayout:YES];
		[self.textView setNeedsDisplay:YES];
		[self.textView setNeedsDisplayInRect:self.textView.frame avoidAdditionalLayout:YES];
	}
	[doc.textView setInsertionPointColor:self.themeManager.caretColor];
			
	// Set global background
	//doc.backgroundView.fillColor = self.themeManager.outlineBackground;
	//doc.backgroundView.fillColor = NSColor.redColor;
	doc.backgroundView.layer.backgroundColor = self.themeManager.outlineBackground.effectiveColor.CGColor;
		
	[doc updateUIColors];

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
	
	//if (self.hideFountainMarkup) self.textView.layoutManager.allowsNonContiguousLayout = NO;
	//else self.textView.layoutManager.allowsNonContiguousLayout = YES;
	self.textView.layoutManager.allowsNonContiguousLayout = YES;
	
	[self.textView toggleHideFountainMarkup];
	[self updateLayout];
}

#pragma mark - Return to editor from any subview

- (void)returnToEditor {
	[self showTab:_editorTab];
	[self updateLayout];
	[self ensureCaret];
}

#pragma mark - Preview

- (void)setupPreview {
	[self.printWebView.configuration.userContentController addScriptMessageHandler:self name:@"selectSceneFromScript"];
	[self.printWebView.configuration.userContentController addScriptMessageHandler:self name:@"closePrintPreview"];
	
	[_printWebView loadHTMLString:@"<html><body style='background-color: #333; margin: 0;'><section style='margin: 0; padding: 0; width: 100%; height: 100vh; display: flex; justify-content: center; align-items: center; font-weight: 200; font-family: \"Helvetica Light\", Helvetica; font-size: .8em; color: #eee;'>Creating Print Preview...</section></body></html>" baseURL:nil];
	
	if (@available(macOS 11.0, *)) {
		self.printWebView.pageZoom = 1.2;
	}
	
	_preview = [[BeatPreview alloc] initWithDocument:self];
}

- (void)invalidatePreview {
	// Mark the current preview as invalid
	_previewUpdated = NO;
	
	// If preview is visible, recreate it
	if (self.currentTab == _previewTab) {
		[self updatePreviewAndUI:YES];
	}
}

- (IBAction)preview:(id)sender
{
	/*
	 
	 We should put all of this into a separate class: Create a preview object that
	 handles previews and builds the preview on per-page basis, similar to live pagination.
	 Perhaps even connect preview + live pagination?
	 
	 This is a *VERY* hacky and convoluted system right now.
	 
	 */
	
    if (self.currentTab != _previewTab) {
		// Do a synchronous refresh of the preview if the preview is not available
		if (_htmlString.length < 1 || !_previewUpdated) [self updatePreviewAndUI:YES];
		else {
			// Create JS scroll function call and append it straight into the HTML
			Line *currentLine = [self.parser closestPrintableLineFor:self.currentLine];
			
			NSString *scrollTo = [NSString stringWithFormat:@"<script>scrollToIdentifier('%@');</script>", currentLine.uuid.UUIDString.lowercaseString];
			
			_htmlString = [_htmlString stringByReplacingOccurrencesOfString:@"<script name='scrolling'></script>" withString:scrollTo];
			[self.printWebView loadHTMLString:_htmlString baseURL:nil]; // Load HTML
			
			// Revert changes to the code (so we can replace the placeholder again,
			// if needed, without recreating the whole HTML)
			_htmlString = [_htmlString stringByReplacingOccurrencesOfString:scrollTo withString:@"<script name='scrolling'></script>"];
			
			// Evaluate JS in window to be sure it shows the correct scene
			//[_printWebView evaluateJavaScript:[NSString stringWithFormat:@"scrollToScene(%@);", currentScene.sceneNumber] completionHandler:nil];
			[_printWebView evaluateJavaScript:[NSString stringWithFormat:@"scrollToIdentifier(%@);", currentLine.uuid.UUIDString.lowercaseString] completionHandler:nil];
		}
	
		[self showTab:_previewTab];
		_printPreview = YES;
    } else {
		_printPreview = NO;
		[self returnToEditor];
    }
}

- (NSString*)previewHTML {
	return _htmlString;
}

- (void)updatePreview  {
	[self updatePreviewAndUI:NO];
}
- (void)updatePreviewAndUI:(bool)updateUI {
	// WORK IN PROGRESS // WIP WIP WIP
	// Update preview in background
	
	_attrTextCache = [self getAttributedText];
	
	[_previewTimer invalidate];
	self.previewUpdated = NO;
	self.previewCanceled = YES;
	
	// Wait 1 second after writing has ended to build preview
	// If there is no preview present, do it immediately
	CGFloat previewWait = 1.5;
	if (_htmlString.length < 1 || updateUI) previewWait = 0;
	
	_previewTimer = [NSTimer scheduledTimerWithTimeInterval:previewWait repeats:NO block:^(NSTimer * _Nonnull timer) {
		self.previewCanceled = NO;
		
		self.outline = [self getOutlineItems];
		OutlineScene *currentScene = self.currentScene;
		
		NSString *rawText = self.text;
		
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
			__block NSString *html = [self.preview createPreviewFor:rawText type:BeatPrintPreview];
			self.htmlString = html;
			
			self.previewUpdated = YES;
			
			if (updateUI || self.printPreview) {
				dispatch_async(dispatch_get_main_queue(), ^(void){
					//[[self.webView mainFrame] loadHTMLString:html baseURL:nil];
					NSString *scrollTo = [NSString stringWithFormat:@"<script>scrollToScene(%@);</script>", currentScene.sceneNumber];
					html = [html stringByReplacingOccurrencesOfString:@"<script name='scrolling'></script>" withString:scrollTo];
					[self.printWebView loadHTMLString:html baseURL:nil];
				});
			}
		});
	}];
}

- (void)deallocPreview {
	// WIP: Move this into preview class
	[self.printWebView.configuration.userContentController removeScriptMessageHandlerForName:@"selectSceneFromScript"];
	[self.printWebView.configuration.userContentController removeScriptMessageHandlerForName:@"closePrintPreview"];
	self.printWebView.navigationDelegate = nil;
	self.printWebView = nil;
}
- (void)cancelOperation:(id) sender
{
	// ESCAPE KEY pressed
	if (_printPreview) [self preview:nil];
	if (_cardsVisible) [self toggleCards:nil];
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
		[self.autocompletion collectCharacterNames]; // Get characters for filtering through autocomplete (this is silly, I know)
		
		self.outlineView.enclosingScrollView.hasVerticalScroller = YES;
		
		if (![self isFullscreen]) {
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
		
		if (![self isFullscreen]) {
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

- (void)setupOutlineView {
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(searchOutline) name:NSControlTextDidChangeNotification object:self.outlineSearchField];
}

- (NSMutableArray *)getOutlineItems {
	// Make a copy of the outline to avoid threading issues
	NSMutableArray * outlineItems = self.parser.outline.mutableCopy;
	return outlineItems;
}

- (NSMutableArray*)filteredOutline {
	return self.outlineView.filteredOutline;
}

- (void)searchOutline {
	// This should probably be moved to BeatOutlineView, too.
	// Don't search if it's only spaces
	if (_outlineSearchField.stringValue.containsOnlyWhitespace ||
		_outlineSearchField.stringValue.length < 1) {
        [self.outlineView.filters byText:@""];
	}
	
    [self.outlineView.filters byText:_outlineSearchField.stringValue];
    [self.outlineView reloadOutline];
	
	// Mask scenes that were left out
	[self maskScenes];
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
- (void) menuDidClose:(NSMenu *)menu {
	// Reset timeline selection, to be on the safe side
	_timeline.clickedItem = nil;
}
- (void)menuNeedsUpdate:(NSMenu *)menu {
	id item = nil;
	
	if (self.outlineView.clickedRow >= 0) {
		item = [self.outlineView itemAtRow:[self.outlineView clickedRow]];
	} else if (_timeline.clickedItem != nil) {
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
			
			[picker.colorList setColor:NSColor.blackColor forKey:@"none"]; // THE HOUSE IS BLACK.
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

- (void)setColor:(NSString *)color forScene:(OutlineScene *) scene {
	if (!scene) return;
	
	color = color.uppercaseString;
		
	if (![scene.color isEqualToString:@""] && scene.color != nil &&
		scene.line.colorRange.length > 0 && scene.line.colorRange.location != NSNotFound) {
		// Scene already has a color (a very robust check, just in case)

		// If color is set to none, we'll remove the previous string.
		// If the color is changed, let's replace the string.
		if ([color.lowercaseString isEqualToString:@"none"]) {
			_outlineEdit = YES;

			NSRange localRange = scene.line.colorRange;
			NSRange colorRange = [self globalRangeFromLocalRange:&localRange inLineAtPosition:scene.line.position];
			[self removeRange:colorRange];
			
			_outlineEdit = NO;
			
		} else {
			NSRange localRange = scene.line.colorRange;
			NSRange colorRange = [self globalRangeFromLocalRange:&localRange inLineAtPosition:scene.line.position];
			NSString * newColor = [NSString stringWithFormat:@"[[COLOR %@]]", color];
						
			_outlineEdit = YES;
			[self replaceRange:colorRange withString:newColor];
			_outlineEdit = NO;
		}
	} else {
		// No color yet
		if ([color.lowercaseString isEqualToString:@"none"]) return; // Do nothing if set to none
		
		NSString * colorString = [NSString stringWithFormat:@"[[COLOR %@]]", color];
		NSString *heading = scene.line.string;
		
		// Add space before color if needed
		if (heading.length > 1) {
			if ([heading characterAtIndex:heading.length - 1] != ' ') colorString = [NSString stringWithFormat:@" %@", colorString];
		}
			
		NSUInteger position = scene.line.position + scene.line.string.length;
		
		_outlineEdit = YES;
		[self addString:colorString atIndex:position];
		_outlineEdit = NO;
	}

	return;
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

- (NSMutableArray *)scenes {
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
	
	[self.textView refreshLayoutElements];
	[self updateChangeCount:NSChangeDone];
	
	[_documentWindow endSheet:_sceneNumberingPanel];
}

- (NSInteger)sceneNumberingStartsFrom {
	return [self.documentSettings getInt:DocSettingSceneNumberStart];
}

- (void)resetSceneNumberLabels {
	if (_sceneNumberLabelUpdateOff || !_showSceneNumberLabels) return;
	[self.textView resetSceneNumberLabels];
}

- (IBAction)toggleSceneLabels: (id) sender {
	self.showSceneNumberLabels = !self.showSceneNumberLabels;
	[BeatUserDefaults.sharedDefaults saveSettingsFrom:self];
	
	if (self.showSceneNumberLabels) [self ensureLayout];
	else [self.textView deleteSceneNumberLabels];
	
	// Update the print preview accordingly
	self.previewUpdated = NO;
	
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
	
	for (Line* line in self.parser.lines) {
		if (line.marker.length == 0 && line.color.length == 0) continue;

		NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:line.textRange actualCharacterRange:nil];
		CGFloat yPosition = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer].origin.y;
		CGFloat relativeY = yPosition / [self.textView.layoutManager usedRectForTextContainer:_textView.textContainer].size.height;
		
		if (line.isOutlineElement) [markers addObject:@{ @"color": line.color, @"y": @(relativeY), @"scene": @(true) }];
		else [markers addObject:@{ @"color": line.marker, @"y": @(relativeY) }];
	}
	
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
		scrollPosition.y = scrollPosition.y * _magnification;
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
	[_touchbarTimeline setData:[self getOutlineItems]];
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

- (void)setupAnalysis {
	// Move this to the analysis/statistics class
	NSMutableDictionary *genders = [(NSDictionary*)[self.documentSettings get:@"CharacterGenders"] mutableCopy];
	
	if (!genders) _characterGenders = [NSMutableDictionary dictionary];
	else {
		_characterGenders = [NSMutableDictionary dictionaryWithDictionary:genders];
		for (NSString *name in _characterGenders.allKeys) {
			// Backwards compatibility
			if ([_characterGenders[name] isEqualToString:@"male"]) _characterGenders[name] = @"man";
			else if ([_characterGenders[name] isEqualToString:@"female"]) _characterGenders[name] = @"woman";
		}
	}
}

#pragma mark - Advanced Filtering

/*
 
 Fuck all of this. The filtering should be rewritten and rethought.
 
 */

- (void)maskScenes {
	// If there is no filtered outline, just reset everything
	[self.parser createOutline];
	if (!_outlineView.filteredOutline.count) {
		[self.textView.masks removeAllObjects];
		[self ensureLayout];
		return;
	}
	
	// Mask scenes that didn't match our filter
	NSMutableArray* masks = [NSMutableArray array];
	[self.textView.masks removeAllObjects];

	for (OutlineScene* scene in _outline) {
		// Ignore this scene if it's contained in filtered scenes
		if ([self.filteredOutline containsObject:scene] || scene.type == section || scene.type == synopse) {
			continue;
		}
		NSRange sceneRange = NSMakeRange([scene position], scene.length);

		// Add scene ranges to TextView's masks
		NSValue* rangeValue = [NSValue valueWithRange:sceneRange];
		[masks addObject:rangeValue];
	}
		
	self.textView.masks = masks;
	[self ensureLayout];

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
- (void)paginateAt:(NSRange)range sync:(bool)sync {
	if (!self.showPageNumbers) return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		// Null the timer so we don't have too many of these operations queued
		if (self.paginationTimer) {
			[self.paginationTimer invalidate];
			self.paginationTimer = nil;
		}
		
		NSInteger wait = 1.0;
		if (sync) wait = 0;

		self.paginationTimer = [NSTimer scheduledTimerWithTimeInterval:wait repeats:NO block:^(NSTimer * _Nonnull timer) {
			// Make a copy of the array for thread-safety
			NSArray *lines = [NSArray arrayWithArray:self.parser.preprocessForPrinting];
			
			// Dispatch to a background thread
			dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0 ), ^(void){
				[self.paginator livePaginationFor:lines changeAt:range.location];
				
				NSArray *pageBreaks = self.paginator.pageBreaks;
				
				// Don't do nothing if the page break array is nil
				// This SHOULD mean that pagination was canceled
				if (pageBreaks == nil) return;
				
				// Update text view page breaks in main queue
				dispatch_async(dispatch_get_main_queue(), ^(void){
					[self.textView updatePageBreaks:pageBreaks];
				});
			});
		}];
	});
}

- (void)setPrintInfo:(NSPrintInfo *)printInfo {
	[super setPrintInfo:printInfo];
	
	BeatPaperSize size;
	
	if (printInfo.paperSize.width > 600) size = BeatUSLetter;
	else size = BeatA4;
	
	//[self.documentSettings setInt:DocSettingPageSize as:size];
	
	// I have no idea what's with these values, but here they are.
	// documentWidth determines how the insets are set, while linePadding makes some space for revision markers.
	// Everything is terrible. BeatTextView inset scheme should be reworked.
	if (size == BeatA4) self.documentWidth = DOCUMENT_WIDTH_A4 + BeatTextView.linePadding * (2 - .5);
	else self.documentWidth = DOCUMENT_WIDTH_US + BeatTextView.linePadding * (2 - .5);
	
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
	self.printInfo = [BeatPaperSizing setSize:pageSize printInfo:self.printInfo];
	
	[self.documentSettings setInt:DocSettingPageSize as:pageSize];
	[self updateLayout];
	[self paginate];
	_previewUpdated = NO;
}

- (NSInteger)numberOfPages {
	// If pagination is not on, create temporary paginator
	if (!self.showPageNumbers) {
		BeatPaginator *paginator = [[BeatPaginator alloc] initForLivePagination:self withElements:self.parser.preprocessForPrinting];
		return paginator.numberOfPages;
	} else {
		return self.paginator.numberOfPages;
	}
}
- (NSInteger)getPageNumber:(NSInteger)location {
	NSInteger page = 0;
	
	// If we don't have pagination turned on, create temporary paginator
	if (!self.showPageNumbers) {
		BeatPaginator *paginator = [[BeatPaginator alloc] initForLivePagination:self withElements:self.parser.preprocessForPrinting];
		[paginator paginate];
		return [paginator pageNumberFor:location];
	} else {
		return [self.paginator pageNumberFor:location];
	}
	return page;
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
	OutlineScene *scene = [self getNextScene];
	if (scene) [self scrollToScene:scene];
}
- (IBAction)previousScene:(id)sender {
	OutlineScene *scene = [self getPreviousScene];
	if (scene) [self scrollToScene:scene];
}

#pragma mark - Autosave

/*

 Beat has two kinds of autosave: recovery & saving in place.
 
 Autosave provided by NSDocument is used to saving drafts and
 recovery files, while the custom autosave (enabled by the
 user and triggered once a minute) just saves the file.
 
 Recovery happens in ApplicationDelegate when launching the app
 
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
		bool backup = [BeatBackup backupWithDocumentURL:url name:[self fileNameString]];
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
	// Don't autosave if it's an untitled document
	if (self.fileURL == nil) return;
	
	if (_autosave && self.documentEdited) {
		[self saveDocument:nil];
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

	NSURL *url = [(BeatAppDelegate*)NSApp.delegate appDataPath:@"Autosave"];
	url = [url URLByAppendingPathComponent:previousName];
	url = [url URLByAppendingPathExtension:@"fountain"];
		 
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:url.path]) {
		[fileManager removeItemAtURL:url error:nil];
	}
}

-(void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
	[super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

-(void)windowWillBeginSheet:(NSNotification *)notification {
	[self hideAllPluginWindows];
	[self.documentWindow makeKeyAndOrderFront:self];
}

-(void)windowDidEndSheet:(NSNotification *)notification {
	[self showPluginWindowsForCurrentDocument];
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

#pragma mark - Plugin support for documents

/*
 
 Some explanation:
 
 Plugins are run inside document scope, unless they are standalone tools.
 If the plugins are "resident" (can be left running in the background),
 they are registered and deregistered when launching and shutting down.
 
 Some changes made to the document are sent to all of the running plugins,
 if they have any change listeners.
 
 */

- (void)setupPlugins {
	_pluginManager = BeatPluginManager.sharedManager;
}
- (IBAction)runPlugin:(id)sender {
	NSMenuItem *menuItem = (NSMenuItem*)sender;
	NSString *pluginName = menuItem.title;
	
	os_log(OS_LOG_DEFAULT, "# Run plugin: %@", pluginName);
	
	if (_runningPlugins[pluginName]) {
		// Disable a running plugin and return
		[(BeatPlugin*)_runningPlugins[pluginName] forceEnd];
		[_runningPlugins removeObjectForKey:pluginName];
		return;
	}
	
	BeatPlugin *parser = [[BeatPlugin alloc] init];
	parser.delegate = self;
	
	BeatPluginData *plugin = [_pluginManager pluginWithName:pluginName];
	[parser loadPlugin:plugin];
		
	parser = nil;
}

- (void)registerPlugin:(id)plugin {
	BeatPlugin *parser = (BeatPlugin*)plugin;
	if (!_runningPlugins) _runningPlugins = [NSMutableDictionary dictionary];
	
	_runningPlugins[parser.pluginName] = parser;
}
- (void)deregisterPlugin:(id)plugin {
	BeatPlugin *parser = (BeatPlugin*)plugin;
	[_runningPlugins removeObjectForKey:parser.pluginName];
	parser = nil;
}

- (void)updatePlugins:(NSRange)range {
	// Run resident plugins
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatPlugin *plugin = _runningPlugins[pluginName];
		[plugin update:range];
	}
}

- (void)updatePluginsWithSelection:(NSRange)range {
	// Run resident plugins which are listening for selection changes
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatPlugin *plugin = _runningPlugins[pluginName];
		[plugin updateSelection:range];
	}
}

- (void)updatePluginsWithSceneIndex:(NSInteger)index {
	// Run resident plugins which are listening for selection changes
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatPlugin *plugin = _runningPlugins[pluginName];
		[plugin updateSceneIndex:index];
	}
}

- (void)updatePluginsWithOutline:(NSArray*)outline {
	// Run resident plugins which are listening for selection changes
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatPlugin *plugin = _runningPlugins[pluginName];
		[plugin updateOutline:outline];
	}
}

- (void)notifyPluginsThatWindowBecameMain {
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatPlugin *plugin = _runningPlugins[pluginName];
		[plugin documentDidBecomeMain];
	}
}

- (void)addWidget:(id)widget {
	[_widgetView addWidget:widget];
	[self showWidgets:nil];
}

// For those who REALLY, REALLY know what the fuck they are doing
- (void)setPropertyValue:(NSString*)key value:(id)value {
	[self setValue:value forKey:key];
}
- (id)getPropertyValue:(NSString*)key {
	return [self valueForKey:key];
}

#pragma mark - Color Customization

- (IBAction)customizeColors:(id)sender {
	[_themeManager showEditor];
}

#pragma mark - Review Mode

- (void)setupReview {
	_review = [BeatReview.alloc initWithEditorDelegate:self];
	[_review setupReviewsWithRanges:[_documentSettings get:DocSettingReviews]];
}

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
	else [self lock];
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
		
		[self.lockButton hide];
	}
}
- (void)showLockStatus {
	[self.lockButton displayLabel];
}

-(bool)contentLocked {
	return [self.documentSettings getBool:@"Locked"];
}


#pragma mark - For avoiding throttling

- (bool)hasChanged {
	if ([self.textView.string isEqualToString:bufferedText]) return NO;
	else {
		bufferedText = [NSString stringWithString:self.textView.string];
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
