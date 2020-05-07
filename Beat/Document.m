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
 */


/*
 
 N.B.
 
 Beat has been cooked up by using lots of trial and error, and this file has become a 4000-line monster.  I've started fixing some of my silliest coding practices, but it's still a WIP. About a third of the code has its origins in Writer, an open source Fountain by Hendrik Noeller.
 
 Some structures (such as themes) are legacy from Writer, and while they have since been replaced with a totally different approach, their names and complimentary methods still linger around. You can find some *very* shady stuff, such as ThemeManager, lying around here and there with no real purpose. I built some very convoluted UI methods on top of legacy code from Writer before getting a grip on AppKit & Objective-C programming. I have since made it much more sensible, but dismantling those weird solutions is still WIP.
 
 As I started this project, I had close to zero knowledge on Objective-C, and it really shows. I have gotten gradually better at writing code, and there is even some multi-threading, omg.
 
 Beat is released under GNU General Public License, so all of this code will remain open forever, even if I make a commercial version to finance the development. I started developing the app to overcome some PTSD symptoms and to combat creative block. It has since become a real app with a real user base, which I'm thankful for. If you find this code or the app useful, you can always send some currency through PayPal or hide bunch of coins in an old oak tree.
 
 Anyway, may this be of some use to you, dear friend.
 The abandoned git repository will be my monument when I'm gone.
 
 Lauri-Matti Parppei
 Helsinki
 Finland
 
 
 = = = = = = = = = = = = = = = = = = = = = = = =
 
 Page sizing info:
 
 Character - 32%
 Parenthetical - 30%
 Dialogue - 16%
 Dialogue width - 74%
 
 = = = = = = = = = = = = = = = = = = = = = = = =
 
 I plant my hands in the garden soil—
 I will sprout,
              I know, I know, I know.
 And in the hollow of my ink-stained palms
 swallows will make their nest.
  
 
*/

#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>
#import "Document.h"
#import "ScrollView.h"
#import "BeatTextView.h"
#import "FNScript.h"
#import "FNHTMLScript.h"
#import "FDXInterface.h"
#import "OutlineExtractor.h"
#import "PrintView.h"
#import "ColorView.h"
#import "ContinousFountainParser.h"
#import "ThemeManager.h"
#import "OutlineScene.h"
#import "CenteredClipView.h"
#import "DynamicColor.h"
#import "ApplicationDelegate.h"
#import "NSString+Whitespace.h"
#import "FountainAnalysis.h"
#import "BeatOutlineView.h"
#import "ColorCheckbox.h"
#import "SceneFiltering.h"
#import "FDXImport.h"
#import "LivePagination.h"
#import "MasterView.h"

@interface Document ()

// Window
@property (weak) NSWindow *thisWindow;

// Autosave
@property (nonatomic) bool autosave;
@property (weak) NSTimer *autosaveTimer;

// Text view
@property (unsafe_unretained) IBOutlet BeatTextView *textView;
@property (weak) IBOutlet ScrollView *textScrollView;
@property (weak) IBOutlet NSClipView *textClipView;
@property (nonatomic) NSTimer * scrollTimer;
@property (nonatomic) NSLayoutManager *layoutManager;
@property (nonatomic) bool documentIsLoading;
@property (nonatomic) LivePagination *pagination;
@property (nonatomic) NSMutableArray *sectionMarkers;

