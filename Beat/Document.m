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

#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>
#import "Document.h"
#import "ScrollView.h"
#import "FDXInterface.h"
#import "OutlineExtractor.h"
#import "PrintView.h"
#import "ColorView.h"
#import "ThemeManager.h"
#import "OutlineScene.h"
#import "DynamicColor.h"
#import "ApplicationDelegate.h"
#import "NSString+Whitespace.h"
#import "FountainAnalysis.h"
#import "BeatOutlineView.h"
#import "ColorCheckbox.h"
#import "SceneFiltering.h"
#import "FDXImport.h"
#import "FountainPaginator.h"
#import "MasterView.h"
#import "WebPrinter.h"
#import "SceneCards.h"
#import "RegExCategories.h"
#import "TouchTimelineView.h"
#import "TouchTimelinePopover.h"
#import "MarginView.h"
#import "BeatPreview.h"
#import "BeatColors.h"
#import "BeatTimer.h"
#import "BeatTimeline.h"
#import "TKSplitHandle.h"
#import "BeatPrint.h"
#import "BeatDocumentSettings.h"
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
#import "BeatRevisionTracking.h"
#import "BeatRevisionItem.h"
#import "ITSwitch.h"
#import "BeatTitlePageEditor.h"

#import "BeatScriptParser.h"
#import "BeatPluginManager.h"

@interface Document ()

// Window
@property (weak) NSWindow *thisWindow;
@property (weak) IBOutlet TKSplitHandle *splitHandle;
@property (nonatomic) NSArray *itemsToValidate; // Menu items

// Autosave
@property (nonatomic) bool autosave;
@property (weak) NSTimer *autosaveTimer;

// Plugin support
@property (assign) BeatPluginManager *pluginManager;

// Quick Settings
@property (nonatomic) NSPopover *quickSettingsPopover;
@property (nonatomic, weak) IBOutlet NSView *quickSettingsView;
@property (nonatomic, weak) IBOutlet ITSwitch *sceneNumbersSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *pageNumbersSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *revisionModeSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *taggingModeSwitch;
@property (nonatomic, weak) IBOutlet ITSwitch *darkModeSwitch;
@property (nonatomic, weak) IBOutlet NSPopUpButton *revisionColorPopup;

// Editor buttons
@property (nonatomic, weak) IBOutlet NSButton *outlineButton;
@property (nonatomic, weak) IBOutlet NSButton *previewButton;
@property (nonatomic, weak) IBOutlet NSButton *timelineButton;
@property (nonatomic, weak) IBOutlet NSButton *quickSettingsButton;
@property (nonatomic, weak) IBOutlet NSButton *cardsButton;

// Text view
@property (weak, nonatomic) IBOutlet BeatTextView *textView;
@property (weak, nonatomic) IBOutlet ScrollView *textScrollView;
@property (weak, nonatomic) IBOutlet MarginView *marginView;
@property (weak, nonatomic) IBOutlet NSClipView *textClipView;
@property (nonatomic) NSLayoutManager *layoutManager;
@property (nonatomic) bool documentIsLoading;
@property (nonatomic) FountainPaginator *paginator;
@property (nonatomic) NSTimer *paginationTimer;
@property (nonatomic) NSMutableArray *sectionMarkers;
@property (nonatomic) bool newScene;
@property (nonatomic) bool moving;
@property (nonatomic) bool sceneHeadingEdited;
@property (nonatomic) bool sceneHeadingUndoString;
@property (nonatomic) bool showPageNumbers;
@property (nonatomic) bool autoLineBreaks;
@property (nonatomic) bool characterInput;
@property (nonatomic) Line* characterInputForLine;
@property (nonatomic) NSDictionary *postEditAction;
@property (nonatomic) bool typewriterMode;
@property (nonatomic) CGFloat textInsetY;
@property (nonatomic) NSMutableArray *recentCharacters;
@property (nonatomic) NSRange lastChangedRange;

// Outline view
@property (weak) IBOutlet BeatOutlineView *outlineView;
@property (weak) IBOutlet NSScrollView *outlineScrollView;
@property (weak) NSArray *draggedNodes;
@property (weak) OutlineScene *draggedScene; // Drag & drop for outline view
@property (nonatomic) NSMutableArray *outline;
@property (weak) IBOutlet NSSearchField *outlineSearchField;
@property (weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property BOOL outlineViewVisible;
@property (nonatomic) NSMutableArray *outlineClosedSections;
@property (weak) IBOutlet NSMenu *colorMenu;

// Outline view filtering
@property (weak) IBOutlet NSBox *filterView;
@property (weak) IBOutlet NSLayoutConstraint *filterViewHeight;
@property (weak) IBOutlet NSPopUpButton *characterBox;

// Views
@property (weak) IBOutlet NSTabView *tabView; // Master tab view (holds edit/print/card views)
@property (weak) IBOutlet BeatPrint *printing; // Master tab view (holds edit/print/card views)
@property (weak) IBOutlet ColorView *backgroundView; // Master background
@property (weak) IBOutlet ColorView *outlineBackgroundView; // Background for outline
@property (weak) IBOutlet MasterView *masterView; // View which contains every other view

// Print preview
@property (weak) IBOutlet WKWebView *printWebView; // Print preview
@property (nonatomic) NSString *htmlString;
@property (nonatomic) bool previewUpdated;
@property (nonatomic) bool previewCanceled;
@property (nonatomic) NSTimer *previewTimer;
@property (nonatomic) BeatPreview *preview;

// Analysis
@property (nonatomic) BeatAnalysisPanel *analysisWindow;

// Card view
@property (nonatomic) SceneCards *sceneCards;
@property (weak) IBOutlet WKWebView *cardView;
@property (nonatomic) bool cardsVisible;

// Timeline view
@property (weak) IBOutlet NSLayoutConstraint *timelineViewHeight;
@property (nonatomic) NSInteger timelineClickedScene;
@property (nonatomic) NSInteger timelineSelection;
@property (nonatomic) bool timelineVisible;
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
@property (strong, nonatomic) PrintView *printView; //To keep the asynchronously working print data generator in memory

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

// Autocompletion
@property (nonatomic) NSString *cachedText;
@property (nonatomic) bool isAutoCompleting;
@property (nonatomic) NSMutableArray *characterNames;
@property (nonatomic) NSMutableArray *sceneHeadings;
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
@property (nonatomic) BeatTagging *tagging;
@property (weak) IBOutlet NSTextView *tagTextView;
@property (weak) IBOutlet ColorView *sideView;
@property (weak) IBOutlet NSLayoutConstraint *sideViewCostraint;

@property (nonatomic) NSDate *executionTime;
@property (nonatomic) NSTimeInterval executionTimeCache;
@property (nonatomic) Line* lineCache;

// Revision Tracking
@property (nonatomic) BeatRevisionTracking *revision;
@property (nonatomic) NSString *revisionColor;

// Debug flags
@property (nonatomic) bool debug;
@end

#define APP_NAME @"Beat"

#define MIN_WINDOW_HEIGHT 400
#define MIN_OUTLINE_WIDTH 270

#define AUTOSAVE_INTERVAL 10.0
#define AUTOSAVE_INPLACE_INTERVAL 60.0

#define SECTION_FONT_SIZE 20.0 // base value for section sizes
#define FONT_SIZE 17.92 // 19.5 for Inconsolata
#define LINE_HEIGHT 1.1 // 1.15 for Inconsolata

#define DOCUMENT_WIDTH 630
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

#define CHARACTER_INDENT_P 0.36
#define PARENTHETICAL_INDENT_P 0.27
#define DIALOGUE_INDENT_P 0.164
#define DIALOGUE_RIGHT_P 0.75

@implementation Document

#pragma mark - Document Initialization

- (instancetype)init {
    self = [super init];
    return self;
}
- (void) close {
	if (!self.hasUnautosavedChanges) {
		[self.thisWindow saveFrameUsingName:[self fileNameString]];
	}
	
	// Save the gender list & caret position if the document is saved
	if (!self.documentEdited) {
		// This should be moved into document settings.
		if (_characterGenders.count > 0) [self saveGenders];
		[self saveCaret];
	}
	
	// Avoid retain cycles with WKWebView
	[self deallocPreview];
	[self deallocCards];
	
	// Terminate running plugins
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatScriptParser* plugin = _runningPlugins[pluginName];
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
	
	// Without this, BeatTextView is retained. I haven't found the reason for now.
	self.preview = nil;
	self.textView = nil;
	
	[self.textScrollView.mouseMoveTimer invalidate];
	[self.textScrollView.timerMouseMoveTimer invalidate];
	self.textScrollView.mouseMoveTimer = nil;
	self.textScrollView.timerMouseMoveTimer = nil;
	
	// Null other stuff, just in case
	self.parser = nil;
	self.outlineView = nil;
	self.thisWindow = nil;
	self.contentBuffer = nil;
	self.printView = nil;
	self.analysisWindow = nil;
	self.currentScene = nil;
	self.currentLine = nil;
	self.sceneCards = nil;
	self.paginator = nil;
	self.outlineView.filters = nil;
	self.sceneCards = nil;
	self.outline = nil;
	self.outlineView.filteredOutline = nil;
	self.tagging = nil;
	self.itemsToValidate = nil;
	self.documentSettings = nil;
	
	// Terminate autosave timer
	if (_autosaveTimer) [self.autosaveTimer invalidate];
	self.autosaveTimer = nil;
	
	[NSNotificationCenter.defaultCenter removeObserver:self];
		
	// ApplicationDelegate will show welcome screen when no documents are open
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document close" object:nil];
	[super close];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	[super windowControllerDidLoadNib:aController];
	_thisWindow = aController.window;
	
	// Hide the welcome screen
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document open" object:nil];
		
	// Initialize document settings if needed
	if (!self.documentSettings) self.documentSettings = [[BeatDocumentSettings alloc] init];

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
	[self loadSerifFonts];
	
	// Setup views
	[self setupTextView];
	[self setupOutlineView];
	[self setupCards];
	[self setupPreview];
	[self setupTimeline];
	[self setupTouchTimeline];
	[self setupAnalysis];
	[self setupColorPicker];
		
	// Setup layout here first
	[self setupLayoutWithPagination:NO];
		
	// Setup plugin management
	[self setupPlugins];
	
	// Initialize arrays
	self.characterNames = [[NSMutableArray alloc] init];
	self.sceneHeadings = [[NSMutableArray alloc] init];
		
	// Pagination etc.
	self.paginator = [[FountainPaginator alloc] initForLivePagination:self];
	self.printing.document = self;
	
	//Put any previously loaded data into the text view
	self.documentIsLoading = YES;
	if (self.contentBuffer) {
		[self setText:self.contentBuffer];
	} else {
		[self setText:@""];
	}
		
	// Initialize parser
	self.parser = [[ContinuousFountainParser alloc] initWithString:[self getText]];
	self.parser.delegate = self;
	
	// Initialize edit tracking
	[self setupRevision];
	
	[self applyInitialFormatting];
	
	// Load tags
	[self setupTagging];
	
	// Setup page size
	// (We'll disable undo registration here, so the doc won't appear as edited on open)
	[self.undoManager disableUndoRegistration];
	self.printInfo = [BeatPaperSizing setSize:[_documentSettings getInt:@"Page Size"] printInfo:self.printInfo];
	[self.undoManager enableUndoRegistration];
	[self updateChangeCount:NSChangeCleared];

	// Document loading has ended
	self.documentIsLoading = NO;
	
	// Ensure layout
	[self setupLayoutWithPagination:YES];
	[self initAutosave];
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self updateLayout];
	});
}
-(void)awakeFromNib {
	// Set up recovery file saving
	[[NSDocumentController sharedDocumentController] setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
}

- (void)readUserSettings {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:MATCH_PARENTHESES_KEY]) {
		self.matchParentheses = YES;
	} else {
		self.matchParentheses = [[NSUserDefaults standardUserDefaults] boolForKey:MATCH_PARENTHESES_KEY];
	}

	if (![[NSUserDefaults standardUserDefaults] objectForKey:AUTOMATIC_LINEBREAKS_KEY]) {
		self.autoLineBreaks = YES;
	} else {
		self.autoLineBreaks = [[NSUserDefaults standardUserDefaults] boolForKey:AUTOMATIC_LINEBREAKS_KEY];
	}
	
	if (![[NSUserDefaults standardUserDefaults] objectForKey:TYPERWITER_KEY]) {
		self.typewriterMode = NO;
	} else {
		self.typewriterMode = [[NSUserDefaults standardUserDefaults] boolForKey:TYPERWITER_KEY];
	}
	
	if (![[NSUserDefaults standardUserDefaults] objectForKey:SHOW_PAGENUMBERS_KEY]) {
		self.showPageNumbers = YES;
	} else {
		self.showPageNumbers = [[NSUserDefaults standardUserDefaults] boolForKey:SHOW_PAGENUMBERS_KEY];
	}

	if (![[NSUserDefaults standardUserDefaults] objectForKey:PRINT_SCENE_NUMBERS_KEY]) {
		self.printSceneNumbers = YES;
	} else {
		self.printSceneNumbers = [[NSUserDefaults standardUserDefaults] boolForKey:PRINT_SCENE_NUMBERS_KEY];
	}

	if (![[NSUserDefaults standardUserDefaults] objectForKey:SHOW_SCENE_LABELS_KEY]) {
		self.showSceneNumberLabels = YES;
		self.printSceneNumbers = YES;
	} else {
		self.showSceneNumberLabels = [[NSUserDefaults standardUserDefaults] boolForKey:SHOW_SCENE_LABELS_KEY];
		self.printSceneNumbers = self.showSceneNumberLabels;
	}
}

