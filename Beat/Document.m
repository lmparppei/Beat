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
 
 N.B. Much of this code has its origins in Writer by Hendrik Noeller. As I started
 this project, I had close to zero knowledge on Objective-C, and it really shows.
 
 Beat has been cooked up by using lots of trial and error, and this file has become a
 2900-line monster.  I've started fixing some of my silliest coding practices, but
 it's still a WIP. Some structures (such as themes) are legacy from Writer, and
 have since been replaced with totally different approach. Their names and complimentary
 methods still linger around.
 
 Anyway, may this be of some use to you, dear friend.
 
 Lauri-Matti Parppei
 
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
#import "FNScript.h"
#import "FNHTMLScript.h"
#import "FDXInterface.h"
#import "OutlineExtractor.h"
#import "PrintView.h"
#import "ColorView.h"
#import "ContinousFountainParser.h"
#import "ThemeManager.h"
#import "OutlineScene.h"
#import "SelectorWithDebounce.h"
#import "CenteredClipView.h"
#import "DynamicColor.h"
#import "ApplicationDelegate.h"
#import "NSString+Whitespace.h"
#import "FountainReport.h"

@interface Document ()

@property (unsafe_unretained) IBOutlet NCRAutocompleteTextView *textView;
@property (weak) IBOutlet NSScrollView *textScrollView;
@property (nonatomic) NSTimer * scrollTimer;

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSScrollView *outlineScrollView;
@property (weak) NSArray *draggedNodes;
@property (weak) OutlineScene *draggedScene; // Drag & drop for outline view
@property (nonatomic) NSMutableArray *flatOutline;
@property (nonatomic) NSMutableArray *filteredOutline;

@property (weak) IBOutlet NSSearchField *outlineSearchField;

@property (weak) NSWindow *thisWindow;

@property (nonatomic) NSLayoutManager *layoutManager;

@property (unsafe_unretained) IBOutlet WebView *webView;
@property (unsafe_unretained) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet ColorView *backgroundView;
@property (weak) IBOutlet ColorView *outlineBackgroundView;
@property (weak) IBOutlet NSView *masterView;

@property (weak) IBOutlet NSMenu *colorMenu;

@property (weak) IBOutlet NSPanel *analysisPanel;
@property (unsafe_unretained) IBOutlet WKWebView *analysisView;

@property (unsafe_unretained) IBOutlet WKWebView *cardView;
@property (unsafe_unretained) IBOutlet WKWebView *timelineView;
@property (weak) IBOutlet NSLayoutConstraint *timelineViewHeight;

@property (nonatomic) NSInteger timelineClickedScene;
@property (nonatomic) NSInteger timelineSelection;

@property (unsafe_unretained) IBOutlet NSBox *leftMargin;
@property (unsafe_unretained) IBOutlet NSBox *rightMargin;

@property (weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property BOOL outlineViewVisible;
@property (nonatomic) NSMutableArray *outlineClosedSections;

@property (nonatomic) NSMutableArray *sceneNumberLabels;
@property (nonatomic) bool sceneNumberLabelUpdateOff;
@property (nonatomic) bool showSceneNumberLabels;

@property (weak) IBOutlet NSButton *outlineButton;

@property (strong, nonatomic) NSString *contentBuffer; //Keeps the text until the text view is initialized

@property (strong, nonatomic) NSFont *courier;
@property (strong, nonatomic) NSFont *boldCourier;
@property (strong, nonatomic) NSFont *italicCourier;

@property (nonatomic) NSUInteger fontSize;
@property (nonatomic) NSUInteger zoomLevel;
@property (nonatomic) NSUInteger zoomCenter;

@property (nonatomic) CGFloat magnification;
@property (nonatomic) CGFloat scaleFactor;

@property (nonatomic) CGFloat scale;
@property (nonatomic) bool livePreview;
@property (nonatomic) bool printPreview;
@property (nonatomic) bool cardsVisible;
@property (nonatomic) bool timelineVisible;
@property (nonatomic, readwrite) NSString *preprocessedText;

@property (nonatomic) bool matchParentheses;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) NSUInteger documentWidth;

@property (nonatomic) NSUInteger characterIndent;
@property (nonatomic) NSUInteger parentheticalIndent;
@property (nonatomic) NSUInteger dialogueIndent;
@property (nonatomic) NSUInteger dialogueIndentRight;
@property (nonatomic) NSUInteger ddCharacterIndent;
@property (nonatomic) NSUInteger ddParentheticalIndent;
@property (nonatomic) NSUInteger doubleDialogueIndent;
@property (nonatomic) NSUInteger ddRight;

// Autocompletion purposes
@property (nonatomic) Line *currentLine;
@property OutlineScene *currentScene;
@property (nonatomic) NSString *cachedText;
@property (nonatomic) bool isAutoCompleting;
@property (nonatomic) NSMutableArray *characterNames;
@property (nonatomic) NSMutableArray *sceneHeadings;
@property (readwrite, nonatomic) bool darkPopup;

@property (strong, nonatomic) PrintView *printView; //To keep the asynchronously working print data generator in memory

@property (strong, nonatomic) ContinousFountainParser* parser;
@property (strong, nonatomic) FountainReport* report;

@property (strong, nonatomic) ThemeManager* themeManager;
@property (nonatomic) bool nightMode;
@end

#define UNIT_MULTIPLIER 17
#define ZOOMLEVEL_KEY @"Zoomlevel"
#define DEFAULT_ZOOM 16

#define FONT_SIZE_MODIFIER 0.028
#define ZOOM_MODIFIER 40

#define MAGNIFYLEVEL_KEY @"Magnifylevel"
#define DEFAULT_MAGNIFY 1.1
#define MAGNIFY YES