// Outline view
@property (weak) IBOutlet BeatOutlineView *outlineView;
@property (weak) IBOutlet NSScrollView *outlineScrollView;
@property (weak) NSArray *draggedNodes;
@property (weak) OutlineScene *draggedScene; // Drag & drop for outline view
@property (nonatomic) NSMutableArray *flatOutline;
@property (weak) IBOutlet NSButton *outlineButton;
@property (weak) IBOutlet NSSearchField *outlineSearchField;
@property (weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property BOOL outlineViewVisible;
@property (nonatomic) NSMutableArray *outlineClosedSections;
@property (weak) IBOutlet NSMenu *colorMenu;
@property BOOL outlineEdit;

// Outline view filtering
@property (nonatomic) NSMutableArray *filteredOutline;
@property (nonatomic) IBOutlet NSBox *filterView;
@property (nonatomic) IBOutlet NSLayoutConstraint *filterViewHeight;
@property (nonatomic) IBOutlet NSPopUpButton *characterBox;
@property (nonatomic) SceneFiltering *filters;
@property (nonatomic) IBOutlet NSButton *resetColorFilterButton;
@property (nonatomic) IBOutlet NSButton *resetCharacterFilterButton;

// Fuck you macOS & Apple. For two things, particulary:
//
// 1) IBOutletCollection is iOS-only
// 2) This computer (and my phone and everything else) is made in
//    subhuman conditions in some sweatshop in China, just to add
//    to your fucking sky-high profits.
//
//    You are the most profitable company operating in our current monetary
//    and economic system. EQUALITY, WELFARE AND FREEDOM FOR EVERYONE.
//    FUCK YOU, APPLE.

//    2020 edit: FUCK YOU EVEN MORE, fucking capitalist motherfuckers for
//    allowing SLAVE LABOUR in your subcontracting factories, you fucking
//    pieces of human garbage!!! Go fuck yourself, Apple.
//    So, on to the code:

@property (nonatomic) IBOutlet ColorCheckbox *redCheck;
@property (nonatomic) IBOutlet ColorCheckbox *blueCheck;
@property (nonatomic) IBOutlet ColorCheckbox *greenCheck;
@property (nonatomic) IBOutlet ColorCheckbox *orangeCheck;
@property (nonatomic) IBOutlet ColorCheckbox *cyanCheck;
@property (nonatomic) IBOutlet ColorCheckbox *brownCheck;
@property (nonatomic) IBOutlet ColorCheckbox *magentaCheck;
@property (nonatomic) IBOutlet ColorCheckbox *pinkCheck;


// Views
@property (unsafe_unretained) IBOutlet WebView *webView; // Print preview
@property (unsafe_unretained) IBOutlet NSTabView *tabView; // Master tab view (holds edit/print/card views)
@property (weak) IBOutlet ColorView *backgroundView; // Master background
@property (weak) IBOutlet ColorView *outlineBackgroundView; // Background for outline
@property (weak) IBOutlet MasterView *masterView; // View which contains every other view


// Analysis
@property (weak) IBOutlet NSPanel *analysisPanel;
@property (unsafe_unretained) IBOutlet WKWebView *analysisView;
@property (strong, nonatomic) FountainAnalysis* analysis;
@property (nonatomic) NSMutableDictionary *characterGenders;

// Card view
@property (unsafe_unretained) IBOutlet WKWebView *cardView;
@property (nonatomic) bool cardsVisible;


// Timeline view
@property (unsafe_unretained) IBOutlet WKWebView *timelineView;
@property (weak) IBOutlet NSLayoutConstraint *timelineViewHeight;
@property (nonatomic) NSInteger timelineClickedScene;
@property (nonatomic) NSInteger timelineSelection;
@property (nonatomic) bool timelineVisible;


// Margin views, unused for now
@property (unsafe_unretained) IBOutlet NSBox *leftMargin;
@property (unsafe_unretained) IBOutlet NSBox *rightMargin;


// Scene number labels
@property (nonatomic) NSMutableArray *sceneNumberLabels;
@property (nonatomic) bool sceneNumberLabelUpdateOff;
@property (nonatomic) bool showSceneNumberLabels;


// Content buffer
@property (strong, nonatomic) NSString *contentBuffer; //Keeps the text until the text view is initialized


// Fonts
@property (strong, nonatomic) NSFont *courier;
@property (strong, nonatomic) NSFont *boldCourier;
@property (strong, nonatomic) NSFont *italicCourier;

// Weird stuff which... uh. Forget about it for now.
@property (nonatomic) NSUInteger fontSize;
@property (nonatomic) NSUInteger zoomLevel;
@property (nonatomic) NSUInteger zoomCenter;


// Magnification
@property (nonatomic) CGFloat magnification;
@property (nonatomic) CGFloat scaleFactor;
@property (nonatomic) CGFloat scale;


// Printing
@property (nonatomic) bool printPreview;
@property (nonatomic, readwrite) NSString *preprocessedText;
@property (nonatomic) bool printSceneNumbers;
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
@property (nonatomic) NSUInteger doubleDialogueIndent;
@property (nonatomic) NSUInteger ddRight;


// Current line / scene
@property (nonatomic) Line *currentLine;
@property (nonatomic) OutlineScene *currentScene;


// Autocompletion
@property (nonatomic) NSString *cachedText;
@property (nonatomic) bool isAutoCompleting;
@property (nonatomic) NSMutableArray *characterNames;
@property (nonatomic) NSMutableArray *sceneHeadings;
@property (readwrite, nonatomic) bool darkPopup;

// Touch bar
@property (nonatomic) NSColorPickerTouchBarItem *colorPicker;

// Parser
@property (strong, nonatomic) ContinousFountainParser* parser;

// Title page editor
@property (weak) IBOutlet NSPanel *titlePagePanel;
@property (weak) IBOutlet NSTextField *titleField;
@property (weak) IBOutlet NSTextField *creditField;
@property (weak) IBOutlet NSTextField *authorField;
@property (weak) IBOutlet NSTextField *sourceField;
@property (weak) IBOutlet NSTextField *dateField;
@property (weak) IBOutlet NSTextField *contactField;
@property (weak) IBOutlet NSTextField *notesField;
@property (nonatomic) NSMutableArray *customFields;

// Theme settings
@property (strong, nonatomic) ThemeManager* themeManager;
@property (nonatomic) bool nightMode; // THE HOUSE IS BLACK.

@end


// Uh. Refer to fontSize / zooming functions to make sense of this stuff.
// This spaghetti should be fixed ASAP.

#define APP_NAME @"Beat"

#define DEFAULT_ZOOM 16
#define FONT_SIZE_MODIFIER 0.028
#define ZOOM_MODIFIER 40

#define AUTOSAVE_INTERVAL 10.0
#define AUTOSAVE_INPLACE_INTERVAL 60.0

// Some fixes for convoluted UI stuff
#define FONT_SIZE 17.92 // used to be DEFAULT_ZOOM * FONT_SIZE_MODIFIER * ZOOM_MODIFIER
#define DOCUMENT_WIDTH 640 // DEFAULT_ZOOM * ZOOM_MODIFIER;

#define MAGNIFYLEVEL_KEY @"Magnifylevel"
#define DEFAULT_MAGNIFY 1.1
#define MAGNIFY YES

#define MATCH_PARENTHESES_KEY @"Match Parentheses"
#define SHOW_SCENE_LABELS_KEY @"Show Scene Number Labels"
#define FONTSIZE_KEY @"Fontsize"
#define PRINT_SCENE_NUMBERS_KEY @"Print scene numbers"

#define LOCAL_REORDER_PASTEBOARD_TYPE @"LOCAL_REORDER_PASTEBOARD_TYPE"
#define OUTLINE_DATATYPE @"OutlineDatatype"
#define FLATOUTLINE YES
// The whole outline thing should be rewritten ASAP


// DOCUMENT LAYOUT SETTINGS
// The 0.?? values represent percentages of view width

#define TEXT_INSET_TOP 40

#define INITIAL_WIDTH 900
#define INITIAL_HEIGHT 700

#define DD_CHARACTER_INDENT_P 0.56
#define DD_PARENTHETICAL_INDENT_P 0.50
#define DOUBLE_DIALOGUE_INDENT_P 0.40
#define DD_RIGHT 650
#define DD_RIGHT_P .95

#define TITLE_INDENT .15

#define CHARACTER_INDENT_P 0.36
#define PARENTHETICAL_INDENT_P 0.27
#define DIALOGUE_INDENT_P 0.164
#define DIALOGUE_RIGHT_P 0.72

#define TREE_VIEW_WIDTH 330
#define TIMELINE_VIEW_HEIGHT 120

#define OUTLINE_SECTION_SIZE 13.0
#define OUTLINE_SYNOPSE_SIZE 12.0
#define OUTLINE_SCENE_SIZE 11.5


@implementation Document

#pragma mark - Document Basics

- (instancetype)init {
    self = [super init];
    if (self) {
        self.printInfo.topMargin = 25;
        self.printInfo.bottomMargin = 55;
		self.printInfo.paperSize = NSMakeSize(595, 842);
    }
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document open" object:nil];
	
    return self;
}
- (void) close {
	// Save the gender list, if needed
	if ([_characterGenders count] > 0) [self saveGenders];
	
	// This stuff is here to fix some strange memory issues.
	// it might be unnecessary, but maybe it isn't bad to unset the most memory-consuming variables anyway?
	self.textView = nil;
	self.parser = nil;
	self.outlineView = nil;
	self.sceneNumberLabels = nil;
	self.thisWindow = nil;
	self.contentBuffer = nil;
	self.printView = nil;
	self.analysis = nil;
	self.themeManager = nil;
	self.currentScene = nil;
	self.currentLine = nil;
	
	if (_autosaveTimer) [self.autosaveTimer invalidate];
	self.autosaveTimer = nil;
	
	// ApplicationDelegate will show welcome screen when no documents are open
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document close" object:nil];
	
	[super close];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
	
	_thisWindow = aController.window;
	[_thisWindow setMinSize:CGSizeMake(_thisWindow.minSize.width, 350)];
	
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	
	// Hide the welcome screen
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document open" object:nil];
	
	// Revised layout code for 1.1.0 release
	// _zoomLevel = DEFAULT_ZOOM;
	_documentWidth = DOCUMENT_WIDTH;
	[self setZoom];

    // Set the width programmatically since we've got the outline visible in IB to work on it, but don't want it visible on launch
    NSWindow *window = aController.window;
    NSRect newFrame = NSMakeRect(window.frame.origin.x,
                                 window.frame.origin.y,
                                 _documentWidth * 1.7,
                                 _documentWidth * 1.5);
    [window setFrame:newFrame display:YES];
	
	// Accept mouse moved events + set window object to master view
	[aController.window setAcceptsMouseMovedEvents:YES];
	self.masterView.parentWindow = aController.window;
	self.masterView.styleMask = aController.window.styleMask;
	
	// Outline view setup
    self.outlineViewVisible = false;
    self.outlineViewWidth.constant = 0;

	// TextView setup
    self.textView.textContainer.widthTracksTextView = false;
	self.textView.textContainer.heightTracksTextView = false;
	
	[[self.textScrollView documentView] setPostsBoundsChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boundsDidChange:) name:NSViewBoundsDidChangeNotification object:[self.textScrollView contentView]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchOutline) name:NSControlTextDidChangeNotification object:self.outlineSearchField];
	
	// Window frame will be the same as text frame width at startup (outline is not visible by default)
	// TextView won't have a frame size before load, so let's use the window width instead to set the insets.
	self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
	self.textView.textContainerInset = NSMakeSize(window.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
	
	// Set textView style
	[self.textView setFont:[self courier]];
    [self.textView setAutomaticQuoteSubstitutionEnabled:NO];
    [self.textView setAutomaticDataDetectionEnabled:NO];
    [self.textView setAutomaticDashSubstitutionEnabled:NO];
	
	// Set first responder to the text field to focus it on startup
	[aController.window makeFirstResponder:self.textView];
	[self.textView setEditable:YES];
	
	// Pagination
	_pagination = [[LivePagination alloc] init];
	
	// Read default settings
    if (![[NSUserDefaults standardUserDefaults] objectForKey:MATCH_PARENTHESES_KEY]) {
        self.matchParentheses = NO;
    } else {
        self.matchParentheses = [[NSUserDefaults standardUserDefaults] boolForKey:MATCH_PARENTHESES_KEY];
    }
	
	if (![[NSUserDefaults standardUserDefaults] objectForKey:PRINT_SCENE_NUMBERS_KEY]) {
		self.printSceneNumbers = YES;
	} else {
		self.printSceneNumbers = [[NSUserDefaults standardUserDefaults] boolForKey:PRINT_SCENE_NUMBERS_KEY];
	}

	if (![[NSUserDefaults standardUserDefaults] objectForKey:SHOW_SCENE_LABELS_KEY]) {
		self.showSceneNumberLabels = YES;
	} else {
		self.showSceneNumberLabels = [[NSUserDefaults standardUserDefaults] boolForKey:SHOW_SCENE_LABELS_KEY];
	}
		
	//Initialize Theme Manager (before formatting the content, because we need the colors for formatting!)
	self.themeManager = [ThemeManager sharedManager];
	[self loadSelectedTheme:false];
	_nightMode = [self isDark];
	
	// Background fill - WIP: MOVE UNDER THEME LOADING
	self.backgroundView.fillColor = self.themeManager.theme.outlineBackground;
	self.textScrollView.backgroundColor = self.themeManager.theme.backgroundColor;
	
	// Initialize drag & drop for outline view
	[self.outlineView registerForDraggedTypes:@[LOCAL_REORDER_PASTEBOARD_TYPE, OUTLINE_DATATYPE]];
	[self.outlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];

    //Put any previously loaded data into the text view
	_documentIsLoading = YES;
    if (self.contentBuffer) {
        [self setText:self.contentBuffer];
    } else {
        [self setText:@""];
    }
	
	// Outline view setup
	self.outlineClosedSections = [[NSMutableArray alloc] init];
	self.filteredOutline = [[NSMutableArray alloc] init];
	[self hideFilterView];
	
	// Scene number labels
	self.sceneNumberLabels = [[NSMutableArray alloc] init];
	
	// Autocomplete setup
	self.characterNames = [[NSMutableArray alloc] init];
	self.sceneHeadings = [[NSMutableArray alloc] init];
	
    self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
	self.analysis = [[FountainAnalysis alloc] init];

	// CardView webkit
	[self.cardView.configuration.userContentController addScriptMessageHandler:self name:@"cardClick"];
	[self.cardView.configuration.userContentController addScriptMessageHandler:self name:@"setColor"];
	[self.cardView.configuration.userContentController addScriptMessageHandler:self name:@"move"];
	[self setupCards];
	
	// Timeline webkit
	[self setupTimeline];
	self.timelineVisible = false;
	self.timelineViewHeight.constant = 0;
	[self.timelineView.configuration.userContentController addScriptMessageHandler:self name:@"jumpToScene"];
	[self.timelineView.configuration.userContentController addScriptMessageHandler:self name:@"timelineContext"];
	_timelineClickedScene = -1;
	
	// Setup analysis
	[self setupAnalysis];
	[self.analysisView.configuration.userContentController addScriptMessageHandler:self name:@"setGender"];
	
	// Apply format changes to the changed region (which is the whole document) and mark document loading as done
	[self applyFormatChanges];
	_documentIsLoading = NO;
	
	// Setup touch bar colors
	[self initColorPicker];
	
	// Init scene filtering
	_filters = [[SceneFiltering alloc] init];

	// Custom autosave
	[self initAutosave];
	
	// Let's set a timer for 200ms. This should update the scene number labels after letting the text render.
	//[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(afterLoad) userInfo:nil repeats:NO];

	// Can I come over, I need to rest
	// lay down for a while, disconnect
	// the night was so long, the day even longer
	// lay down for a while, recollect
	
}
-(void)awakeFromNib {
	[self updateLayout];
	
	[self updateSceneNumberLabels];
	[self updateSectionMarkers];
	
	// Set up recovery file saving
	[[NSDocumentController sharedDocumentController] setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
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

# pragma mark - Window interactions

- (bool) isFullscreen {
	return (([_thisWindow styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

- (void)windowDidResize:(NSNotification *)notification {
	[self updateLayout];
}

- (void) updateLayout {
	[self setMinimumWindowSize];
	
	CGFloat width = (self.textView.frame.size.width / 2 - _documentWidth * _magnification / 2) / _magnification;
	
	if (width < 9000) { // Some arbitrary number to see that there is some sort of width set & view has loaded
		self.textView.textContainerInset = NSMakeSize(width, TEXT_INSET_TOP);
		self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);

		self.textScrollView.insetWidth = self.textView.textContainerInset.width;
		self.textScrollView.magnificationLevel = _magnification;
		[self.textScrollView setNeedsDisplay:YES]; // Force redraw if needed
	}
	
	[self ensureLayout];
}

- (void) setMinimumWindowSize {
	if (!_outlineViewVisible) {
		[self.thisWindow setMinSize:NSMakeSize(_documentWidth * _magnification + 200, 400)];
	} else {
		[self.thisWindow setMinSize:NSMakeSize(_documentWidth * _magnification + 200 + _outlineView.frame.size
											   .width, 400)];
	}
}

/*
 
 Zooming in / out

 This is a mess. I am so sorry for anyone reading this.
 
 Update 2019/09/06
 I have finally rebuilt the zooming. I have tried all sorts of tricks from magnification to other weird stuff, such as 3rd party libraries for scaling the NSScrollView. Everything was terrible and caused even more problems. I'm not too familiar with Cocoa and/or Objective-C, but if I understand correctly, the best way would be having a custom NSView inside the NSScrollView and then to magnify the scroll view. NSTextView's layout manager would then handle displaying the text in those custom views.
 
 I still have no help and I'm working alone. Until that changes, I guess this won't get any better. :-)
 
 What matters most is how well you walk through the fire.
 
 */

- (void) zoom: (bool) zoomIn {
	if (!_scaleFactor) _scaleFactor = _magnification;
	CGFloat oldMagnification = _magnification;
	
	// Save scroll position
	NSPoint scrollPosition = [[self.textScrollView contentView] documentVisibleRect].origin;
	
	// For some reason, setting 1.0 scale for NSTextView causes weird sizing bugs, so we will use something that will never produce 1.0...... omg lol help
	if (zoomIn) {
		if (_magnification < 1.2) _magnification += 0.09;
	} else {
		if (_magnification > 0.9) _magnification -= 0.09;
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
		clipFrame.size.height = _textClipView.superview.frame.size.height;
		_textClipView.frame = clipFrame;
		
		[[NSUserDefaults standardUserDefaults] setFloat:_magnification forKey:MAGNIFYLEVEL_KEY];
	}
}

- (void)ensureCaret {
	[self.textView updateInsertionPointStateAndRestartTimer:YES];
}
- (void)ensureLayout {
	[[self.textView layoutManager] ensureLayoutForTextContainer:[self.textView textContainer]];
	[self.textView setNeedsDisplay:YES];
		
	[self updateSceneNumberLabels];
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
		curDocFrameSize = [clipView frame].size;
		
		// The new bounds will be frame divided by scale factor
		newDocBoundsSize.width = curDocFrameSize.width;
		newDocBoundsSize.height = curDocFrameSize.height / _scaleFactor;
		
		NSRect newFrame = NSMakeRect(0, 0, newDocBoundsSize.width, newDocBoundsSize.height);
		clipView.frame = newFrame;
	}
	_scaleFactor = newScaleFactor;
	[self scaleChanged:oldScaleFactor newScale:newScaleFactor];
}

- (void) scaleChanged:(CGFloat)oldScale newScale:(CGFloat)newScale
{
	CGFloat scaler = newScale / oldScale;
	[self.textView scaleUnitSquareToSize:NSMakeSize(scaler, scaler)];
	
	NSLayoutManager* lm = [self.textView layoutManager];
	NSTextContainer* tc = [self.textView textContainer];
	[lm ensureLayoutForTextContainer:tc];
}

- (void) setZoom {
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

// Old method names. Should be fixed.
- (IBAction)increaseFontSize:(id)sender { [self zoom:true]; }
- (IBAction)decreaseFontSize:(id)sender { [self zoom:false]; }
- (IBAction)resetFontSize:(id)sender {
	_magnification = 1.1;
	[self setScaleFactor:_magnification adjustPopup:false];
	[self updateLayout];
}

#pragma mark - Window settings
// Oh well. Let's not autosave and instead have the good old "save as..." button in the menu.
+ (BOOL)autosavesInPlace {
    return NO;
}

+ (BOOL)autosavesDrafts {
	return YES;
}


// I have no idea what these are or do.

- (NSString *)windowNibName {
    return @"Document";
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSData *dataRepresentation = [[self getText] dataUsingEncoding:NSUTF8StringEncoding];
    return dataRepresentation;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    [self setText:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"]];
    return YES;
}


# pragma mark - Text I/O

- (NSString *)getText
{
    return [self.textView string];
}

- (void)setText:(NSString *)text
{
    if (!self.textView) {
        self.contentBuffer = text;
    } else {
        [self.textView setString:text];
        //[self updateWebView];
    }
	[self updateSceneNumberLabels];
}

- (IBAction)printDocument:(id)sender
{
    if ([[self getText] length] == 0) {
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"Can not print an empty document";
        alert.informativeText = @"Please enter some text before printing, or obtain white paper directly by accessing you printers paper tray.";
		alert.alertStyle = NSAlertStyleWarning;
        [alert beginSheetModalForWindow:self.windowControllers[0].window completionHandler:nil];
    } else {
		if (self.printSceneNumbers) {
			self.preprocessedText = [self preprocessSceneNumbers];
		} else {
			self.preprocessedText = [self.getText copy];
		}
        self.printView = [[PrintView alloc] initWithDocument:self toPDF:NO toPrint:YES];
    }
}

- (IBAction)exportPDF:(id)sender
{
	if (self.printSceneNumbers) {
		self.preprocessedText = [self preprocessSceneNumbers];
	} else {
		self.preprocessedText = [self.getText copy];
	}
	
	self.printView = [[PrintView alloc] initWithDocument:self toPDF:YES toPrint:YES];
}

- (IBAction)exportHTML:(id)sender
{
	if (self.printSceneNumbers) {
		self.preprocessedText = [self preprocessSceneNumbers];
	} else {
		self.preprocessedText = [self getText];
	}
	
    NSSavePanel *saveDialog = [NSSavePanel savePanel];
    [saveDialog setAllowedFileTypes:@[@"html"]];
    [saveDialog setRepresentedFilename:[self lastComponentOfFileName]];
    [saveDialog setNameFieldStringValue:[self fileNameString]];
    [saveDialog beginSheetModalForWindow:self.windowControllers[0].window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            FNScript* fnScript = [[FNScript alloc] initWithString: self.preprocessedText];
            FNHTMLScript* htmlScript = [[FNHTMLScript alloc] initWithScript:fnScript];
            NSString* htmlString = [htmlScript html];
            [htmlString writeToURL:saveDialog.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }];
}

- (IBAction)exportFDX:(id)sender
{
    NSSavePanel *saveDialog = [NSSavePanel savePanel];
    [saveDialog setAllowedFileTypes:@[@"fdx"]];
    [saveDialog setNameFieldStringValue:[self fileNameString]];
    [saveDialog beginSheetModalForWindow:self.windowControllers[0].window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString* fdxString = [FDXInterface fdxFromString:[self getText]];
            [fdxString writeToURL:saveDialog.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
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

- (NSString*)fileNameString
{
    NSString* fileName = [self lastComponentOfFileName];
    NSUInteger lastDotIndex = [fileName rangeOfString:@"." options:NSBackwardsSearch].location;
    if (lastDotIndex != NSNotFound) {
        fileName = [fileName substringToIndex:lastDotIndex];
    } 
    return fileName;
}

- (void)updateWebView
{
	FNScript *script = [[FNScript alloc] initWithString:[self preprocessSceneNumbers]];
	FNHTMLScript *htmlScript;
	OutlineScene *currentScene = [self getCurrentScene];
	
	// Let's see if we have a scene selected
	if (currentScene) {
		htmlScript = [[FNHTMLScript alloc] initWithScript:script document:self scene:currentScene.sceneNumber];
	} else {
		htmlScript = [[FNHTMLScript alloc] initWithScript:script document:self];
	}
	
    [[self.webView mainFrame] loadHTMLString:[htmlScript html] baseURL:nil];
}
- (OutlineScene*)getCurrentScene {
	NSInteger position = [self.textView selectedRange].location;
	
	NSInteger index = 0;
	
	for (OutlineScene *scene in [self getOutlineItems]) {
		NSRange range = NSMakeRange(scene.sceneStart, scene.sceneLength);
		
		// Found the current scene. Let's cache the result just in case
		if (NSLocationInRange(position, range)) {
			_currentScene = scene;
			if ([_filteredOutline count] < 1) {
				self.outlineView.currentScene = index;
			} else {
				self.outlineView.currentScene = [_filteredOutline indexOfObject:scene];
			}
			
			// Also, update touch bar color if needed (omg this is cool)
			if (scene.color) {
				if ([self colors][[scene.color lowercaseString]]) {
					[_colorPicker setColor:[self colors][[scene.color lowercaseString]]];
				}
			}
			
			return scene;
		}
		index++;
	}
	
	_currentScene = nil;
	self.outlineView.currentScene = -1;
	
	return nil;
}

- (OutlineScene*)getPreviousScene {
	if ([_flatOutline count] == 0) {
		_flatOutline = [self getOutlineItems];
		if ([_flatOutline count] == 0) return nil;
	}
	
	_currentScene = [self getCurrentScene];
	if (!_currentScene) return nil;
	
	NSInteger index = [_flatOutline indexOfObject:_currentScene];
	
	if (index - 1 >= 0 && index < [_flatOutline count]) {
		return [_flatOutline objectAtIndex:index - 1];
	} else {
		return nil;
	}
}
- (OutlineScene*)getNextScene {
	if ([_flatOutline count] == 0) {
		_flatOutline = [self getOutlineItems];
		if ([_flatOutline count] == 0) return nil;
	}
	
	_currentScene = [self getCurrentScene];
	if (!_currentScene) return nil;

	NSInteger index = [_flatOutline indexOfObject:_currentScene];

	if (index >= 0 && (index + 1) < [_flatOutline count]) {
		return [_flatOutline objectAtIndex:index + 1];
	} else {
		return nil;
	}
}

# pragma mark - Undo

- (IBAction)undoEdit:(id)sender {
	[self.undoManager undo];
	if (_cardsVisible) [self refreshCards:YES];
	
	// To avoid some graphical glitches
	[self updateSceneNumberLabels];
	//[self.textView setNeedsDisplay:YES];
	[self ensureLayout];
}
- (IBAction)redoEdit:(id)sender {
	[self.undoManager redo];
	if (_cardsVisible) [self refreshCards:YES];
	
	// To avoid some graphical glitches
	[self ensureLayout];
}

# pragma mark - Text manipulation

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
    //If something is being inserted, check whether it is a "(" or a "[[" and auto close it
    if (self.matchParentheses) {
        if (affectedCharRange.length == 0) {
            if ([replacementString isEqualToString:@"("]) {
                [self addString:@")" atIndex:affectedCharRange.location];
                [self.textView setSelectedRange:affectedCharRange];
                
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
            }
        }
    }

	[self.parser parseChangeInRange:affectedCharRange withString:replacementString];
	
	// Fire up autocomplete and create cached lists of scene headings / character names
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

	// WIP
	// [self paginate];
	[self updateSectionMarkers];
		
    return YES;
}

// Never used
- (Line*)getCurrentLine {
	NSInteger position = [self cursorLocation].location;

	for (Line* line in self.parser.lines) {
		if (position >= line.position && position <= line.position + [line.string length]) return line;
	}
	return nil;
}

- (IBAction)reformatRange:(id)sender {
	if ([self.textView selectedRange].length > 0) {
		NSString *string = [[[self.textView textStorage] string] substringWithRange:[self.textView selectedRange]];
		if ([string length]) {
			[self.parser parseChangeInRange:[self.textView selectedRange] withString:string];
			[self applyFormatChanges];
			
			[self.parser createOutline];
			[self updateSceneNumberLabels];

		}
	}
}

- (void)textDidChange:(NSNotification *)notification
{
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;

	// If outline has changed, we will rebuild outline & timeline if needed
	bool changeInOutline = [self.parser getAndResetChangeInOutline];
	if (changeInOutline) {
		// This builds outline in the parser. Weird method name, I know.
		[self.parser createOutline];
		if (self.outlineViewVisible) [self reloadOutline];
		if (self.timelineVisible) [self reloadTimeline];
	}
	
	[self applyFormatChanges];
	
	[self.parser numberOfOutlineItems];
	[self updateSceneNumberLabels];
	
	// Draw masks again if text did change
	if ([_filteredOutline count]) [self maskScenes];
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;

	// Locate current scene & reload outline without building it in parser
	if ((_outlineViewVisible || _timelineVisible) && !_outlineEdit) {
		
		[self getCurrentScene];
		if (_timelineVisible && _currentScene) {
			[self findOnTimeline:_currentScene];
		}
		
		// So... uh. For some reason, _currentScene can get messed up after reloading the outline, so that's why we checked the timeline position first.
		if (_outlineViewVisible) {
			[self getCurrentScene];
			[self reloadOutline];
		}
		
		if (_outlineViewVisible && _currentScene) {
			// Alright, we have some conditions for this.
			// We need to check if the outline was filtered AND if the current scene is within the filtered scenes.
			// Else, just hop to current scene.
			if ([_filteredOutline count]) {
				if ([_filteredOutline containsObject:_currentScene]) {
					[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
						context.allowsImplicitAnimation = YES;
						[self.outlineView scrollRowToVisible:[self.outlineView rowForItem:[self getCurrentScene]]];
					} completionHandler:NULL];
				}
			} else {
				// [self.outlineView scrollRowToVisible:[self.outlineView rowForItem:[self getCurrentScene]]];
				//[[self.outlineView animator] scrollRowToVisible:[self.outlineView rowForItem:[self getCurrentScene]]];
				[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
					context.allowsImplicitAnimation = YES;
					[self.outlineView scrollRowToVisible:[self.outlineView rowForItem:[self getCurrentScene]]];
				} completionHandler:NULL];
			}
		}
	}
}

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

- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index
{
	NSRange range = NSMakeRange(index, [string length]);
	[self replaceCharactersInRange:range withString:newString];
	[[[self undoManager] prepareWithInvocationTarget:self] replaceString:newString withString:string atIndex:index];
}


- (void)moveString:(NSString*)string withRange:(NSRange)range newRange:(NSRange)newRange
{
	// Soooooo... just to let the future version of me to know:
	// OutlineScene has the info if its omission  was left unterminated or doesn't even start.
	// You should really use that info here somehow... you know, add /* and */... every hero's journey is paved with string index and NSRange magic
	
	// Delete the string and add it again to its new position
	[self replaceCharactersInRange:range withString:@""];
	[self replaceCharactersInRange:newRange withString:string];
	
	// Create new ranges for undoing the operation
	NSRange undoRange = NSMakeRange(newRange.location, range.length);
	NSRange undoNewRange = NSMakeRange(range.location, 0);
	[[[self undoManager] prepareWithInvocationTarget:self] moveString:string withRange:undoRange newRange:undoNewRange];
	[[self undoManager] setActionName:@"Move Scene"];
	
	[self reloadOutline];
	if (_timelineVisible) [self reloadTimeline];
}

- (NSRange)cursorLocation
{
	return [[self.textView selectedRanges][0] rangeValue];
}

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
	return NSMakeRange(range->location + position, range->length);
}


# pragma mark - Autocomplete

// Collect all character names from script
- (void) collectCharacterNames {
    /*
     
     So let me elaborate a bit. This is currently two systems upon each other...
     Other use is to collect character cues for autocompletion. There, it doesn't really matter if we have strange stuff after names, because different languages can use their own abbreviations.
     
     Characters are also collected for the filtering feature, so we will just strip away everything after the name, and hope for the best. That's why we have two separate lists of names.
     
     */
    
	[_characterNames removeAllObjects];
	
	// If there was a character selected in Character Filter Box, save it
	NSString *selectedCharacter = _characterBox.selectedItem.title;
    
    NSMutableArray *characterList = [NSMutableArray array];
    
	[_characterBox removeAllItems];
	[_characterBox addItemWithTitle:@" "]; // Add one empty item at the beginning
		
	for (Line *line in [self.parser lines]) {
		if (line.type == character && line != _currentLine && ![_characterNames containsObject:line.string]) {
			// Don't add this line if it's just a character with cont'd, vo, or something we'll add automatically
			if ([line.string rangeOfString:@"(CONT'D)" options:NSCaseInsensitiveSearch].location != NSNotFound) continue;
			
            NSString *character = [line.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
			[_characterNames addObject:character];
			
			// Add automatic CONT'D suffixes
			[_characterNames addObject:[NSString stringWithFormat:@"%@ (CONT'D)", character]];
			            
            if ([character rangeOfString:@"("].location != NSNotFound) {
                NSRange infoRange = [character rangeOfString:@"("];
                NSRange characterRange = NSMakeRange(0, infoRange.location);
                
                character = [NSString stringWithString:[character substringWithRange:characterRange]];
            }
            
            // Trim any useless whitespace
            character = [NSString stringWithString:[character stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            if (![characterList containsObject:character]) {
                // Add character to the filter box
                [_characterBox addItemWithTitle:character];
                
                // Add character to the pure list
                [characterList addObject:character];
            }
		}
	}
    
    // There was a character selected in the filtering menu, so select it again
    if ([selectedCharacter length]) {
        for (NSMenuItem *item in _characterBox.itemArray) {
            if ([item.title isEqualToString:selectedCharacter]) [_characterBox selectItem:item];
        }
    }
}
- (void) collectHeadings {
	[_sceneHeadings removeAllObjects];
	for (Line *line in [self.parser lines]) {
		if (line.type == heading && line != _currentLine && ![_sceneHeadings containsObject:line.string]) {
			[_sceneHeadings addObject:[line.string uppercaseString]];
		}
	}
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {

	NSMutableArray *matches = [NSMutableArray array];
	NSMutableArray *search = [NSMutableArray array];
	
	// Choose which array to search
	if (_currentLine.type == character) search = _characterNames;
	else if (_currentLine.type == heading) search = _sceneHeadings;
	
	// Find matching lines for the partially typed line
	for (NSString *string in search) {
		if ([string rangeOfString:[[textView string] substringWithRange:charRange] options:NSAnchoredSearch range:NSMakeRange(0, [string length])].location != NSNotFound) {
			[matches addObject:string];
		}
	}
	
	[matches sortUsingSelector:@selector(compare:)];
	return matches;
}


# pragma  mark - Formatting

// This is a panic button. It replaces the whole document with raw text input.
- (IBAction) reformatEverything:(id)sender {
	NSString *wholeText = [NSString stringWithString:[self getText]];
	
	[self setText:wholeText];
	self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
	
	[self applyFormatChanges];
	[self formatAllLines];
}

- (void)formatAllLines
{
	for (Line* line in self.parser.lines) {
		[self formatLineOfScreenplay:line onlyFormatFont:NO];
	}
	
	[self updateSceneNumberLabels];
}

- (void)refontAllLines
{
    for (Line* line in self.parser.lines) {
        [self formatLineOfScreenplay:line onlyFormatFont:NO];
    }
}

- (void)applyFormatChanges
{
    for (NSNumber* index in self.parser.changedIndices) {
        Line* line = self.parser.lines[index.integerValue];
        [self formatLineOfScreenplay:line onlyFormatFont:NO];
    }
	
    [self.parser.changedIndices removeAllObjects];
}

- (void)formatLineOfScreenplay:(Line*)line onlyFormatFont:(bool)fontOnly
{
	[self formatLineOfScreenplay:line onlyFormatFont:fontOnly recursive:false];
}

- (void)formatLineOfScreenplay:(Line*)line onlyFormatFont:(bool)fontOnly recursive:(bool)recursive
{
	_currentLine = line;
	
	NSUInteger begin = line.position;
	NSUInteger length = [line.string length];
	NSRange range = NSMakeRange(begin, length);
	
	NSUInteger cursor = [self cursorLocation].location;
	
	// We'll perform a lookback to see that we didn't mistake some uppercase for character cues.
	// I really have NO FUCKING IDEA what's going on in here.
	// Still I managed to get it to work.
	
	/// And basically, this is the part where I officially lost any hope for having an iOS version. The loopback system here is quite convoluted and simultaneously relies on both the parser and interface. I guess interface SHOULD NOT handle this recursion, but that would require an overhaul of the parser. And I'm not strong enough.
	
	if (!recursive) {
		NSInteger index = [[self.parser lines] indexOfObject:line];
		if (index - 2 >= 0) {
			Line* preceedingLine = [[self.parser lines] objectAtIndex:index-1];
			Line* lineBeforeThat = [[self.parser lines] objectAtIndex:index-2];
			
			bool currentlyEditing = false;
			
			if (cursor >= range.location && cursor <= (range.location + range.length)) {
				currentlyEditing = YES;
			}

			if ([preceedingLine.string length] == 0 && lineBeforeThat.type == character && currentlyEditing) {
				lineBeforeThat.type = [self.parser parseLineType:lineBeforeThat atIndex:index - 2 recursive:YES currentlyEditing:currentlyEditing];
				[self formatLineOfScreenplay:lineBeforeThat onlyFormatFont:NO recursive:YES];
				
				preceedingLine.type = [self.parser parseLineType:preceedingLine atIndex:index - 2 recursive:YES currentlyEditing:currentlyEditing];
				[self formatLineOfScreenplay:preceedingLine onlyFormatFont:NO recursive:YES];
			}
			
			if (preceedingLine.type == character) {
				// If next line contains text, we will reformat it too
				if (index + 1 < [self.parser.lines count] && [line.string length] > 0) {
					Line *nextLine = [self.parser.lines objectAtIndex:index+1];
					if ([nextLine.string length] > 0) {
						if (nextLine.type != dialogue && nextLine.type != parenthetical) nextLine.type = dialogue;
						[self formatLineOfScreenplay:nextLine onlyFormatFont:NO recursive:YES];
					}
				}
				
				// Next part is terrible. Let me explain.
				
				// If the line currently parsed is EMPTY and we are NOT editing the line before or
				// the current line, we'll take a step back and reformat it as action.
				// This is sometimes unreliable, but 70% of the time it works pretty OK.
				
				else if ([line.string length] == 0) {
					NSRange previousLineRange = NSMakeRange(preceedingLine.position, [preceedingLine.string length]);
					
					if ((cursor >= previousLineRange.location && cursor <= previousLineRange.location + previousLineRange.length) || currentlyEditing) {
						// Do nothing
					} else {
						// Reset the line type
						preceedingLine.type = [self.parser parseLineType:preceedingLine atIndex:index - 2 recursive:YES];
						[self formatLineOfScreenplay:preceedingLine onlyFormatFont:NO recursive:YES];
					}
				}
			}
			
		}
	}
	
	// Let's do the real formatting now
	NSTextStorage *textStorage = [self.textView textStorage];
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
	
	// This doesn't format empty lines for some reason: [lineHeight setLineHeightMultiple:1.05];
	//NSMutableParagraphStyle *lineHeight = [[NSMutableParagraphStyle alloc]init];
	//[attributes setObject:lineHeight forKey:NSParagraphStyleAttributeName];
	
	// Format according to style
	if ((line.type == heading && [line.string characterAtIndex:0] != '.') ||
		(line.type == transitionLine && [line.string characterAtIndex:0] != '>')) {
		//Make uppercase, and then reapply cursor position, because they'd get lost otherwise
		NSArray<NSValue*>* selectedRanges = self.textView.selectedRanges;
		[textStorage replaceCharactersInRange:range
								   withString:[[textStorage.string substringWithRange:range] uppercaseString]];
		[self.textView setSelectedRanges:selectedRanges];
	}
	if (line.type == heading) {
		//Set Font to bold
		[attributes setObject:[self boldCourier] forKey:NSFontAttributeName];
		
		//If the scene as a color, let's color it!
		if (![line.color isEqualToString:@""]) {
			NSColor* headingColor = [self colors][[line.color lowercaseString]];
			if (headingColor != nil) [attributes setObject:headingColor forKey:NSForegroundColorAttributeName];
		}
	
	} else if (line.type == pageBreak) {
		//Set Font to bold
		[attributes setObject:[self boldCourier] forKey:NSFontAttributeName];
		
	} else if (line.type == lyrics) {
		//Set Font to italic
		[attributes setObject:[self italicCourier] forKey:NSFontAttributeName];
	}

	if (!fontOnly) {
		NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
		
		// Some experiments for section headers
		//[paragraphStyle setParagraphSpacing:0];
		//[paragraphStyle setParagraphSpacingBefore:0];
		
		// This won't format empty lines for some reason: [paragraphStyle setLineHeightMultiple:1.05];
		
		// Handle title page block
		if (line.type == titlePageTitle  ||
			line.type == titlePageAuthor ||
			line.type == titlePageCredit ||
			line.type == titlePageSource) {
			
			// [paragraphStyle setAlignment:NSTextAlignmentCenter];
			
			[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		} else if (line.type == titlePageUnknown ||
				   line.type == titlePageContact ||
				   line.type == titlePageDraftDate) {
			
			//NSColor* commentColor = [self.themeManager currentCommentColor];
			//[attributes setObject:commentColor forKey:NSForegroundColorAttributeName];
			
			/* WORK IN PROGRESS */
			// We'll indent title page blocks a bit more
			
			if ([line.string rangeOfString:@":"].location != NSNotFound) {
				[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
				[paragraphStyle setHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH];
			} else {
				[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * 1.25 * DOCUMENT_WIDTH];
				[paragraphStyle setHeadIndent:TITLE_INDENT * 1.1 * DOCUMENT_WIDTH];
			}

			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

		} else if (line.type == transitionLine) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setAlignment:NSTextAlignmentRight];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == centered || line.type == lyrics) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setAlignment:NSTextAlignmentCenter];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == character) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setFirstLineHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH];

			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == parenthetical) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setFirstLineHeadIndent:PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == dialogue) {
			[paragraphStyle setFirstLineHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == doubleDialogueCharacter) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setFirstLineHeadIndent:DD_CHARACTER_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:DD_CHARACTER_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == doubleDialogueParenthetical) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setFirstLineHeadIndent:DD_PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:DD_PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == doubleDialogue) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
			[paragraphStyle setFirstLineHeadIndent:DOUBLE_DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setHeadIndent:DOUBLE_DIALOGUE_INDENT_P * DOCUMENT_WIDTH];
			[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == section || line.type == synopse) {
			// Stylize sections & synopses
			
			if (self.themeManager) {
				NSColor* commentColor = [self.themeManager currentCommentColor];
				[attributes setObject:commentColor forKey:NSForegroundColorAttributeName];
			}
			
			// Bold section headings for first-level sections
			if (line.type == section) {
				/*
				 // Experiments for section headers
				NSInteger lineIndex = [_parser.lines indexOfObject:line];
				bool sectionBefore = NO;
				bool sectionAfter = NO;
				if (lineIndex < _parser.lines.count - 1 && lineIndex > 1) {
					if ([(Line*)[_parser.lines objectAtIndex:lineIndex - 1] type] == section)  sectionBefore = YES;
					if ([(Line*)[_parser.lines objectAtIndex:lineIndex + 1] type] == section) sectionAfter = YES;
					
					[self formatLineOfScreenplay:[_parser.lines objectAtIndex:lineIndex - 1] onlyFormatFont:NO recursive:YES];
					[self formatLineOfScreenplay:[_parser.lines objectAtIndex:lineIndex + 1] onlyFormatFont:NO recursive:YES];
				}

				
				if (!sectionBefore) [paragraphStyle setParagraphSpacingBefore:15];
				if (!sectionAfter) [paragraphStyle setParagraphSpacing:15];
				 */
				
				if (line.sectionDepth < 2) [attributes setObject:[self boldCourier] forKey:NSFontAttributeName];
				[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			}
			
			if (line.type == synopse) [attributes setObject:[self italicCourier] forKey:NSFontAttributeName];
			
		} else if (line.type == empty) {
			// Just to make sure
			NSInteger index = [_parser.lines indexOfObject:line];
			
			Line* preceedingLine;
			
			if (index > 1) {
				preceedingLine = [_parser.lines objectAtIndex:index - 1];
				if ([preceedingLine.string length] < 1) {
					[paragraphStyle setFirstLineHeadIndent:0];
					[paragraphStyle setHeadIndent:0];
					[paragraphStyle setTailIndent:0];
					[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
				}
			}
		}
	}
		
	// Remove all former paragraph styles and overwrite fonts
	if (!fontOnly) {
		[textStorage removeAttribute:NSParagraphStyleAttributeName range:range];
		
		if (![attributes valueForKey:NSForegroundColorAttributeName]) {
			[attributes setObject:self.themeManager.currentTextColor forKey:NSForegroundColorAttributeName];
		}
		if (![attributes valueForKey:NSUnderlineStyleAttributeName]) {
			[attributes setObject:@0 forKey:NSUnderlineStyleAttributeName];
		}
	}
	if (![attributes valueForKey:NSFontAttributeName]) {
		[attributes setObject:[self courier] forKey:NSFontAttributeName];
	}
	
	//Add selected attributes
	if (range.length > 0) {
		[textStorage addAttributes:attributes range:range];
	} else {
		if (range.location + 1 < [textStorage.string length]) {

			range = NSMakeRange(range.location, range.length + 1);
			[textStorage addAttributes:attributes range:range];
		}
	}
	
	// INPUT ATTRIBUTES FOR CARET / CURSOR
	if ([line.string length] == 0 && !recursive) {
		// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
		
		Line* previousLine;
		NSInteger lineIndex = [_parser.lines indexOfObject:line];
		if (lineIndex > 0) previousLine = [_parser.lines objectAtIndex:lineIndex - 1];
		
		NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];

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
	
	//Add in bold, underline, italic and all that other good stuff. it looks like a lot of code, but the content is only executed for every formatted block. For unformatted text, this just whizzes by.
	
	[line.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSUInteger symbolLength = 1;
		NSRange effectiveRange;
		if (range.length >= 2*symbolLength) {
			effectiveRange = NSMakeRange(range.location + symbolLength, range.length - 2*symbolLength);
		} else {
			effectiveRange = NSMakeRange(range.location + symbolLength, 0);
		}
		[textStorage addAttribute:NSFontAttributeName value:self.italicCourier
							range:[self globalRangeFromLocalRange:&effectiveRange
												 inLineAtPosition:line.position]];
		
		NSRange openSymbolRange = NSMakeRange(range.location, symbolLength);
		NSRange closeSymbolRange = NSMakeRange(range.location+range.length-symbolLength, symbolLength);
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
							range:[self globalRangeFromLocalRange:&openSymbolRange
												 inLineAtPosition:line.position]];
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
							range:[self globalRangeFromLocalRange:&closeSymbolRange
												 inLineAtPosition:line.position]];
	}];
	
	[line.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSUInteger symbolLength = 2;
		NSRange effectiveRange;
		if (range.length >= 2*symbolLength) {
			effectiveRange = NSMakeRange(range.location + symbolLength, range.length - 2*symbolLength);
		} else {
			effectiveRange = NSMakeRange(range.location + symbolLength, 0);
		}
		
		[textStorage addAttribute:NSFontAttributeName value:self.boldCourier
							range:[self globalRangeFromLocalRange:&effectiveRange
												 inLineAtPosition:line.position]];
		
		NSRange openSymbolRange = NSMakeRange(range.location, symbolLength);
		NSRange closeSymbolRange = NSMakeRange(range.location+range.length-symbolLength, symbolLength);
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
							range:[self globalRangeFromLocalRange:&openSymbolRange
												 inLineAtPosition:line.position]];
		[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
							range:[self globalRangeFromLocalRange:&closeSymbolRange
												 inLineAtPosition:line.position]];
	}];
	
	if (!fontOnly) {
		[line.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			NSUInteger symbolLength = 1;
			
			[textStorage addAttribute:NSUnderlineStyleAttributeName value:@1
								range:[self globalRangeFromLocalRange:&range
													 inLineAtPosition:line.position]];
			
			NSRange openSymbolRange = NSMakeRange(range.location, symbolLength);
			NSRange closeSymbolRange = NSMakeRange(range.location+range.length-symbolLength, symbolLength);
			[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
								range:[self globalRangeFromLocalRange:&openSymbolRange
													 inLineAtPosition:line.position]];
			[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
								range:[self globalRangeFromLocalRange:&closeSymbolRange
													 inLineAtPosition:line.position]];
		}];
		
		[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentCommentColor
								range:[self globalRangeFromLocalRange:&range
													 inLineAtPosition:line.position]];
		}];
		
		[line.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			[textStorage addAttribute:NSForegroundColorAttributeName value:self.themeManager.currentInvisibleTextColor
								range:[self globalRangeFromLocalRange:&range
													 inLineAtPosition:line.position]];
		}];
	}
}