- (void)setupWindow {
	[_tagTextView.enclosingScrollView setHasHorizontalScroller:NO];
	[_tagTextView.enclosingScrollView setHasVerticalScroller:NO];
	[_sideViewCostraint setConstant:0];
	
	// The document width constant is ca. A4 width compared to the font size.
	// It's used here and there for proportional measurement.
	_documentWidth = DOCUMENT_WIDTH;
	_textView.documentWidth = _documentWidth;
	
	// Reset zoom
	[self setZoom];

	// Split view
	_splitHandle.bottomOrLeftMinSize = MIN_OUTLINE_WIDTH;
	_splitHandle.delegate = self;
	[_splitHandle collapseBottomOrLeftView];
	
	// Recall window position
	if (![self.fileNameString isEqualToString:@"Untitled"]) _thisWindow.frameAutosaveName = self.fileNameString;
	
	CGFloat x = _thisWindow.frame.origin.x;
	CGFloat y = _thisWindow.frame.origin.y;
	CGFloat width = [_documentSettings getFloat:DocSettingWindowWidth];
	CGFloat height = [_documentSettings getFloat:DocSettingWindowHeight];
	
	// Default size for new windows or those going over screen bounds
	if (width < _documentWidth || x > _thisWindow.screen.frame.size.width) {
		width = _documentWidth * 1.6;
		x = (_thisWindow.screen.frame.size.width - width) / 2;
	}
	if (height < MIN_WINDOW_HEIGHT || y + height > _thisWindow.screen.frame.size.height) {
		height = _thisWindow.screen.frame.size.height * .85;
		
		if (height < MIN_WINDOW_HEIGHT) height = MIN_WINDOW_HEIGHT;
		if (height > _documentWidth * 2.5) height = _documentWidth * 1.75;
		
		y = (_thisWindow.screen.frame.size.height - height) / 2;
	}
	
	// Set the width programmatically since we've got the outline visible in IB to work on it, but don't want it visible on launch
	[_thisWindow setMinSize:CGSizeMake(_thisWindow.minSize.width, MIN_WINDOW_HEIGHT)];
	NSRect newFrame = NSMakeRect(x,
								 y,
								 width,
								 height);
	[_thisWindow setFrame:newFrame display:YES];
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
	NSString *oldName = [NSString stringWithString:[self fileNameString]];
	[super setFileURL:fileURL];
	NSString *newName = [NSString stringWithString:[self fileNameString]];
						 
    // The file was renamed
	 if (![newName isEqualToString:oldName] && [oldName length] > 0) {
		 // Set gender data --- though I guess this is unnecessary?
		 /*
		 NSDictionary *genderData = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"CharacterGender"] objectForKey:oldName];
		 [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"CharacterGender"] setValue:genderData forKey:newName];
		 NSLog(@"old gender data %@", genderData);
		  */
	 }
}
- (NSString *)displayName {
	if (![self fileURL]) return @"Untitled";
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

- (void)setTab:(NSUInteger)index
{
	[self.tabView selectTabViewItem:[self.tabView tabViewItemAtIndex:index]];
}

- (bool)isFullscreen
{
	return (([_thisWindow styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

- (void)windowDidResize:(NSNotification *)notification
{
	[_documentSettings setFloat:DocSettingWindowWidth as:_thisWindow.frame.size.width];
	[_documentSettings setFloat:DocSettingWindowHeight as:_thisWindow.frame.size.height];
	[self updateLayout];
}
- (void)updateLayout
{
	[self setMinimumWindowSize];
	
	CGFloat width = (self.textView.frame.size.width / 2 - _documentWidth * _magnification / 2) / _magnification;
	
	// Set global variable for top inset, if it's unset
	// For typewriter mode, we set the top & bottom bounds a bit differently
	// (this math must be wrong, now that I'm lookign at it, but won't fix it yet)
	if (self.typewriterMode) {
		_textInsetY = (self.textClipView.frame.size.height / 2 - self.fontSize / 2) * (1 + (1 - _magnification));
		self.textView.textInsetY = _textInsetY;
	} else {
		_textInsetY = TEXT_INSET_TOP;
		self.textView.textInsetY = TEXT_INSET_TOP;
	}
	
	if (width < 10000) { // Some arbitrary number to see that there is some sort of width set & view has loaded
		[_textView setInsets];

		// We have to inform the views of both the magnification and inset width
		// This would be safer if it was built as a delegate method
		self.textScrollView.insetWidth = self.textView.textContainerInset.width;
		self.marginView.insetWidth = self.textView.textContainerInset.width;

		self.textScrollView.magnificationLevel = _magnification;
		self.marginView.magnificationLevel = _magnification;
		
		[self.textScrollView setNeedsDisplay:YES];
		[self.marginView setNeedsDisplay:YES];
	} else {
		[_textView setInsets];
	}
	 
	[self ensureLayout];
	[self ensureCaret];
}


- (void) setMinimumWindowSize {
	// These are arbitratry values. Sorry, anyone reading this.
	if (!_outlineViewVisible) {
		[self.thisWindow setMinSize:NSMakeSize(_documentWidth * _magnification + 150, MIN_WINDOW_HEIGHT)];
	} else {
		[self.thisWindow setMinSize:NSMakeSize(_documentWidth * _magnification + 150 + _outlineView.frame.size.width, MIN_WINDOW_HEIGHT)];
	}
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
	[_revisionModeSwitch setChecked:self.trackChanges];
	[_darkModeSwitch setChecked:self.isDark];
	
	if (self.mode == TaggingMode) [_taggingModeSwitch setChecked:YES]; else [_taggingModeSwitch setChecked:NO];
	
	if (_revisionColor) {
		for (NSMenuItem* item in _revisionColorPopup.itemArray) {
			if ([item.title.lowercaseString isEqualToString:_revisionColor]) [_revisionColorPopup selectItem:item];
		}
	}
	
	if (self.mode == TaggingMode) {
		[_revisionColorPopup setEnabled:NO];
		[_revisionModeSwitch setEnabled:NO];
	} else {
		[_revisionColorPopup setEnabled:YES];
		[_revisionModeSwitch setEnabled:YES];
	}
}

- (IBAction)toggleQuickSetting:(id)sender {
	ITSwitch *button = sender;
	
	if (button == _sceneNumbersSwitch) [self toggleSceneLabels:nil];
	else if (button == _pageNumbersSwitch) [self togglePageNumbers:nil];
	else if (button == _revisionModeSwitch) [self toggleTrackChanges:nil];
	else if (button == _taggingModeSwitch) [self toggleTagging:nil];
	else if (button == _darkModeSwitch) [self toggleNightMode:nil];
	
	[self updateQuickSettings];
}


#pragma mark - Zooming

- (IBAction)zoomIn:(id)sender {
	[self zoom:YES];
}
- (IBAction)zoomOut:(id)sender {
	[self zoom:NO];
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
		if (_magnification < 1.2) _magnification += 0.04;
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
	if (self.showSceneNumberLabels) [self.textView updateSceneLabelsFrom:0];
	[self.textView setNeedsDisplay:YES];
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag
{
	self.textView.zoomLevel = newScaleFactor;
	
	CGFloat oldScaleFactor = _scaleFactor;
	if (_scaleFactor != newScaleFactor)
	{
		NSSize curDocFrameSize, newDocBoundsSize;
		NSView *clipView = [[self textView] superview];
		
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
	self.splitHandle.topOrRightMinSize = _documentWidth * _magnification;
}

- (void)scaleChanged:(CGFloat)oldScale newScale:(CGFloat)newScale
{
	// Thank you, Mark Munz @ stackoverflow
	CGFloat scaler = newScale / oldScale;
	[self.textView scaleUnitSquareToSize:NSMakeSize(scaler, scaler)];
	
	NSLayoutManager* lm = [self.textView layoutManager];
	NSTextContainer* tc = [self.textView textContainer];
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
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSData *dataRepresentation = [[self createDocumentFile] dataUsingEncoding:NSUTF8StringEncoding];
    return dataRepresentation;
}
- (NSString*)createDocumentFile {
	// This puts together string content & settings block. It is returned to dataOfType:
	
	// Save tagged ranges
	[self saveTags];
	
	// Save added/removed ranges
	[self saveRevisionRanges];
	
	return [NSString stringWithFormat:@"%@%@", self.getText, (self.documentSettings.getSettingsString) ? self.documentSettings.getSettingsString : @""];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	// Read settings
	if (!_documentSettings) {
		_documentSettings = [[BeatDocumentSettings alloc] init];
	}
	
	// Load text & remove settings block
	NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
	NSRange settingsRange = [_documentSettings readSettingsAndReturnRange:text];
	text = [text stringByReplacingCharactersInRange:settingsRange withString:@""];
    
	[self setText:text];
    return YES;
}

/*
 
 But if the while I think on thee,
 dear friend,
 All losses are restor'd,
 and sorrows end.
 
 */

# pragma mark - Text I/O

- (void)setupTextView {
	self.textView.editable = YES;
	
	self.textView.textContainer.widthTracksTextView = NO;
	self.textView.textContainer.heightTracksTextView = NO;
	
	// Set textView style
	self.textView.font = self.courier;
	self.textView.automaticDataDetectionEnabled = NO;
	self.textView.automaticQuoteSubstitutionEnabled = NO;
	self.textView.automaticDashSubstitutionEnabled = NO;

	// Create a default paragraph style for line height
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[self.textView setDefaultParagraphStyle:paragraphStyle];
	
	self.textInsetY = TEXT_INSET_TOP;
	self.textView.textInsetY = TEXT_INSET_TOP;
	[self.textView setInsets];
	
	self.textView.editorDelegate = self;
	self.textView.taggingDelegate = self;
	
	// Make the text view first responder
	[_thisWindow makeFirstResponder:self.textView];
}

- (NSString *)getText
{
    return self.textView.string;
}
- (NSAttributedString *)getAttributedText
{
	return self.textView.attributedString;
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

#pragma mark - Print & Export

- (NSString*)fileNameString
{
	NSString* fileName = [self lastComponentOfFileName];
	NSUInteger lastDotIndex = [fileName rangeOfString:@"." options:NSBackwardsSearch].location;
	if (lastDotIndex != NSNotFound) {
		fileName = [fileName substringToIndex:lastDotIndex];
	}
	return fileName;
}

- (IBAction)openPrintSettings:(id)sender {
	_attrTextCache = [self getAttributedText];
	[self.printing open:self];
}
- (IBAction)openPDFExport:(id)sender {
	_attrTextCache = [self getAttributedText];
	[self.printing openForPDF:self];
}

- (IBAction)exportFDX:(id)sender
{
    NSSavePanel *saveDialog = [NSSavePanel savePanel];
    [saveDialog setAllowedFileTypes:@[@"fdx"]];
    [saveDialog setNameFieldStringValue:[self fileNameString]];
    [saveDialog beginSheetModalForWindow:self.windowControllers[0].window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
			BeatFDXExport *fdxExport = [[BeatFDXExport alloc] initWithString:self.getText attributedString:self.textView.attributedString includeTags:YES includeRevisions:YES];
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
        if (result == NSFileHandlingPanelOKButton) {
            NSString* outlineString = [OutlineExtractor outlineFromParse:self.parser];
            [outlineString writeToURL:saveDialog.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }];
}


# pragma mark - Scene Data

- (OutlineScene*)getCurrentScene {
	NSInteger position = self.textView.selectedRange.location;
	return [self getCurrentSceneWithPosition:position];
}
- (OutlineScene*)getCurrentSceneWithPosition:(NSInteger)position {
	if (position >= self.getText.length) {
		return self.parser.outline.lastObject;
	}
	
	NSInteger lastPosition = -1;
	OutlineScene *lastScene;
	
	// Remember to create outline first
	for (OutlineScene *scene in self.outline) {
		if (NSLocationInRange(position, scene.range)) {
			_currentScene = scene;
			return scene;
		}
		else if (position >= lastPosition && position < scene.position && lastScene) {
			return lastScene;
		}
		
		lastPosition = scene.position + scene.length;
		lastScene = scene;
	}

	_currentScene = nil;
	return nil;
}

- (OutlineScene*)getPreviousScene {
	NSArray *outline = [self getOutlineItems];
	if (outline.count == 0) return nil;
	
	NSInteger position = self.selectedRange.location;
	
	Line * currentLine = [self getLineAt:position];
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
	
	NSInteger position = self.selectedRange.location;
	
	Line * currentLine = [self getLineAt:position];
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
	if (_cardsVisible) [self refreshCards:YES];
	
	// To avoid some graphical glitches
	[self ensureLayout];
}
- (IBAction)redoEdit:(id)sender {
	[self.undoManager redo];
	if (_cardsVisible) [self refreshCards:YES];
	
	// To avoid some graphical glitches
	[self ensureLayout];
}

- (void)saveCaret {
	[self saveDocumentSetting:@"Caret Position" value:[NSNumber numberWithInteger:self.textView.selectedRange.location]];
}
- (void)loadCaret {
	NSInteger position = [(NSNumber*)[self getDocumentSetting:@"Caret Position"] integerValue];
	if (position < self.textView.string.length && position >= 0) {
		[self.textView setSelectedRange:NSMakeRange(position, 0)];
		[self.textView scrollRangeToVisible:NSMakeRange(position, 0)];
	}
}

- (id)getDocumentSetting:(NSString*)settingName {
	if ([self.fileNameString isEqualToString:@"Untitled"]) return nil;
	NSDictionary *documentSettings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"Document Settings"];
	NSDictionary *settings = [documentSettings objectForKey:self.fileNameString];
	return [settings objectForKey:settingName];
}
- (void)saveDocumentSetting:(NSString*)settingName value:(id)object {
	if ([self.fileNameString isEqualToString:@"Untitled"]) return;
	
	NSMutableDictionary *documentSettings = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"Document Settings"]];

	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:[documentSettings objectForKey:[self fileNameString]]];
	if (settings && object != nil) {
		[settings setObject:object forKey:settingName];
		[documentSettings setObject:settings forKey:[self fileNameString]];
	}
	
	[[NSUserDefaults standardUserDefaults] setValue:documentSettings forKey:@"Document Settings"];
}


/*
 
 and in a darkened underpass
 I thought, oh god, my chance has come at last
 but then
 a strange fear gripped me
 and I just couldn't ask
 
 */

# pragma mark - Text events

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string
{
	// If range is over bounds (this can happen with certain undo operations for some reason), let's fix it
	if (range.length + range.location > self.textView.string.length) {
		NSLog(@"replacement over bounds: %lu / %lu", range.location + range.length, self.textView.string.length);
		NSInteger length = self.textView.string.length - range.location;
		range = NSMakeRange(range.location, length);
		NSLog(@"fixed to: %lu / %lu", range.location + range.length, self.textView.string.length);
	}
	
    if ([self textView:self.textView shouldChangeTextInRange:range replacementString:string]) {
        [self.textView replaceCharactersInRange:range withString:string];
        [self textDidChange:[NSNotification notificationWithName:@"" object:nil]];
    }
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	[self startMeasure];
	
	// Don't allow editing the script while tagging
	if (_mode != EditMode) return NO;
	
	if (replacementString.length == 1 && affectedCharRange.length == 0 && self.beatTimer.running) {
		if (![replacementString isEqualToString:@"\n"]) self.beatTimer.charactersTyped++;
	}
	
	// Check for character input trouble
	if (_characterInput) {
		_currentLine = [self getCurrentLine];
		
		// Stop character input if line has changed.
		if (_currentLine != _characterInputForLine) {
			// If the character cue was left empty, remove its type
			if (_characterInputForLine.string.length == 0) {
				_characterInputForLine.type = action;
				[self formatLineOfScreenplay:_characterInputForLine];
			}

			[self cancelCharacterInput];
		}
	}
	
	
	// Also, if it's an enter key and we are handling a CHARACTER, force dialogue if needed
	bool forceDialogue = NO;
	if ([replacementString isEqualToString:@"\n"] && affectedCharRange.length == 0 && _currentLine.type == character) {
		Line *nextLine = [_parser nextLine:_currentLine];
		if (nextLine.type == dialogue && nextLine.string.length) {
			//[self setSelectedRange:(NSRange){ affectedCharRange.location + 1, 0 }];
			forceDialogue = YES;
			//return NO;
		}
	}

	
	// Backspace / deletion handling for some special case scenarios
	// Implementing some undoing weirdness, which works, kind-of.
	
	if (!self.documentIsLoading && replacementString.length < 1 && affectedCharRange.length > 0 && affectedCharRange.location <= self.textView.string.length) {
		
		Line * affectedLine = [self getLineAt:affectedCharRange.location];

		if (affectedLine.type == character && _characterInput && affectedLine.string.length == 0) {
			affectedLine.type = action;
			[self cancelCharacterInput];
		}
		
		Line * otherLine = [self getLineAt:affectedCharRange.location + affectedCharRange.length];
		
		if (otherLine.string.length > 0) {
			if (affectedLine.type == heading && otherLine.type != heading) {
				if (self.undoManager.isRedoing) NSLog(@"Redoing");
				if (self.undoManager.isUndoing) NSLog(@"Undoing");
				
				__block NSString *undoString = [otherLine.string stringByAppendingString:@"\n"];
				NSLog(@"Affected: %@ / undo: %@", affectedLine.string, undoString);
				
				NSInteger position = otherLine.position;
				NSInteger length = undoString.length;
				
				if (position + length > [self getText].length) {
					NSLog(@"attempting to fix length");
					length = undoString.length;
				}
				
				[self.undoManager beginUndoGrouping];
				[self.undoManager registerUndoWithTarget:self handler:^(id _Nonnull target) {
					[self replaceCharactersInRange:NSMakeRange(position, length) withString:undoString];
				}];
				[self.undoManager endUndoGrouping];
			}
			else if (_characterInput && otherLine.type != empty) {
				// delete key was pressed at the end of line and the app would make the next line uppercase
				// let's avoid that
				if (affectedCharRange.location == _currentLine.string.length + 1) {
					[self cancelCharacterInput];
				}
			}
		}
	}
	
    //If something is being inserted, check whether it is a "(" or a "[[" and auto close it
    if (self.matchParentheses) {
        if (affectedCharRange.length == 0) {
            if ([replacementString isEqualToString:@"("]) {
				if (_currentLine.type != character) {
					[self addString:@")" atIndex:affectedCharRange.location];
					[self.textView setSelectedRange:affectedCharRange];
				}
            } else if ([replacementString isEqualToString:@"["]) {
                if (affectedCharRange.location != 0) {
                    unichar characterBefore = [[self.textView string] characterAtIndex:affectedCharRange.location-1];
                    
                    if (characterBefore == '[') {
                        [self addString:@"]]" atIndex:affectedCharRange.location];
                        [self.textView setSelectedRange:affectedCharRange];
                    }
                }
            } else if ([replacementString isEqualToString:@"*"]) {
                if (affectedCharRange.location != 0) {
                    unichar characterBefore = [[self.textView string] characterAtIndex:affectedCharRange.location-1];
                    
                    if (characterBefore == '/') {
                        [self addString:@"*/" atIndex:affectedCharRange.location];
                        [self.textView setSelectedRange:affectedCharRange];
                    }
                }
            } else if ([replacementString isEqualToString:@")"] || [replacementString isEqualToString:@"]"]) {
				if (affectedCharRange.location < [self getText].length) {
					unichar currentCharacter = [[self.textView string] characterAtIndex:affectedCharRange.location];
					if (currentCharacter == ')' && [replacementString isEqualToString:@")"]) {
						[self.textView setSelectedRange:NSMakeRange(affectedCharRange.location + 1, 0)];
						return NO;
					}
					if (currentCharacter == ']' && [replacementString isEqualToString:@"]"]) {
						[self.textView setSelectedRange:NSMakeRange(affectedCharRange.location + 1, 0)];
						return NO;
					}
				}
			} else if ([replacementString isEqualToString:@"<"]) {
				if (affectedCharRange.location != 0) {
					unichar characterBefore = [[self.textView string] characterAtIndex:affectedCharRange.location-1];
					
					if (characterBefore == '<') {
						[self addString:@">>" atIndex:affectedCharRange.location];
						[self.textView setSelectedRange:affectedCharRange];
					}
				}
			} else if ([replacementString isEqualToString:@"{"]) {
				if (affectedCharRange.location != 0) {
					unichar characterBefore = [[self.textView string] characterAtIndex:affectedCharRange.location-1];
					
					if (characterBefore == '{') {
						[self addString:@"}}" atIndex:affectedCharRange.location];
						[self.textView setSelectedRange:affectedCharRange];
					}
				}
			}
        }
    }
	
	// Add an extra line break after some elements
	bool processDoubleBreak = NO;
	
	// Enter key
	if ([replacementString isEqualToString:@"\n"] && affectedCharRange.length == 0  && ![self.undoManager isUndoing] && !self.documentIsLoading) {
		_currentLine = [self getCurrentLine];
		
		// Process line break after a forced character input
		if (_characterInput && _characterInputForLine) {
			// Don't go out of range
			if (_characterInputForLine.position + _characterInputForLine.string.length <= self.textView.string.length) {
				// If the cue is empty, reset it
				if (_characterInputForLine.string.length == 0) {
					_characterInputForLine.type = empty;
					[self formatLineOfScreenplay:_characterInputForLine];
				}
				// If the character is less than 3 characters long, we need to force it.
				else if (_characterInputForLine.string.length < 3) {
					_postEditAction = @{ @"index": [NSNumber numberWithInteger:_characterInputForLine.position], @"string": @"@" };
				}
			}
		}
		
		// Process double breaks after some elements
		// This should be rewritten at some point, I have no idea what's going on
		if (self.autoLineBreaks) {
			// Test if we should add a new line
			// (We are not in the process of adding a dual line break and shift is not pressed)
			if (!_newScene && _currentLine.string.length > 0 && !([NSEvent modifierFlags] & NSEventModifierFlagShift)) {
				
				if (_currentLine.type == heading ||
					_currentLine.type == section ||
					_currentLine.type == synopse) {
					// No shift down, add two breaks afer a scene heading, heading and synopsis
					_newScene = YES;
					[self addString:@"\n" atIndex:affectedCharRange.location];
				} else if (_currentLine.type == action) {
					NSUInteger currentIndex = [self.parser.lines indexOfObject:_currentLine];
					
					// Perform double-check if there is a next line
					if (currentIndex < self.parser.lines.count - 2 && currentIndex != NSNotFound) {
						Line* nextLine = [self.parser.lines objectAtIndex:currentIndex + 1];
						if (nextLine.string.length == 0) {
							_newScene = YES;
							[self addString:@"\n" atIndex:affectedCharRange.location];
						} else {
							_newScene = NO;
						}
					} else {
						_newScene = YES;
						[self addString:@"\n" atIndex:affectedCharRange.location];
					}
				} else if (_currentLine.type == dialogue) {
					_newScene = YES;
					[self addString:@"\n" atIndex:affectedCharRange.location];
					processDoubleBreak = YES;
				} else {
					// Nothing applies, go on
					_newScene = NO;
				}
			} else {
				//if (_newScene) processDoubleBreak = YES;
				_newScene = NO;
			}
		}
	}
	
	if (_characterInput) replacementString = [replacementString uppercaseString];

	// Parse changes so far
	[self.parser parseChangeInRange:affectedCharRange withString:replacementString];
	_currentLine = [self getCurrentLine];
	
	/*
	if (forceDialogue) {
		Line *nextLine = [self getNextLine:_currentLine];
		if (nextLine.type == empty) {
			nextLine.type = dialogue;
			[self forceFormatChangesInRange:nextLine.textRange];
		}
	}
	*/
	
	if (processDoubleBreak) {
		// This is here to fix a formatting error with dialogue.
		// If the caret is at the end of the document, we need to parse one step behind
		// to correctly format the extra line break we just added.
		@try {
			[self.parser parseChangeInRange:NSMakeRange(affectedCharRange.location + 1, 1) withString:@"\n"];
		}
		@catch (NSException *e) {
			NSLog(@"out of bounds: %@", _currentLine.string);
		}
	}
	
	// Fire up autocomplete at the end of string and
	// create cached lists of scene headings / character names
	if (_textView.selectedRange.location == _currentLine.position + _currentLine.string.length - 1) {
		if (_currentLine.type == character) {
			if (![_characterNames count]) [self collectCharacterNames];
			[self.textView setAutomaticTextCompletionEnabled:YES];
		} else if (_currentLine.type == heading) {
			if (![_sceneHeadings count]) [self collectHeadings];
			[self.textView setAutomaticTextCompletionEnabled:YES];
		} else {
			[_characterNames removeAllObjects];
			[_sceneHeadings removeAllObjects];
			[self.textView setAutomaticTextCompletionEnabled:NO];
		}
	}

	_lastChangedRange = (NSRange){ affectedCharRange.location, replacementString.length };
	
	
	// WIP
	[self paginateAt:affectedCharRange sync:NO];
	
	_previewUpdated = NO;
    return YES;
}
- (Line*)getNextLine:(Line*)line {
	NSInteger i = [self.parser.lines indexOfObject:line];
	if (i < self.parser.lines.count - 1 && i != NSNotFound) {
		return self.parser.lines[i + 1];
	} else {
		return nil;
	}
}

- (IBAction)toggleAutoLineBreaks:(id)sender {
	self.autoLineBreaks = !self.autoLineBreaks;
	[[NSUserDefaults standardUserDefaults] setBool:self.autoLineBreaks forKey:AUTOMATIC_LINEBREAKS_KEY];
}

- (Line*)getCurrentLine {
	NSInteger location = self.selectedRange.location;
	if (location > self.getText.length) { location = self.getText.length; }
	return [self getLineAt:location];
}
- (Line*)getLineAt:(NSInteger)position {
	// Let's make a copy of the parser array so it's not mutated while iterated.
	// I'm not sure if this is needed, but we have so many background tasks going on
	// right now, that I'm a bit afraid of crashes :---)
	NSArray * lines = [NSArray arrayWithArray:self.parser.lines];
	for (Line* line in lines) {
		if (line) {
			if (position == line.position) return line;
			else if (NSLocationInRange(position, line.range)) return line;
		}
	}
	return nil;
}

- (IBAction)reformatRange:(id)sender {
	if (self.textView.selectedRange.length > 0) {
		NSArray *lines = [self.parser linesInRange:self.textView.selectedRange];
		if (lines) [self.parser correctParsesForLines:lines];
		[self.parser createOutline];
		[self ensureLayout];
	}	
}

- (void)registerChangesInRange:(NSRange)range {
	//NSColor *changeColor = [[BeatColors color:@"pink"] colorWithAlphaComponent:0.2];
	//[_textView.textStorage addAttribute:NSBackgroundColorAttributeName value:changeColor range:range];
	//[self markRangeAsAddition:range];
	[_textView.textStorage addAttribute:revisionAttribute value:[BeatRevisionItem type:RevisionAddition color:_revisionColor] range:range];
}
- (bool)inRange:(NSRange)range {
	NSRange intersection = NSIntersectionRange(range, (NSRange){0, _textView.string.length  });
	if (intersection.length == range.length) return YES;
	else return NO;
}

- (void)textDidChange:(NSNotification *)notification
{
	if (![self.undoManager isUndoRegistrationEnabled]) [self.undoManager enableUndoRegistration];
	
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;

	if (_postEditAction) {
		NSLog(@"post edit %@", _postEditAction);
		NSInteger index = [_postEditAction[@"index"] integerValue];
		NSString *string = _postEditAction[@"string"];
		_postEditAction = nil;
		
		if (index <= self.textView.string.length) {
			[self addString:string atIndex:index];
		}
	}
		
	// Register changes
	if (_trackChanges) [self registerChangesInRange:_lastChangedRange];
	
	// If outline has changed, we will rebuild outline & timeline if needed
	bool changeInOutline = [self.parser getAndResetChangeInOutline];
	
	if (changeInOutline) {
		[self.parser createOutline];
		if (self.outlineViewVisible) [self reloadOutline];
		if (self.timelineVisible) [self reloadTimeline];
		if (self.timelineBar.visible) [self reloadTouchTimeline];
		if (_runningPlugins.count) [self updatePluginsWithOutline:self.parser.outline];
	} else {
		if (self.timelineVisible) [_timeline refreshWithDelay];
	}
	
	[self applyFormatChanges];
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
	// If the outline has changed, update all labels
	if (changeInOutline) [self updateSceneNumberLabels:0];
	else [self updateSceneNumberLabels:_lastChangedRange.location];
	
	// Update preview screen
	[self updatePreview];
	
	// Draw masks again if text did change
	if (_outlineView.filteredOutline.count) [self maskScenes];
	
	// Update any currently running plugins
	if (_runningPlugins.count) [self updatePlugins:_lastChangedRange];
	
	
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;
	
	// Close popups
	if (_quickSettingsPopover.shown) [self closeQuickSettings];
	if (self.typewriterMode) [self typewriterScroll];

	//if (!NSLocationInRange(_textView.selectedRange.location, _currentLine.textRange)) self.currentLine = [self getCurrentLine];
	self.currentLine = [self getCurrentLine];
	
	// Reset forced character input
	if (self.characterInputForLine != self.currentLine) self.characterInput = NO;
	
	// We REALLY REALLY should make some sort of cache for these
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		if (self.outlineViewVisible || self.timelineVisible || self.runningPlugins) {
			self.outline = [self getOutlineItems];
			self.currentScene = [self getCurrentSceneWithPosition:self.selectedRange.location];
		}
		
		[self updateUIwithCurrentScene];
		
		if (self.mode == TaggingMode) [self updateTaggingData];
		
		if (self.runningPlugins.count) [self updatePluginsWithSelection:self.selectedRange];
	});
	
}

- (void)updateUIwithCurrentScene {
	__block NSInteger sceneIndex = [self.outline indexOfObject:self.currentScene];
	
	// Update Timeline & TouchBar Timeline
	if (self.timelineVisible) [_timeline scrollToScene:sceneIndex];
	if (self.timelineBar.visible) [_touchbarTimeline selectItem:[_outline indexOfObject:_currentScene]];
	
	// Locate current scene & reload outline without building it in parser
	// I don't know what this is, to be honest
	if (_outlineViewVisible && !_outlineEdit) {
		
		if (self.outlineViewVisible) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self reloadOutline];
				if (self.currentScene) [self.outlineView scrollToScene:self.currentScene];
				
				if (self.outlineView.filteredOutline.count < 1) {
					self.outlineView.currentScene = sceneIndex;
				} else {
					self.outlineView.currentScene = [self.outlineView.filteredOutline indexOfObject:self.currentScene];
				}
			});
		}
	}
	
	// Update touch bar color if needed
	if (_currentScene.color) {
		if ([BeatColors color:[_currentScene.color lowercaseString]]) {
			[_colorPicker setColor:[BeatColors color:[_currentScene.color lowercaseString]]];
		}
	}
	
	if (_runningPlugins) [self updatePluginsWithSceneIndex:sceneIndex];
}