#define MATCH_PARENTHESES_KEY @"Match Parentheses"
#define LIVE_PREVIEW_KEY @"Live Preview"
#define SHOW_SCENE_LABELS_KEY @"Show Scene Number Labels"
#define FONTSIZE_KEY @"Fontsize"
#define PRINT_SCENE_NUMBERS_KEY @"Print scene numbers"

#define LOCAL_REORDER_PASTEBOARD_TYPE @"LOCAL_REORDER_PASTEBOARD_TYPE"
#define OUTLINE_DATATYPE @"OutlineDatatype"
#define FLATOUTLINE YES


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
	// This stuff was here to fix some strange memory issues.
	// Probably unnecessary now, but maybe it isn't bad to unset the most memory-consuming variables anyway
	self.textView = nil;
	self.parser = nil;
	self.outlineView = nil;
	self.sceneNumberLabels = nil;
	self.thisWindow = nil;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document close" object:nil];
	
	[super close];
}

#define TEXT_INSET_SIDE 80
#define TEXT_INSET_TOP 40

#define INITIAL_WIDTH 900
#define INITIAL_HEIGHT 700
#define DOCUMENT_WIDTH 610

#define DD_CHARACTER_INDENT_P 0.56
#define DD_PARENTHETICAL_INDENT_P 0.50
#define DOUBLE_DIALOGUE_INDENT_P 0.40
#define DD_RIGHT 650
#define DD_RIGHT_P .95

#define TITLE_INDENT .2

#define CHARACTER_INDENT_P 0.36
#define PARENTHETICAL_INDENT_P 0.27
#define DIALOGUE_INDENT_P 0.164
#define DIALOGUE_RIGHT_P 0.74