# pragma  mark Fonts

- (NSFont*)courier
{
    if (!_courier) {
        //_courier = [NSFont fontWithName:@"Andale Mono" size:[self fontSize]];
		_courier = [NSFont fontWithName:@"Courier Prime" size:[self fontSize]];
    }
    return _courier;
}

- (NSFont*)boldCourier
{
    if (!_boldCourier) {
        _boldCourier = [NSFont fontWithName:@"Courier Prime Bold" size:[self fontSize]];
    }
    return _boldCourier;
}

- (NSFont*)italicCourier
{
    if (!_italicCourier) {
        _italicCourier = [NSFont fontWithName:@"Courier Prime Italic" size:[self fontSize]];
    }
    return _italicCourier;
}

// This is here for legacy reasons
- (NSUInteger)fontSize
{
	// Beat used to have font-based "zoom", legacy of Writer. I tried thousands of weird tricks to fix and circumvent it until I figured out how to use scaleUnitToSize.
	// Font size was finally determined by this weird equation. I have no idea what I was thinking about, but for now, this is how we set our font size...... everything is proportially sized, and it shouldn't be too hard to just use constants for these in the future. But, for now, until I have the time and energy, we're stuck with this stuff. Read more nearby setZoom.
	
	// Old way
	// _fontSize = DEFAULT_ZOOM * FONT_SIZE_MODIFIER * ZOOM_MODIFIER;
	
	// New way :-)
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

- (NSString*)titlePage
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd.MM.yyyy"];
    return [NSString stringWithFormat:@"Title: \nCredit: \nAuthor: \nDraft date: %@\nContact: \n\n", [dateFormatter stringFromDate:[NSDate date]]];
}