- (IBAction)showInfo:(id)sender {
	[self.textView showInfo:self];
}


#pragma mark - Text I/O

- (void)addString:(NSString*)string atIndex:(NSUInteger)index
{
	[self replaceCharactersInRange:NSMakeRange(index, 0) withString:string];
	[[[self undoManager] prepareWithInvocationTarget:self] removeString:string atIndex:index];
}

- (void)removeString:(NSString*)string atIndex:(NSUInteger)index
{
	[self replaceCharactersInRange:NSMakeRange(index, [string length]) withString:@""];
	[[[self undoManager] prepareWithInvocationTarget:self] addString:string atIndex:index];
}
- (void)replaceRange:(NSRange)range withString:(NSString*)newString {
	// Replacement method with undo
	NSString *oldString = [self.textView.string substringWithRange:range];
	[self replaceCharactersInRange:range withString:newString];
	[[[self undoManager] prepareWithInvocationTarget:self] replaceString:newString withString:oldString atIndex:range.location];
}
- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index
{
	NSRange range = NSMakeRange(index, [string length]);
	[self replaceCharactersInRange:range withString:newString];
	[[[self undoManager] prepareWithInvocationTarget:self] replaceString:newString withString:string atIndex:index];
}
- (void)removeRange:(NSRange)range {
	NSString *string = [self.getText substringWithRange:range];
	[self replaceCharactersInRange:range withString:@""];
	[[[self undoManager] prepareWithInvocationTarget:self] addString:string atIndex:range.location];
}
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position {
	_moving = YES;
	
	NSString *stringToMove = [self.getText substringWithRange:range];
	NSInteger length = self.getText.length;
	
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
	
	[[[self undoManager] prepareWithInvocationTarget:self] moveStringFrom:undoingRange to:undoPosition];
	[[self undoManager] setActionName:@"Move Scene"];
	
	_moving = NO;
}

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
	return NSMakeRange(range->location + position, range->length);
}
- (NSString*)lastCharacter:(NSString*)string {
	if (string.length < 1) return nil;
	else if (string.length == 1) return string;
	else {
		return [string substringFromIndex:string.length - 1];
	}
}


// There is no shortage of ugliness in the world.
// If a person closed their eyes to it,
// there would be even more.


# pragma mark - Autocomplete

// Collect all character names from script
- (void)collectCharacterNames {
    /*
     
     So let me elaborate a bit. This is currently two systems upon each
	 other and two separate lists of character names are stored.
	 
     Other use is to collect character cues for autocompletion.
	 There, it doesn't really matter if we have strange stuff after names,
	 because different languages can use their own abbreviations.
     
     Characters are also collected for the filtering feature, so we will
	 just strip away everything after the name (such as V.O. or O.S.), and
	 hope for the best.
	 
	 NB: We need some sort of a system to organize autocomplete hits
	 according to the character's line count.
     
     */
	
	[_characterNames removeAllObjects];
	
	// If there was a character selected in Character Filter Box, save it
	NSString *selectedCharacter = _characterBox.selectedItem.title;
    
    NSMutableArray *characterList = [NSMutableArray array];
	NSMutableDictionary *charactersAndLines = [NSMutableDictionary dictionary];
    
	[_characterBox removeAllItems];
	[_characterBox addItemWithTitle:@" "]; // Add one empty item at the beginning
		
	for (Line *line in [self.parser lines]) {
		if ((line.type == character || line.type == dualDialogueCharacter) && line != _currentLine
			//&& ![_characterNames containsObject:line.string]
			) {
			// Don't add this line if it's just a character with cont'd.
			// We'll account for other things later, such as V.O., O.S. etc.
			if ([line.string rangeOfString:@"(CONT'D)" options:NSCaseInsensitiveSearch].location != NSNotFound) continue;
			
			// Character name, INCLUDING any suffixes, such as (CONT'D), (V.O.') etc.
            NSString *character = [line.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
			
			// Add the character + suffix into dict and calculate number of appearances
			if (charactersAndLines[character]) {
				NSInteger lines = [charactersAndLines[character] integerValue] + 1;
				charactersAndLines[character] = [NSNumber numberWithInteger:lines];
			} else {
				charactersAndLines[character] = [NSNumber numberWithInteger:1];
			}
						            
			// Remove anything that's NOT a character name
			character = line.characterName;
			
			// Add character to list
			if (character && ![characterList containsObject:character]) {
				[_characterBox addItemWithTitle:character]; // Add into the dropown
                [characterList addObject:character];
            }
		}
	}
	
	// Create an ordered list with all the character names. One with the most lines will be the first suggestion.
	NSArray *characters = [charactersAndLines keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2){
		return [obj2 compare:obj1];
	}];
	for (NSString *character in characters) {
		[_characterNames addObject:character];
		[_characterNames addObject:[NSString stringWithFormat:@"%@ (CONT'D)", character]];
	}
	
    // There was a character selected in the filtering menu, so select it again (if applicable)
    if (selectedCharacter.length) {
        for (NSMenuItem *item in _characterBox.itemArray) {
            if ([item.title isEqualToString:selectedCharacter]) [_characterBox selectItem:item];
        }
    }
}
- (void) collectHeadings {
	[_sceneHeadings removeAllObjects];
	for (Line *line in self.parser.lines) {
		if (line.type == heading && line != _currentLine && ![_sceneHeadings containsObject:line.string]) {
			
			// If the heading has a color set, strip the color
			if ([line.string rangeOfString:@"[[COLOR"].location != NSNotFound) {
				[_sceneHeadings addObject:[line.string.uppercaseString substringToIndex:[line.string rangeOfString:@"[[COLOR"].location]];
			} else {
				[_sceneHeadings addObject:line.string.uppercaseString];
			}
		}
	}
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	NSMutableArray *matches = [NSMutableArray array];
	NSMutableArray *search = [NSMutableArray array];

	// We need to get current line here for some reason, indexes are wrong otherwise
	_currentLine = [self getCurrentLine];
	
	// Choose which array to search
	if (_currentLine.type == character) search = _characterNames;
	else if (_currentLine.type == heading) search = _sceneHeadings;
	
	// Find matching lines for the partially typed line
	for (NSString *string in search) {
		if ([string rangeOfString:[textView.string substringWithRange:charRange] options:NSAnchoredSearch range:NSMakeRange(0, string.length)].location != NSNotFound) {
			[matches addObject:string];
		}
	}
	
	[matches sortUsingSelector:@selector(compare:)];
	return matches;
}

- (void)handleTabPress {
	// Don't allow this to happen twice
	if (_characterInput) return;
	
	// Force character if the line is suitable
	_currentLine = [self getCurrentLine];
	if (_currentLine.type == empty) {
		NSInteger index = [self.parser.lines indexOfObject:_currentLine];
		
		if (index > 0) {
			Line* previousLine = [self.parser.lines objectAtIndex:index - 1];
			if (previousLine.type == empty ||
				(previousLine.type == action && previousLine.string.length == 0)) {
				[self forceCharacterInput];
			}
		}
	} else {
		// Default behaviour: add tab
		// nope
		// [self replaceCharactersInRange:self.textView.selectedRange withString:@"\t"];
	}
}