#define TREE_VIEW_WIDTH 350
#define TIMELINE_VIEW_HEIGHT 120

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
	_thisWindow = aController.window;
	[_thisWindow setMinSize:CGSizeMake(_thisWindow.minSize.width, 350)];
	
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    //    aController.window.titleVisibility = NSWindowTitleHidden; //Makes the title and toolbar unified by hiding the title
	
	/// Hide the welcome screen
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document open" object:nil];
	
	// Get zoom level & font size. This is pretty fucked up now, as from 1.1.0 onwards zooming is done by scaling.
	// If you are wondering, read more nearby the setZoom method. Lol.
	_zoomLevel = DEFAULT_ZOOM;
	_documentWidth = DEFAULT_ZOOM * ZOOM_MODIFIER;
	[self setZoom];

    //Set the width programmatically since w've got the outline visible in IB to work on it, but don't want it visible on launch
    NSWindow *window = aController.window;
    NSRect newFrame = NSMakeRect(window.frame.origin.x,
                                 window.frame.origin.y,
                                 _documentWidth * 1.7,
                                 _documentWidth * 1.5);
    [window setFrame:newFrame display:YES];
	
	// Accept mouse moved events... nah
	// [aController.window setAcceptsMouseMovedEvents:YES];
	
	
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
	
	// Read default settings
    if (![[NSUserDefaults standardUserDefaults] objectForKey:MATCH_PARENTHESES_KEY]) {
        self.matchParentheses = YES;
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
	
	 // Let's enable live preview as default, don't load preferences for it.
	self.livePreview = YES;
	
	//Initialize Theme Manager (before formatting the content, because we need the colors for formatting!)
	self.themeManager = [ThemeManager sharedManager];
	[self loadSelectedTheme:false];
	_nightMode = [self isDark];
	
	// Background fill
	self.backgroundView.fillColor = self.themeManager.theme.outlineBackground;
	
	// Initialize drag & drop for outline view
	//[self.outlineView registerForDraggedTypes:@[LOCAL_REORDER_PASTEBOARD_TYPE, NSPasteboardTypeString]];
	[self.outlineView registerForDraggedTypes:@[LOCAL_REORDER_PASTEBOARD_TYPE, OUTLINE_DATATYPE]];
	[self.outlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];

    //Put any previously loaded data into the text view
    if (self.contentBuffer) {
        [self setText:self.contentBuffer];
    } else {
        [self setText:@""];
    }
	
	// Outline view setup
	self.outlineClosedSections = [[NSMutableArray alloc] init];
	self.filteredOutline = [[NSMutableArray alloc] init];
	
	// Scene number labels
	self.sceneNumberLabels = [[NSMutableArray alloc] init];
	
	// Autocomplete setup
	self.characterNames = [[NSMutableArray alloc] init];
	self.sceneHeadings = [[NSMutableArray alloc] init];
	
    self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
	self.report = [[FountainReport alloc] init];

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
	
	// Read more about this in (void)reformatScript
	[self applyFormatChanges];
	//[self reformatScript];

	// Let's set a timer for 200ms. This should update the scene number labels after letting the text render.
	[NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(afterLoad) userInfo:nil repeats:NO];
	
	// That's about it. The rest is even messier.
	
	// Can I come over, I need to rest
	// lay down for a while, disconnect
	// the night was so long, the day even longer
	// lay down for a while, recollect
}
- (void) afterLoad {
	dispatch_async(dispatch_get_main_queue(), ^{
		[[self.textView layoutManager] ensureLayoutForTextContainer:[self.textView textContainer]];
		[self updateLayout];
		
		// This is a silly duct-tape fix for a bug I can't track. Send help.
		[self updateSceneNumberLabels];
		[self updateSceneNumberLabels];
	});
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
 I have finally rebuilt the zooming. I have tried all sorts of tricks from
 magnification to other weird stuff, such as 3rd party libraries for scaling the
 NSScrollView. Everything was terrible and caused even more problems. I'm not too
 familiar with Cocoa and/or Objective-C, but if I understand correctly, the best way
 would be having a custom NSView inside the NSScrollView and then to magnify the
 scroll view. NSTextView's layout manager would then handle displaying the
 text in those custom views.
 
 I still have no help and I'm working alone. Until that changes, I guess
 this won't get any better. :-)
 
 The problem here is that we have multiple keys that set font size, document width, etc.
 and out of legacy reasons, they are scattered around the code. Maybe some day I have the
 time to fix everything, but for now, we're using duct-tape approach.
 
 What matters most is how well you walk through the fire.
 
 */

- (void) zoom: (bool) zoomIn {
	if (!_scaleFactor) _scaleFactor = _magnification;
	CGFloat oldMagnification = _magnification;
	
	// Save scroll position
	NSPoint scrollPosition = [[self.textScrollView contentView] documentVisibleRect].origin;
	
	// For some reason, setting 1.0 scale for NSTextView causes weird sizing bugs, so we will use something that will never produce 1.0...... omg help
	if (zoomIn) {
		if (_magnification < 1.6) _magnification += 0.09;
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
	}
}

- (void)ensureLayout {
	[[self.textView layoutManager] ensureLayoutForTextContainer:[self.textView textContainer]];
	[self.textView setNeedsDisplay:true];
	[self updateSceneNumberLabels];
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag
{
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
	_scaleFactor = 1.0;
	_magnification = 1.1;
	[self setScaleFactor:_magnification adjustPopup:false];
	//[self setScaleFactor:_magnification adjustPopup:false];

	[self updateLayout];
}

- (IBAction)increaseFontSize:(id)sender
{
	[self zoom:true];
}

- (IBAction)decreaseFontSize:(id)sender
{
	[self zoom:false];
}


- (IBAction)resetFontSize:(id)sender
{
	_magnification = 1.1;
	[self setScaleFactor:_magnification adjustPopup:false];
	[self updateLayout];
}

// Oh well. Let's not autosave and instead have the good old "save as..." button in the menu.
+ (BOOL)autosavesInPlace {
    return NO;
}

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
        [self updateWebView];
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
	
	for (OutlineScene *scene in [self getOutlineItems]) {
		NSRange range = NSMakeRange(scene.sceneStart, scene.sceneLength);
		
		// Found the current scene. Let's cache the result just in case
		if (NSLocationInRange(position, range)) {
			_currentScene = scene;
			return scene;
		}
	}
	
	_currentScene = nil;
	return nil;
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
	
	// Fire up autocomplete
	if (_currentLine.type == character) {
		[self.textView setAutomaticTextCompletionEnabled:YES];
	} else if (_currentLine.type == heading) {
		[self.textView setAutomaticTextCompletionEnabled:YES];
	} else if ([_currentLine.string length] < 5) {
		[self.textView setAutomaticTextCompletionEnabled:YES];
	} else {
		[self.textView setAutomaticTextCompletionEnabled:NO];
	}
	
    [self.parser parseChangeInRange:affectedCharRange withString:replacementString];
    return YES;
}

- (IBAction)reformatRange:(id)sender {
	if ([self.textView selectedRange].length > 0) {
		NSString *string = [[[self.textView textStorage] string] substringWithRange:[self.textView selectedRange]];
		if ([string length]) {
			[self.parser parseChangeInRange:[self.textView selectedRange] withString:string];
			[self applyFormatChanges];
			
			[self.parser numberOfOutlineItems];
			[self updateSceneNumberLabels];

		}
	}
}

- (void)textDidChange:(NSNotification *)notification
{
	// If outline has changed, we will rebuild outline & timeline if needed
	bool changeInOutline = [self.parser getAndResetChangeInOutline];
	if (changeInOutline) {
		// This builds outline in the parser. Weird method name, I know.
		[self.parser numberOfOutlineItems];
		if (self.outlineViewVisible) [self reloadOutline];
		if (self.timelineVisible) [self reloadTimeline];
	}
	
	[self applyFormatChanges];
	
	[self.parser numberOfOutlineItems];
	[self updateSceneNumberLabels];
}
- (void)textViewDidChangeSelection:(NSNotification *)notification {
	// Locate current scene & reload outline without building it in parser
	
	if (_outlineViewVisible || _timelineVisible) {
		
		[self getCurrentScene];
		if (_timelineVisible && _currentScene) {
			[self findOnTimeline:_currentScene];
		}
		
		// So... uh. For some reason, _currentScene can get messed up after reloading the outline, so that's why we checked the timeline position first.
		[self getCurrentScene];
		if (_outlineViewVisible) [self reloadOutline];
		if (_outlineViewVisible && _currentScene) [self.outlineView scrollRowToVisible:[self.outlineView rowForItem:[self getCurrentScene]]];
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

// We need a method to be able to undo scene reordering.
- (void)moveString:(NSString*)string withRange:(NSRange)range newRange:(NSRange)newRange
{
	// Delete the string and add it again to its new position
	[self replaceCharactersInRange:range withString:@""];
	[self replaceCharactersInRange:newRange withString:string];
	
	// Create new ranges for undoing the operation
	NSRange undoRange = NSMakeRange(newRange.location, range.length);
	NSRange undoNewRange = NSMakeRange(range.location, 0);
	[[[self undoManager] prepareWithInvocationTarget:self] moveString:string withRange:undoRange newRange:undoNewRange];
	
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
	[_characterNames removeAllObjects];
	for (Line *line in [self.parser lines]) {
		if (line.type == character && line != _currentLine && ![_characterNames containsObject:line.string]) {
			[_characterNames addObject:line.string];
		}
	}
}
- (void) collectHeadings {
	[_sceneHeadings removeAllObjects];
	for (Line *line in [self.parser lines]) {
		if (line.type == heading && line != _currentLine && ![_sceneHeadings containsObject:line.string]) {
			[_sceneHeadings addObject:line.string];
		}
	}
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	
	NSMutableArray *matches = [NSMutableArray array];
	NSMutableArray *search = [NSMutableArray array];
	
	if (_currentLine.type == character) {
		[self collectCharacterNames];
		search = _characterNames;
	}
	else if (_currentLine.type == heading) {
		[self collectHeadings];
		search = _sceneHeadings;
	}
	
	for (NSString *string in search) {
		if ([string rangeOfString:[[textView string] substringWithRange:charRange] options:NSAnchoredSearch|NSLiteralSearch range:NSMakeRange(0, [string length])].location != NSNotFound) {
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
	[self formattAllLines];
}

- (void)formattAllLines
{
    if (self.livePreview) {
        for (Line* line in self.parser.lines) {
            [self formatLineOfScreenplay:line onlyFormatFont:NO];
        }
    } else {
        [self.textView setFont:[self courier]];
        [self.textView setTextColor:self.themeManager.currentTextColor];
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setAlignment:NSTextAlignmentLeft];
        [paragraphStyle setFirstLineHeadIndent:0];
        [paragraphStyle setHeadIndent:0];
        [paragraphStyle setTailIndent:0];
        
        [self.textView.textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [self getText].length)];
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
- (void)reformatScript
{
	// This function is used to perform lookback when loading the script. The thing is, Fountain files should be parsed from bottom to top, as otherwise we really won't know the meaning of some lines.
	
	// Beat relies on Hendrik Noeller's work on Continuous Fountain Parser, which parses the file in a linear manner. This works just fine most of the time, but in Beat, formatting methods have been updated to take next and previous lines into consideration.
	
	// Unfortunately, this also means having to parse the whole file two times when loading.
	
	// Set all indices as changed
	[self.parser resetParsing];
	// Format everything again
	[self applyFormatChanges];
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
				
				// If the line currently parsed is EMPTY and we are NOT editing the line before or the current line, we'll take a step back and reformat it as action.
				// This is unreliable at times, but 70% of the time it works OK.
				
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
	
	NSTextStorage *textStorage = [self.textView textStorage];
	
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
	
	NSMutableParagraphStyle *lineHeight = [[NSMutableParagraphStyle alloc]init];
	
	// This doesn't format empty lines for some reason: [lineHeight setLineHeightMultiple:1.05];
	[attributes setObject:lineHeight forKey:NSParagraphStyleAttributeName];
	
	//Formatt according to style
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
		// This won't format empty lines for some reason: [paragraphStyle setLineHeightMultiple:1.05];
		if (line.type == titlePageTitle  ||
			line.type == titlePageAuthor ||
			line.type == titlePageCredit ||
			line.type == titlePageSource) {
			
			[paragraphStyle setAlignment:NSTextAlignmentCenter];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		} else if (line.type == titlePageUnknown ||
				   line.type == titlePageContact ||
				   line.type == titlePageDraftDate) {
			
			NSColor* commentColor = [self.themeManager currentCommentColor];
			[attributes setObject:commentColor forKey:NSForegroundColorAttributeName];
			/* WORK IN PROGRESS */
			//[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * ZOOM_MODIFIER * _zoomLevel];
			//[paragraphStyle setHeadIndent:TITLE_INDENT * ZOOM_MODIFIER * _zoomLevel];
			//[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

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
			[paragraphStyle setFirstLineHeadIndent:CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setHeadIndent:CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];

			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == parenthetical) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setFirstLineHeadIndent:PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setHeadIndent:PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == dialogue) {
			[paragraphStyle setFirstLineHeadIndent:DIALOGUE_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setHeadIndent:DIALOGUE_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == doubleDialogueCharacter) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setFirstLineHeadIndent:DD_CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setHeadIndent:DD_CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setTailIndent:DD_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == doubleDialogueParenthetical) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
			[paragraphStyle setFirstLineHeadIndent:DD_PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setHeadIndent:DD_PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setTailIndent:DD_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == doubleDialogue) {
			//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
			[paragraphStyle setFirstLineHeadIndent:DOUBLE_DIALOGUE_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setHeadIndent:DOUBLE_DIALOGUE_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
			[paragraphStyle setTailIndent:DD_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
			
			[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
			
		} else if (line.type == section || line.type == synopse) {
			if (self.themeManager) {
				NSColor* commentColor = [self.themeManager currentCommentColor];
				[attributes setObject:commentColor forKey:NSForegroundColorAttributeName];
			}
		}
	}
	
	//Remove all former paragraph styles and overwrite fonts
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
	
	if ([line.string length] == 0) {
		// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
		[self.textView setTypingAttributes:attributes];
	}
	
	//Add in bold, underline, italic and all that other good stuff. it looks like a lot of code, but the content is only executed for every formatted block. for unformatted text, this just whizzes by
	
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
	_fontSize = DEFAULT_ZOOM * FONT_SIZE_MODIFIER * ZOOM_MODIFIER;
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
	
	// Just in case
	[self updateSceneNumberLabels];
}


- (NSString*) preprocessSceneNumbers
{
	// Regex for scene testing
	NSString * pattern = @"^(([iI][nN][tT]|[eE][xX][tT]|[^\\w][eE][sS][tT]|\\.|[iI]\\.?\\[eE]\\.?)).+";
	NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
	NSString *sceneNumberPattern = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPattern];
	NSArray *lines = [self.getText componentsSeparatedByString:@"\n"];
	NSString *fullText = @"";
	
	NSUInteger sceneCount = 1; // Track scene amount

	for (__strong NSString *rawLine in lines) {
		NSString *cleanedLine = [rawLine stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		// Test if this is a scene header, but don't add an auto scene number
		// if it already has one
		if ([test evaluateWithObject: cleanedLine] && ![testSceneNumber evaluateWithObject: cleanedLine]) {
			
			// Make scene heading strings
			NSString *sceneNumber = [NSString stringWithFormat:@"%@%lu%@", @"#", sceneCount, @"#"];
			NSString *newLine = [NSString stringWithFormat:@"%@ %@", cleanedLine, sceneNumber];
			fullText = [NSString stringWithFormat:@"%@%@\n", fullText, newLine];
			
			sceneCount++;
		} else {
			fullText = [NSString stringWithFormat:@"%@%@\n", fullText, cleanedLine];
		}
	}
	
	return fullText;
}

- (IBAction)lockSceneNumbers:(id)sender
{
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
	
	//[self applyFormatChanges];
	
	_sceneNumberLabelUpdateOff = false;
	[self updateSceneNumberLabels];
	
	// [[[self undoManager] prepareWithInvocationTarget:self] undoSceneNumbering:rawText];
}

- (void)undoSceneNumbering:(NSString*)rawText
{
	[self setText:rawText];
	[self textDidChange:[NSNotification notificationWithName:@"" object:nil]];
	self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
	[self applyFormatChanges];
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
    //If the cursor resides in an empty line
    //Which either happens because the beginning of the line is the end of the document
    //Or is indicated by the next character being a newline
    //The range for the first charate in line needs to be an empty string
    if (indexOfLineBeginning == [[self getText] length]) {
        firstCharacterRange = NSMakeRange(indexOfLineBeginning, 0);
    } else if ([[[self getText] substringWithRange:NSMakeRange(indexOfLineBeginning, 1)] isEqualToString:@"\n"]){
        firstCharacterRange = NSMakeRange(indexOfLineBeginning, 0);
    } else {
        firstCharacterRange = NSMakeRange(indexOfLineBeginning, 1);
    }
    NSString *firstCharacter = [[self getText] substringWithRange:firstCharacterRange];
    
    //If the line is already forced to the desired type, remove the force
    if ([firstCharacter isEqualToString:symbol]) {
        [self replaceCharactersInRange:firstCharacterRange withString:@""];
    } else {
        //If the line is not forced to the desirey type, check if it is forced to be something else
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
            [self replaceCharactersInRange:firstCharacterRange withString:symbol];
        } else {
            [self replaceCharactersInRange:firstCharacterRange withString:[symbol stringByAppendingString:firstCharacter]];
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
		[self reloadOutline];
		
		[self.outlineView expandItem:nil expandChildren:true];
        [self.outlineViewWidth setConstant:TREE_VIEW_WIDTH];
		
		NSWindow *window = self.windowControllers[0].window;
		NSRect newFrame;
		
		if (![self isFullscreen]) {
			newFrame = NSMakeRect(window.frame.origin.x,
										 window.frame.origin.y,
										 window.frame.size.width + TREE_VIEW_WIDTH + offset,
										 window.frame.size.height);
			[window setFrame:newFrame display:YES];
		} else {
			CGFloat width = ((window.frame.size.width - TREE_VIEW_WIDTH) / 2 - _documentWidth * _magnification / 2) / _magnification;
			[self.textView setTextContainerInset:NSMakeSize(width, TEXT_INSET_TOP)];
		}
    } else {
		[self.outlineViewWidth setConstant:0];
		NSWindow *window = self.windowControllers[0].window;
		NSRect newFrame;
		
		if (![self isFullscreen]) {
			newFrame = NSMakeRect(window.frame.origin.x - offset,
										 window.frame.origin.y,
										 window.frame.size.width - TREE_VIEW_WIDTH - offset * 2,
										 window.frame.size.height);
			[window setFrame:newFrame display:YES];
		} else {
			newFrame = NSMakeRect(window.frame.origin.x - offset,
								  window.frame.origin.y,
								  window.frame.size.width,
								  window.frame.size.height);
			
			CGFloat width = (window.frame.size.width / 2 - _documentWidth * _magnification / 2) / _magnification;
			
			[self.textView setTextContainerInset:NSMakeSize(width, TEXT_INSET_TOP)];
		}
    }
	
	[[self.textView layoutManager] ensureLayoutForTextContainer:[self.textView textContainer]];
}

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}
- (IBAction)export:(id)sender {}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([self selectedTabViewTab] != 0) {
		if ([self selectedTabViewTab] == 1 && [menuItem.title isEqualToString:@"Toggle Preview"]) {
			[menuItem setState:NSOnState];
			return YES;
		}

		if ([self selectedTabViewTab] == 2 && [menuItem.title isEqualToString:@"Show Cards"]) {
			[menuItem setState:NSOnState];
			return YES;
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
    } else if ([menuItem.title isEqualToString:@"Print…"] || [menuItem.title isEqualToString:@"PDF"] || [menuItem.title isEqualToString:@"HTML"]) {
        NSArray* words = [[self getText] componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString* visibleCharacters = [words componentsJoinedByString:@""];
        if ([visibleCharacters length] == 0) {
            return NO;
        }
	} else if ([menuItem.title isEqualToString:@"Undo"]) {
		if ([self selectedTabViewTab] != 0) {
			NO;
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
    } else if ([menuItem.title isEqualToString:@"Live Preview"]) {
        if (self.livePreview) {
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
	
    return YES;
}

- (IBAction)shareFromService:(id)sender
{
    [[sender representedObject] performWithItems:@[self.fileURL]];
}
- (IBAction)toggleNightMode:(id)sender {
	[(ApplicationDelegate *)[NSApp delegate] toggleDarkMode];
	
	[_masterView setNeedsDisplayInRect:[_masterView frame]];
	[self.backgroundView setNeedsDisplay:true];
	[self.thisWindow setViewsNeedDisplay:true];
	[[self.textView layoutManager] ensureLayoutForTextContainer:[self.textView textContainer]];
	//[self updateSceneNumberLabels];
	
	[self updateTimelineStyle];
	
	[self.textView setNeedsDisplay:true];
	
	for (NSTextField* textField in self.sceneNumberLabels) {
		//textField.textColor = self.themeManager.currentTextColor;
		[textField setNeedsDisplay:true];
	}
	
	[self.textView toggleDarkPopup:nil];
	_darkPopup = [self isDark];
}
- (bool)isDark {
	return [(ApplicationDelegate *)[NSApp delegate] isDark];
}

- (IBAction)toggleLivePreview:(id)sender
{
    NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
    
    for (Document* doc in openDocuments) {
        doc.livePreview = !doc.livePreview;
        [doc formattAllLines];
    }
    [[NSUserDefaults standardUserDefaults] setBool:self.livePreview forKey:LIVE_PREVIEW_KEY];
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

- (void)loadSelectedTheme:(bool)forAll
{
	NSArray* openDocuments;
	if (forAll) openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	else openDocuments = @[self];
	
    for (Document* doc in openDocuments) {
        NSTextView *textView = doc.textView;
		
		[textView setBackgroundColor:[self.themeManager currentBackgroundColor]];
        [textView setSelectedTextAttributes:@{
											  NSBackgroundColorAttributeName: [self.themeManager currentSelectionColor],
											  NSForegroundColorAttributeName: [self.themeManager currentBackgroundColor]
		}];
        [textView setTextColor:[self.themeManager currentTextColor]];
        [textView setInsertionPointColor:[self.themeManager currentCaretColor]];
        [doc formattAllLines];
		
		NSOutlineView *outlineView = doc.outlineView;
		[outlineView setBackgroundColor:self.themeManager.theme.outlineBackground];
		
		// Set global background
		doc.backgroundView.fillColor = self.themeManager.theme.outlineBackground;
		
		//NSBox *leftMargin = doc.leftMargin;
		//NSBox *rightMargin = doc.rightMargin;
		
		//[leftMargin setFillColor:[self.themeManager currentMarginColor]];
		//[rightMargin setFillColor:[self.themeManager currentMarginColor]];
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
		
		if ([scene.scenes count]) {
			for (OutlineScene * subscene in scene.scenes) {
				if (subscene.type == heading) [scenes addObject:subscene];
			}
		}
	}
	
	return scenes;
}

// NOTE: This returns a FLAT outline.
- (NSMutableArray *) getOutlineItems {
	NSMutableArray * outlineItems = [NSMutableArray array];
	
	// WIP
	for (OutlineScene * scene in [self.parser outline]) {
		[outlineItems addObject:scene];
		
		if ([scene.scenes count]) {
			for (OutlineScene * subscene in scene.scenes) {
				[outlineItems addObject:subscene];
			}
		}
	}
	
	_flatOutline = outlineItems;
	return outlineItems;
}

- (void) filterOutline:(NSString*) filter {
	// We don't need to GET outline at this point, let's use the cached one
	[_filteredOutline removeAllObjects];
	
	for (OutlineScene * scene in _flatOutline) {
		if ([scene.string rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound) {
			[_filteredOutline addObject:scene];
		} else if ([scene.color localizedCaseInsensitiveContainsString:filter]) {
			[_filteredOutline addObject:scene];
		}
	}
}

- (void)searchOutline {
	// Don't search if it's only spaces
	if ([_outlineSearchField.stringValue containsOnlyWhitespace] || [_outlineSearchField.stringValue length] < 1) {
		[_filteredOutline removeAllObjects];
	}
	
	[self filterOutline:_outlineSearchField.stringValue];
	[self.outlineView reloadData];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item;
{
	if (FLATOUTLINE) {
		// If we have a search term, let's use the filtered array
		if ([_outlineSearchField.stringValue length] > 0) {
			return [_filteredOutline count];
		} else {
			return [[self getOutlineItems] count];
		}
	}
	
	/*
	if (![self.parser outline]) return 0;
	if ([[self.parser outline] count] < 1) return 0;
	
    if (!item) {
        //Children of root
        return [self.parser numberOfOutlineItems];
	} else {
		return [[item scenes] count];
	}
    //return 0;
	 */
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	if (FLATOUTLINE) {
		// If there is a search term, let's search the filtered array
		if ([_outlineSearchField.stringValue length] > 0) {
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

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{ @autoreleasepool {
    if ([item isKindOfClass:[OutlineScene class]]) {
		
        OutlineScene* line = item;
		NSUInteger sceneNumberLength = 0;
		bool currentScene = false;

		// The outline elements will be formatted as rich text,
		// which is apparently VERY CUMBERSOME in Cocoa/Objective-C.
		NSMutableAttributedString * resultString = [[NSMutableAttributedString alloc] initWithString:line.string];
		//[resultString addAttribute:NSFontAttributeName value:[self cothamRegular] range:NSMakeRange(0, [line.string length])];
		
        if (line.type == heading) {
			if (_currentScene.string) {
				if (_currentScene == line) currentScene = true;
				if ([line.string isEqualToString:_currentScene.string] && line.sceneNumber == _currentScene.sceneNumber) currentScene = true;
			}
			
			//Replace "INT/EXT" with "I/E" to make the lines match nicely
            NSString* string = [line.string uppercaseString];
            string = [string stringByReplacingOccurrencesOfString:@"INT/EXT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"INT./EXT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"EXT/INT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"EXT./INT" withString:@"I/E"];
			
			// Remove force scene character
			if ([string characterAtIndex:0] == '.') {
				string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
			}
			
			if (line.sceneNumber) {
				NSString *sceneHeader = [NSString stringWithFormat:@"    %@.", line.sceneNumber];
                string = [NSString stringWithFormat:@"%@ %@", sceneHeader, [string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", line.sceneNumber] withString:@""]];
				resultString = [[NSMutableAttributedString alloc] initWithString:string];
				sceneNumberLength = [sceneHeader length];
				
				// Scene number will be displayed in a slightly darker shade
				[resultString addAttribute:NSForegroundColorAttributeName value:NSColor.grayColor range:NSMakeRange(0,[sceneHeader length])];
				[resultString addAttribute:NSForegroundColorAttributeName value:[self colors][@"darkGray"] range:NSMakeRange([sceneHeader length], [resultString length] - [sceneHeader length])];
				
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
            NSString* string = line.string;
            if ([string length] > 0) {
                //Remove "="
                if ([string characterAtIndex:0] == '=') {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
                //Remove leading whitespace
                while (string.length && [string characterAtIndex:0] == ' ') {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
                string = [@"  " stringByAppendingString:string];
				
				NSFont *font = [NSFont systemFontOfSize:13.0f];
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
            NSString* string = line.string;
            if ([string length] > 0) {
                //Remove "#"
                if ([string characterAtIndex:0] == '#') {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
                //Remove leading whitespace
                while (string.length && [string characterAtIndex:0] == ' ') {
                    string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
				
				string = [@"" stringByAppendingString:string];
				
				NSFont *font = [NSFont systemFontOfSize:13.0f];
				NSDictionary * fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, nil];

				resultString = [[NSMutableAttributedString alloc] initWithString:string attributes:fontAttributes];
				
				// Bold + highlight color
				[resultString addAttribute:NSForegroundColorAttributeName value:self.themeManager.theme.outlineHighlight range:NSMakeRange(0,[resultString length])];
				
				[resultString applyFontTraits:NSBoldFontMask range:NSMakeRange(0,[resultString length])];
            } else {
                resultString = [[NSMutableAttributedString alloc] initWithString:line.string];
            }
        }

		if (line.color) {
			
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
	if ([_filteredOutline count] > 0 || [_outlineSearchField.stringValue length] > 0) return nil;
	
	OutlineScene *scene = (OutlineScene*)item;
	_draggedScene = scene;
	
	NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];
	//[pboardItem setString:scene.string forType: NSPasteboardTypeString];
	//NSData *data = [NSKeyedArchiver archivedDataWithRootObject:scene];
	//[pboardItem setValue:scene forType:OUTLINE_DATATYPE];
	return pboardItem;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id < NSDraggingInfo >)info proposedItem:(id)targetItem proposedChildIndex:(NSInteger)index{
	
	// Don't allow reordering a filtered list
	if ([_filteredOutline count] > 0 || [_outlineSearchField.stringValue length] > 0) return NSDragOperationNone;
	
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
	[self moveScene:_draggedScene from:from to:to];
	return YES;
}

- (void) reloadOutline {
	/*
	// DEPRECATED
	 
	// Save list of sections that have been collapsed
	[_outlineClosedSections removeAllObjects];
	for (int i = 0; i < [[self.parser outline] count]; i++) {
		id item = [self.outlineView itemAtRow:i];
		if (![self.outlineView isItemExpanded:item]) {
			[_outlineClosedSections addObject:[item string]];
		}
	}
	 */
	
	// Save outline scroll position
	NSPoint scrollPosition = [[self.outlineScrollView contentView] bounds].origin;
	
	// Create outline
	_flatOutline = [self getOutlineItems];
	
	// Build a filtered outline if we have a filter applied
	if ([_outlineSearchField.stringValue length] > 0) [self filterOutline:_outlineSearchField.stringValue];
	
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
	NSInteger moveToIndex = 0;
	if (!moveToEnd) moveToIndex = beforeScene.sceneStart;
	else moveToIndex = [[self getText] length];
	
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
 
 Color rontext menu, WIP.
 
 The same menu is used for both outline and timeline. Because clickedRow is set all the time (?)
 Regexes hurt my brain, and they do so even more in Objective-C, so maybe I'll just search for ranges whenever I decide to do this.
 Also, in principle it should be possible to enter custom colors in hex. Such as [[COLOR #d00dd]].

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
			[self removeString:oldColorString atIndex:range.location];
		} else {
			NSString * oldColor = [NSString stringWithFormat:@"COLOR %@", scene.color];
			NSString * newColor = [NSString stringWithFormat:@"COLOR %@", color];
			NSRange innerRange = [scene.line.string rangeOfString:oldColor];
			NSRange range = NSMakeRange([[scene line] position] + innerRange.location, innerRange.length);
			[self replaceString:oldColor withString:newColor atIndex:range.location];
		}
	} else {
		// No color yet
		
		if ([[color lowercaseString] isEqualToString:@"none"]) return; // Do nothing if set to none
		
		NSString * colorString = [NSString stringWithFormat:@" [[COLOR %@]]", color];
		NSUInteger position = [[scene line] position] + [[scene line].string length];
		[self addString:colorString atIndex:position];
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
			 @"darkGray": [self colorWithRed:170 green:170 blue:170]
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
		[self setSelectedTabViewTab:0];
		[self updateLayout];
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
	content = [content stringByAppendingFormat:@"</head><body><div id='close'>✕</div><div id='debug'></div><div id='container'>"];
	content = [content stringByAppendingFormat:@"</div><script>%@</script></body></html>", javaScript];
	[_cardView loadHTMLString:content baseURL:nil];
}

// This might be pretty shitty solution for my problem but whatever
- (OutlineScene *) findSceneByLine: (Line *) line {
	for (OutlineScene * scene in [self.parser outline]) {
		if (line == scene.line) return scene;
		
		if ([scene.scenes count] > 0) {
			for (OutlineScene * subScene in scene.scenes) {
				if (line == subScene.line) return subScene;
			}
		}
	}
	
	return nil;
}
	
- (void) refreshCards {
	
	if ([self isDark]) {
		[_cardView evaluateJavaScript:@"nightModeOn();" completionHandler:nil];
	} else {
		[_cardView evaluateJavaScript:@"nightModeOff();" completionHandler:nil];
	}
	
	NSString * json = @"[";
	for (OutlineScene * scene in [self.parser outline]) {
		json = [json stringByAppendingFormat:@"{"];
		json = [json stringByAppendingString:[self getJSONCard:scene selected:[self isSceneSelected:scene]]];
		json = [json stringByAppendingFormat:@"},"];
		
		if ([scene.scenes count] > 0) {
			for (OutlineScene * subScene in scene.scenes) {
				json = [json stringByAppendingFormat:@"{ %@ },", [self getJSONCard:subScene selected:[self isSceneSelected:subScene]]];
			}
		}
	}
	json = [json stringByAppendingString:@"]"];
	
	NSString * jsCode = [NSString stringWithFormat:@"createCards(%@);", json];
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
		snippet = [[[self.parser lines] objectAtIndex:lineIndex] string];
	}
	
	NSString * status = @"'selected': ''";
	if (selected) {
		status =  @"'selected': 'yes'";
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
	
	// Context menu for timeline. WIP.
	if ([message.name isEqualToString:@"timelineContext"]) {
		_timelineClickedScene = [message.body integerValue];
		OutlineScene *scene = [[self getOutlineItems] objectAtIndex:_timelineClickedScene];
		if (scene) [self contextMenu:scene.string];
	}
	
	// Work in progress. Can be enabled by editing CardView.js and setting dragDrop = true;
	// Trouble is, there is no way of undoing this from card view for now. Until then, this won't be enabled in the app.
	if ([message.name isEqualToString:@"move"]) {
		if ([message.body rangeOfString:@","].location != NSNotFound) {
			NSArray *fromTo = [message.body componentsSeparatedByString:@","];
			if ([fromTo count] < 2) return;
			
			NSInteger from = [[fromTo objectAtIndex:0] integerValue];
			NSInteger to = [[fromTo objectAtIndex:1] integerValue];
			
			NSMutableArray *outline = [self getOutlineItems];
			if ([outline count] < 1) return;
			
			OutlineScene *scene = [outline objectAtIndex:from];
			
			// MOVESCENE
			[self moveScene:scene from:from to:to];
			
			[self refreshCards];
			
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
// There are CPU & memory spikes on scroll, but debouncing the calls to update didn't work as scrolling might end during the debounce cooldown.
// Send help.
// Well, at least this is something that Slugline and Logline can't do. :--------)

- (void) updateSceneNumberLabels {
	if (_sceneNumberLabelUpdateOff || !_showSceneNumberLabels) return;
	
	if (![[self.parser outline] count]) {
		[self.parser numberOfOutlineItems];
	}
	
	NSInteger numberOfScenes = [self getNumberOfScenes];
	NSInteger numberOfLabels = [self.sceneNumberLabels count];
	NSInteger difference = numberOfScenes - numberOfLabels;
	
	// Create missing labels for newly created scenes
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
			@autoreleasepool {
				if (index >= [self.sceneNumberLabels count]) break;
				
				NSTextField * label = [self.sceneNumberLabels objectAtIndex:index];
				
				label = [self.sceneNumberLabels objectAtIndex:index];
				if (scene.sceneNumber) { [label setStringValue:scene.sceneNumber]; }
				
				NSRange characterRange = NSMakeRange([scene.line position], [scene.line.string length]);
				NSRange range = [[self.textView layoutManager] glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
				NSRect rect = [[self.textView layoutManager] boundingRectForGlyphRange:range inTextContainer:[self.textView textContainer]];
				
				rect.size.width = 0.5 * ZOOM_MODIFIER * [scene.sceneNumber length];
				rect.origin.x = self.textView.textContainerInset.width - ZOOM_MODIFIER - rect.size.width;
				
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


#pragma mark - Reporting

- (IBAction)showAnalysis:(id)sender {

}

- (IBAction)createReport:(id)sender {
	[_thisWindow beginSheet:_analysisPanel completionHandler:nil];
	NSString *jsonString = [self.report createReport:[self.parser lines]];
	NSString *javascript = [NSString stringWithFormat:@"refresh(%@)", jsonString];
	[_analysisView evaluateJavaScript:javascript completionHandler:nil];
}

- (void) setupAnalysis {
	NSString *analysisPath = [[NSBundle mainBundle] pathForResource:@"analysis.html" ofType:@""];
	NSString *content = [NSString stringWithContentsOfFile:analysisPath encoding:NSUTF8StringEncoding error:nil];
	
	[_analysisView loadHTMLString:content baseURL:nil];
}
- (IBAction)closeAnalysis:(id)sender {
	[_thisWindow endSheet:_analysisPanel];
}


#pragma mark - scroll listeners

/* Listen to scrolling of the view. Listen to the birds. Listen to wind blowing all your dreams away, to make space for new ones to rise, when the spring comes. */
- (void)boundsDidChange:(NSNotification*)notification {
	if (notification.object != [self.textScrollView contentView]) return;
	
	//[self updateSceneNumberLabels];
	

	// if(_scrollTimer == nil) [self scrollViewDidScroll];
	[self performSelector:@selector(updateSceneNumberLabels) withDebounceDuration:.1];
	
	if (_scrollTimer != nil && [_scrollTimer isValid])
		[_scrollTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
	else
		_scrollTimer = [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(scrollViewDidEndScrolling) userInfo:nil repeats:NO];
}
- (void)scrollViewDidScroll {
	//[self performSelector:@selector(updateSceneNumberLabels) withDebounceDuration:0.01];
	//[self updateSceneNumberLabels];
}
- (void)scrollViewDidEndScrolling
{
	[self updateSceneNumberLabels];
	if(_scrollTimer != nil) _scrollTimer = nil;
}

@end

/*
 
 some moments are nice, some are
 nicer, some are even worth
 writing
 about
 
 */