- (IBAction)addTitlePage:(id)sender
{
    if ([self selectedTabViewTab] == 0) {
        if ([[self getText] length] < 6) {
            [self addString:[self titlePage] atIndex:0];
            self.textView.selectedRange = NSMakeRange(7, 0);
        } else if (![[[self getText] substringWithRange:NSMakeRange(0, 6)] isEqualToString:@"Title:"]) {
            [self addString:[self titlePage] atIndex:0];
        }
    }
}

- (IBAction)addPageBreak:(id)sender
{
    if ([self selectedTabViewTab] == 0) {
        NSRange cursorLocation = [self cursorLocation];
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
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self format:cursorLocation beginningSymbol:boldSymbol endSymbol:boldSymbol];
    }
}

- (IBAction)unlockSceneNumbers:(id)sender
{
	NSString *sceneNumberPatternString = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPatternString];
	
	NSError *error = nil;
	NSRegularExpression *sceneNumberPattern = [NSRegularExpression regularExpressionWithPattern: @" (\\#([0-9A-Za-z\\.\\)-]+)\\#)" options: NSRegularExpressionCaseInsensitive error: &error];
	
	
	_sceneNumberLabelUpdateOff = true;
	for (OutlineScene * scene in [self getScenes]) {
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
	[self updateSceneNumberLabels];
}


// Preprocessing was apparently a bottleneck. Redone in 1.1.0f
- (NSString*) preprocessSceneNumbers
{
	NSString *sceneNumberPattern = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPattern];
	NSMutableString *fullText = [NSMutableString stringWithString:@""];
	
	NSUInteger sceneCount = 1; // Track scene amount
		
	for (Line *line in [self.parser lines]) {
		NSString *cleanedLine = [line.string stringByTrimmingCharactersInSet: NSCharacterSet.whitespaceCharacterSet];
		
		// If the heading already has a forced number, skip it
		if (line.type == heading && ![testSceneNumber evaluateWithObject: cleanedLine]) {
			// Check if the scene heading is omited
			if (![line omited]) {
				[fullText appendFormat:@"%@ #%lu#\n", cleanedLine, sceneCount];
				sceneCount++;
			}
		} else {
			[fullText appendFormat:@"%@\n", cleanedLine];
		}
	}
	
	return fullText;
}

- (IBAction)lockSceneNumbers:(id)sender
{
	NSString *rawText = [self getText];
	
	NSString *sceneNumberPattern = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPattern];
	
	_sceneNumberLabelUpdateOff = true;
	for (OutlineScene * scene in [self getScenes]) {
		if (![testSceneNumber evaluateWithObject: scene.string]) {
			if (!scene.sceneNumber) { scene.sceneNumber = @""; }
			NSString *sceneNumber = [NSString stringWithFormat:@"%@%@%@", @" #", scene.sceneNumber, @"#"];
			NSUInteger index = scene.line.position + [scene.string length];
			[self addString:sceneNumber atIndex:index];
		}
	}
	
	_sceneNumberLabelUpdateOff = false;
	[self updateSceneNumberLabels];
	
	[[[self undoManager] prepareWithInvocationTarget:self] undoSceneNumbering:rawText];
}

- (void)undoSceneNumbering:(NSString*)rawText
{
	[self setText:rawText];
	[self textDidChange:[NSNotification notificationWithName:@"" object:nil]];
	
	self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
	[self applyFormatChanges];
	
	// This is a strange bug
	[self updateSceneNumberLabels];
}


- (IBAction)makeItalic:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self format:cursorLocation beginningSymbol:italicSymbol endSymbol:italicSymbol];
    }
}

- (IBAction)makeUnderlined:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self format:cursorLocation beginningSymbol:underlinedSymbol endSymbol:underlinedSymbol];
    }
}


- (IBAction)makeNote:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self format:cursorLocation beginningSymbol:noteOpen endSymbol:noteClose];
    }
}

- (IBAction)makeOmitted:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
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

- (IBAction)forceHeading:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self forceLineType:cursorLocation symbol:forceHeadingSymbol];
    }
}

- (IBAction)forceAction:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self forceLineType:cursorLocation symbol:forceActionSymbol];
    }
}

- (IBAction)forceCharacter:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self forceLineType:cursorLocation symbol:forceCharacterSymbol];
    }
}

- (IBAction)forcetransitionLine:(id)sender
{
    
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self forceLineType:cursorLocation symbol:forcetransitionLineSymbol];
    }
}

- (IBAction)forceLyrics:(id)sender
{
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self forceLineType:cursorLocation symbol:forceLyricsSymbol];
    }
}