- (void) forceCharacterInput {
	// Don't allow this to happen twice
	if (_characterInput) return;
	
	// If no line is selected, return
	_currentLine = [self getCurrentLine];
	if (!_currentLine) return;
	
	_currentLine.type = character;
	_characterInputForLine = _currentLine;
	
	_characterInput = YES;
	
	// Format the line (if mid-screenplay)
	[self formatLineOfScreenplay:_currentLine];

	// Set typing attributes (just in case, and if at the end)
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[paragraphStyle setFirstLineHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH];
	[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	[self.textView setTypingAttributes:attributes];
}
- (void) cancelCharacterInput {
	_characterInput = NO;
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[attributes setValue:self.courier forKey:NSFontAttributeName];
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[paragraphStyle setFirstLineHeadIndent:0];
	[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
	[self.textView setTypingAttributes:attributes];
}

- (void)addRecentCharacter:(NSString*)name {
	// Init array if needed
	if (_recentCharacters == nil) _recentCharacters = [NSMutableArray array];
	
	// Remove any suffixes
	name = [name replace:RX(@"\\((.*)\\)") with:@""];
	name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	if ([_recentCharacters indexOfObject:name] != NSNotFound) {
		[_recentCharacters removeObject:name];
		[_recentCharacters insertObject:name atIndex:0];
	}
}


#pragma mark - Formatting

- (IBAction)reformatEverything:(id)sender {
	[self.parser resetParsing];
	[self applyFormatChanges];
	[self formatAllLines];
}

- (void)formatAllLines
{
	for (Line* line in self.parser.lines) {
		[self formatLineOfScreenplay:line];
	}
	
	[self ensureLayout];
}
- (void)applyFormatChanges
{
    for (NSNumber* index in self.parser.changedIndices) {
        [self formatLineOfScreenplay:self.parser.lines[index.integerValue]];
    }
	
    [self.parser.changedIndices removeAllObjects];
}
- (void)forceFormatChangesInRange:(NSRange)range
{
	NSArray *lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		[self formatLineOfScreenplay:line];
	}
}

-(void)applyInitialFormatting {
	// This is optimization for first-time format with no lookbacks (with a look-forward, though)
	NSInteger index = 0;

	for (Line* line in self.parser.lines) {
		[self formatLineOfScreenplay:line firstTime:YES];
		index++;
	}

	[_parser.changedIndices removeAllObjects];
	[self initialTextBackgroundRender];
}

- (void)formatLineOfScreenplay:(Line*)line
{
	[self formatLineOfScreenplay:line firstTime:NO];
}

- (void)formatLineOfScreenplay:(Line*)line firstTime:(bool)firstTime
{
	// Don't go out of range
	if (line.position + line.string.length > self.textView.string.length) return;
	
	if (!firstTime) _currentLine = line;
	
	NSUInteger begin = line.position;
	NSUInteger length = line.string.length;
	NSRange range = NSMakeRange(begin, length);
		
	// Let's do the real formatting now
	NSTextStorage *textStorage = self.textView.textStorage;
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
	
	// Redo everything we just did for forced character input
	if (_characterInput && _characterInputForLine == line) {
		line.type = character;
		
		NSRange selectedRange = self.textView.selectedRange;
		
		// Only do this if we are REALLY typing at this location
		// Foolproof fix for a strange, rare bug which changes multiple
		// lines into character cues and the user is unable to undo the changes
		if (range.location + range.length <= selectedRange.location) {
			[_textView replaceCharactersInRange:range withString:[[textStorage.string substringWithRange:range] uppercaseString]];
			line.string = [line.string uppercaseString];
			[self.textView setSelectedRange:selectedRange];
		}
	}
	
	// Format according to style
	// WIP: Replace with delegation
	if ((line.type == heading && [line.string characterAtIndex:0] != '.') ||
		(line.type == transitionLine && [line.string characterAtIndex:0] != '>')) {
		//Make uppercase, and then reapply cursor position, because they'd get lost otherwise
		NSArray<NSValue*>* selectedRanges = self.textView.selectedRanges;
		[_textView replaceCharactersInRange:range withString:[[textStorage.string substringWithRange:range] uppercaseString]];
		[self.textView setSelectedRanges:selectedRanges];
	}
	
	if (line.type == heading) {
		// Format heading
		
		// Set Font to bold
		[attributes setObject:self.boldCourier forKey:NSFontAttributeName];
		
		// If the scene has a color, let's color it
		if (line.color.length) {
			NSColor* headingColor = [BeatColors color:line.color.lowercaseString];
			if (headingColor != nil) [attributes setObject:headingColor forKey:NSForegroundColorAttributeName];
		}
	
	} else if (line.type == pageBreak) {
		// Format page break
		// Set Font to bold
		[attributes setObject:self.boldCourier forKey:NSFontAttributeName];
		
	} else if (line.type == lyrics) {
		// Format lyrics
		// Set Font to italic
		[attributes setObject:[self italicCourier] forKey:NSFontAttributeName];
	}

	// Format layout & alignment
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	// Handle title page block
	if (line.type == titlePageTitle  ||
		line.type == titlePageAuthor ||
		line.type == titlePageCredit ||
		line.type == titlePageSource ||
		
		line.type == titlePageUnknown ||
		line.type == titlePageContact ||
		line.type == titlePageDraftDate) {
		
		[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
		[paragraphStyle setHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
		// Indent lines following a first-level title page element a bit more
		if ([line.string rangeOfString:@":"].location != NSNotFound) {
			[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
		} else {
			[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * 1.25 * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:TITLE_INDENT * 1.1 * DOCUMENT_WIDTH];
		}

		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
	} else if (line.type == transitionLine) {
		// Transitions
		[paragraphStyle setAlignment:NSTextAlignmentRight];
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
	} else if (line.type == centered || line.type == lyrics) {
		// Lyrics & centered text
		[paragraphStyle setAlignment:NSTextAlignmentCenter];
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	} else if (line.type == character) {
		// Character cue
		[paragraphStyle setFirstLineHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH];

		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	} else if (line.type == parenthetical) {
		// Parenthetical after character
		[paragraphStyle setFirstLineHeadIndent:PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setHeadIndent:PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH];
		
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
	} else if (line.type == dialogue) {
		// Dialogue block
		[paragraphStyle setFirstLineHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH];
		
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
	} else if (line.type == dualDialogueCharacter) {
		[paragraphStyle setFirstLineHeadIndent:DD_CHARACTER_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setHeadIndent:DD_CHARACTER_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH];
		
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
	} else if (line.type == dualDialogueParenthetical) {
		[paragraphStyle setFirstLineHeadIndent:DD_PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setHeadIndent:DD_PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH];
		
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
	} else if (line.type == dualDialogue) {
		[paragraphStyle setFirstLineHeadIndent:DUAL_DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setHeadIndent:DUAL_DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
		[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH];
		
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
	} else if (line.type == section || line.type == synopse) {
		// Stylize sections & synopses

		// Bold section headings for first-level sections
		if (line.type == section) {
			[paragraphStyle setParagraphSpacingBefore:20];
			CGFloat size = SECTION_FONT_SIZE;
			
			NSColor *sectionColor;
			
			if (line.sectionDepth == 1) {
				// Black or custom for high-level sections
				if (line.color) {
					if (!(sectionColor = [BeatColors color:line.color])) sectionColor = self.themeManager.sectionTextColor;
				} else sectionColor = self.themeManager.sectionTextColor;

				[attributes setObject:sectionColor forKey:NSForegroundColorAttributeName];
				[attributes setObject:[self sectionFontWithSize:size] forKey:NSFontAttributeName];
			} else {
				// And custom or gray for others
				if (line.color) {
					if (!(sectionColor = [BeatColors color:line.color])) sectionColor = self.themeManager.sectionTextColor;
				} else sectionColor = self.themeManager.commentColor;
				
				[attributes setObject:sectionColor forKey:NSForegroundColorAttributeName];
				
				// Also, make lower sections a bit smaller
				size = size - line.sectionDepth;
				if (size < 15) size = 15.0;
				
				[attributes setObject:[self sectionFontWithSize:size] forKey:NSFontAttributeName];
			}
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		}
		
		if (line.type == synopse) {
			NSColor* synopsisColor;
			if (line.color) {
				if (!(synopsisColor = [BeatColors color:line.color])) synopsisColor = self.themeManager.sectionTextColor;
			} else synopsisColor = self.themeManager.synopsisTextColor;
			
			if (synopsisColor) [attributes setObject:synopsisColor forKey:NSForegroundColorAttributeName];
			
			[attributes setObject:[self synopsisFont] forKey:NSFontAttributeName];
		}
		
	} else if (line.type == action) {
		// Take note if this is a paragraph split into two
		// WIP: Check if this is needed
		NSInteger index = [_parser.lines indexOfObject:line];
		if (index > 0) {
			Line* preceedingLine = [_parser.lines objectAtIndex:index-1];
			if (preceedingLine.type == action && preceedingLine.string.length > 0) {
				line.isSplitParagraph = YES;
			}
		}
	} else if (line.type == empty) {
		// Just to make sure
		NSInteger index = [_parser.lines indexOfObject:line];
		
		Line* preceedingLine;
		
		if (index > 1) {
			preceedingLine = [_parser.lines objectAtIndex:index - 1];
			if (preceedingLine.string.length < 1) {
				[paragraphStyle setFirstLineHeadIndent:0];
				[paragraphStyle setHeadIndent:0];
				[paragraphStyle setTailIndent:0];
				[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			}
		}
	}
		
	// Remove all former paragraph styles and overwrite fonts if they are not set yet
	//[textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
	//[textStorage removeAttribute:NSParagraphStyleAttributeName range:range];

	
	if (![attributes valueForKey:NSFontAttributeName]) {
		[attributes setObject:self.courier forKey:NSFontAttributeName];
	}
	if (![attributes valueForKey:NSForegroundColorAttributeName]) {
		[attributes setObject:self.themeManager.textColor forKey:NSForegroundColorAttributeName];
	}
	if (![attributes valueForKey:NSUnderlineStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSUnderlineStyleAttributeName];
	}
	if (![attributes valueForKey:NSStrikethroughStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSStrikethroughStyleAttributeName];
	}
	if (!attributes[NSBackgroundColorAttributeName]) {
		[textStorage addAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor range:range];
	}

	//Add selected attributes
	if (range.length > 0) {
		[textStorage addAttributes:attributes range:range];
	} else {
		// Add attributes ahead
		if (range.location + 1 < textStorage.string.length) {
			range = NSMakeRange(range.location, range.length + 1);
			[textStorage addAttributes:attributes range:range];
		}
	}
	
	// INPUT ATTRIBUTES FOR CARET / CURSOR
	if (line.string.length == 0 && !firstTime) {
		// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
		Line* previousLine;
		NSInteger lineIndex = [_parser.lines indexOfObject:line];
		if (lineIndex > 0) previousLine = [_parser.lines objectAtIndex:lineIndex - 1];
		
		//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];

		// Keep dialogue input for character blocks
		if ((previousLine.type == dialogue || previousLine.type == character || previousLine.type == parenthetical)
			&& [previousLine.string length]) {
			[paragraphStyle setFirstLineHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH];
		} else {
			[paragraphStyle setFirstLineHeadIndent:0];
			[paragraphStyle setHeadIndent:0];
			[paragraphStyle setTailIndent:0];
		}
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		[self.textView setTypingAttributes:attributes];
	}
	
	//Format scene number as invisible
	if (line.sceneNumberRange.length > 0) {
		NSRange sceneNumberRange = NSMakeRange(line.sceneNumberRange.location - 1, line.sceneNumberRange.length + 2);
		// Don't go out of range, please, please
		if (sceneNumberRange.location + sceneNumberRange.length <= line.string.length && sceneNumberRange.location >= 0) {
			[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
								range:[self globalRangeFromLocalRange:&sceneNumberRange inLineAtPosition:line.position]];
		}
	}
	
	//Add in bold, underline, italics and other stylization
	[line.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSFontAttributeName value:self.italicCourier line:line range:range formattingSymbol:italicSymbol];
	}];
	[line.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSFontAttributeName value:self.boldCourier line:line range:range formattingSymbol:boldSymbol];
	}];
	[line.boldItalicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSFontAttributeName value:self.boldItalicCourier line:line range:range formattingSymbol:@""];
	}];
	[line.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSUnderlineStyleAttributeName value:@1 line:line range:range formattingSymbol:underlinedSymbol];
	}];
	[line.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSStrikethroughStyleAttributeName value:@1 line:line range:range formattingSymbol:strikeoutSymbolOpen];
	}];

	if (line.isTitlePage && line.titleRange.length > 0) {
		NSRange titleRange = line.titleRange;
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.commentColor range:[self globalRangeFromLocalRange:&titleRange inLineAtPosition:line.position]];
	}
	
	[line.escapeRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.invisibleTextColor
							range:[self globalRangeFromLocalRange:&range
												 inLineAtPosition:line.position]];
	}];
	
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.commentColor
							range:[self globalRangeFromLocalRange:&range
												 inLineAtPosition:line.position]];
	}];
	
	[line.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.invisibleTextColor
							range:[self globalRangeFromLocalRange:&range
												 inLineAtPosition:line.position]];
	}];


	// Format force element symbols
	if (line.numberOfPreceedingFormattingCharacters > 0 && line.string.length >= line.numberOfPreceedingFormattingCharacters) {
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.invisibleTextColor
							range:NSMakeRange(line.position, line.numberOfPreceedingFormattingCharacters)];
	} else if (line.type == centered && line.string.length > 1) {
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.invisibleTextColor
		range:NSMakeRange(line.position, 1)];
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.invisibleTextColor
							range:NSMakeRange(line.position + line.string.length - 1, 1)];
	}
	
	//[self renderTextBackgroundOnLine:line];
	
	// Render backgrounds according to text attributes
	// This is AMAZINGLY slow

	if (!firstTime) {
		[textStorage enumerateAttributesInRange:line.textRange options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {

			if (!attrs[NSBackgroundColorAttributeName]) {
				[textStorage addAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor range:range];
			}

			// Revisions
			if (attrs[revisionAttribute]) {
				BeatRevisionItem *revision = attrs[revisionAttribute];
				if (revision.type == RevisionAddition) [textStorage addAttribute:NSBackgroundColorAttributeName value:revision.backgroundColor range:range];
				else if (revision.type == RevisionRemoval) {
					[textStorage addAttribute:NSStrikethroughColorAttributeName value:[BeatColors color:@"red"] range:range];
					[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@1 range:range];
					[textStorage addAttribute:NSBackgroundColorAttributeName value:[[BeatColors color:@"red"] colorWithAlphaComponent:0.2] range:range];
				}
			}
			
			// Tags
			if (attrs[tagAttribute]) {
				BeatTag *tag = attrs[tagAttribute];
				NSColor *tagColor = [BeatTagging colorFor:tag.type];
				tagColor = [tagColor colorWithAlphaComponent:.6];
				
				[self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:tagColor range:range];
			}
		}];
	}
}

- (void)initialTextBackgroundRender {
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[self.textView.textStorage enumerateAttributesInRange:(NSRange){0,self.textView.string.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
			
			// Revisions
			if (attrs[revisionAttribute]) {
				BeatRevisionItem *revision = attrs[revisionAttribute];
				if (revision.type == RevisionAddition) [self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:revision.backgroundColor range:range];
				else if (revision.type == RevisionRemoval) {
					[self.textView.textStorage addAttribute:NSStrikethroughColorAttributeName value:[BeatColors color:@"red"] range:range];
					[self.textView.textStorage addAttribute:NSStrikethroughStyleAttributeName value:@1 range:range];
					[self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:[[BeatColors color:@"red"] colorWithAlphaComponent:0.2] range:range];
				}
			}
			
			// Tags
			if (attrs[tagAttribute]) {
				BeatTag *tag = attrs[tagAttribute];
				NSColor *tagColor = [BeatTagging colorFor:tag.type];
				tagColor = [tagColor colorWithAlphaComponent:.6];
				
				NSLog(@"tag color %@", tagColor);
				
				if (tagColor) [self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:tagColor range:range];
			}
		}];
	});
}

- (void)stylize:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
	NSUInteger symLen = sym.length;
	NSRange openRange = (NSRange){ range.location, symLen };
	NSRange closeRange = (NSRange){ range.location + range.length - symLen, symLen };
	
	NSRange effectiveRange;
	
	if (symLen == 0) {
		// Format full range
		effectiveRange = NSMakeRange(range.location, range.length);
	}
	else if (range.length >= 2 * symLen) {
		// Format between characters (ie. *italic*)
		effectiveRange = NSMakeRange(range.location + symLen, range.length - 2 * symLen);
	} else {
		// Format nothing
		effectiveRange = NSMakeRange(range.location + symLen, 0);
	}
	
	if (key.length) [self.textView.textStorage addAttribute:key value:value
						range:[self globalRangeFromLocalRange:&effectiveRange
											 inLineAtPosition:line.position]];
	
	if (openRange.length) {
		[self.textView.textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.invisibleTextColor
						range:[self globalRangeFromLocalRange:&openRange
											 inLineAtPosition:line.position]];
		[self.textView.textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.invisibleTextColor
						range:[self globalRangeFromLocalRange:&closeRange
											 inLineAtPosition:line.position]];
	}
}


#pragma mark - Scrolling

- (IBAction)goToScene:(id)sender {
	BeatModalInput *input = [[BeatModalInput alloc] init];
	[input inputBoxWithMessage:@"Go to scene number..." text:@"" placeholder:@"e.g. 123" forWindow:_thisWindow completion:^(NSString * _Nonnull result) {
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
	//[self.textView scrollRangeToVisible:lineRange];
	[self.textView scrollToRange:lineRange];
	[_thisWindow makeFirstResponder:_textView];
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
	[_thisWindow makeKeyWindow];
}


#pragma mark - Parser delegation

- (NSRange)selectedRange {
	return self.textView.selectedRange;
}
- (void)setSelectedRange:(NSRange)range {
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

- (void)headingChangedToActionAt:(Line*)line {
	if (!NSThread.isMainThread) return;
	
	// The parser has changed a presumed line element back into action/something else,
	// but the Line element should still have the original string value intact.
	
	// The parser is way ahead of the textView here, so we need to take it into account with text ranges, as
	// the last character has not been added into view yet. This signal has come right from parser level.
	[self.textView.textStorage replaceCharactersInRange:NSMakeRange(line.position, line.string.length - 1) withString:[line.string substringToIndex:line.string.length - 1]];
}

- (void)actionChangedToHeadingAt:(Line*)line {
	if (!NSThread.isMainThread) return;
	if (_moving) return;
	
	// The parser changed a line with some text already on it into a scene heading, for example by by typing int. at the start of a line.
	NSRange range = NSMakeRange(line.position, line.string.length - 1);
	
	// This can happen when moving strings, ignore
	if (range.location + range.length > self.textView.string.length) return;
	
	NSString *string = [self.textView.textStorage.string substringWithRange:range];

	[self.undoManager beginUndoGrouping];
	[self.undoManager registerUndoWithTarget:self handler:^(id _Nonnull target) {
		[self replaceCharactersInRange:range withString:string];
		[self.textView setSelectedRange:NSMakeRange(range.location, 0)];
	}];
	[self.undoManager endUndoGrouping];
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
	if (self.textView.selectedRange.location >= line.position && self.textView.selectedRange.location <= line.position + [line.string length]) return YES;
	else return NO;
}

/*
 
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

static NSString *lineBreak = @"\n\n===\n\n";
static NSString *boldSymbol = @"**";
static NSString *italicSymbol = @"*";
static NSString *underlinedSymbol = @"_";
static NSString *noteOpen = @"[[";
static NSString *noteClose= @"]]";
static NSString *omitOpen = @"/*";
static NSString *omitClose= @"*/";
static NSString *forceHeadingSymbol = @".";
static NSString *forceActionSymbol = @"!";
static NSString *forceCharacterSymbol = @"@";
static NSString *forcetransitionLineSymbol = @">";
static NSString *forceLyricsSymbol = @"~";
static NSString *forceDualDialogueSymbol = @"^";

static NSString *highlightSymbolOpen = @"<<";
static NSString *highlightSymbolClose = @">>";
static NSString *strikeoutSymbolOpen = @"{{";
static NSString *strikeoutSymbolClose = @"}}";

static NSString *tagAttribute = @"BeatTag";
static NSString *revisionAttribute = @"Revision";

- (NSString*)titlePage
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd.MM.yyyy"];
    return [NSString stringWithFormat:@"Title: \nCredit: \nAuthor: \nDraft date: %@\nContact: \n\n", [dateFormatter stringFromDate:[NSDate date]]];
}


- (IBAction)addTitlePage:(id)sender
{
    if ([self selectedTab] == 0) {
        if ([[self getText] length] < 6) {
            [self addString:[self titlePage] atIndex:0];
            self.textView.selectedRange = NSMakeRange(7, 0);
        } else if (![[[self getText] substringWithRange:NSMakeRange(0, 6)] isEqualToString:@"Title:"]) {
            [self addString:[self titlePage] atIndex:0];
        }
    }
}

- (IBAction)dualDialogue:(id)sender {
	_currentLine = [self getCurrentLine];
	
	// Current line is character
	if (_currentLine.type == character) {
		// We won't allow making a first dialogue block dual, let's see if there is another block of dialogue
		NSInteger index = [_parser.lines indexOfObject:_currentLine] - 1;
		bool previousDialogueFound = NO;
		
		while (index >= 0) {
			Line* previousLine = [_parser.lines objectAtIndex:index];
			if (previousLine.type == character) { previousDialogueFound = YES; break; }
			if ((previousLine.type == action && previousLine.string.length > 0) || previousLine.type == heading) break;
			index--;
		}
		
		if (previousDialogueFound) [self addString:forceDualDialogueSymbol atIndex:_currentLine.position + _currentLine.string.length];
	
	// if it's already a dual dialogue cue, remove the symbol
	} else if (_currentLine.type == dualDialogueCharacter) {
		NSRange range = [_currentLine.string rangeOfString:forceDualDialogueSymbol];
		// Remove symbol
		[self removeString:forceDualDialogueSymbol atIndex:_currentLine.position + range.location];
		
	// Dialogue block. Find the character cue and add/remove dual dialogue symbol
	} else if (_currentLine.type == dialogue ||
			   _currentLine.type == dualDialogue ||
			   _currentLine.type == parenthetical ||
			   _currentLine.type == dualDialogueParenthetical) {
		NSInteger index = [_parser.lines indexOfObject:_currentLine] - 1;
		while (index >= 0) {
			Line* previousLine = [_parser.lines objectAtIndex:index];

			if (previousLine.type == character) {
				// Add
				[self addString:forceDualDialogueSymbol atIndex:previousLine.position + previousLine.string.length];
				break;
			}
			if (previousLine.type == dualDialogueCharacter) {
				// Remove
				NSRange range = [previousLine.string rangeOfString:forceDualDialogueSymbol];
				[self removeString:forceDualDialogueSymbol atIndex:previousLine.position + range.location];
				break;
			}
			index--;
		}
	}
}

- (IBAction)addPageBreak:(id)sender
{
    if ([self selectedTab] == 0) {
		NSRange cursorLocation = self.selectedRange;
        if (cursorLocation.location != NSNotFound) {
            //Step forward to end of line
            NSUInteger location = cursorLocation.location + cursorLocation.length;
            NSUInteger length = [[self getText] length];
            while (true) {
                if (location == length) {
                    break;
                }
                NSString *nextChar = [[self getText] substringWithRange:NSMakeRange(location, 1)];
                if ([nextChar isEqualToString:@"\n"]) {
                    break;
                }
                
                location++;
            }
            self.textView.selectedRange = NSMakeRange(location, 0);
            [self addString:lineBreak atIndex:location];
        }
    }
}

- (IBAction)makeBold:(id)sender
{
	// Only allow this for editor view
    if ([self selectedTab] == 0) {
		NSRange range = [self rangeUntilLineBreak:self.selectedRange];
        [self format:range beginningSymbol:boldSymbol endSymbol:boldSymbol];
    }
}

- (IBAction)makeItalic:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTab] == 0) {
        //Retreiving the cursor location
		NSRange range = [self rangeUntilLineBreak:self.selectedRange];
        [self format:range beginningSymbol:italicSymbol endSymbol:italicSymbol];
    }
}

- (IBAction)makeUnderlined:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTab] == 0) {
        //Retreiving the cursor location
		NSRange range = [self rangeUntilLineBreak:self.selectedRange];
        [self format:range beginningSymbol:underlinedSymbol endSymbol:underlinedSymbol];
    }
}


- (IBAction)makeNote:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTab] == 0) {
        //Retreiving the cursor location
		NSRange range = [self rangeUntilLineBreak:self.selectedRange];
        [self format:range beginningSymbol:noteOpen endSymbol:noteClose];
    }
}

- (IBAction)makeOmitted:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTab] == 0) {
        //Retreiving the cursor location
		NSRange cursorLocation = self.selectedRange;
        [self format:cursorLocation beginningSymbol:omitOpen endSymbol:omitClose];
    }
}

- (void)format:(NSRange)cursorLocation beginningSymbol:(NSString*)beginningSymbol endSymbol:(NSString*)endSymbol
{
    //Checking if the cursor location is vaild
    if (cursorLocation.location  + cursorLocation.length <= [[self getText] length]) {
        //Checking if the selected text is allready formated in the specified way
        NSString *selectedString = [self.textView.string substringWithRange:cursorLocation];
        NSInteger selectedLength = [selectedString length];
        NSInteger symbolLength = [beginningSymbol length] + [endSymbol length];
        
        NSInteger addedCharactersBeforeRange;
        NSInteger addedCharactersInRange;
        
        if (selectedLength >= symbolLength &&
            [[selectedString substringToIndex:[beginningSymbol length]] isEqualToString:beginningSymbol] &&
            [[selectedString substringFromIndex:selectedLength - [endSymbol length]] isEqualToString:endSymbol]) {
            
            //The Text is formated, remove the formatting
            [self replaceCharactersInRange:cursorLocation
                                withString:[selectedString substringWithRange:NSMakeRange([beginningSymbol length],
                                                                                          selectedLength - [beginningSymbol length] - [endSymbol length])]];
            //Put a corresponding undo action
            [[[self undoManager] prepareWithInvocationTarget:self] format:NSMakeRange(cursorLocation.location,
                                                                                      cursorLocation.length - [beginningSymbol length] - [endSymbol length])
                                                          beginningSymbol:beginningSymbol
                                                                endSymbol:endSymbol];
            addedCharactersBeforeRange = 0;
            addedCharactersInRange = -([beginningSymbol length] + [endSymbol length]);
        } else {
            //The Text isn't formated, but let's alter the cursor range and check again because there might be formatting right outside the selected area
            NSRange modifiedCursorLocation = cursorLocation;
            
            if (cursorLocation.location >= [beginningSymbol length] &&
                (cursorLocation.location + cursorLocation.length) <= ([[self getText] length] - [endSymbol length])) {
                
                if (modifiedCursorLocation.location + modifiedCursorLocation.length + [endSymbol length] - 1 <= [[self getText] length]) {
                    modifiedCursorLocation = NSMakeRange(modifiedCursorLocation.location - [beginningSymbol length],
                                                         modifiedCursorLocation.length + [beginningSymbol length]  + [endSymbol length]);
                }
            }
            NSString *newSelectedString = [self.textView.string substringWithRange:modifiedCursorLocation];
            //Repeating the check from above
            if ([newSelectedString length] >= symbolLength &&
                [[newSelectedString substringToIndex:[beginningSymbol length]] isEqualToString:beginningSymbol] &&
                [[newSelectedString substringFromIndex:[newSelectedString length] - [endSymbol length]] isEqualToString:endSymbol]) {
                
                //The Text is formated outside of the original selection, remove!!!
                [self replaceCharactersInRange:modifiedCursorLocation
                                    withString:[newSelectedString substringWithRange:NSMakeRange([beginningSymbol length],
                                                                                                 [newSelectedString length] - [beginningSymbol length] - [endSymbol length])]];
                [[[self undoManager] prepareWithInvocationTarget:self] format:NSMakeRange(modifiedCursorLocation.location,
                                                                                          modifiedCursorLocation.length - [beginningSymbol length] - [endSymbol length])
                                                              beginningSymbol:beginningSymbol
                                                                    endSymbol:endSymbol];
                addedCharactersBeforeRange = - [beginningSymbol length];
                addedCharactersInRange = 0;
            } else {
                //The text really isn't formatted. Just add the formatting using the original data.
                [self replaceCharactersInRange:NSMakeRange(cursorLocation.location + cursorLocation.length, 0)
                                    withString:endSymbol];
                [self replaceCharactersInRange:NSMakeRange(cursorLocation.location, 0)
                                    withString:beginningSymbol];
                [[[self undoManager] prepareWithInvocationTarget:self] format:NSMakeRange(cursorLocation.location,
                                                                                          cursorLocation.length + [beginningSymbol length] + [endSymbol length])
                                                              beginningSymbol:beginningSymbol
                                                                    endSymbol:endSymbol];
                addedCharactersBeforeRange = [beginningSymbol length];
                addedCharactersInRange = 0;
            }
        }
        self.textView.selectedRange = NSMakeRange(cursorLocation.location+addedCharactersBeforeRange, cursorLocation.length+addedCharactersInRange);
    }
}

- (void) forceElement:(NSString*)element {
	if ([element isEqualToString:@"Action"]) [self forceAction:self];
	else if ([element isEqualToString:@"Scene Heading"]) [self forceHeading:self];
	else if ([element isEqualToString:@"Character"]) [self forceCharacter:self];
	else if ([element isEqualToString:@"Lyrics"]) [self forceLyrics:self];
	else if ([element isEqualToString:@"Transition"]) [self forceTransition:self];
}

- (IBAction)forceHeading:(id)sender
{
	NSRange cursorLocation = self.selectedRange;
	[self forceLineType:cursorLocation symbol:forceHeadingSymbol];
}

- (IBAction)forceAction:(id)sender
{
	NSRange cursorLocation = self.selectedRange;
	[self forceLineType:cursorLocation symbol:forceActionSymbol];
}

- (IBAction)forceCharacter:(id)sender
{
	NSRange cursorLocation = self.selectedRange;
	[self forceLineType:cursorLocation symbol:forceCharacterSymbol];
}

- (IBAction)forceTransition:(id)sender
{
	NSRange cursorLocation = self.selectedRange;
	[self forceLineType:cursorLocation symbol:forcetransitionLineSymbol];
}

- (IBAction)forceLyrics:(id)sender
{
	NSRange cursorLocation = self.selectedRange;
	[self forceLineType:cursorLocation symbol:forceLyricsSymbol];
}

- (void)forceLineType:(NSRange)cursorLocation symbol:(NSString*)symbol
{
	// Only allow this for editor view
	if ([self selectedTab] != 0) return;
	
    //Find the index of the first symbol of the line
    NSUInteger indexOfLineBeginning = cursorLocation.location;
    while (true) {
        if (indexOfLineBeginning == 0) {
            break;
        }
        NSString *characterBefore = [[self getText] substringWithRange:NSMakeRange(indexOfLineBeginning - 1, 1)];
        if ([characterBefore isEqualToString:@"\n"]) {
            break;
        }
        
        indexOfLineBeginning--;
    }
	
    NSRange firstCharacterRange;
	
    // If the cursor resides in an empty line
    // (because the beginning of the line is the end of the document or is indicated by the next character being a newline)
    // The range for the first charater in line needs to be an empty string
	
    if (indexOfLineBeginning == [[self getText] length]) {
        firstCharacterRange = NSMakeRange(indexOfLineBeginning, 0);
    } else if ([[[self getText] substringWithRange:NSMakeRange(indexOfLineBeginning, 1)] isEqualToString:@"\n"]){
        firstCharacterRange = NSMakeRange(indexOfLineBeginning, 0);
    } else {
        firstCharacterRange = NSMakeRange(indexOfLineBeginning, 1);
    }
    NSString *firstCharacter = [[self getText] substringWithRange:firstCharacterRange];
    
    // If the line is already forced to the desired type, remove the force
    if ([firstCharacter isEqualToString:symbol]) {
		[self replaceString:firstCharacter withString:@"" atIndex:firstCharacterRange.location];
    } else {
        // If the line is not forced to the desired type, check if it is forced to be something else
        BOOL otherForce = NO;
        
        NSArray *allForceSymbols = @[forceActionSymbol, forceCharacterSymbol, forceHeadingSymbol, forceLyricsSymbol, forcetransitionLineSymbol];
        
        for (NSString *otherSymbol in allForceSymbols) {
            if (otherSymbol != symbol && [firstCharacter isEqualToString:otherSymbol]) {
                otherForce = YES;
                break;
            }
        }
        
        //If the line is forced to be something else, replace that force with the new force
        //If not, insert the new character before the first one
        if (otherForce) {
            [self replaceString:firstCharacter withString:symbol atIndex:firstCharacterRange.location];
        } else {
			[self addString:symbol atIndex:firstCharacterRange.location];
        }
    }
}

- (IBAction)addHighlight:(id)sender {
	// Only allow this for editor view
	if ([self selectedTab] != 0) return;
	NSRange range = [self rangeUntilLineBreak:self.selectedRange];
	[self format:range beginningSymbol:highlightSymbolOpen endSymbol:highlightSymbolClose];
}
- (IBAction)addStrikeout:(id)sender {
	// Only allow this for editor view
	if ([self selectedTab] != 0) return;
	NSRange range = [self rangeUntilLineBreak:self.selectedRange];
	[self format:range beginningSymbol:strikeoutSymbolOpen endSymbol:strikeoutSymbolClose];
}
- (NSRange)rangeUntilLineBreak:(NSRange)range {
	NSString *text = [self.getText substringWithRange:range];
	if ([text rangeOfString:@"\n"].location != NSNotFound) {
		NSInteger lineBreakIndex = [text rangeOfString:@"\n"].location;
		return (NSRange){ range.location, lineBreakIndex };
	} else {
		return range;
	}
}

#pragma mark - Edit Tracking

- (void)setupRevision {
	_revisionColor = [_documentSettings getString:DocSettingRevisionColor];
	if (![_revisionColor isKindOfClass:NSString.class]) _revisionColor = @"";
	if (!_revisionColor) _revisionColor = @"";
		
	NSDictionary *revisions = [_documentSettings get:DocSettingRevisions];
	
	for (NSString *key in revisions.allKeys) {
		NSArray *items = revisions[key];
		for (NSArray *item in items) {
			NSString *color;
			NSInteger loc = [(NSNumber*)item[0] integerValue];
			NSInteger len = [(NSNumber*)item[1] integerValue];
			
			// Load color if available
			if (item.count > 2) {
				color = item[2];
			}
			
			// Ensure the revision is in range and then paint it 
			if (len > 0 && loc + len <= self.getText.length) {
				RevisionType type;
				NSRange range = (NSRange){loc, len};
				if ([key isEqualToString:@"Addition"]) type = RevisionAddition;
				else if ([key isEqualToString:@"Removal"]) type = RevisionRemoval;
				else type = RevisionNone;
				
				BeatRevisionItem *revisionItem = [BeatRevisionItem type:type color:color];
				if (revisionItem) [self.textView.textStorage addAttribute:revisionAttribute value:revisionItem range:range];
			}
		}
	}
	
	bool revisionMode = [_documentSettings getBool:DocSettingRevisionMode];
	if (revisionMode) {
		self.trackChanges = YES;
		[self updateQuickSettings];
	}
}

- (IBAction)markAddition:(id)sender
{
	[self markerAction:RevisionAddition];
}
- (IBAction)markRemoval:(id)sender
{
	[self markerAction:RevisionRemoval];
}
- (IBAction)clearMarkings:(id)sender {
	[self markerAction:RevisionNone];
}
- (void)markerAction:(RevisionType)type {
	// Only allow this for editor view
	if ([self selectedTab] != 0) return;
	
	NSRange range = [self selectedRange];
	if (range.length == 0) return;

	NSDictionary *oldAttributes = [self.textView.attributedString attributesAtIndex:range.location longestEffectiveRange:nil inRange:range];
	
	if (type == RevisionRemoval) [self markRangeForRemoval:range];
	else if (type == RevisionAddition) [self markRangeAsAddition:range];
	else [self clearReviewMarkers:range];
	
	[self.textView setSelectedRange:(NSRange){range.location + range.length, 0}];
	[self updateChangeCount:NSChangeDone];
	[self updatePreview];
		
	// Create an undo step
	[self.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
		[self.textView.textStorage setAttributes:oldAttributes range:range];
	}];
}

- (void)markRangeAsAddition:(NSRange)range {
	BeatRevisionItem *revision = [BeatRevisionItem type:RevisionAddition color:_revisionColor];
	if (revision) [_textView.textStorage addAttribute:revisionAttribute value:revision range:range];
	[self forceFormatChangesInRange:range];
}
- (void)markRangeForRemoval:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionRemoval];
	if (revision) [_textView.textStorage addAttribute:revisionAttribute value:revision range:range];
	[self forceFormatChangesInRange:range];
}
- (void)clearReviewMarkers:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionNone];
	if (revision) [_textView.textStorage addAttribute:revisionAttribute value:revision range:range];
	[self forceFormatChangesInRange:range];
}

-(IBAction)toggleTrackChanges:(id)sender {
	_trackChanges = !_trackChanges;
	[self updateQuickSettings];
	
	[_documentSettings setBool:DocSettingRevisionMode as:_trackChanges];
}