- (void)forceLineType:(NSRange)cursorLocation symbol:(NSString*)symbol
{
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

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string
{
    if ([self textView:self.textView shouldChangeTextInRange:range replacementString:string]) {
        [self.textView replaceCharactersInRange:range withString:string];
        [self textDidChange:[NSNotification notificationWithName:@"" object:nil]];
    }
}


#pragma mark - User Interaction

- (IBAction)toggleOutlineView:(id)sender
{
	// Animations removed in 1.1.0. They were slow and ugly.
	
    self.outlineViewVisible = !self.outlineViewVisible;
	
	NSUInteger offset = 20;
	if ([self isFullscreen]) offset = 0;
	
    if (self.outlineViewVisible) {
		// Show outline
		[self reloadOutline];
		[self collectCharacterNames]; // For filtering
		
		[self.outlineView expandItem:nil expandChildren:true];
        [self.outlineViewWidth setConstant:TREE_VIEW_WIDTH];
		
		NSWindow *window = self.windowControllers[0].window;
		NSRect newFrame;
		
		if (![self isFullscreen]) {
			
			CGFloat newWidth = window.frame.size.width + TREE_VIEW_WIDTH + offset;
			CGFloat newX = window.frame.origin.x - TREE_VIEW_WIDTH / 2;
			CGFloat screenWidth = [NSScreen mainScreen].frame.size.width;
			
			// Ensure the main document won't go out of screen bounds when opening the sidebar
			if (newX + newWidth > screenWidth) {
				newX = newX - (newX + newWidth - screenWidth);
			} else if (newX < 0) {
				newX = 0;
			}
			
			newFrame = NSMakeRect(newX,
										 window.frame.origin.y,
										 newWidth,
										 window.frame.size.height);
			[window setFrame:newFrame display:YES];
		} else {
			// We need a bit different settings if the app is fullscreen
			CGFloat width = ((window.frame.size.width - TREE_VIEW_WIDTH) / 2 - _documentWidth * _magnification / 2) / _magnification;
			[self.textView setTextContainerInset:NSMakeSize(width, TEXT_INSET_TOP)];
			[self updateSceneNumberLabels];
		}
    } else {
		// Hide outline
		[self.outlineViewWidth setConstant:0];
		NSWindow *window = self.windowControllers[0].window;
		NSRect newFrame;
		
		CGFloat newX = window.frame.origin.x + TREE_VIEW_WIDTH / 2;
		
		if (![self isFullscreen]) {
			newFrame = NSMakeRect(newX,
								  window.frame.origin.y,
								  window.frame.size.width - TREE_VIEW_WIDTH - offset,
								  window.frame.size.height);
			[window setFrame:newFrame display:YES];
		} else {
			CGFloat width = (window.frame.size.width / 2 - _documentWidth * _magnification / 2) / _magnification;
			
			[self.textView setTextContainerInset:NSMakeSize(width, TEXT_INSET_TOP)];
			[self updateSceneNumberLabels];
		}
    }
	
	[[self.textView layoutManager] ensureLayoutForTextContainer:[self.textView textContainer]];
}

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}
- (IBAction)export:(id)sender {}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Special conditions for other than normal edit view
	if ([self selectedTabViewTab] != 0) {
		if ([self selectedTabViewTab] == 1 && [menuItem.title isEqualToString:@"Toggle Preview"]) {
			[menuItem setState:NSOnState];
			return YES;
		}

		// If CARD VIEW is enabled
		if ([self selectedTabViewTab] == 2) {
			//
			if ([menuItem.title isEqualToString:@"Show Cards"]) {
				[menuItem setState:NSOnState];
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
		
		return NO;
	}
	if (_timelineVisible && [menuItem.title isEqualToString:@"Show Timeline"]) {
		[menuItem setState:NSOnState];
		return YES;
	} else {
		[menuItem setState:NSOffState];
	}
	
	if ([menuItem.title isEqualToString:@"Share"]) {
        [menuItem.submenu removeAllItems];
        NSArray *services = @[];
        if (self.fileURL) {
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
        return YES;
	} else if ([menuItem.title isEqualToString:@"Autosave"]) {
		if (_autosave) menuItem.state = NSOnState; else menuItem.state = NSOffState;
	} else if ([menuItem.title isEqualToString:@"Print…"] || [menuItem.title isEqualToString:@"PDF"] || [menuItem.title isEqualToString:@"HTML"]) {
        NSArray* words = [[self getText] componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString* visibleCharacters = [words componentsJoinedByString:@""];
        if ([visibleCharacters length] == 0) {
            return NO;
        }
	} else if ([menuItem.title isEqualToString:@"Automatically Match Parentheses"]) {
        if (self.matchParentheses) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        if ([self selectedTabViewTab] != 0) {
            return NO;
        }
	} else if ([menuItem.title isEqualToString:@"Show Scene Numbers"]) {
		if (self.showSceneNumberLabels) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
		if ([self selectedTabViewTab] != 0) {
			return NO;
		}
	} else if ([menuItem.title isEqualToString:@"Print Automatic Scene Numbers"]) {
		if (self.printSceneNumbers) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
		if ([self selectedTabViewTab] != 0) {
			return NO;
		}
    } else if ([menuItem.title isEqualToString:@"Show Outline"]) {
        if (self.outlineViewVisible) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        if ([self selectedTabViewTab] != 0) {
            return NO;
        }
	} else if ([menuItem.title isEqualToString:@"Dark Mode"]) {
		if ([(ApplicationDelegate *)[NSApp delegate] isDark]) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
		if ([self selectedTabViewTab] != 0) {
			return NO;
		}
    } else if ([menuItem.title isEqualToString:@"Zoom In"] || [menuItem.title isEqualToString:@"Zoom Out"] || [menuItem.title isEqualToString:@"Reset Zoom"]) {
        if ([self selectedTabViewTab] != 0) {
            return NO;
        }
    } else if ([menuItem.title isEqualToString:@"Show Cards"]) {
		if ([self selectedTabViewTab] == 1) return NO;
		if ([self selectedTabViewTab] == 2) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
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
- (IBAction)toggleNightMode:(id)sender {
	[(ApplicationDelegate *)[NSApp delegate] toggleDarkMode];
	
	[self.thisWindow setViewsNeedDisplay:true];
	
	[self.masterView setNeedsDisplayInRect:[_masterView frame]];
	[self.backgroundView setNeedsDisplay:true];
	[self.textView setNeedsDisplay:true];
	[self.textScrollView setNeedsDisplay:true];
	
	[[self.textView layoutManager] ensureLayoutForTextContainer:[self.textView textContainer]];
	
	[self updateTimelineStyle];
	
	[self.textView setNeedsDisplay:true];
	
	for (NSTextField* textField in self.sceneNumberLabels) {
		//textField.textColor = self.themeManager.currentTextColor;
		[textField setNeedsDisplay:true];
	}
	
	if (_outlineViewVisible) [self.outlineView setNeedsDisplay:YES];
	
	[self.textView toggleDarkPopup:nil];
	_darkPopup = [self isDark];
}
- (bool)isDark {
	return [(ApplicationDelegate *)[NSApp delegate] isDark];
}

- (IBAction)toggleMatchParentheses:(id)sender
{
    NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
    
    for (Document* doc in openDocuments) {
        doc.matchParentheses = !doc.matchParentheses;
    }
    [[NSUserDefaults standardUserDefaults] setBool:self.matchParentheses forKey:MATCH_PARENTHESES_KEY];
}

- (IBAction)togglePrintSceneNumbers:(id)sender
{
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	
	for (Document* doc in openDocuments) {
		doc.printSceneNumbers = !doc.printSceneNumbers;
	}
	[[NSUserDefaults standardUserDefaults] setBool:self.printSceneNumbers forKey:PRINT_SCENE_NUMBERS_KEY];
}

// Some weirdness because of the Writer legacy. Writer had real themes, and this function loaded the selected theme for every open window. We only have day/night, but the method names remain.
// WIP: Rename, conform + stylize this part
- (void)loadSelectedTheme:(bool)forAll
{
	NSArray* openDocuments;
	if (forAll) openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	else openDocuments = @[self];
	
    for (Document* doc in openDocuments) {
        BeatTextView *textView = doc.textView;
		
		[textView setBackgroundColor:[self.themeManager currentBackgroundColor]];
		[doc.textScrollView setMarginColor:[self.themeManager currentMarginColor]];
		[doc.textView setMarginColor:[self.themeManager currentMarginColor]];
		
        [textView setSelectedTextAttributes:@{
											  NSBackgroundColorAttributeName: [self.themeManager currentSelectionColor],
											  NSForegroundColorAttributeName: [self.themeManager currentBackgroundColor]
		}];
        [textView setTextColor:[self.themeManager currentTextColor]];
        [textView setInsertionPointColor:[self.themeManager currentCaretColor]];
        [doc formatAllLines];
		
		NSOutlineView *outlineView = doc.outlineView;
		[outlineView setBackgroundColor:self.themeManager.theme.outlineBackground];
		
		// Set global background
		doc.backgroundView.fillColor = self.themeManager.theme.outlineBackground;
    }
}

- (IBAction)preview:(id)sender
{
    if ([self selectedTabViewTab] == 0) {
        [self updateWebView];
        
        [self setSelectedTabViewTab:1];
		_printPreview = YES;
    } else {
		[self setSelectedTabViewTab:0];
		[self updateLayout];
		[self ensureCaret];
		
		_printPreview = NO;
    }
	[self updateSceneNumberLabels];
}
- (void)cancelOperation:(id) sender
{
	if (_printPreview) [self preview:nil];
	if (_cardsVisible) [self toggleCards:nil];
	//if (_timelineVisible) [self toggleTimeline:nil];
}

- (NSUInteger)selectedTabViewTab
{
    return [self.tabView indexOfTabViewItem:[self.tabView selectedTabViewItem]];
}

- (void)setSelectedTabViewTab:(NSUInteger)index
{
    [self.tabView selectTabViewItem:[self.tabView tabViewItemAtIndex:index]];
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

#pragma  mark - Outline data source + delegate

- (NSUInteger) getNumberOfScenes {
	NSUInteger result = 0;
	for (Line * line in [self.parser lines]) {
		if (line.type == heading) result++;
	}
	return result;
}

- (NSMutableArray *) getScenes {
	NSMutableArray * scenes = [[NSMutableArray alloc] init];
	for (OutlineScene * scene in [self.parser outline]) {
		if (scene.type == heading) [scenes addObject:scene];
		/*
		// NOPE. Deprecated.
		if ([scene.scenes count]) {
			for (OutlineScene * subscene in scene.scenes) {
				if (subscene.type == heading) [scenes addObject:subscene];
			}
		}
		*/
	}
	
	return scenes;
}

- (NSMutableArray *) getOutlineItems {
	// For some reason we can't check the original array (memory/thread reasons?)
	// so we'll make a copy out of all the items
	NSMutableArray * outlineItems = [NSMutableArray array];
	for (OutlineScene * scene in [self.parser outline]) {
		[outlineItems addObject:scene];
	}
	
	return outlineItems;
}

- (void) filterOutline {
	// We don't need to GET outline at this point, let's use the cached one
	[_filteredOutline removeAllObjects];
	if (![_filters activeFilters]) return;
	
	if ([_filters.character length] > 0) {
		[_filters setScript:self.parser.lines scenes:[self getOutlineItems]];
		[_filters byCharacter:self.filters.character];
	} else {
		[_filters resetScenes];
	}

	for (OutlineScene * scene in _flatOutline) {
		//NSLog(@"%@ - %@", scene.string, [_filters match:scene] ? @"YES" : @"NO");
        if ([_filters match:scene]) [_filteredOutline addObject:scene];
	}
}

- (void)searchOutline {
	// Don't search if it's only spaces
	if ([_outlineSearchField.stringValue containsOnlyWhitespace] || [_outlineSearchField.stringValue length] < 1) {
		//[_filteredOutline removeAllObjects];
        [_filters byText:@""];
	}
	
    [_filters byText:_outlineSearchField.stringValue];
    [self reloadOutline];
	
	// Mask scenes that were left out
	[self maskScenes];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item;
{
	if (FLATOUTLINE) {
		// If we have a search term, let's use the filtered array
		if ([_filters activeFilters]) {
			return [_filteredOutline count];
		} else {
			return [[self getOutlineItems] count];
		}
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	if (FLATOUTLINE) {
		// If there is a search term, let's search the filtered array
		if ([_filters activeFilters]) {
			return [_filteredOutline objectAtIndex:index];
		} else {
			return [[self getOutlineItems] objectAtIndex:index];
		}
	}
	
	/*
	if (!item) {
		return [[self.parser outline] objectAtIndex:index];
	} else {
		return [[item scenes] objectAtIndex:index];
	}
	 */
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (FLATOUTLINE) return NO;
	
	if ([[item scenes] count] > 0) {
		return YES;
	}
	else { return NO; }
}

/*
 
 Searching for sunlight there in your room
 Trolling for one light there in the gloom
 You dream of a better day
 alone with the moon
 
 */

// Outline items
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{ @autoreleasepool {
    if ([item isKindOfClass:[OutlineScene class]]) {
		
        OutlineScene* line = item;
		NSUInteger sceneNumberLength = 0;
		bool currentScene = false;

		// Check that this scene is not omited from the screenplay
		bool omited = line.line.omited;
		
		// Create padding for entry
		NSString *padding = @"";
		NSString *paddingSpace = @"    ";
		padding = [@"" stringByPaddingToLength:(line.sectionDepth * paddingSpace.length) withString: paddingSpace startingAtIndex:0];
		
		// Section padding is slightly smaller
		if (line.type == section) {
			if (line.sectionDepth > 1) padding = [@"" stringByPaddingToLength:((line.sectionDepth - 1) * paddingSpace.length) withString: paddingSpace startingAtIndex:0];
			else padding = @"";
		}
		
		
		// The outline elements will be formatted as rich text,
		// which is apparently VERY CUMBERSOME in Cocoa/Objective-C.
		NSMutableString *rawString = [NSMutableString stringWithString:line.string];
		
		// Strip any formatting
		[rawString replaceOccurrencesOfString:@"*" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [rawString length])];
		
		NSMutableAttributedString * resultString = [[NSMutableAttributedString alloc] initWithString:rawString];
		
		// If empty, return the empty string
		if ([resultString length] == 0) return resultString;
		
		// Remove any formatting
        if (line.type == heading) {
			if (_currentScene.string) {
				if (_currentScene == line) currentScene = true;
				if ([line.string isEqualToString:_currentScene.string] && line.sceneNumber == _currentScene.sceneNumber) currentScene = true;
			}
			
			//Replace "INT/EXT" with "I/E" to make the lines match nicely
			NSString* string = [rawString uppercaseString];
            string = [string stringByReplacingOccurrencesOfString:@"INT/EXT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"INT./EXT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"EXT/INT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"EXT./INT" withString:@"I/E"];
			
			// Remove force scene character
			if ([string characterAtIndex:0] == '.') {
				string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
			}
			
			// Looking at this a year after starting the project, finding out it's convoluted and deciding not to do anything about it
			if (line.sceneNumber) {
				// Clean up forced scene number from the string
				string = [string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", line.sceneNumber] withString:@""];
								
				NSString *sceneHeader;
				if (!omited) {
					sceneHeader = [NSString stringWithFormat:@" %@%@.", padding, line.sceneNumber];
					string = [NSString stringWithFormat:@"%@ %@", sceneHeader, string];
				} else {
					// If scene is omited, put it in brackets
					sceneHeader = [NSString stringWithFormat:@" %@", padding];
					string = [NSString stringWithFormat:@"%@(%@)", sceneHeader, string];
				}
				
				NSFont *font = [NSFont systemFontOfSize:OUTLINE_SCENE_SIZE];
				NSDictionary * fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, nil];
				
				resultString = [[NSMutableAttributedString alloc] initWithString:string attributes:fontAttributes];
				sceneNumberLength = [sceneHeader length];
				
				// Scene number will be displayed in a slightly darker shade
				if (!omited) {
					[resultString addAttribute:NSForegroundColorAttributeName value:NSColor.grayColor range:NSMakeRange(0,[sceneHeader length])];
					[resultString addAttribute:NSForegroundColorAttributeName value:[self colors][@"darkGray"] range:NSMakeRange([sceneHeader length], [resultString length] - [sceneHeader length])];
				}
				// If it's omited, make it totally gray
				else {
					[resultString addAttribute:NSForegroundColorAttributeName value:[self colors][@"veryDarkGray"] range:NSMakeRange(0, [resultString length])];
				}
				
				// If this is the currently edited scene, make the whole string white. For color-coded scenes, the color will be set later.
				if (currentScene) {
					[resultString addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, [resultString length])];
				}
								
				// Lines without RTF formatting have uneven leading, so let's fix that.
				[resultString applyFontTraits:NSUnitalicFontMask range:NSMakeRange(0,[resultString length])];
				
            } else {
                //return [NSString stringWithFormat:@"  %@", string];
				resultString = [[NSMutableAttributedString alloc] initWithString:string];
            }
			
			[resultString applyFontTraits:NSBoldFontMask range:NSMakeRange(0,[resultString length])];
        }
        if (line.type == synopse) {
            NSString* string = rawString;
            if ([string length] > 0) {
                //Remove "="
                if ([string characterAtIndex:0] == '=') {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
                //Remove leading whitespace
                while (string.length && [string characterAtIndex:0] == ' ') {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
				string = [NSString stringWithFormat:@" %@%@", padding, string];
                //string = [@"  " stringByAppendingString:string];
				
				NSFont *font = [NSFont systemFontOfSize:OUTLINE_SECTION_SIZE];
				NSDictionary * fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, nil];
				
				resultString = [[NSMutableAttributedString alloc] initWithString:string attributes:fontAttributes];
				
				// Italic + white color
				[resultString applyFontTraits:NSItalicFontMask range:NSMakeRange(0,[resultString length])];
				
				[resultString addAttribute:NSForegroundColorAttributeName value:self.themeManager.theme.outlineHighlight range:NSMakeRange(0, [resultString length])];
            } else {
                resultString = [[NSMutableAttributedString alloc] initWithString:line.string];
            }
        }
        if (line.type == section) {
            NSString* string = rawString;
            if ([string length] > 0) {
				
                //Remove "#"
				while ([string characterAtIndex:0] == '#' && [string length] > 1) {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
				
                //Remove leading whitespace
                while (string.length && [string characterAtIndex:0] == ' ') {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
				
				string = [NSString stringWithFormat:@"%@%@", padding, string];
				
				NSFont *font = [NSFont systemFontOfSize:OUTLINE_SECTION_SIZE];
				NSDictionary * fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, nil];

				resultString = [[NSMutableAttributedString alloc] initWithString:string attributes:fontAttributes];
				
				// Bold + highlight color
				[resultString addAttribute:NSForegroundColorAttributeName value:self.themeManager.theme.outlineHighlight range:NSMakeRange(0,[resultString length])];
				
				[resultString applyFontTraits:NSBoldFontMask range:NSMakeRange(0,[resultString length])];
            } else {
                resultString = [[NSMutableAttributedString alloc] initWithString:line.string];
            }
        }

		// Don't color omited scenes
		if (line.color && !omited) {
			//NSMutableAttributedString * color = [[NSMutableAttributedString alloc] initWithString:@" ⬤" attributes:nil];
			NSString *colorString = [line.color lowercaseString];
			NSColor *colorName = [self colors][colorString];
			
			// If we found a suitable color, let's add it
			if (colorName != nil) {
				[resultString addAttribute:NSForegroundColorAttributeName value:colorName range:NSMakeRange(sceneNumberLength, [resultString length] - sceneNumberLength)];
				//[color addAttribute:NSForegroundColorAttributeName value:colorName range:NSMakeRange(0, 2)];
				//[resultString appendAttributedString:color];
			}
		}
		
		return resultString;
    }
    return @"";
	
} }

- (void)scrollToScene:(OutlineScene*)scene {
	NSRange lineRange = NSMakeRange([scene line].position, [scene line].string.length);
	[self.textView setSelectedRange:lineRange];
	[self.textView scrollRangeToVisible:lineRange];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	if ([item isKindOfClass:[OutlineScene class]]) {
		[self scrollToScene:item];
		[_thisWindow makeFirstResponder:_textView];
	}
	return NO;
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray *)draggedItems {
	//_draggedNodes = draggedItems;
	[session.draggingPasteboard setData:[NSData data] forType:LOCAL_REORDER_PASTEBOARD_TYPE];
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	// ?
}


- (id <NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item{
	//OutlineScene *scene = (OutlineScene *)(((NSTreeNode *)item).representedObject);

	// Don't allow reordering a filtered list
	if ([_filters activeFilters]) return nil;
	
	OutlineScene *scene = (OutlineScene*)item;
	_draggedScene = scene;
	
	NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];
	[pboardItem setString:scene.string forType: NSPasteboardTypeString];
	//NSData *data = [NSKeyedArchiver archivedDataWithRootObject:scene];
	//[pboardItem setValue:scene forType:OUTLINE_DATATYPE];
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
	
	NSMutableArray *outline = [self getOutlineItems];
	
	NSInteger to = index;
	NSInteger from = [outline indexOfObject:_draggedScene];
	
	if (from == to || from  == to - 1) return NO;
	
	// Let's move the scene
	_outlineEdit = YES;
	[self moveScene:_draggedScene from:from to:to];
	_outlineEdit = NO;
	return YES;
}

- (void) reloadOutline {
	// Save outline scroll position
	NSPoint scrollPosition = [[self.outlineScrollView contentView] bounds].origin;
	
	// Create outline
	_flatOutline = [self getOutlineItems];
	
	[self filterOutline];
	[self.outlineView reloadData];
	
	/*
	// DEPRECATED
	 
	// Expand all
	[self.outlineView expandItem:nil expandChildren:true];
	
	// Then let's close the ones that the user had closed
	for (int i = 0; i < [[self.parser outline] count]; i++) {
		id item = [self.outlineView itemAtRow:i];
		if ([_outlineClosedSections containsObject:[item string]]) {
			[self.outlineView collapseItem:item];
		}
	}
	 */
	
	// Scroll back to original position after reload
	[[self.outlineScrollView contentView] scrollPoint:scrollPosition];
	[self updateSceneNumberLabels];
}

- (void) moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to {
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
	OutlineScene *beforeScene;
	if (!moveToEnd) beforeScene = [outline objectAtIndex:to];
	
	// On to the very dangerous stuff :-) fuck me :----)
	NSRange range = NSMakeRange(sceneToMove.sceneStart, sceneToMove.sceneLength);
	NSString *textToMove = [[self getText] substringWithRange:range];

	// Count the index.
	//NSInteger moveToIndex = 0;
	//if (!moveToEnd) moveToIndex = beforeScene.sceneStart;
	//else moveToIndex = [[self getText] length];
	
	NSRange newRange;
	
	// Different ranges depending on to which direction the scene was moved
	if (from < to) {
		if (!moveToEnd) {
			newRange = NSMakeRange(beforeScene.sceneStart - sceneToMove.sceneLength, 0);
		} else {
			newRange = NSMakeRange([[self getText] length] - sceneToMove.sceneLength, 0);
		}
	} else {
		newRange = NSMakeRange(beforeScene.sceneStart, 0);
	}
	
	// We move the string itself in an easily undoable method
	[self moveString:textToMove withRange:range newRange:newRange];
}


#pragma mark - Outline/timeline context menu, including setting colors

/*
 
 Color context menu
 
 Note: self.timelineClickedScene keeps track if a scene was clicked on the timeline. The reason for this is that we use the same menu for both outline and timeline views. NSOutlineView's clickedRow property seems to be always set, so we'll always check first if something was clicked on the timeline.

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

- (void)initColorPicker {
	for (NSTouchBarItem *item in [self.textView.touchBar templateItems]) {
		if ([item.className isEqualTo:@"NSColorPickerTouchBarItem"]) {
			NSColorPickerTouchBarItem *picker = (NSColorPickerTouchBarItem*)item;
			_colorPicker = picker;
			picker.colorList = [[NSColorList alloc] init];

			[picker.colorList setColor:NSColor.blackColor forKey:@"none"]; // THE HOUSE IS BLACK.
			[picker.colorList setColor:[self colors][@"red"] forKey:@"red"];
			[picker.colorList setColor:[self colors][@"blue"] forKey:@"blue"];
			[picker.colorList setColor:[self colors][@"green"] forKey:@"green"];
			[picker.colorList setColor:[self colors][@"cyan"] forKey:@"cyan"];
			[picker.colorList setColor:[self colors][@"orange"] forKey:@"orange"];
			[picker.colorList setColor:[self colors][@"pink"] forKey:@"pink"];
			[picker.colorList setColor:[self colors][@"gray"] forKey:@"gray"];
			[picker.colorList setColor:[self colors][@"magenta"] forKey:@"magenta"];
		}
	}
}

- (IBAction) pickColor:(id)sender {
	NSString *pickedColor;

	for (NSString *color in [self colors]) {
		if ([_colorPicker.color isEqualTo:[self colors][color]]) {
			pickedColor = color;
		}
	}
	
	if ([_colorPicker.color isEqualTo:NSColor.blackColor]) pickedColor = @"none"; // THE HOUSE IS BLACK.
	
	_currentScene = [self getCurrentScene];
	if (!_currentScene) return;
	
	[self setColor:pickedColor forScene:_currentScene];

}

- (IBAction) setNoneColor:(id) sender { [self setColor:@"NONE"]; }
- (IBAction) setRedColor:(id) sender { [self setColor:@"RED"]; }
- (IBAction) setBlueColor:(id) sender { [self setColor:@"BLUE"]; }
- (IBAction) setGreenColor:(id) sender { [self setColor:@"GREEN"]; }
- (IBAction) setCyanColor:(id) sender { [self setColor:@"CYAN"]; }
- (IBAction) setOrangeColor:(id) sender { [self setColor:@"ORANGE"]; }
- (IBAction) setPinkColor:(id) sender { [self setColor:@"PINK"]; }
- (IBAction) setGrayColor:(id) sender { [self setColor:@"GRAY"]; }
- (IBAction) setMagentaColor:(id) sender { [self setColor:@"MAGENTA"]; }
- (IBAction) setBrownColor:(id) sender { [self setColor:@"BROWN"]; }

- (void) setColor:(NSString *) color {
	id item = nil;
	
	if ([self.outlineView clickedRow] > -1) {
		item = [self.outlineView itemAtRow:[self.outlineView clickedRow]];
	} else if (_timelineSelection > -1) {
		item = [[self getOutlineItems] objectAtIndex:_timelineSelection];
	}
	
	if (item != nil && [item isKindOfClass:[OutlineScene class]]) {
		OutlineScene *scene = item;
		[self setColor:color forScene:scene];
		if (_timelineClickedScene >= 0) [self reloadTimeline];
	}
	_timelineClickedScene = -1;
}
- (void) setColor:(NSString *) color forScene:(OutlineScene *) scene {
	color = [color uppercaseString];

	if (![scene.color isEqualToString:@""] && scene.color != nil) {
		// Scene already has a color

		// If color is set to none, we'll remove the previous string.
		// If the color is changed, let's replace the string.
		if ([[color lowercaseString] isEqualToString:@"none"]) {
			NSString *oldColorString = [NSString stringWithFormat:@"[[COLOR %@]]", [scene.color uppercaseString]];
			NSRange innerRange = [scene.line.string rangeOfString:oldColorString];
			NSRange range = NSMakeRange([[scene line] position] + innerRange.location, innerRange.length);
			
			_outlineEdit = YES;
			[self removeString:oldColorString atIndex:range.location];
			_outlineEdit = NO;
			
		} else {
			NSString * oldColor = [NSString stringWithFormat:@"COLOR %@", scene.color];
			NSString * newColor = [NSString stringWithFormat:@"COLOR %@", color];
			NSRange innerRange = [scene.line.string rangeOfString:oldColor];
			NSRange range = NSMakeRange([[scene line] position] + innerRange.location, innerRange.length);
			
			_outlineEdit = YES;
			[self replaceString:oldColor withString:newColor atIndex:range.location];
			_outlineEdit = NO;
		}
	} else {
		// No color yet
		
		if ([[color lowercaseString] isEqualToString:@"none"]) return; // Do nothing if set to none
		
		NSString * colorString = [NSString stringWithFormat:@" [[COLOR %@]]", color];
		NSUInteger position = [[scene line] position] + [[scene line].string length];
		
		_outlineEdit = YES;
		[self addString:colorString atIndex:position];
		_outlineEdit = NO;
	}

	return;
}



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


#pragma mark - Card view

- (IBAction) toggleCards: (id)sender {
	if ([self selectedTabViewTab] != 2) {
		_cardsVisible = YES;
		
		[self refreshCards];
		[self setSelectedTabViewTab:2];
	} else {
		_cardsVisible = NO;
		
		// Reload outline + timeline in case there were any changes in outline
		if (_outlineViewVisible) [self reloadOutline];
		if (_timelineVisible) [self reloadTimeline];
		
		[self setSelectedTabViewTab:0];
		[self updateLayout];
		[self ensureCaret];
	}
}

// Some day, we'll move all this stuff to another file. It won't be soon.

- (void) setupCards {
	NSError *error = nil;
	
	NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"CardCSS.css" ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"CardView.js" ofType:@""];
	NSString *javaScript = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString *dragulaPath = [[NSBundle mainBundle] pathForResource:@"dragula.js" ofType:@""];
	NSString *dragula = [NSString stringWithContentsOfFile:dragulaPath encoding:NSUTF8StringEncoding error:&error];

	NSString* content = [NSString stringWithFormat:@"<html><head><style>%@</style>", css];
	content = [content stringByAppendingFormat:@"<script>%@</script>", dragula];
	content = [content stringByAppendingFormat:@"</head><body>"];
	
	// Spinner
	content = [content stringByAppendingFormat:@"<div id='wait'><div class='lds-spinner'><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div></div></div>"];
	
	content = [content stringByAppendingString:@"<div id='close'>✕</div><div id='debug'></div><div id='container'>"];
	content = [content stringByAppendingFormat:@"</div><script>%@</script></body></html>", javaScript];
	[_cardView loadHTMLString:content baseURL:nil];
}

// This might be pretty shitty solution for my problem but whatever
- (OutlineScene *) findSceneByLine: (Line *) line {
/*
	// This crap has been deprecated
	for (OutlineScene * scene in [self.parser outline]) {
		if (line == scene.line) return scene;
		
		if ([scene.scenes count] > 0) {
			for (OutlineScene * subScene in scene.scenes) {
				if (line == subScene.line) return subScene;
			}
		}
	}
*/
	for (OutlineScene * scene in [self.parser outline]) {
		if (line == scene.line) return scene;
	}
	
	return nil;
}


- (void) refreshCards {
	// Refresh cards assuming the view isn't visible
	[self refreshCards:NO changed:-1];
}

- (void) refreshCards:(BOOL)alreadyVisible {
	// Just refresh cards, no change index
	[self refreshCards:alreadyVisible changed:-1];
}

- (void) refreshCards:(BOOL)alreadyVisible changed:(NSInteger)changedIndex {
	
	if ([self isDark]) {
		[_cardView evaluateJavaScript:@"nightModeOn();" completionHandler:nil]; // THE HOUSE IS BLACK.
	} else {
		[_cardView evaluateJavaScript:@"nightModeOff();" completionHandler:nil];
	}
	
	NSString * json = @"[";
	
	// Let's go through the two-level outline
	// Should fix this back to the flat outline too, I guess.
	for (OutlineScene * scene in [self.parser outline]) {
		json = [json stringByAppendingFormat:@"{"];
		json = [json stringByAppendingString:[self getJSONCard:scene selected:[self isSceneSelected:scene]]];
		json = [json stringByAppendingFormat:@"},"];
	}
	json = [json stringByAppendingString:@"]"];
	
	NSString * jsCode;
	
	// The card view will scroll to current scene by default.
	// If the cards are already visible, we'll tell it not to scroll.
	
	if (alreadyVisible && changedIndex > -1) {
		// Already visible, changed index
		jsCode = [NSString stringWithFormat:@"createCards(%@, true, %lu);", json, changedIndex];
	} else if (alreadyVisible && changedIndex < 0) {
		// Already visible, no index
		jsCode = [NSString stringWithFormat:@"createCards(%@, true);", json];
	} else {
		// Fresh new view
		jsCode = [NSString stringWithFormat:@"createCards(%@);", json];
	}
	
	[_cardView evaluateJavaScript:jsCode completionHandler:nil];
}
- (bool) isSceneSelected: (OutlineScene *) scene {
	NSUInteger position = [self.textView selectedRange].location;
	
	NSMutableArray *scenes = [self getScenes];
	NSUInteger index = [scenes indexOfObject:scene];
	NSUInteger nextIndex = index + 1;
	
	if (nextIndex < [scenes count]) {
		OutlineScene *nextScene = [scenes objectAtIndex:index+1];

		if (position >= scene.line.position && position < nextScene.line.position) {
			return YES;
		}
	} else {
		if (position >= scene.line.position) return YES;
	}
	
	return NO;
}
- (NSString *) getJSONCard:(OutlineScene *) scene selected:(bool)selected {
	NSUInteger index = [[self.parser lines] indexOfObject:scene.line];
	
	NSUInteger sceneIndex = [[self getOutlineItems] indexOfObject:scene];
	
	// If we won't reach the end of file with this, let's take out a snippet from the script for the card
	NSUInteger lineIndex = index + 2;
	NSString * snippet = @"";
	if (lineIndex < [[self.parser lines] count]) {
		// Somebody might be just using card view to craft a step outline, so we need to check that this line is not a scene heading
		Line* snippetLine = [[self.parser lines] objectAtIndex:lineIndex];
		if (snippetLine.type != heading) snippet = [[[self.parser lines] objectAtIndex:lineIndex] string];
	}
	
	NSString * status = @"'selected': ''";
	if (selected) {
		status =  @"'selected': 'yes'";
	}
	if (scene.omited) {
		status = [status stringByAppendingString:@", 'omited': 'yes'"];
	}
		
	if (scene.type == section) {
		return [NSString stringWithFormat:@"'type': 'section', 'name': '%@', 'position': '%lu'", [self JSONString:scene.string], scene.line.position];
	} else if (scene.type == synopse) {
		return [NSString stringWithFormat:@"'type': 'synopse', 'name': '%@', 'position': '%lu'", [self JSONString:scene.string], scene.line.position];
	} else {
		return [NSString stringWithFormat:@"'sceneNumber': '%@', 'name': '%@', 'snippet': '%@', 'position': '%lu', 'color': '%@', 'lineIndex': %lu, 'sceneIndex': %lu, %@",
				[self JSONString:scene.sceneNumber],
				[self JSONString:scene.string],
				[self JSONString:snippet],
				scene.line.position,
				[scene.color lowercaseString],
				index,
				sceneIndex,
				status];
	}
}

-(NSString *)JSONString:(NSString *)aString {
	NSMutableString *s = [NSMutableString stringWithString:aString];
	[s replaceOccurrencesOfString:@"\'" withString:@"\\\'" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"/" withString:@"\\/" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\b" withString:@"\\b" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\f" withString:@"\\f" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\r" withString:@"\\r" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	[s replaceOccurrencesOfString:@"\t" withString:@"\\t" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	return [NSString stringWithString:s];
}

/* JavaScript call listener */
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *) message{
	if ([message.body  isEqual: @"exit"]) {
		[self toggleCards:nil];
		return;
	}
	
	if ([message.name isEqualToString:@"jumpToScene"]) {
		OutlineScene *scene = [[self getOutlineItems] objectAtIndex:[message.body intValue]];
		[self scrollToScene:scene];
		return;
	}
	
	if ([message.name isEqualToString:@"cardClick"]) {
		OutlineScene *scene = [[self getOutlineItems] objectAtIndex:[message.body intValue]];
		[self scrollToScene:scene];
		[self toggleCards:nil];
		
		return;
	}
	
	// Context menu for timeline
	if ([message.name isEqualToString:@"timelineContext"]) {
		_timelineClickedScene = [message.body integerValue];
		OutlineScene *scene = [[self getOutlineItems] objectAtIndex:_timelineClickedScene];
		if (scene) [self contextMenu:scene.string];
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
	
	if ([message.name isEqualToString:@"setGender"]) {
		if ([message.body rangeOfString:@":"].location != NSNotFound) {
			NSArray *nameAndGender = [message.body componentsSeparatedByString:@":"];
			NSString *name = [nameAndGender objectAtIndex:0];
			NSString *gender = [nameAndGender objectAtIndex:1];
			[self setGenderFor:name gender:gender];
		}
	}
}
- (void) contextMenu:(NSString*)context {
	// Let's take a moment to marvel at the beauty of objective-c code:
	NSPoint localPosition = [_timelineView convertPoint:[_thisWindow convertPointFromScreen:[NSEvent mouseLocation]] fromView:nil];
	
	[_colorMenu popUpMenuPositioningItem:_colorMenu.itemArray[0] atLocation:localPosition inView:_timelineView];
}


#pragma mark - Scene numbering for NSTextView

/* The following section is memory-intesive. Would like to see it fixed somehow. */

- (NSTextField *) createLabel: (OutlineScene *) scene {
	NSTextField * label;
	label = [[NSTextField alloc] init];
	
	if (scene != nil) {
		NSRange characterRange = NSMakeRange([scene.line position], [scene.line.string length]);
		NSRange range = [[self.textView layoutManager] glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
		
		if (scene.sceneNumber) [label setStringValue:scene.sceneNumber]; else [label setStringValue:@""];
		NSRect rect = [[self.textView layoutManager] boundingRectForGlyphRange:range inTextContainer:[self.textView textContainer]];
		rect.origin.y += TEXT_INSET_TOP;
		rect.size.width = 0.5 * ZOOM_MODIFIER * [scene.sceneNumber length];
		rect.origin.x = self.textView.textContainerInset.width - 2 * ZOOM_MODIFIER - rect.size.width;
	}
	
	[label setBezeled:NO];
	[label setSelectable:NO];
	[label setDrawsBackground:NO];
	[label setFont:self.courier];
	[label setAlignment:NSTextAlignmentRight];
	[self.textView addSubview:label];
	
	[self.sceneNumberLabels addObject:label];
	return label;
}


// This kind of works but might make things a bit slow. I'm not sure.
// Well, at least this is something that Slugline and Logline STILL can't do. :---)

- (void) updateSceneNumberLabels {
	if (_sceneNumberLabelUpdateOff || !_showSceneNumberLabels) return;
	
	if (![[self.parser outline] count]) {
		[self.parser createOutline];
	}
	
	NSInteger numberOfScenes = [self getNumberOfScenes];
	NSInteger numberOfLabels = [self.sceneNumberLabels count];
	NSInteger difference = numberOfScenes - numberOfLabels;
	
	// Create missing labels for new scenes
	if (difference > 0 && [self.sceneNumberLabels count]) {
		for (NSUInteger d = 0; d < difference; d++) {
			[self createLabel:nil];
		}
	}
	
	// Create labels if none are present
	if (![self.sceneNumberLabels count]) {
		[self createAllLabels];
	} else {
		NSUInteger index = 0;
		
		for (OutlineScene * scene in [self getScenes]) {
			// We'll wrap this in an autorelease pool, not sure if it helps or not :-)
			@autoreleasepool {
				if (index >= [self.sceneNumberLabels count]) break;
				
				NSTextField * label = [self.sceneNumberLabels objectAtIndex:index];
				
				label = [self.sceneNumberLabels objectAtIndex:index];
				if (scene.sceneNumber) { [label setStringValue:scene.sceneNumber]; }
				
				NSRange characterRange = NSMakeRange([scene.line position], [scene.line.string length]);
				NSRange range = [[self.textView layoutManager] glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
				NSRect rect = [[self.textView layoutManager] boundingRectForGlyphRange:range inTextContainer:[self.textView textContainer]];
				
				rect.size.width = 0.5 * ZOOM_MODIFIER * [scene.sceneNumber length];
				rect.origin.x = self.textView.textContainerInset.width - ZOOM_MODIFIER - rect.size.width + 10;
				
				rect.origin.y += TEXT_INSET_TOP;

				label.frame = rect;
				[label setFont:self.courier];
				if (![scene.color isEqualToString:@""] && scene.color != nil) {
					NSString *color = [scene.color lowercaseString];
					[label setTextColor:[self colors][color]];
				} else {
					[label setTextColor:self.themeManager.currentTextColor];
				}
			
				index++;
			}
		}

		// Remove unused labels from the end of the array.
		if (difference < 0) {
			for (NSInteger d = 0; d > difference; d--) {
				// Let's just do a double check to reduce the chance of errors
				if ([self.sceneNumberLabels count] > [self.sceneNumberLabels count] - 1) {
					NSTextField * label = [self.sceneNumberLabels objectAtIndex:[self.sceneNumberLabels count] - 1];
				
					//[label performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
					[self.sceneNumberLabels removeObject:label];
					[label removeFromSuperview];
				}
				
			}
		}
	}
	
	return;
}
- (void) createAllLabels {
	for (OutlineScene * scene in [self getScenes]) {
		[self createLabel:scene];
	}
}
- (void) deleteAllLabels {
	for (NSTextField * label in _sceneNumberLabels) {
		[label removeFromSuperview];
	}
	[_sceneNumberLabels removeAllObjects];
}
- (IBAction) toggleSceneLabels: (id) sender {
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	
	for (Document* doc in openDocuments) {
		doc.showSceneNumberLabels = !doc.showSceneNumberLabels;
		if (!doc.showSceneNumberLabels) {
			[doc deleteAllLabels];
		} else {
			[doc updateSceneNumberLabels];
		}
	}
	[[NSUserDefaults standardUserDefaults] setBool:self.showSceneNumberLabels forKey:SHOW_SCENE_LABELS_KEY];
}

#pragma mark - Timeline + chronometry

/*
 
 This is a simple attempt at measuring scene lengths. It is not scientific.
 I'm counting beats, and about 55 beats equal 1 minute.
 
 Characters per line: ca 58
 Lines per page: ca 55 -> 1 minute
 Dialogue multiplier: 1,64 (meaning, how much more dialogue takes space)
 
*/

- (IBAction)toggleTimeline:(id)sender
{
	// There is a KNOWN BUG here.
	// For some reason, the textview jumps into strange position when timeline is toggled and scroll position is towards the end.
	// It has to do with scaling, I guess, but I have no idea how to fix it.
	
	_timelineVisible = !_timelineVisible;
	
	NSPoint scrollPosition = [[self.textScrollView contentView] documentVisibleRect].origin;
	
	if (_timelineVisible) {
		[self updateTimelineStyle];
		[self reloadTimeline];
		self.timelineViewHeight.constant = TIMELINE_VIEW_HEIGHT;
		
		[self ensureLayout];
		
		[self.textView scrollPoint:scrollPosition];
	} else {
		self.timelineViewHeight.constant = 0;
		scrollPosition.y = scrollPosition.y * _magnification;
		
		[self.textScrollView.contentView scrollToPoint:scrollPosition];
	}
	
	//[self.textScrollView.contentView scrollToPoint:scrollPosition];
}

- (void) setupTimeline {
	NSString *timelinePath = [[NSBundle mainBundle] pathForResource:@"timeline.html" ofType:@""];
	NSString *content = [NSString stringWithContentsOfFile:timelinePath encoding:NSUTF8StringEncoding error:nil];

	[_timelineView loadHTMLString:content baseURL:nil];
	[self updateTimelineStyle];
}
- (void) updateTimelineStyle {
	if ([self isDark]) [self.timelineView evaluateJavaScript:@"setStyle('dark');" completionHandler:nil];
	else [self.timelineView evaluateJavaScript:@"setStyle('light');" completionHandler:nil];
}
- (void) reloadTimeline {
	__block OutlineScene *currentScene = [self getCurrentScene];
	__block NSMutableArray *scenes = [self getOutlineItems];
	
	// Let's build the timeline in another thread, to not slow down your writing
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSInteger charsPerLine = 57;
		NSInteger charsPerDialogue = 35;
		
		CGFloat totalLengthInSeconds = 0.0;
		
		NSMutableString *jsonData = [NSMutableString stringWithString:@"["];
		
		bool previousLineEmpty = false;
		
		for (OutlineScene *scene in scenes) {
			if (scene.type == synopse || scene.type == section) {
				NSString *type;
				if (scene.type == synopse) type = @"synopsis";
				if (scene.type == section) type = @"section";
				
				[jsonData appendFormat:@"{ text: \"%@\", type: '%@' },", [self JSONString:scene.string], type];
			}
			else if (scene.type == heading) {
				//[self JSONString:scene.string]
				
				NSInteger length = 2; // A scene heading is 2 beats

				NSInteger position = [[self.parser lines] indexOfObject:scene.line];
				NSInteger index = 0;
				
				bool selected = false;
				if (currentScene) {
					if (scene.line == currentScene.line) {
						
						selected = true;
					}
				}
				
				// Loop the lines until next scene
				while (position + index + 1 < [[self.parser lines] count]) {
					index++;
					Line* line = [[self.parser lines] objectAtIndex:position + index];
					
					// Break away when next scene is encountered
					if (line.type == heading) break;
					
					// Don't count in synopses or sections
					if (line.type == synopse || line.type == section) continue;
					
					// Empty row equals 1 beat
					if ([line.string isEqualToString:@""]) {
						if (previousLineEmpty) continue;
						
						previousLineEmpty = true;
						length += 1;
						continue;
					} else {
						previousLineEmpty = false;
					}

					NSInteger lineLength = [line.string length];
					
					// We need to take omitted ranges into consideration, so they won't add up to scene lengths
					__block NSUInteger omitLength = 0;
					[line.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
						omitLength += range.length;
					}];
					if (lineLength - omitLength >= 0) lineLength -= omitLength;
					
					// Character cue and parenthetical add 1 beat each
					if (line.type == character || line.type == parenthetical) {
						length += 1;
						continue;
					}
					
					if (line.type == dialogue) {
						length += (lineLength + charsPerDialogue - 1) / charsPerDialogue;
						continue;
					}
					
					if (line.type == action) {
						length += (lineLength + charsPerLine - 1) / charsPerLine;
					}
			
				}
				
				CGFloat seconds = round((CGFloat)length / 52 * 60);
				totalLengthInSeconds += seconds;
				
				NSString *selectedValue = @"false";
				if (selected) selectedValue = @"true";
				
				[jsonData appendFormat:@"{ text: \"%@\", sceneLength: %lu, sceneIndex: %lu, sceneNumber: '%@', color: '%@', selected: %@ },", [self JSONString:scene.string], length, [scenes indexOfObject:scene], scene.sceneNumber, [scene.color lowercaseString], selectedValue];
			}
		}
		[jsonData appendString:@"]"];
		
		NSString *evalString = [NSString stringWithFormat:@"refreshTimeline(%@);", jsonData];
		
		dispatch_async(dispatch_get_main_queue(), ^(void){
			[self->_timelineView evaluateJavaScript:evalString completionHandler:nil];
		});
	});
}
- (void) findOnTimeline: (OutlineScene *) scene {
	NSUInteger index = [[self getOutlineItems] indexOfObject:scene];
	
	NSString *evalString = [NSString stringWithFormat:@"refreshTimeline(null, %lu)", index];
	[_timelineView evaluateJavaScript:evalString completionHandler:nil];
}


#pragma mark - Analysis

- (IBAction)showAnalysis:(id)sender {
	[self createAnalysis:nil];
	[_thisWindow beginSheet:_analysisPanel completionHandler:nil];
}

- (IBAction)createAnalysis:(id)sender {
	// Setup analyzer
	
	[self.analysis setupScript:[self.parser lines] scenes:[self getOutlineItems] characterGenders:_characterGenders];
	
	NSString *jsonString = [self.analysis getJSON];
	NSString *javascript = [NSString stringWithFormat:@"refresh(%@)", jsonString];
	[_analysisView evaluateJavaScript:javascript completionHandler:nil];
}

- (void) setupAnalysis {
	NSString *analysisPath = [[NSBundle mainBundle] pathForResource:@"analysis.html" ofType:@""];
	NSString *content = [NSString stringWithContentsOfFile:analysisPath encoding:NSUTF8StringEncoding error:nil];
	_characterGenders = [NSMutableDictionary dictionaryWithDictionary:[self getGenders]];
	[_analysisView loadHTMLString:content baseURL:nil];
}
- (IBAction)closeAnalysis:(id)sender {
	[_thisWindow endSheet:_analysisPanel];
}

- (void) setGenderFor:(NSString*)name gender:(NSString*)gender {
	[_characterGenders setObject:gender forKey:name];
}
- (NSMutableDictionary*) getGenders {
	// The gender dictionary is saved per FILE
	return [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"CharacterGender"] objectForKey:[self fileNameString]];
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
	[self maskScenes];
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
    [self maskScenes];
    
    // Hide the button
    [_resetColorFilterButton setHidden:YES];
}

- (IBAction)filterByCharacter:(id)sender {
	NSString *characterName = _characterBox.selectedItem.title;
	[_filters setScript:self.parser.lines scenes:[self getOutlineItems]];
	
	if ([characterName isEqualToString:@" "] || [characterName length] == 0) {
        [self resetCharacterFilter:nil];
		return;
	}

	[_filters byCharacter:characterName];
    
    // Reload outline and set visual masks to apply the filter
	[self reloadOutline];
	[self maskScenes];
    
    // Show the button to reset character filter
    [_resetCharacterFilterButton setHidden:NO];
}

- (IBAction)resetCharacterFilter:(id)sender {
    [_filters resetScenes];
    _filters.character = @"";
	
    [self reloadOutline];
	[self maskScenes];
    
    // Hide the button to reset filter
    [_resetCharacterFilterButton setHidden:YES];
    
    // Select the first item (hopefully it exists by now)
    [_characterBox selectItem:[_characterBox.itemArray objectAtIndex:0]];
}

- (void) maskScenes {
	// If there is no filtered outline, just reset everything
	[self.parser createOutline];
	if (![_filteredOutline count]) {
		[self.textView.masks removeAllObjects];
		[self ensureLayout];
		return;
	}
	
	// Mask scenes that didn't match our filter
	__block NSMutableArray* masks = [NSMutableArray array];
	[self.textView.masks removeAllObjects];

	// Create flat outline if we don't have one
	if (![_flatOutline count]) _flatOutline = [self getOutlineItems];
	
	for (OutlineScene* scene in _flatOutline) {
		// Ignore this scene if it's contained in filtered scenes
		if ([self.filteredOutline containsObject:scene] || scene.type == section || scene.type == synopse) continue;
		NSRange sceneRange = NSMakeRange([scene sceneStart], [scene sceneLength]);

		// Add scene ranges to TextView's masks
		NSValue* rangeValue = [NSValue valueWithRange:sceneRange];
		[masks addObject:rangeValue];
	}
		
	self.textView.masks = masks;
	[self ensureLayout];

}


#pragma mark - Pagination

- (void)updateSectionMarkers {
	[self updateSectionMarkersFromIndex:-1];
}
- (void)updateSectionMarkersFromIndex:(NSInteger)fromIndex {
	if (fromIndex < 0) fromIndex = 0;
	
	__block NSMutableArray *sections = [NSMutableArray array];
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		for (NSInteger i = fromIndex; i < self.parser.lines.count; i++) {
			Line* line = [self.parser.lines objectAtIndex:i];
			if (line.type == section) [sections addObject:[self.parser.lines objectAtIndex:i]];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void){
			NSMutableArray *sectionRects = [NSMutableArray array];
			
			for (Line* line in sections) {

				// Don't draw breaks for less-important sections
				if (line.sectionDepth > 2) continue;
				NSRange characterRange = NSMakeRange(line.position, [line.string length]);
				
				NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
				
				NSRect rect = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer];

				// If the next line is something we care about, include it in the rect for a nicer display
				// If next line is NOT EMPTY, don't add the rect at all.
				NSInteger index = [self.parser.lines indexOfObject:line];
				
				if (index < self.parser.lines.count - 1) {				
					Line* previousLine;
					Line* nextLine = [self.parser.lines objectAtIndex:index + 1];
					
					if (index > 0) previousLine = [self.parser.lines objectAtIndex:index - 1];
					
					if ((nextLine.type == synopse || nextLine.type == section) && [previousLine.string length] < 1) {
						characterRange = NSMakeRange(nextLine.position, [nextLine.string length]);
						glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
						NSRect nextRect = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer];
						
						rect.size.height += nextRect.size.height;
						
						[sectionRects addObject:[NSValue valueWithRect:rect]];
					}
					else if ((nextLine == empty || ![nextLine.string length]) && [previousLine.string length] < 1 ) {
						[sectionRects addObject:[NSValue valueWithRect:rect]];
					}
				}
			}
			
			[self.textView updateSections:sectionRects];
			[self ensureLayout];
		});
	});
}

/*
 
 Let's make a couple of things clear:
 - this probably will never make it into the main branch
 - this is a complete waste of time
 
 */

- (void)paginate {
	
	// !!! Pagination should have some sort of starting index, so that we can only update affected pages !!!
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		self.pagination.paperSize = CGSizeMake(self.printInfo.paperSize.width, self.printInfo.paperSize.height);
				
		// Send parsed lines for pagination, which results in an array of y coordinates
		__block NSArray *pageBreaks = [self.pagination paginate:self.parser.lines];
		
		dispatch_async(dispatch_get_main_queue(), ^(void){
			// Update UI in main thread
			NSMutableArray *breakPositions = [NSMutableArray array];
			
			for (NSDictionary *pageBreak in pageBreaks) {
				CGFloat lineHeight = 20;
				
				Line *line = pageBreak[@"line"];
				CGFloat position = [pageBreak[@"position"] floatValue];
				
				NSRange characterRange = NSMakeRange(line.position, [line.string length]);
				NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
				
				NSRect rect = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer];
				
				CGFloat y;
				
				// We return -1 for elements that should have page break after them
				if (position >= 0) {
					if (position != 0) position = (round(position / lineHeight) - 1) * lineHeight;
					y = rect.origin.y + position;
				}
				else y = rect.origin.y + rect.size.height;
				
				[breakPositions addObject:[NSNumber numberWithFloat:y]];
			}
			
			[self.textView setPageBreaks:breakPositions];
			[self ensureLayout];
		});
	});
}