- (void)saveRevisionRanges {
	// This saves the review ranges into Document Settings
	NSDictionary *ranges = [BeatRevisionTracking rangesForSaving:self.textView.attributedString];
	
	[_documentSettings set:DocSettingRevisions as:ranges];
	[_documentSettings setString:DocSettingRevisionColor as:_revisionColor];
}
- (IBAction)selectRevisionColor:(id)sender {
	NSPopUpButton *button = sender;
	_revisionColor = button.selectedItem.title.lowercaseString;
	
	[_documentSettings setString:DocSettingRevisionColor as:_revisionColor];
}
- (IBAction)commitChanges:(id)sender {
	NSAttributedString *attrStr = self.textView.attributedString;

	// Bake revision ranges into lines
	[attrStr enumerateAttribute:revisionAttribute inRange:(NSRange){0, attrStr.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *item = value;
		
		if (item.type == RevisionRemoval) {
			NSArray *lines = [self.parser linesInRange:range];
			for (Line* line in lines) {
				NSRange lineRange = [line globalRangeToLocal:range];
				if (!line.removalRanges) line.removalRanges = [NSMutableIndexSet indexSet];
				[line.removalRanges addIndexesInRange:lineRange];
			}
		}
	}];
	
	
	for (Line *line in [NSArray arrayWithArray:self.parser.lines]) {
		NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
		
		if (line.removalRanges.count) {
			[line.removalRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
				[indices addIndexesInRange:range];
			}];
		}
		
		if (indices.count) {
			NSMutableString *string = [NSMutableString string];
			NSMutableIndexSet *result = [NSMutableIndexSet indexSetWithIndexesInRange:(NSRange){0, line.string.length}];
			[result removeIndexes:indices];
			
			[result enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
				[string appendString:[line.string substringWithRange:range]];
			}];
			
			// Remove resulting double spaces and add a line break for the editor
			[string replaceOccurrencesOfString:@"  " withString:@" " options:0 range:(NSRange){0, string.length}];
			[string appendString:@"\n"];
			
			[self replaceRange:line.range withString:string];
		}
	}
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
			if (![line omitted]) {
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
	NSString *sceneNumberPatternString = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPatternString];
	
	NSError *error = nil;
	NSRegularExpression *sceneNumberPattern = [NSRegularExpression regularExpressionWithPattern: @" (\\#([0-9A-Za-z\\.\\)-]+)\\#)" options: NSRegularExpressionCaseInsensitive error: &error];
	
	_sceneNumberLabelUpdateOff = true;
	for (OutlineScene * scene in self.parser.scenes) {
		if ([testSceneNumber evaluateWithObject:scene.line.string]) {
			NSArray * results = [sceneNumberPattern matchesInString:scene.line.string options: NSMatchingReportCompletion range:NSMakeRange(0, [scene.line.string length])];
			if ([results count]) {
				NSTextCheckingResult * result = [results objectAtIndex:0];
				NSRange sceneNumberRange = NSMakeRange(scene.line.position + result.range.location, result.range.length);
				[self replaceCharactersInRange:sceneNumberRange withString:@""];
			}
		}
	}
	
	_sceneNumberLabelUpdateOff = false;
	[self ensureLayout];
}


- (IBAction)lockSceneNumbers:(id)sender
{
	NSString *originalText = [NSString  stringWithString:[self getText]];
	NSMutableString *text = [NSMutableString string];
	
	NSInteger sceneNumber = [self.documentSettings getInt:@"Scene Numbering Starts From"];
	if (sceneNumber == 0) sceneNumber = 1;
	
	for (Line* line in self.parser.lines) {
		if (line.type != heading) [text appendFormat:@"%@\n", line.string];
		else {
			if (line.sceneNumberRange.length == 0) {
				[text appendFormat:@"%@ #%lu#\n", line.string, sceneNumber];
				sceneNumber++;
			} else {
				[text appendFormat:@"%@\n", line.string];
			}
		}
	}
	
	[self.undoManager disableUndoRegistration];
	
	[self.textView replaceCharactersInRange:NSMakeRange(0, self.textView.string.length) withString:text];
	[self.parser parseText:text];
	[self applyFormatChanges];
	
	[self ensureLayout];
	[self.undoManager enableUndoRegistration];
	
	[[[self undoManager] prepareWithInvocationTarget:self] undoSceneNumbering:originalText];
	
	[self.parser createOutline];
	[self updateSceneNumberLabels:0];
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
	[self updateSceneNumberLabels:0];
}


#pragma mark - Menus

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}
- (IBAction)export:(id)sender {}

- (void)setupMenuItems {
	// Menu items which need to check their on/off state against bool properties in this class
	_itemsToValidate = @[
		[ValidationItem newItem:@"Match Parentheses" setting:@"matchParentheses" target:self],
		[ValidationItem newItem:@"Automatic Paragraph Breaks" setting:@"autoLineBreaks" target:self],
		[ValidationItem newItem:@"Show Scene Numbers" setting:@"showSceneNumberLabels" target:self],
		[ValidationItem newItem:@"Show Page Numbers" setting:@"showPageNumbers" target:self],
		[ValidationItem newItem:@"Typewriter Mode" setting:@"typewriterMode" target:self],
		[ValidationItem newItem:@"Print Automatic Scene Numbers" setting:@"printSceneNumbers" target:self],
		[ValidationItem newItem:@"Show Outline" setting:@"outlineViewVisible" target:self],
		[ValidationItem newItem:@"Show Timeline" setting:@"timelineVisible" target:self],
		[ValidationItem newItem:@"Autosave" setting:@"autosave" target:self],
		[ValidationItem newItem:@"Revision Mode" setting:@"trackChanges" target:self],
	];
}
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Special conditions for other than normal edit view
	if ([self selectedTab] != 0) {
		// If PRINT PREVIEW is enabled
		if ([self selectedTab] == 1 && [menuItem.title isEqualToString:@"Show Preview"]) {
			[menuItem setState:NSOnState];
			return YES;
		}

		// If CARD VIEW is enabled
		if ([self selectedTab] == 2) {
			//
			if ([menuItem.title isEqualToString:@"Show Index Cards"]) {
				menuItem.state = NSOnState;
				return YES;
			}
			
			// Allow undoing scene move in card view, but nothing else
			if ([menuItem.title rangeOfString:@"Undo"].location != NSNotFound) {
				if ([[self.undoManager undoActionName] isEqualToString:@"Move Scene"]) {
					menuItem.title = [NSString stringWithFormat:@"Undo %@", [self.undoManager undoActionName]];
					return YES;
				}
			}
			
			// Allow redoing, too
			if ([menuItem.title rangeOfString:@"Redo"].location != NSNotFound) {
				if ([[self.undoManager redoActionName] isEqualToString:@"Move Scene"]) {
					menuItem.title = [NSString stringWithFormat:@"Redo %@", [self.undoManager redoActionName]];
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
	
	// Validate on/off items
	for (ValidationItem *item in _itemsToValidate) {
		if ([menuItem.title isEqualTo:item.title]) {
			bool on = [item validate];
			if (on) [menuItem setState:NSOnState];
			else [menuItem setState:NSOffState];
		}
	}
	
	if (_mode == TaggingMode) {
		NSArray *markerMenuItems = @[@"Mark as Revised", @"Mark for Removal", @"Clear Markers"];
		if ([markerMenuItems containsObject:menuItem.title]) return NO;
	}
	
	if ([menuItem.title isEqualToString:@"Tagging Mode"]) {
		if (_mode == TaggingMode) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
		
	} else if ([menuItem.title isEqualToString:@"Autosave"]) {
		if (_autosave) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
		
	} else if ([menuItem.title isEqualToString:@"Dark Mode"]) {
		if ([(ApplicationDelegate *)[NSApp delegate] isDark]) [menuItem setState:NSOnState];
		else [menuItem setState:NSOffState];
	
	} else if ([menuItem.title isEqualToString:@"Share"]) {
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
        if ([services count] == 0) {
            NSMenuItem *noThingPleaseSaveItem = [[NSMenuItem alloc] initWithTitle:@"Please save the file to share" action:nil keyEquivalent:@""];
            noThingPleaseSaveItem.enabled = NO;
            [menuItem.submenu addItem:noThingPleaseSaveItem];
        }
		
	} else if ([menuItem.title isEqualToString:@"Print…"] || [menuItem.title isEqualToString:@"Create PDF"] || [menuItem.title isEqualToString:@"HTML"]) {
		// Some magic courtesy of Hendrik Noeller
        NSArray* words = [[self getText] componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString* visibleCharacters = [words componentsJoinedByString:@""];
        if ([visibleCharacters length] == 0) return NO;
		
	} else if ([menuItem.title isEqualToString:@"Dual Dialogue"]) {
		if (_currentLine.type == character ||
			_currentLine.type == dialogue ||
			_currentLine.type == parenthetical ||
			_currentLine.type == dualDialogueCharacter ||
			_currentLine.type == dualDialogueParenthetical ||
			_currentLine.type == dualDialogue) return YES;
		else return NO;
		
    } else if ([menuItem.title isEqualToString:@"Show Index Cards"]) {
		menuItem.state = NSOffState;
	}
	
	// So, I have overriden everything regarding undo (because I couldn't figure it out).
	// That's why we need to handle enabling/disabling undo manually. This sucks.
	else if ([menuItem.title rangeOfString:@"Undo"].location != NSNotFound) {
		menuItem.title = [NSString stringWithFormat:@"Undo %@", [self.undoManager undoActionName]];
		if (![self.undoManager canUndo]) return NO;
	}
	else if ([menuItem.title rangeOfString:@"Redo"].location != NSNotFound) {
		menuItem.title = [NSString stringWithFormat:@"Redo %@", [self.undoManager redoActionName]];
		if (![self.undoManager canRedo]) return NO;
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
    [[NSUserDefaults standardUserDefaults] setBool:self.matchParentheses forKey:MATCH_PARENTHESES_KEY];
}

- (IBAction)togglePageNumbers:(id)sender {
	self.showPageNumbers = !self.showPageNumbers;
	[[NSUserDefaults standardUserDefaults] setBool:self.showPageNumbers forKey:SHOW_PAGENUMBERS_KEY];
	
	if (self.showPageNumbers) [self paginateAt:(NSRange){ 0,0 } sync:YES];
	else {
		self.textView.pageBreaks = nil;
		[self.textView deletePageNumbers];
	}
	
	[self updateQuickSettings];
}
- (void)setPrintSceneNumbers:(bool)value {
	_printSceneNumbers = value;
	[[NSUserDefaults standardUserDefaults] setBool:self.printSceneNumbers forKey:PRINT_SCENE_NUMBERS_KEY];
}
- (IBAction)togglePrintSceneNumbers:(id)sender
{
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	for (Document* doc in openDocuments) {
		doc.printSceneNumbers = !doc.printSceneNumbers;
	}
	[[NSUserDefaults standardUserDefaults] setBool:self.printSceneNumbers forKey:PRINT_SCENE_NUMBERS_KEY];
}
- (void)setRevisedPageColor:(NSString*)color {
	[_documentSettings setString:DocSettingRevisedPageColor as:color];
}
- (void)setColorCodePages:(bool)value {
	[_documentSettings setBool:DocSettingColorCodePages as:value];
}

#pragma mark - Themes & UI outlook

- (IBAction)toggleNightMode:(id)sender {
	[(ApplicationDelegate *)NSApp.delegate toggleDarkMode];
	
	[self updateUIColors];

	[self.textView toggleDarkPopup:nil];
	_darkPopup = [self isDark];
}
- (bool)isDark {
	return [(ApplicationDelegate *)[NSApp delegate] isDark];
}

- (void)updateUIColors {
	[self.thisWindow setViewsNeedDisplay:true];
	
	[self.masterView setNeedsDisplayInRect:[_masterView frame]];
	[self.backgroundView setNeedsDisplay:true];
	[self.textScrollView setNeedsDisplay:true];
	[self.marginView setNeedsDisplay:true];
	
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
	[self.textView drawViewBackgroundInRect:self.textView.bounds];
	[self.textView setNeedsDisplay:true];
	
	[self.textScrollView layoutButtons];

	[self resetSceneNumberLabels];
	
	if (_outlineViewVisible) [self.outlineView setNeedsDisplay:YES];
	
	//[self.textView setNeedsDisplay:true];
	
	[self.textView redrawUI];
}


// Some weirdness because of the Writer legacy. Writer had real themes, and this function loaded the selected theme for every open window. We only have day/night, but the method names remain.
- (void)updateTheme {
	[self setThemeFor:self setTextColor:NO];
}

- (void)setThemeFor:(Document*)doc setTextColor:(bool)setTextColor {
	if (!doc) doc = self;
	
	[doc.textView setMarginColor:[self.themeManager currentMarginColor]];
	
	[doc.textView setSelectedTextAttributes:@{
										  NSBackgroundColorAttributeName: [self.themeManager currentSelectionColor],
										  NSForegroundColorAttributeName: [self.themeManager currentBackgroundColor]
	}];
	
	if (setTextColor) [doc.textView setTextColor:[self.themeManager currentTextColor]];
	else {
		[self.textView setNeedsLayout:YES];
		[self.textView setNeedsDisplay:YES];
		[self.textView setNeedsDisplayInRect:self.textView.frame avoidAdditionalLayout:YES];
	}
	[doc.textView setInsertionPointColor:self.themeManager.caretColor];
			
	// Set global background
	doc.backgroundView.fillColor = self.themeManager.currentOutlineBackground;
	//_outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
	
	// Margins are drawn in a separate view
	doc.marginView.backgroundColor = self.themeManager.currentBackgroundColor;
	doc.marginView.marginColor = self.themeManager.currentMarginColor;
	
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
	[[NSUserDefaults standardUserDefaults] setBool:self.typewriterMode forKey:TYPERWITER_KEY];
	
	[self updateLayout];
}
- (void)typewriterScroll {
	if (self.textView.needsLayout) [self.textView layout];

	// So, we'll try to center the caret.
	// Trouble is, line heights get fucked up for some reason. This probably needs some sort of hack :-(
	
	NSRange range = [[self.textView layoutManager] glyphRangeForCharacterRange:self.textView.selectedRange actualCharacterRange:nil];
	NSRect rect = [[self.textView layoutManager] boundingRectForGlyphRange:range inTextContainer:[self.textView textContainer]];

	CGFloat scrollY = (rect.origin.y - self.fontSize / 2 - 10) * _magnification;
	/*
	// Fix some silliness
	CGFloat boundsY = self.textClipView.bounds.size.height + self.textClipView.bounds.origin.y;
	CGFloat maxY = self.textView.frame.size.height;
	CGFloat pixelsToBottom = maxY - boundsY;
	if (pixelsToBottom < self.fontSize * _magnification * 0.5 && pixelsToBottom > 0) {
		scrollY -= 5 * _magnification;
	}
	NSLog(@"bounds - max = %f", maxY - boundsY);
	*/
	
	// Calculate container height with insets
	CGFloat containerHeight = [_textView.layoutManager usedRectForTextContainer:_textView.textContainer].size.height;
	containerHeight = containerHeight * _magnification + _textInsetY * 2 * _magnification;
		
	CGFloat delta = fabs(scrollY - self.textClipView.bounds.origin.y);
	
	if (scrollY < containerHeight && delta > self.fontSize * _magnification) {
		//scrollY = containerHeight - _textClipView.frame.size.height;
		[[self.textClipView animator] setBoundsOrigin:NSMakePoint(0, scrollY)];
	}
}


#pragma mark - Preview

- (void)setupPreview {
	[self.printWebView.configuration.userContentController addScriptMessageHandler:self name:@"selectSceneFromScript"];
	[self.printWebView.configuration.userContentController addScriptMessageHandler:self name:@"closePrintPreview"];
	
	[_printWebView loadHTMLString:@"<html><body style='background-color: #333; margin: 0;'><section style='margin: 0; padding: 0; width: 100%; height: 100vh; display: flex; justify-content: center; align-items: center; font-weight: 200; font-family: \"Helvetica Light\", Helvetica; font-size: .8em; color: #eee;'>Creating Print Preview...</section></body></html>" baseURL:nil];
	
	_preview = [[BeatPreview alloc] initWithDocument:self];
}

- (IBAction)preview:(id)sender
{
    if (self.selectedTab == 0) {
		// Do a synchronous refresh of the preview if the preview is not available
		if (_htmlString.length < 1 || !_previewUpdated) [self updatePreviewAndUI:YES];
		else {
			// So uh... yeah. Fuck commenting my code at this point.
			// (Thanks, past me. We will insert JS to automatically scroll to the edited scene.
			// HTML template has a placeholder for the inserted script, don't remove it.)
			
			// Create JS scroll function call and append it straight into the HTML
			self.outline = [self getOutlineItems];
			self.currentScene = [self getCurrentScene];
						
			NSString *scrollTo = [NSString stringWithFormat:@"<script>scrollToScene('%@');</script>", self.currentScene.sceneNumber];
			
			_htmlString = [_htmlString stringByReplacingOccurrencesOfString:@"<script name='scrolling'></script>" withString:scrollTo];
			[self.printWebView loadHTMLString:_htmlString baseURL:nil]; // Load HTML
			
			// Revert changes to the code (so we can replace the placeholder again,
			// if needed, without recreating the whole HTML)
			_htmlString = [_htmlString stringByReplacingOccurrencesOfString:scrollTo withString:@"<script name='scrolling'></script>"];
			
			// Evaluate JS in window to be sure it shows the correct scene
			[_printWebView evaluateJavaScript:[NSString stringWithFormat:@"scrollToScene(%@);", _currentScene.sceneNumber] completionHandler:nil];
		}
	
        [self setTab:1];
		_printPreview = YES;
    } else {
		[self setTab:0];
		[self updateLayout];
		[self ensureCaret];
		_printPreview = NO;
    }
}

- (void)updatePreview  {
	[self updatePreviewAndUI:NO];
}
- (void)updatePreviewAndUI:(bool)updateUI {
	// WORK IN PROGRESS // WIP WIP WIP
	// Update preview in background
	
	_attrTextCache = [[NSAttributedString alloc] initWithAttributedString:self.textView.attributedString];
	
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
		self.currentScene = [self getCurrentScene];
		
		NSString *rawText = [self getText];
		
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
			__block NSString *html = [self.preview createPreviewFor:rawText type:BeatPrintPreview];
			self.htmlString = html;
			
			self.previewUpdated = YES;
			
			if (updateUI || self.printPreview) {
				dispatch_async(dispatch_get_main_queue(), ^(void){
					//[[self.webView mainFrame] loadHTMLString:html baseURL:nil];
					NSString *scrollTo = [NSString stringWithFormat:@"<script>scrollToScene(%@);</script>", self.currentScene.sceneNumber];
					html = [html stringByReplacingOccurrencesOfString:@"<script name='scrolling'></script>" withString:scrollTo];
					[self.printWebView loadHTMLString:html baseURL:nil];
				});
			}
		});
	}];
}

- (void)deallocPreview {
	[self.printWebView.configuration.userContentController removeScriptMessageHandlerForName:@"selectSceneFromScript"];
	[self.printWebView.configuration.userContentController removeScriptMessageHandlerForName:@"closePrintPreview"];
	self.printWebView.navigationDelegate = nil;
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

#pragma  mark - Outline Functions

- (IBAction)toggleOutlineView:(id)sender
{
	self.outlineViewVisible = !self.outlineViewVisible;
	
	if (_outlineViewVisible) {
		[_outlineButton setState:NSOnState];
		
		// Show outline
		[self reloadOutline];
		[self collectCharacterNames]; // For filtering
		
		self.outlineView.enclosingScrollView.hasVerticalScroller = YES;
		
		if (![self isFullscreen]) {
			CGFloat sidebarWidth = self.outlineView.enclosingScrollView.frame.size.width;
			CGFloat newWidth = _thisWindow.frame.size.width + sidebarWidth;
			CGFloat newX = _thisWindow.frame.origin.x - sidebarWidth / 2;
			CGFloat screenWidth = [NSScreen mainScreen].frame.size.width;
						
			// Ensure the main document won't go out of screen bounds when opening the sidebar
			if (newWidth > screenWidth) {
				newWidth = screenWidth * .9;
				newX = screenWidth / 2 - newWidth / 2;
			}
			
			if (newX + newWidth > screenWidth) {
				newX = newX - (newX + newWidth - screenWidth);
			}
			
			if (newX < 0) {
				newX = 0;
			}
			
			NSRect newFrame = NSMakeRect(newX,
										 _thisWindow.frame.origin.y,
										 newWidth,
										 _thisWindow.frame.size.height);
			[_thisWindow setFrame:newFrame display:YES];
		}
		
		// Show sidebar
		[_splitHandle restoreBottomOrLeftView];
	} else {
		[_outlineButton setState:NSOffState];
		
		// Hide outline
		self.outlineView.enclosingScrollView.hasVerticalScroller = NO;
		
		if (![self isFullscreen]) {
			CGFloat sidebarWidth = self.outlineView.enclosingScrollView.frame.size.width;
			CGFloat newX = _thisWindow.frame.origin.x + sidebarWidth / 2;
			NSRect newFrame = NSMakeRect(newX,
										 _thisWindow.frame.origin.y,
										 _thisWindow.frame.size.width - sidebarWidth,
										 _thisWindow.frame.size.height);

			[_thisWindow setFrame:newFrame display:YES];
		}
		
		[_splitHandle collapseBottomOrLeftView];
	}
	
	// Fix layout
	[_thisWindow layoutIfNeeded];
	[self updateLayout];
}

- (void)setupOutlineView {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchOutline) name:NSControlTextDidChangeNotification object:self.outlineSearchField];
	[self hideFilterView];
}

- (NSMutableArray *)getOutlineItems {
	// Make a copy of the outline to avoid threading issues
	NSMutableArray * outlineItems = [NSMutableArray arrayWithArray:self.parser.outline];
	return outlineItems;
}

- (NSMutableArray*)filteredOutline {
	return self.outlineView.filteredOutline;
}

- (void)searchOutline {
	// This should probably be moved to BeatOutlineView, too.
	// Don't search if it's only spaces
	if ([_outlineSearchField.stringValue containsOnlyWhitespace] || [_outlineSearchField.stringValue length] < 1) {
        [self.outlineView.filters byText:@""];
	}
	
    [self.outlineView.filters byText:_outlineSearchField.stringValue];
    [self reloadOutline];
	
	// Mask scenes that were left out
	[self maskScenes];
}

#pragma mark - Outline View data source, delegation & other madness

/*
 
 Could we move all of this into another class? Just hook it in IB and so on.
 
 */

- (void)reloadOutline {
	// Create outline
	_outline = [self getOutlineItems];
	[self.outlineView reloadOutline];
	return;
}

- (void)scrollOutlineToCurrentScene:(OutlineScene*)scene {
	if (!scene) scene = _currentScene;
	
	// Check if we have filtering turned on, and do nothing if scene is not in the filter results
	if (self.filteredOutline.count) {
		if (![self.filteredOutline containsObject:scene]) return;
	}

	dispatch_async(dispatch_get_main_queue(), ^(void){
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
			context.allowsImplicitAnimation = YES;
			[self.outlineView scrollRowToVisible:[self.outlineView rowForItem:scene]];
		} completionHandler:NULL];
	});
}

- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to {
	// FOLLOWING CODE IS A MESS. Dread lightly.
	// Thanks for the heads up, past me, but I'll just dive right in
	
	// ... or not.
	// NOTE FROM BEAT 1.1 r4:
    // The scenes know if they miss omission begin / terminator. The trouble is, I have no idea how to put that information into use without dwelving into an endless labyrinth of string indexes... soooo... do it later?
	
	NSMutableArray *outline = [self getOutlineItems];
	
	bool moveToEnd = false;
	if (to >= [outline count]) {
		to = [outline count] - 1;
		moveToEnd = true;
	}
	
	// Scene before which this scene will be moved, if not moved to the end
	OutlineScene *sceneAfter;
	if (!moveToEnd) sceneAfter = [outline objectAtIndex:to];
	
	// On to the very dangerous stuff :-) fuck me :----)
	NSRange range = NSMakeRange(sceneToMove.position, sceneToMove.length);
	
	
	
	// Different ranges depending on to which direction the scene was moved
	/*
	NSRange newRange;
	if (from < to) {
		if (!moveToEnd) {
			newRange = NSMakeRange(sceneAfter.sceneStart - sceneToMove.sceneLength, 0);
		} else {
			newRange = NSMakeRange([[self getText] length] - sceneToMove.sceneLength, 0);
		}
	} else {
		newRange = NSMakeRange(sceneAfter.sceneStart, 0);
	}
	 */

	// We move the string itself in an easily undoable method
	//[self moveString:textToMove withRange:range newRange:newRange];
	
	if (!moveToEnd) {
		[self moveStringFrom:range to:sceneAfter.position];
	} else {
		[self moveStringFrom:range to:self.getText.length];
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

// We are using this same menu for both outline & timeline view
- (void) menuDidClose:(NSMenu *)menu {
	// Reset timeline selection, to be on the safe side
	_timelineClickedScene = -1;
}
- (void) menuNeedsUpdate:(NSMenu *)menu {
	id item = nil;
	
	if ([self.outlineView clickedRow] >= 0) {
		item = [self.outlineView itemAtRow:[self.outlineView clickedRow]];
		_timelineSelection = -1;
	} else if (_timelineClickedScene >= 0) {
		item = [[self getOutlineItems] objectAtIndex:_timelineClickedScene];
		_timelineSelection = _timelineClickedScene;
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

	for (NSString *color in [self colors]) {
		if ([_colorPicker.color isEqualTo:[BeatColors color:color]]) {
			pickedColor = color;
		}
	}
	
	if ([_colorPicker.color isEqualTo:NSColor.blackColor]) pickedColor = @"none"; // THE HOUSE IS BLACK.
	
	_currentScene = [self getCurrentScene];
	if (!_currentScene) return;
	
	if (pickedColor != nil) [self setColor:pickedColor forScene:_currentScene];

}

- (IBAction)setSceneColor:(id)sender {
	NSMenuItem *item = sender;
	NSString *colorName = item.title.uppercaseString;
	
	if (self.outlineView.clickedRow > -1) {
		id selectedScene = nil;
		selectedScene = [self.outlineView itemAtRow:self.outlineView.clickedRow];
		
		if (selectedScene != nil && [selectedScene isKindOfClass:[OutlineScene class]]) {
			OutlineScene *scene = selectedScene;
			[self setColor:colorName forScene:scene];
			if (_timelineClickedScene >= 0) [self reloadTimeline];
			if (self.timelineBar.visible) [self reloadTouchTimeline];
		}
		
		_timeline.clickedItem = nil;
		_timelineClickedScene = -1;
	}
}

- (void)setColor:(NSString *)color forScene:(OutlineScene *) scene {
	if (!scene) return;;
	
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
		if ([[color lowercaseString] isEqualToString:@"none"]) return; // Do nothing if set to none
		
		NSString * colorString = [NSString stringWithFormat:@" [[COLOR %@]]", color];
		NSUInteger position = scene.line.position + scene.line.string.length;
		
		_outlineEdit = YES;
		[self addString:colorString atIndex:position];
		_outlineEdit = NO;
	}

	return;
}

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene {
	if (scene.storylines.count > 0) {
		// Check if the storyline was already there
		if (![scene.storylines containsObject:storyline]) {
			NSArray *storylines = [scene.storylines arrayByAddingObject:storyline];
			[self setStorylines:storylines for:scene];
		}
	} else {
		[self setStorylines:@[storyline] for:scene];
	}
}
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene {
	if (scene.storylines.count > 0) {
		// Is the storyline there really?
		if ([scene.storylines containsObject:storyline]) {
			NSMutableArray *storylines = [NSMutableArray arrayWithArray:scene.storylines];
			[storylines removeObject:storyline];
			[self setStorylines:storylines for:scene];
		}
	}
}
- (void)setStorylines:(NSArray*)storylines for:(OutlineScene*)scene {
	// Create storyline list
	NSString *storylineString = [NSString stringWithFormat:@"[[STORYLINE %@]]", [storylines componentsJoinedByString:@", "]];
	
	// New storyline
	if (scene.storylines.count == 0 && storylines.count) {
		[self addString:[NSString stringWithFormat:@" %@", storylineString] atIndex:scene.line.position + scene.line.string.length];
	}
	// Remove all storylines
	else if (scene.storylines.count && storylines.count == 0) {
		[self removeString:[scene.line.string substringWithRange:scene.line.storylineRange] atIndex:scene.line.position + scene.line.storylineRange.location];
	}
	// Add storyline
	else if (scene.storylines.count && storylines.count) {
		[self replaceString:[scene.line.string substringWithRange:scene.line.storylineRange]
				 withString:storylineString
					atIndex:scene.line.position + scene.line.storylineRange.location];
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

// This stuff is a mess.

- (NSMutableArray*)lines {
	return self.parser.lines;
}

- (NSMutableArray *)scenes {
	return [self getOutlineItems];
}

#pragma mark - Card view

// I'm sorry, but this whole thing should be rewritten.
// I agree, a year later.

- (IBAction) toggleCards: (id)sender {
	if ([self selectedTab] != 2) {
		_cardsVisible = YES;
		
		[self refreshCards];
		[self setTab:2];
	} else {
		_cardsVisible = NO;
		
		// Reload outline + timeline in case there were any changes in outline
		if (_outlineViewVisible) [self reloadOutline];
		if (_timelineVisible) [self reloadTimeline];
		if (self.timelineBar.visible) [self reloadTouchTimeline];
		
		[self setTab:0];
		[self updateLayout];
		[self ensureCaret];
	}
}

- (void) setupCards {
	// Set up index card view
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"cardClick"];
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"setColor"];
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"move"];
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"printCards"];
	
	_sceneCards = [[SceneCards alloc] initWithWebView:_cardView];
	_sceneCards.delegate = self;
}
- (void) deallocCards {
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"cardClick"];
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"setColor"];
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"move"];
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"printCards"];
	
}

// This might be pretty shitty solution for my problem but whatever
- (OutlineScene *) findSceneByLine: (Line *) line {
	for (OutlineScene * scene in [self.parser outline]) {
		if (line == scene.line) return scene;
	}
	return nil;
}

- (void)refreshCards {
	// Refresh cards assuming the view isn't visible
	[self refreshCards:NO changed:-1];
}

- (void)refreshCards:(BOOL)alreadyVisible {
	// Just refresh cards, no change in index
	[self refreshCards:alreadyVisible changed:-1];
}

- (void)printCards {
	[_sceneCards printCardsWithInfo:[self.printInfo copy]];
	//[_sceneCards printCards:[self getSceneCards] printInfo:self.printInfo];
}
- (void) refreshCards:(BOOL)alreadyVisible changed:(NSInteger)changedIndex {
	// Change style in card view if needed
	if ([self isDark]) {
		[_cardView evaluateJavaScript:@"nightModeOn();" completionHandler:nil]; // THE HOUSE IS BLACK.
	} else {
		[_cardView evaluateJavaScript:@"nightModeOff();" completionHandler:nil];
	}
		
	[_sceneCards reloadCardsWithVisibility:alreadyVisible changed:changedIndex];
}


#pragma mark - JavaScript message listeners

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *) message{
	if ([message.body  isEqual: @"exit"]) {
		[self toggleCards:nil];
		return;
	}
	
	if ([message.name isEqualToString:@"closePrintPreview"]) {
		[self preview:nil];
		return;
	}
	
	if ([message.name isEqualToString:@"selectSceneFromScript"]) {
		NSInteger sceneIndex = [message.body integerValue];
		
		[self preview:nil];
		if (sceneIndex < [self getOutlineItems].count) {
			OutlineScene *scene = [[self getOutlineItems] objectAtIndex:sceneIndex];
			if (scene) [self scrollToScene:scene];
		}
	}
	
	if ([message.name isEqualToString:@"jumpToScene"]) {
		OutlineScene *scene = [[self getOutlineItems] objectAtIndex:[message.body intValue]];
		[self scrollToScene:scene];
		return;
	}
	
	if ([message.name isEqualToString:@"cardClick"]) {
		[self toggleCards:nil];
		OutlineScene *scene = [[self getOutlineItems] objectAtIndex:[message.body intValue]];
		[self scrollToScene:scene];
		
		return;
	}
	
	if ([message.name isEqualToString:@"printCards"]) {
		[self printCards];
	}
	
	// Move scene via card view
	if ([message.name isEqualToString:@"move"]) {
		if ([message.body rangeOfString:@","].location != NSNotFound) {
			NSArray *fromTo = [message.body componentsSeparatedByString:@","];
			if ([fromTo count] < 2) return;
			
			NSInteger from = [[fromTo objectAtIndex:0] integerValue];
			NSInteger to = [[fromTo objectAtIndex:1] integerValue];
			
			NSInteger changedIndex = -1;
			if (from < to) changedIndex = to -1; else changedIndex = to;
			
			NSMutableArray *outline = [self getOutlineItems];
			if ([outline count] < 1) return;
			
			OutlineScene *scene = [outline objectAtIndex:from];
			
			[self moveScene:scene from:from to:to];
			
			// Refresh the view, tell it's already visible
			[self refreshCards:YES changed:changedIndex];
			
			return;
		}
	}

	if ([message.name isEqualToString:@"setColor"]) {
		if ([message.body rangeOfString:@":"].location != NSNotFound) {
			NSArray *indexAndColor = [message.body componentsSeparatedByString:@":"];
			NSUInteger index = [[indexAndColor objectAtIndex:0] integerValue];
			NSString *color = [indexAndColor objectAtIndex:1];
			
			Line *line = [[self.parser lines] objectAtIndex:index];
			OutlineScene *scene = [self findSceneByLine:line];
			
			[self setColor:color forScene:scene];
		}
	}
	/*
	
	if ([message.name isEqualToString:@"setGender"]) {
		if ([message.body rangeOfString:@":"].location != NSNotFound) {
			NSArray *nameAndGender = [message.body componentsSeparatedByString:@":"];
			NSString *name = [nameAndGender objectAtIndex:0];
			NSString *gender = [nameAndGender objectAtIndex:1];
			[self setGenderFor:name gender:gender];
		}
	}
	 
	*/
}

#pragma mark - Scene numbering for NSTextView

- (IBAction)showSceneNumberStart:(id)sender {
	// Load previous setting
	if ([_documentSettings getInt:@"Scene Numbering Starts From"] > 0) {
		[_sceneNumberStartInput setIntegerValue:[_documentSettings getInt:@"Scene Numbering Starts From"]];
	}
	[_thisWindow beginSheet:_sceneNumberingPanel completionHandler:nil];
}
- (IBAction)closeSceneNumberStart:(id)sender {
	NSLog(@"close");
	[_thisWindow endSheet:_sceneNumberingPanel];
}
- (IBAction)applySceneNumberStart:(id)sender {
	if (_sceneNumberStartInput.integerValue > 1) {
		[_documentSettings setInt:@"Scene Numbering Starts From" as:_sceneNumberStartInput.integerValue];
	} else {
		[_documentSettings remove:@"Scene Numbering Starts From"];
	}
		
	// Rebuild outline everywhere
	[self.parser createOutline];
	[self reloadOutline];
	[self reloadTimeline];
	[self updateSceneNumberLabels:0];
	[self updateChangeCount:NSChangeDone];
	
	[_thisWindow endSheet:_sceneNumberingPanel];
}
- (NSInteger)sceneNumberingStartsFrom {
	return [self.documentSettings getInt:@"Scene Numbering Starts From"];
}
- (void)resetSceneNumberLabels {
	if (_sceneNumberLabelUpdateOff || !_showSceneNumberLabels) return;
	[self.textView resetSceneNumberLabels];
}
- (void)updateSceneNumberLabels:(NSInteger)changedIndex {
	if (_sceneNumberLabelUpdateOff || !_showSceneNumberLabels) return;
	[self.textView updateSceneLabelsFrom:changedIndex];
}

- (IBAction)toggleSceneLabels: (id) sender {
	self.showSceneNumberLabels = !self.showSceneNumberLabels;
	
	[[NSUserDefaults standardUserDefaults] setBool:self.showSceneNumberLabels forKey:SHOW_SCENE_LABELS_KEY];
	
	if (self.showSceneNumberLabels) [self ensureLayout];
	else [self.textView deleteSceneNumberLabels];
	
	// Update the print preview accordingly
	self.previewUpdated = NO;
	
	[self updateQuickSettings];
}

#pragma mark - Timeline + chronometry

/*
 
 Timeline has been rewritten to be a native Cocoa class instead of the
 javascript/webkit mess.
   
*/