#pragma mark - Title page editor

- (IBAction)editTitlePage:(id)sender {
	
	FNScript* script = [[FNScript alloc] initWithString:[self getText]];

	// List of applicable fields
	NSDictionary* fields = @{
							 @"title":_titleField,
							 @"credit":_creditField,
							 @"authors":_authorField,
							 @"source":_sourceField,
							 @"draft date":_dateField,
							 @"contact":_contactField,
							 @"notes":_notesField
							 };

	// Clear custom fields
	_customFields = [NSMutableArray array];
	
	if ([script.titlePage count] > 0) {
		// This is a shitty approach, but what can you say. When copying the dictionary, the order of entries gets messed up, so we need to uh...
		for (NSDictionary *dict in script.titlePage) {
			NSString *key = [dict.allKeys objectAtIndex:0];
			
			if ([fields objectForKey:key]) {
				NSMutableString *values = [NSMutableString string];
				
				for (NSString *val in dict[key]) {
					if ([dict[key] indexOfObject:val] == [dict[key] count] - 1) [values appendFormat:@"%@", val];
					else [values appendFormat:@"%@\n", val];
				}
				
				if (![fields[key] isKindOfClass:[NSTextView class]]) [fields[key] setStringValue:values];
				else [fields[key] setString:values];
			} else {
				[_customFields addObject:dict];
			}
		}
	} else {
		// Clear all fields
		for (NSString *key in fields) {
			[fields[key] setStringValue:@""];
		}
	}
	
	//_customFields = [NSMutableDictionary dictionaryWithDictionary:titlePage];
	
	// Display
	[_thisWindow beginSheet:_titlePagePanel completionHandler:nil];
}

- (IBAction)cancelTitlePageEdit:(id)sender {
	[_thisWindow endSheet:_titlePagePanel];
}

- (IBAction)applyTitlePageEdit:(id)sender {
	[_thisWindow endSheet:_titlePagePanel];
	
	NSMutableString *titlePage = [NSMutableString string];
	
	// BTW, isn't Objective C nice, beautiful and elegant?
	[titlePage appendFormat:@"Title: %@\n", [_titleField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Credit: %@\n", [_creditField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Author: %@\n", [_authorField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Source: %@\n", [_sourceField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	[titlePage appendFormat:@"Draft date: %@\n", [_dateField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet]];
	
	// Only add contact + notes fields they are not empty
	NSString *contact = [_contactField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet];
	if ([contact length] > 0) [titlePage appendFormat:@"Contact:\n%@\n", contact];
	
	NSString *notes = [_notesField.stringValue stringByTrimmingTrailingCharactersInSet:NSCharacterSet.newlineCharacterSet];
	if ([notes length] > 0) [titlePage appendFormat:@"Notes:\n%@\n", notes];
	
	// Add back possible custom fields that were left out
	for (NSDictionary *dict in _customFields) {
		NSString *key = [dict.allKeys objectAtIndex:0];
		NSArray *obj = dict[key];
	
		// Check if it is a text block or single line
		if ([obj count] == 1) [titlePage appendFormat:@"%@:", [key capitalizedString]];
		else  [titlePage appendFormat:@"%@:\n", [key capitalizedString]];
		
		for (NSString *val in obj) {
			[titlePage appendFormat:@"%@\n", val];
		}
	}
	
	// Find the range
	if ([[self getText] length] < 6) {
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
		if (titlePageEnd < 0) titlePageEnd = [[self getText] length];
		
		NSRange titlePageRange = NSMakeRange(0, titlePageEnd);
		NSString *oldTitlePage = [[self getText] substringWithRange:titlePageRange];

		[self replaceString:oldTitlePage withString:titlePage atIndex:0];
	}
	
}

#pragma mark - touchbar buttons

- (IBAction)nextScene:(id)sender {
	OutlineScene *scene = [self getNextScene];
	if (scene) {
		[self scrollToScene:scene];
	} else if (!scene && [_flatOutline count]) {
		// We were not inside a scene. Move to next one if possible.
		[self scrollToScene:[_flatOutline objectAtIndex:0]];
	}
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
- (void) autosaveInPlace {
	// Don't autosave if it's an untitled document
	if (self.fileURL == nil) return;
	
	if (_autosave && self.documentEdited) {
		[self saveDocument:nil];
	}
}

- (NSURL *)autosavedContentsFileURL {
	NSURL *autosavePath = [self appDataPath:@"Autosave"];
	autosavePath = [autosavePath URLByAppendingPathComponent:[self fileNameString]];
	autosavePath = [autosavePath URLByAppendingPathExtension:@"fountain"];

	return autosavePath;
}
- (NSURL*)autosavePath {
	return [self appDataPath:@"Autosave"];
}
- (NSURL*)appDataPath:(NSString*)subPath {
	NSString* pathComponent = APP_NAME;
	if ([subPath length] > 0) pathComponent = [pathComponent stringByAppendingPathComponent:subPath];
	
    NSArray<NSString*>* searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                          NSUserDomainMask,
                                                                          YES);
	NSString* appSupportDir = [searchPaths firstObject];
	appSupportDir = [appSupportDir stringByAppendingPathComponent:pathComponent];
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
	
    if (![fileManager fileExistsAtPath:appSupportDir]) {
        [fileManager createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
	
	return [NSURL fileURLWithPath:appSupportDir isDirectory:YES];
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

- (void) initAutosave {
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
	
	NSURL *url = [self appDataPath:@"Autosave"];
	url = [url URLByAppendingPathComponent:previousName];
	url = [url URLByAppendingPathExtension:@"fountain"];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:url.path]) {
		[fileManager removeItemAtURL:url error:nil];
	}
}
#pragma mark - scroll listeners

/* Listen to scrolling of the view. Listen to the birds. Listen to wind blowing all your dreams away, to make space for new ones to rise, when the spring comes. */
- (void)boundsDidChange:(NSNotification*)notification {
	if (notification.object != [self.textScrollView contentView]) return;
}

// In other words, this is no longer used.

@end

/*
 
 some moments are nice, some are
 nicer, some are even worth
 writing
 about
 
 */