- (IBAction)toggleTimeline:(id)sender
{
	_timelineVisible = !_timelineVisible;
	
	NSPoint scrollPosition = self.textScrollView.contentView.documentVisibleRect.origin;
		
	if (_timelineVisible) {
	
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

- (void) setupTouchTimeline {
	self.touchbarTimeline.delegate = self;
	self.touchbarTimelineButton.delegate = self;
}

- (void) setupTimeline {
	// New timeline
	_timeline.delegate = self;
	_timeline.heightConstraint = _timelineViewHeight;
	self.timeline.enclosingScrollView.hasHorizontalScroller = NO;
	
	[_timeline hide];
	_timelineClickedScene = -1;
}

- (void) reloadTimeline {
	[self.timeline reload];
	return;
}

/*
 
 nyt tulevaisuus
 on musta aukko
 nyt tulevaisuus
 on musta aukko
 
*/


#pragma mark - Timeline Delegation

- (void) reloadTouchTimeline {
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

- (IBAction)showAnalysis:(id)sender {
	_analysisWindow = [[BeatAnalysisPanel alloc] initWithParser:self.parser delegate:self];
	[_thisWindow beginSheet:_analysisWindow.window completionHandler:^(NSModalResponse returnCode) {
		self.analysisWindow = nil;
	}];
}

- (void) setupAnalysis {
	// N.B. Genders are saved locally in app preferences (for now - this could very well be saved into document settings, too)
	_characterGenders = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"CharacterGender"] objectForKey:[self fileNameString]];
}
- (void) saveGenders {
	// Get gender dictionary, which contains character genders according to FILE NAME
	// Like this: { @"YourFile.fountain": { @"Name": @"female" } }
	NSMutableDictionary *genderLists = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"CharacterGender"]];
	[genderLists setObject:_characterGenders forKey:[self fileNameString]];
	
	// Save the list
	[[NSUserDefaults standardUserDefaults] setObject:genderLists forKey:@"CharacterGender"];
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
		NSLog(@"masking: %@", scene.string);
		// Ignore this scene if it's contained in filtered scenes
		if ([self.filteredOutline containsObject:scene] || scene.type == section || scene.type == synopse) {
			NSLog(@" ... ignore");
			continue;
		}
		NSRange sceneRange = NSMakeRange([scene position], [scene length]);

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


- (NSArray*)onlyPrintableElements:(NSArray*)lines {
	NSMutableArray *result = [NSMutableArray array];
	
	bool hasDualDialogue = NO;
	for (Line* line in lines) {
		// Make a copy of the line so we don't fuck up the current parse
		if (line.type != empty && !line.omitted) {
			[result addObject:[line clone]];
			if (line.type == dualDialogueCharacter) hasDualDialogue = YES;
		}
	}
	
	// Perform quick & dirty fix for missing dual dialogue info
	if (hasDualDialogue) {
		for (Line* line in result) {
			if (line.type == dualDialogueCharacter) {
				NSInteger index = [result indexOfObject:line] - 1;
				while (index >= 0) {
					Line *preceedingLine = [result objectAtIndex:index];
					if (preceedingLine.type == character) {
						preceedingLine.nextElementIsDualDialogue = YES;
						break;
					}
					
					// Break on action or scene heading
					if (preceedingLine.type == action || preceedingLine.type == heading) break;
					index--;
				}
			}
		}
	}
	
	return result;
}
- (void)paginate {
	[self paginateAt:(NSRange){0,0} sync:NO];
}
- (void)paginateAt:(NSRange)range sync:(bool)sync {
	if (!self.showPageNumbers) return;
	
	// Reset page size (just in case)
	self.paginator.paperSize = self.printInfo.paperSize;
	
	/*

	 WIP!!!
	 It should work like this:
	 - Check range of changed indices
	 - Find on which page the changed ranges are (roughly, even if we start from previous page it still saves CPU time)
	 - Tell the paginator to start pagination over from some page
	   -> see which elements are newly created (split) on that page and start from that y and Line element
	 - Other pages and page breaks remain intact
	 - Recreate page breaks for BeatTextView
	 
	 The above is already implemented, but doesn't work. Lol.
	 
	 
	 Idea for rewrite:
	 Set up a delegate for live pagination. It has a timer and a method for checking whethe
	 the text has changed. If it has, it will repaginate the document. OR even better, use
	 changed indices from the parser.
	 
	 */
	
	// Null the timer so we don't have too many of these operations queued
	[_paginationTimer invalidate];
	NSInteger wait = 1.0;
	if (sync) wait = 0;
	
	_paginationTimer = [NSTimer scheduledTimerWithTimeInterval:wait repeats:NO block:^(NSTimer * _Nonnull timer) {
		// Make a copy of the array for thread-safety
		NSArray *lines = [NSArray arrayWithArray:self.parser.lines];
		
		// Dispatch to another thread (though we are already in timer, so I'm not sure?)
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void){
			[self.paginator livePaginationFor:[self onlyPrintableElements:lines] changeAt:range];
			
			NSArray *pageBreaks = self.paginator.pageBreaks;
			
			// Don't do nothing if the page break array is nil
			// This SHOULD mean that pagination was canceled
			if (pageBreaks == nil) return;
			
			dispatch_async(dispatch_get_main_queue(), ^(void){
				// Update UI in main thread
				
				NSMutableArray *breakPositions = [NSMutableArray array];
				
				for (NSDictionary *pageBreak in pageBreaks) { @autoreleasepool {
					CGFloat lineHeight = 13; // Line height from pagination
					CGFloat UIlineHeight = 20;
					
					Line *line = pageBreak[@"line"];

					CGFloat position = [pageBreak[@"position"] floatValue];
					
					NSRange characterRange = NSMakeRange(line.position, [line.string length]);
					NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
					
					NSRect rect = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer];
					
					CGFloat y;
					
					// We return -1 for elements that should have page break after them
					if (position >= 0) {
						if (position != 0) position = round(position / lineHeight) * UIlineHeight;
						//y = rect.origin.y + position - FONT_SIZE; // y is calculated from BOTTOM of line, so make it match its tow
						y =  rect.origin.y + position;
					}
					else y = rect.origin.y + rect.size.height;
					
					[breakPositions addObject:[NSNumber numberWithFloat:y]];
				} }
				
				[self.textView updatePageNumbers:breakPositions];

				//[self ensureLayout];
				[self.textView setNeedsDisplay:YES];
			});
		});
	}];
}

- (void)setPrintInfo:(NSPrintInfo *)printInfo {
	[super setPrintInfo:printInfo];
	
	if (printInfo.paperSize.width > 600) [self.documentSettings setInt:@"Page Size" as:BeatUSLetter];
	else [self.documentSettings setInt:@"Page Size" as:BeatA4];
}

- (NSInteger)numberOfPages {
	// If pagination is not on, create temporary paginator
	if (!self.showPageNumbers) {
		FountainPaginator *paginator = [[FountainPaginator alloc] initForLivePagination:self withElements:[self onlyPrintableElements:self.parser.lines]];
		return paginator.numberOfPages;
	} else {
		return self.paginator.numberOfPages;
	}
}
- (NSInteger)getPageNumber:(NSInteger)location {
	NSInteger page = 0;
	
	// If we don't have pagination turned on, create temporary paginator
	if (!self.showPageNumbers) {
		FountainPaginator *paginator = [[FountainPaginator alloc] initForLivePagination:self withElements:[self onlyPrintableElements:self.parser.lines]];
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

- (IBAction)editTitlePage:(id)sender {
	_titlePageEditor = [[BeatTitlePageEditor alloc] initWithDelegate:self];
	
	[_thisWindow beginSheet:_titlePageEditor.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSModalResponseOK) {
			// User pressed cancel, dealloc the sheet
			self.titlePageEditor = nil;
			return;
		}
		
		NSString *titlePage = self.titlePageEditor.result;
		
		// Find the range
		if (self.getText.length < 6) {
			// If there is not much text in the script, just add the title page in the beginning of the document, followed by newlines
			[self addString:[NSString stringWithFormat:@"%@\n\n", titlePage] atIndex:0];
		} else if (![[[self getText] substringWithRange:NSMakeRange(0, 6)] isEqualToString:@"Title:"]) {
			// There is no title page present here either. We're just careful not to cause errors with ranges
			[self addString:[NSString stringWithFormat:@"%@\n\n", titlePage] atIndex:0];
		} else {
			// There IS a title page, so we need to find out its range to replace it.
			NSInteger titlePageEnd = -1;
			for (Line* line in [self.parser lines]) {
				if (line.type == empty) {
					titlePageEnd = line.position;
					break;
				}
			}
			if (titlePageEnd < 0) titlePageEnd = self.getText.length;
			
			NSRange titlePageRange = NSMakeRange(0, titlePageEnd);
			NSString *oldTitlePage = [self.getText substringWithRange:titlePageRange];

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

// Oh well. Let's not autosave and instead have the good old "save as..." button in the menu.

+ (BOOL)autosavesInPlace {
	return NO;
}

+ (BOOL)autosavesDrafts {
	return YES;
}

- (IBAction)toggleAutosave:(id)sender {
	if (_autosave) {
		_autosave = NO;
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"Autosave"];
	} else {
		_autosave = YES;
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"Autosave"];
	}
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
	NSURL *autosavePath = [self autosavePath];
	autosavePath = [autosavePath URLByAppendingPathComponent:[self fileNameString]];
	autosavePath = [autosavePath URLByAppendingPathExtension:@"fountain"];
	
	return autosavePath;
}
- (NSURL*)autosavePath {
	return [ApplicationDelegate appDataPath:@"Autosave"];
}

- (void)autosaveDocumentWithDelegate:(id)delegate didAutosaveSelector:(SEL)didAutosaveSelector contextInfo:(void *)contextInfo {
	self.autosavedContentsFileURL = [self autosavedContentsFileURL];

	[super autosaveDocumentWithDelegate:delegate didAutosaveSelector:didAutosaveSelector contextInfo:contextInfo];
	
	[[NSDocumentController sharedDocumentController] setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
}
- (BOOL)hasUnautosavedChanges {
	// Always return YES if the file is a draft
	if (self.fileURL == nil) return YES;
	else { return [super hasUnautosavedChanges]; }
}

- (void)initAutosave {
 	_autosaveTimer = [NSTimer scheduledTimerWithTimeInterval:AUTOSAVE_INPLACE_INTERVAL target:self selector:@selector(autosaveInPlace) userInfo:nil repeats:YES];
	
	// Set default if not set
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave"]) {
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"Autosave"];
	}
	
	NSString *autosaving = [[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave"];
	if ([autosaving isEqualToString:@"YES"]) _autosave = YES; else _autosave = NO;
}

- (void)saveDocumentAs:(id)sender {
	// Delete old drafts when saving under a new name
	NSString *previousName = self.fileNameString;
	
	[super saveDocumentAs:sender];
	
	NSURL *url = [(ApplicationDelegate*)NSApp.delegate appDataPath:@"Autosave"];
	url = [url URLByAppendingPathComponent:previousName];
	url = [url URLByAppendingPathExtension:@"fountain"];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:url.path]) {
		[fileManager removeItemAtURL:url error:nil];
	}
}


#pragma mark - split view listener

- (void)splitViewDidResize {
	[self updateLayout];
}
- (void)leftViewDidShow {
	self.outlineViewVisible = YES;
	[_outlineButton setState:NSOnState];
	[self reloadOutline];
}
- (void)leftViewDidHide {
	// unused for now
}

#pragma mark - Plugin support for documents

- (void)setupPlugins {
	_pluginManager = [BeatPluginManager sharedManager];
}
- (IBAction)runPlugin:(id)sender {
	NSMenuItem *menuItem = (NSMenuItem*)sender;
	NSString *pluginName = menuItem.title;

	if (_runningPlugins[pluginName]) {
		// Disable a running plugin and return
		[(BeatScriptParser*)_runningPlugins[pluginName] end];
		[_runningPlugins removeObjectForKey:pluginName];
		return;
	}
	
	BeatScriptParser *parser = [[BeatScriptParser alloc] init];
	parser.delegate = self;
	
	BeatPlugin *plugin = [_pluginManager pluginWithName:pluginName];
	[parser runPlugin:plugin];
	
	parser = nil;
}

- (void)registerPlugin:(id)plugin {
	BeatScriptParser *parser = (BeatScriptParser*)plugin;
	if (!_runningPlugins) _runningPlugins = [NSMutableDictionary dictionary];
	
	_runningPlugins[parser.pluginName] = parser;
}
- (void)deregisterPlugin:(id)plugin {
	BeatScriptParser *parser = (BeatScriptParser*)plugin;
	[_runningPlugins removeObjectForKey:parser.pluginName];
	parser = nil;
}

- (void)updatePlugins:(NSRange)range {
	// Run resident plugins
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatScriptParser *plugin = _runningPlugins[pluginName];
		[plugin update:range];
	}
}

- (void)updatePluginsWithSelection:(NSRange)range {
	// Run resident plugins which are listening for selection changes
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatScriptParser *plugin = _runningPlugins[pluginName];
		[plugin updateSelection:range];
	}
}

- (void)updatePluginsWithSceneIndex:(NSInteger)index {
	// Run resident plugins which are listening for selection changes
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatScriptParser *plugin = _runningPlugins[pluginName];
		[plugin updateSceneIndex:index];
	}
}

- (void)updatePluginsWithOutline:(NSArray*)outline {
	// Run resident plugins which are listening for selection changes
	if (!_runningPlugins) return;
	
	for (NSString *pluginName in _runningPlugins.allKeys) {
		BeatScriptParser *plugin = _runningPlugins[pluginName];
		[plugin updateOutline:outline];
	}
}

#pragma mark - Color Customization

- (IBAction)customizeColors:(id)sender {
	[_themeManager showEditor];
}

#pragma mark - Tagging

- (void)setupTagging {
	[_sideView setFillColor:[BeatColors color:@"backgroundGray"]];
	
	_tagging = [[BeatTagging alloc] initWithDelegate:self];
	[_tagging setupTextView:self.tagTextView];

	[_tagging loadTags:[_documentSettings get:DocSettingTags] definitions:[_documentSettings get:DocSettingTagDefinitions]];
}

- (IBAction)toggleTagging:(id)sender {
	if (_mode == TaggingMode) _mode = EditMode;
	else _mode = TaggingMode;
	
	if (_mode == TaggingMode) {
		[_tagTextView.enclosingScrollView setHasHorizontalScroller:NO];
		[_sideViewCostraint setConstant:180];
	} else {
		[self exitTagging:nil];
	}
	
	[_thisWindow layoutIfNeeded];
	[self updateLayout];
	[self updateQuickSettings];
}
- (IBAction)exitTagging:(id)sender {
	_mode = EditMode;
	
	[_tagTextView.enclosingScrollView setHasHorizontalScroller:NO];
	[_sideViewCostraint setConstant:0];
}

- (void)addTagToRange:(NSRange)range tag:(BeatTagItem*)tag {
	NSDictionary *oldAttributes = [self.textView.attributedString attributesAtIndex:range.location longestEffectiveRange:nil inRange:range];
	
	if (tag == NoTag) {
		// Clear tags
		[self.textView.textStorage removeAttribute:tagAttribute range:range];
		[self.textView.textStorage removeAttribute:NSBackgroundColorAttributeName range:range];
		[self saveTags];
	} else {
		[self.textView.textStorage addAttribute:tagAttribute value:tag range:range];
		
		NSColor *tagColor = [tag.color colorWithAlphaComponent:.6];
		[self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:tagColor range:range];
		
		[self saveTags];
	}
	
	[self.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
		[self.textView.textStorage setAttributes:oldAttributes range:range];
	}];
}

- (void)tagRange:(NSRange)range withType:(BeatTagType)type {
	NSString *string = [self.textView.string substringWithRange:range];
	BeatTag* tag = [_tagging addTag:string type:type];
	
	if (tag) {
		[self tagRange:range withTag:tag];
		[self forceFormatChangesInRange:range];
	}
}
- (void)tagRange:(NSRange)range withTag:(BeatTag*)tag {
	// Tag a range with the specified tag.
	// NOTE that this just sets attribute ranges and doesn't save the tag data anywhere else.
	// So the tagging system basically only relies on the attributes in the NSTextView's rich-text string.
	
	// TODO: Somehow check if the range has revision attributes?
	
	NSDictionary *oldAttributes = [self.textView.attributedString attributesAtIndex:range.location longestEffectiveRange:nil inRange:range];
	
	if (tag == nil) {
		// Clear tags
		[self.textView.textStorage removeAttribute:tagAttribute range:range];
		[self saveTags];
	} else {
		[self.textView.textStorage addAttribute:tagAttribute value:tag range:range];
		[self saveTags];
	}
	
	if (!_documentIsLoading) {
		[self.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
			[self.textView.textStorage setAttributes:oldAttributes range:range];
		}];
	}
}

- (void)saveTags {
	NSArray *tags = [_tagging getTags];	
	NSArray *definitions = [_tagging getDefinitions];
	
	[_documentSettings set:DocSettingTags as:tags];
	[_documentSettings set:DocSettingTagDefinitions as:definitions];
}

- (void)updateTaggingData {
	[_tagging setupTextView:self.tagTextView];
	[_tagTextView.textStorage setAttributedString:[_tagging displayTagsForScene:[self getCurrentScene]]];
}

#pragma mark - Locking The Document

// This is unused for now

- (void)toggleLock {
	bool locked = [self.documentSettings getBool:@"Locked"];
	
	if (locked) {
		[self unlock];
	} else {
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
}
- (void)unlock {
	self.textView.editable = YES;
	[self.documentSettings setBool:@"Locked" as:NO];
}
- (void)updateLockingStatus {
	// If file is locked, show an indicator that the document CAN'T BE CHANGED.
}

#pragma mark - Testing methods

- (void)startMeasure
{
	_executionTime = [NSDate date];
}
- (NSTimeInterval)getMeasure {
	NSDate *methodFinish = [NSDate date];
	NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:_executionTime];
	return executionTime;
}
- (void)endMeasure:(NSString*)name
{
	NSDate *methodFinish = [NSDate date];
	NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:_executionTime];
	NSLog(@"%@ execution time = %f", name, executionTime);
}

@end

/*
 
 some moments are nice, some are
 nicer, some are even worth
 writing
 about
 
 */
