//  Document.m
//  Beat
//
//  Copyright (c) 2019 Lauri-Matti Parppei
//  Based on Writer, copyright (c) 2016 Hendrik Noeller

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
 2700-line monster.
 
 But - keep the flight in mind, the bird is mortal.

 Page sizing info:
 
 Character - 32%
 Parenthetical - 30%
 Dialogue - 16%
 Dialogue width - 74%
  
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
#import "ScalingScrollView.h"

//#import "Beat-Bridging-Header.h"
//#import "Beat-Swift.h"

@interface Document ()

@property (unsafe_unretained) IBOutlet NSToolbar *toolbar;
@property (unsafe_unretained) IBOutlet NCRAutocompleteTextView *textView;
@property (weak) IBOutlet ScalingScrollView *textScrollView;
@property (nonatomic) NSTimer * scrollTimer;

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSScrollView *outlineScrollView;
@property (nonatomic) NSWindow *thisWindow;

@property (nonatomic) NSLayoutManager *layoutManager;

@property (unsafe_unretained) IBOutlet WebView *webView;
@property (unsafe_unretained) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet ColorView *backgroundView;

@property (unsafe_unretained) IBOutlet WKWebView *cardView;

@property (unsafe_unretained) IBOutlet NSBox *leftMargin;
@property (unsafe_unretained) IBOutlet NSBox *rightMargin;

@property (weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property BOOL outlineViewVisible;
@property (nonatomic) NSMutableArray *outlineClosedSections;

@property (nonatomic) NSMutableArray *sceneNumberLabels;
@property (nonatomic) bool sceneNumberLabelUpdateOff;
@property (nonatomic) bool showSceneNumberLabels;

// @property (unsafe_unretained) IBOutlet NSCollectionView *cardView;

#pragma mark - Floating outline button
@property (weak) IBOutlet NSButton *outlineButton;

#pragma mark - Toolbar Buttons

@property (strong, nonatomic) NSString *contentBuffer; //Keeps the text until the text view is initialized

@property (strong, nonatomic) NSFont *courier;
@property (strong, nonatomic) NSFont *boldCourier;
@property (strong, nonatomic) NSFont *italicCourier;
@property (strong, nonatomic) NSFont *cothamRegular;

@property (nonatomic) NSUInteger fontSize;
@property (nonatomic) NSUInteger zoomLevel;
@property (nonatomic) NSUInteger zoomCenter;

@property (nonatomic) CGFloat scale;
@property (nonatomic) bool livePreview;
@property (nonatomic) bool printPreview;
@property (nonatomic) bool cardsVisible;
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
@property (nonatomic) NSString *cachedText;
@property (nonatomic) bool isAutoCompleting;
@property (nonatomic) NSMutableArray *characterNames;
@property (nonatomic) NSMutableArray *sceneHeadings;
@property (readwrite, nonatomic) bool darkPopup;

@property (strong, nonatomic) PrintView *printView; //To keep the asynchronously working print data generator in memory

@property (strong, nonatomic) ContinousFountainParser* parser;

@property (strong, nonatomic) ThemeManager* themeManager;
@property (nonatomic) bool nightMode;
@end

#define UNIT_MULTIPLIER 17
#define ZOOMLEVEL_KEY @"Zoomlevel"
#define DEFAULT_ZOOM 16

#define FONT_SIZE_MODIFIER 0.028
#define ZOOM_MODIFIER 40

#define MAGNIFYLEVEL_KEY @"Magnifylevel"
#define DEFAULT_MAGNIFY 17
#define MAGNIFY_REFERENCE 17
// Change to YES to try out new zooms :--(
#define MAGNIFY NO

#define MATCH_PARENTHESES_KEY @"Match Parentheses"
#define LIVE_PREVIEW_KEY @"Live Preview"
#define SHOW_SCENE_LABELS_KEY @"Show Scene Number Labels"
#define FONTSIZE_KEY @"Fontsize"
#define PRINT_SCENE_NUMBERS_KEY @"Print scene numbers"

@implementation Document

#pragma mark - Document Basics

- (instancetype)init {
    self = [super init];
    if (self) {
        self.printInfo.topMargin = 25;
        self.printInfo.bottomMargin = 55;
		self.printInfo.paperSize = NSMakeSize(595, 842);
    }
    return self;
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

#define CHARACTER_INDENT_P 0.36
#define PARENTHETICAL_INDENT_P 0.30
#define DIALOGUE_INDENT_P 0.164
#define DIALOGUE_RIGHT_P 0.74

#define TREE_VIEW_WIDTH 350

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
	_thisWindow = aController.window;
	[_thisWindow setMinSize:CGSizeMake(_thisWindow.minSize.width, 350)];
	
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    //    aController.window.titleVisibility = NSWindowTitleHidden; //Makes the title and toolbar unified by hiding the title
	
	/// Hide the welcome screen
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document open" object:nil];
	
	// Get zoom level & font size
	if (!MAGNIFY) {
		_zoomLevel = self.zoomLevel;
		_documentWidth = _zoomLevel * ZOOM_MODIFIER;
	} else {
		// New way of zooming. This is pretty fucked up.
		// DON'T TOUCH THESE FOR NOW!
		_zoomLevel = DEFAULT_ZOOM;
		_documentWidth = DEFAULT_ZOOM * ZOOM_MODIFIER;
	}
	
    //Set the width programmatically since w've got the outline visible in IB to work on it, but don't want it visible on launch
    NSWindow *window = aController.window;
    NSRect newFrame = NSMakeRect(window.frame.origin.x,
                                 window.frame.origin.y,
                                 _documentWidth * 1.7,
                                 _documentWidth * 1.5);
    [window setFrame:newFrame display:YES];
	
	// Accept mouse moved events
	[aController.window setAcceptsMouseMovedEvents:YES];
	
	
	
	/* ####### Outline button initialization ######## */
	
	CGRect buttonFrame = self.outlineButton.frame;
	buttonFrame.origin.x = 15;
	self.outlineButton.frame = buttonFrame;
	
    self.outlineViewVisible = false;
    self.outlineViewWidth.constant = 0;
	
	
	/* ####### TextView setup ######## */
	
    self.textView.textContainer.widthTracksTextView = false;
	self.textView.textContainer.heightTracksTextView = false;
	
	[[self.textScrollView documentView] setPostsBoundsChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boundsDidChange:) name:NSViewBoundsDidChangeNotification object:[self.textScrollView contentView]];
	
	// Window frame will be the same as text frame width at startup (outline is not visible by default)
	// TextView won't have a frame size before load, so let's use the window width instead to set the insets.
	self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
	self.textView.textContainerInset = NSMakeSize(window.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
	
	// Background fill
    self.backgroundView.fillColor = [NSColor colorWithCalibratedRed:0.3
                                                              green:0.3
                                                               blue:0.3
                                                              alpha:1.0];
	
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
	
    //Put any previously loaded data into the text view
    if (self.contentBuffer) {
        [self setText:self.contentBuffer];
    } else {
        [self setText:@""];
    }
	
/*
	 // I'm doing this on xcode 8, so oh well. When I can upgrade, do this.
 
	 if (@available(macOS 10.14, *)) {
	 NSAppearanceName appearanceName = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		 if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
			// use dark color
		 } else {
			// use light color
		 }
	 }
*/
	
    //Initialize Theme Manager (before formatting the content, because we need the colors for formatting!)
    self.themeManager = [ThemeManager sharedManager];
    [self loadSelectedTheme];
	_nightMode = false;
	
	// Outline view setup
	self.outlineClosedSections = [[NSMutableArray alloc] init];
	
	// Scene number labels
	self.sceneNumberLabels = [[NSMutableArray alloc] init];
	
	// Autocomplete setup
	self.characterNames = [[NSMutableArray alloc] init];
	self.sceneHeadings = [[NSMutableArray alloc] init];
	
    self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
    [self applyFormatChanges];
	
	// CardView webkit
	[self.cardView.configuration.userContentController addScriptMessageHandler:self name:@"cardClick"];
	[self.cardView.configuration.userContentController addScriptMessageHandler:self name:@"setColor"];
	[self setupCards];
	
	
	// Let's set a timer for 200ms. This should update the scene number labels after letting the text render.
	[NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(afterLoad) userInfo:nil repeats:NO];
}
- (void) afterLoad {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (MAGNIFY) [self setZoom];
		
		// This is a silly duct-tape fix for a bug I can't track. Send help.
		[self updateSceneNumberLabels];
		[self updateSceneNumberLabels];
	});
}

# pragma mark Window interactions

- (bool) isFullscreen {
	return (([_thisWindow styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}

- (void)windowDidResize:(NSNotification *)notification {
	[self updateLayout];
}
- (void) updateLayout {
	
	if (!MAGNIFY) { // Old way of magnification
		
		[self setMinimumWindowSize];
		self.textView.textContainerInset = NSMakeSize(self.textView.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
		self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
		
	} else { // New way
		
		// THIS IS A MESS. SEND HELP. SEND IN THE CLOWNS.
		
		CGFloat magnification = self.textScrollView.magnification;
		
		NSRect visible = self.textScrollView.documentView.visibleRect;
		NSRect contentView = self.textScrollView.contentView.frame;
		CGFloat x = contentView.size.width / 2 - visible.size.width / 2;
		
		//contentView.origin.x = x;
		//[self.textScrollView.contentView setFrame:contentView];
		
		NSLog(@"\nProposed x: %f\nVisible - x:%f y:%f w:%f h:%f\nContainer w:%f h:%f", x, visible.origin.x, visible.origin.y, visible.size.width, visible.size.height, self.textScrollView.contentView.frame.size.width, self.textScrollView.contentView.frame.size.height);
		[self setMinimumWindowSize];
		NSLog(@"Window min: %f", self.thisWindow.minSize.width);
		
		// What???
		NSRect textFrame = self.textView.frame;
		textFrame.size.width = self.textScrollView.frame.size.width / magnification - self.outlineViewWidth.constant;
		textFrame.size.height = self.textScrollView.frame.size.height / magnification;
		[self.textView setFrame:textFrame];
		
		
		
		// This is a panic recovery..... which crashes the app
		/*
		if (self.thisWindow.frame.size.width < self.thisWindow.minSize.width) {
			NSRect newFrame = NSMakeRect(0, 0, self.thisWindow.minSize.width, self.thisWindow.frame.size.height);
			[self.thisWindow setFrame:newFrame display:YES];
		}
		*/
		
		// CGFloat magnification = [self.textScrollView magnification];
		NSLog(@"TextView: %f/%f - container %f - Window width %f", self.textView.frame.size.width, self.textView.frame.size.height, self.textView.textContainer.size.height, self.thisWindow.frame.size.width);
		
		// Old way, I have no idea what this did:
		// inset = (self.textView.frame.size.width / 2 - _documentWidth / 2) / magnification;
		
		//[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
		/*
		NSRect visibleRect = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer];
		visibleRect.size.width = self.thisWindow.frame.size.width;
		self.textView.frame = visibleRect;
		*/

		CGFloat inset = ((self.thisWindow.frame.size.width - self.outlineViewWidth.constant) / 2 - _documentWidth / 2);
		self.textView.textContainerInset = NSMakeSize(inset, TEXT_INSET_TOP);
	}
	
	[self updateSceneNumberLabels];
}
- (void) setMinimumWindowSize {
	CGFloat magnification = [self.textScrollView magnification];
	if (!_outlineViewVisible) {
		[self.thisWindow setMinSize:NSMakeSize(_documentWidth * magnification + 200, 400)];
	} else {
		[self.thisWindow setMinSize:NSMakeSize(_documentWidth * magnification + 200 + _outlineView.frame.size
											   .width, 400)];
	}
}

/*
 
 Zooming in / out

 This is a mess. I am so sorry for anyone reading this.
 
 The problem here is that we have multiple keys that set font size, document width, etc.
 and out of legacy reasons, they are scattered around the code. Maybe some day I have the
 time to fix everything, but for now, we're using duct-tape approach.
 
 */
- (void) zoom: (bool) zoomIn {
	
	//SCALINGZOOMVIEW EXPERIMENT
	if (!_zoomCenter) _zoomCenter = 1.00;
	if (zoomIn) {
		//_zoomCenter += .05;
		//[self.textScrollView zoomIn:_zoomCenter];
		[self.textScrollView zoomIn:nil];
	} else {
		[self.textScrollView zoomOut:nil];
	}
		
	return;
	
	CGFloat magnification = [self.textScrollView magnification];

	if (!zoomIn && magnification == 1.00) return; // Don't let zoom out below 1.00
	if (zoomIn && magnification > 1.4) return;

	// Set minimum window size according to magnification
	[self setMinimumWindowSize];

	if (zoomIn) magnification += .05; else magnification -= .05;
	
	// Define center of the view
	NSPoint center = NSMakePoint(self.textView.frame.size.width / 2, self.textView.frame.size.height / 2);
	center.x = _documentWidth / 2;
	
		[self.textScrollView setMagnification:magnification centeredAtPoint:center];
		[self.thisWindow layoutIfNeeded];
		[self updateLayout];
	
		[self updateSceneNumberLabels];
		[self updateLayout];
	
	/*
	// We'll do this at a later time :-)
	[[NSUserDefaults standardUserDefaults] setInteger:_magnifyLevel forKey:MAGNIFYLEVEL_KEY];
	*/
	
	// Update everything in panic
	[self updateSceneNumberLabels];
	[self updateLayout];
}

- (void) setZoom {
	// Set initial zoom
	
	[self updateLayout];
	[self updateSceneNumberLabels];
	
	// Define center of the view
	NSPoint center = NSMakePoint(self.textView.frame.size.width / 2, self.textView.frame.size.height / 2);
	center.y = 0;
	center.x = _documentWidth / 2;
	
	[self.textScrollView setMagnification:1.1 centeredAtPoint:center];
	[self.thisWindow setMinSize:NSMakeSize(_documentWidth * 1.4 * self.textScrollView.magnification, 400)];
	
	[self updateLayout];
    [self updateSceneNumberLabels];
}

- (IBAction)increaseFontSize:(id)sender
{
	if (MAGNIFY) { [self zoom:true]; return; }
	

	// Old way
	if (_zoomLevel < 30)
	{
		NSLog(@"Zoom in: %lu", _zoomLevel);
		_zoomLevel++;
		_documentWidth = _zoomLevel * ZOOM_MODIFIER;
		
		NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
		for (Document* doc in openDocuments) {
			doc.fontSize = _zoomLevel * FONT_SIZE_MODIFIER * ZOOM_MODIFIER;
			
			// Center everything and adjust page width
			self.textView.textContainerInset = NSMakeSize(self.textView.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
			self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
			
			doc.courier = nil;
			doc.boldCourier = nil;
			doc.italicCourier = nil;
			[doc refontAllLines];
		}
	}
	[[NSUserDefaults standardUserDefaults] setInteger:self.zoomLevel forKey:ZOOMLEVEL_KEY];
	[self updateSceneNumberLabels];
}

- (IBAction)decreaseFontSize:(id)sender
{
	if (MAGNIFY) { [self zoom:false]; return; }
	
	// Old way
	if (_zoomLevel > 10) {
		NSLog(@"Zoom out: %lu", _zoomLevel);
		_zoomLevel--;
		_documentWidth = _zoomLevel * ZOOM_MODIFIER;
		
		NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
		
		for (Document* doc in openDocuments) {
			doc.fontSize = _zoomLevel * FONT_SIZE_MODIFIER * ZOOM_MODIFIER;
			
			// Center everything and adjust page width
			self.textView.textContainerInset = NSMakeSize(self.textView.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
			self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
			
			//doc.fontSize--;
			doc.courier = nil;
			doc.boldCourier = nil;
			doc.italicCourier = nil;
			[doc refontAllLines];
		}
	}
	[[NSUserDefaults standardUserDefaults] setInteger:self.zoomLevel forKey:ZOOMLEVEL_KEY];
	[self updateSceneNumberLabels];
}


- (IBAction)resetFontSize:(id)sender
{
	if (MAGNIFY) return;

	// Reset zoom level
	_zoomLevel = DEFAULT_ZOOM;
	_documentWidth = _zoomLevel * ZOOM_MODIFIER;
	
	NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
	
	for (Document* doc in openDocuments) {
		doc.fontSize = _documentWidth * FONT_SIZE_MODIFIER;
		
		// Center everything and adjust page width
		self.textView.textContainerInset = NSMakeSize(self.textView.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
		self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
		
		doc.courier = nil;
		doc.boldCourier = nil;
		doc.italicCourier = nil;
		[doc refontAllLines];
		
	}
	[[NSUserDefaults standardUserDefaults] setInteger:self.zoomLevel forKey:ZOOMLEVEL_KEY];
	[self updateSceneNumberLabels];
}


- (void)resizeMargins {
	/*
	
	 Margins to make an illusion of "page" view. These didn't work because they blocked the find field. Best solution would be just to make a background box and resize the textView accordingly, but I don't have the time or the nerves to count the sizes now. One fine day maybe. I'm not even sure if it would look that good or just distracting.
	 
	*/
	
	/*
	CGRect leftFrame = self.leftMargin.frame;
	leftFrame.origin.x = 0;
	leftFrame.origin.y = 0;
	leftFrame.size = CGSizeMake(self.textView.frame.size.width / 2 - _documentWidth / 2 - 150, self.textView.frame.size.height);
	
	NSLog(@"textview width %f documentwidth %lu", self.textView.frame.size.width, _documentWidth);
	NSLog(@"width %f height %f", leftFrame.size.width, leftFrame.size.height);
	//leftFrame.size = TREE_VIEW_WIDTH + 15;
	//[self.outlineButton.animator setFrame:buttonFrame];
	self.leftMargin.frame = leftFrame;
	
	CGRect rightFrame = self.rightMargin.frame;
	rightFrame.origin.y = 0;
	rightFrame.size = CGSizeMake(self.textView.frame.size.width / 2 - _documentWidth / 2 - 150, self.textView.frame.size.height);
	rightFrame.origin.x = _thisWindow.frame.size.width - rightFrame.size.width;
	self.rightMargin.frame = rightFrame;
	*/
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



# pragma mark Text content stuff

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
    FNHTMLScript *htmpScript = [[FNHTMLScript alloc] initWithScript:script document:self];
    [[self.webView mainFrame] loadHTMLString:[htmpScript html] baseURL:nil];
}


# pragma mark Should change text + autocomplete

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
    //If something is being inserted, check wether it is a "(" or a "[[" and auto close it
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

- (void)textDidChange:(NSNotification *)notification
{
    if (self.outlineViewVisible && [self.parser getAndResetChangeInOutline]) {
		[self reloadOutline];
    }
    [self applyFormatChanges];
	
	[self.parser numberOfOutlineItems];
	[self updateSceneNumberLabels];
}

/* #### AUTOCOMPLETE ##### */

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

# pragma mark Formatting

/* #### FORMATTING #### */
- (IBAction) reformatEverything:(id)sender {
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

/*

#define CHARACTER_INDENT 220
#define PARENTHETICAL_INDENT 185
#define DIALOGUE_INDENT 100
#define DIALOGUE_RIGHT 450

#define DD_CHARACTER_INDENT 200
#define DD_PARENTHETICAL_INDENT 385
#define DOUBLE_DIALOGUE_INDENT 150
#define DD_RIGHT 650

*/

- (void)formatLineOfScreenplay:(Line*)line onlyFormatFont:(bool)fontOnly
{
    if (self.livePreview) {
		_currentLine = line;
		
        NSTextStorage *textStorage = [self.textView textStorage];
        
        NSUInteger begin = line.position;
        NSUInteger length = [line.string length];
        NSRange range = NSMakeRange(begin, length);
		
        NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
		
		NSMutableParagraphStyle *lineHeight = [[NSMutableParagraphStyle alloc]init];
		
		// This doesn't format empty lines for some reason: [lineHeight setLineHeightMultiple:1.05];
		[attributes setObject:lineHeight forKey:NSParagraphStyleAttributeName];
		
        //Formatt according to style
        if ((line.type == heading && [line.string characterAtIndex:0] != '.') ||
            (line.type == transition && [line.string characterAtIndex:0] != '>')) {
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
            } else if (line.type == transition) {
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
                //NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
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
                
            } else if (line.type == section || line.type == synopse || line.type == titlePageUnknown) {
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
        [textStorage addAttributes:attributes range:range];
        
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
}

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
    return NSMakeRange(range->location + position, range->length);
}


- (NSFont*)cothamRegular {
	if (!_cothamRegular) {
		_cothamRegular = [NSFont fontWithName:@"Cotham Sans" size:11];
	}
	return _cothamRegular;
}

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

- (NSUInteger)zoomLevel
{
    if (_zoomLevel == 0) {
        _zoomLevel = [[NSUserDefaults standardUserDefaults] integerForKey:ZOOMLEVEL_KEY];
		NSLog(@"User zoomlevel: %lu", _zoomLevel);
        if (_zoomLevel == 0) {
            _zoomLevel = DEFAULT_ZOOM;
        }
    }
    
    return _zoomLevel;
}
/*
- (NSUInteger)magnifyLevel
{
	if (_magnifyLevel == 0) {
		_magnifyLevel = [[NSUserDefaults standardUserDefaults] integerForKey:MAGNIFYLEVEL_KEY];
		NSLog(@"User magnify level: %lu", _magnifyLevel);
		if (_magnifyLevel == 0) {
			_magnifyLevel = DEFAULT_MAGNIFY;
		}
	}
	
	return _magnifyLevel;
}
*/
- (NSUInteger)fontSize
{
	if (!MAGNIFY) {
		_fontSize = _zoomLevel * FONT_SIZE_MODIFIER * ZOOM_MODIFIER;
		return _fontSize;
	} else {
		_fontSize = DEFAULT_ZOOM * FONT_SIZE_MODIFIER * ZOOM_MODIFIER;
		return _fontSize;
	}
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
static NSString *forceTransitionSymbol = @">";
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
	NSLog(@"Lock scene numbers (the new way)");
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

- (NSRange)cursorLocation
{
    return [[self.textView selectedRanges][0] rangeValue];
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

- (IBAction)forceTransition:(id)sender
{
    
    //Check if the currently selected tab is the one for editing
    if ([self selectedTabViewTab] == 0) {
        //Retreiving the cursor location
        NSRange cursorLocation = [self cursorLocation];
        [self forceLineType:cursorLocation symbol:forceTransitionSymbol];
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
        
        NSArray *allForceSymbols = @[forceActionSymbol, forceCharacterSymbol, forceHeadingSymbol, forceLyricsSymbol, forceTransitionSymbol];
        
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
		
		/*
		NSString *oldString = [[self getText] substringWithRange:range];
		NSRange undoRange = NSMakeRange(range.location, [oldString length]);
		[[[self undoManager] prepareWithInvocationTarget:self] replaceCharactersInRange:undoRange withString:oldString];
		 */
    }
}

// WIP
-(void)updateSizes:(id)sender
{
    
}


#pragma mark - User Interaction

- (IBAction)toggleOutlineView:(id)sender
{
    self.outlineViewVisible = !self.outlineViewVisible;
	
	NSUInteger offset = 20;
	if ([self isFullscreen]) offset = 0;
	
	[NSAnimationContext.currentContext setCompletionHandler:^{
		//[self.textView setTextContainerInset:NSMakeSize((self.thisWindow.frame.size.width - self.outlineViewWidth.constant) / 2 - _documentWidth / 2, TEXT_INSET_TOP)];
		
		[self updateSceneNumberLabels];
	}];
	
    if (self.outlineViewVisible) {
		[self reloadOutline];
		
		[self.outlineView expandItem:nil expandChildren:true];
        [self.outlineViewWidth.animator setConstant:TREE_VIEW_WIDTH];
		
		NSWindow *window = self.windowControllers[0].window;
		NSRect newFrame;
		
		if (![self isFullscreen]) {
			newFrame = NSMakeRect(window.frame.origin.x,
										 window.frame.origin.y,
										 window.frame.size.width + TREE_VIEW_WIDTH + offset,
										 window.frame.size.height);
			[window.animator setFrame:newFrame display:YES];
		} else {
			[self.textView.animator setTextContainerInset:NSMakeSize((window.frame.size.width - TREE_VIEW_WIDTH) / 2 - _documentWidth / 2, TEXT_INSET_TOP)];
			
			//[self.textView.animator setTextContainerInset:NSMakeSize((self.thisWindow.frame.size.width - TREE_VIEW_WIDTH) / 2 - _documentWidth / 2, TEXT_INSET_TOP)];
			/*
			[self.textView setTextContainerInset:NSMakeSize((self.textView.frame.size.width - TREE_VIEW_WIDTH) / 2 - _documentWidth / 2, TEXT_INSET_TOP)];
			[self updateLayout];
			
			[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
				
			} completionHandler:^{
				[self updateLayout];
			}];
			*/
			//[self.textView.animator setTextContainerInset:NSMakeSize((window.frame.size.width - TREE_VIEW_WIDTH) / 2 - _documentWidth / 2, TEXT_INSET_TOP)];
		}
		
		
		CGRect buttonFrame = self.outlineButton.frame;
		buttonFrame.origin.x = TREE_VIEW_WIDTH + 15;
		[self.outlineButton.animator setFrame:buttonFrame];

    } else {
		CGRect buttonFrame = self.outlineButton.frame;
		buttonFrame.origin.x = 15;
		[self.outlineButton.animator setFrame:buttonFrame];
		
		[self.outlineViewWidth.animator setConstant:0];
		NSWindow *window = self.windowControllers[0].window;
		NSRect newFrame;
		
		if (![self isFullscreen]) {
			newFrame = NSMakeRect(window.frame.origin.x - offset,
										 window.frame.origin.y,
										 window.frame.size.width - TREE_VIEW_WIDTH - offset * 2,
										 window.frame.size.height);
			[window.animator setFrame:newFrame display:YES];
		} else {
			newFrame = NSMakeRect(window.frame.origin.x - offset,
								  window.frame.origin.y,
								  window.frame.size.width,
								  window.frame.size.height);

			//self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
			//[self.textView.animator setTextContainerInset:NSMakeSize(window.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP)];
			
		
			// [self.textView.animator setFrame:newFrame];
			
			[self.textView.animator setTextContainerInset:NSMakeSize(window.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP)];
		}
		
		//[self updateLayout];
    }
}

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}

- (IBAction)themes:(id)sender {}

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
    } else if ([menuItem.title isEqualToString:@"Theme"]) { // Deprecated
        if ([self selectedTabViewTab] != 0) {
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
		if (self.nightMode) {
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
	_nightMode = !_nightMode;
	[self.textView toggleDarkPopup:nil];
	
	if (_nightMode) {
		[self.themeManager selectThemeWithName:@"Night"];
		_darkPopup = true;
	} else {
		[self.themeManager selectThemeWithName:@"Day"];
		_darkPopup = false;
	}
	[self loadSelectedTheme];
}

// Deprecated
- (IBAction)selectTheme:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem* menuItem = sender;
        NSString* itemName = menuItem.title;
        [self.themeManager selectThemeWithName:itemName];
        [self loadSelectedTheme];
    }
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

- (void)loadSelectedTheme
{
    NSArray* openDocuments = [[NSApplication sharedApplication] orderedDocuments];
    
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
		
		NSBox *leftMargin = doc.leftMargin;
		NSBox *rightMargin = doc.rightMargin;
		
		[leftMargin setFillColor:[self.themeManager currentMarginColor]];
		[rightMargin setFillColor:[self.themeManager currentMarginColor]];
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
}

- (NSUInteger)selectedTabViewTab
{
    return [self.tabView indexOfTabViewItem:[self.tabView selectedTabViewItem]];
}

- (void)setSelectedTabViewTab:(NSUInteger)index
{
    [self.tabView selectTabViewItem:[self.tabView tabViewItemAtIndex:index]];
}



#pragma  mark - NSOutlineViewDataSource and Delegate

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
	NSMutableArray * outlineItems = [[NSMutableArray alloc] init];
	
	// WIP
	for (OutlineScene * scene in [self.parser outline]) {
		[outlineItems addObject:scene];
		
		if ([scene.scenes count]) {
			for (OutlineScene * subscene in scene.scenes) {
				[outlineItems addObject:subscene];
			}
		}
	}
	
	return outlineItems;
}

- (NSRange) getRangeForScene:(OutlineScene *) scene {
	NSUInteger start = scene.line.position;
	NSUInteger length = 0;
	
	OutlineScene * nextScene = [self getNextScene:scene];
	
	if (nextScene != nil) {
		length = nextScene.line.position - start;
	} else {
		// There is no next scene, so just grab the last line
		Line * lastLine = [[self.parser lines] objectAtIndex: [[self.parser lines] count] + 1];
		length = lastLine.position + lastLine.string.length - start;
	}

	return NSMakeRange(start, length);
	
}
- (OutlineScene *) getNextScene:(OutlineScene *) currentScene {
	// Returns the NEXT heading of any type to this scene .....
	NSInteger index = 0;
	bool found = false;
	OutlineScene * nextScene = nil;
	
	for (OutlineScene * scene in [self.parser outline]) {
		if (found) {
			nextScene = scene;
		}
		
		if (scene == currentScene) {
			found = true;
		}
		
		index++;
	}
	
	return nextScene;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item;
{
    if (!item) {
        //Children of root
        return [self.parser numberOfOutlineItems];
	} else {
		return [[item scenes] count];
	}
    //return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	if (!item) {
		return [[self.parser outline] objectAtIndex:index];
	} else {
		return [[item scenes] objectAtIndex:index];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if ([[item scenes] count] > 0) {
		return YES;
	}
	else { return NO; }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if ([item isKindOfClass:[OutlineScene class]]) {
		
        OutlineScene* line = item;

		// The outline elements will be formatted as rich text,
		// which is apparently VERY CUMBERSOME in Objective-C.
		NSMutableAttributedString * resultString = [[NSMutableAttributedString alloc] initWithString:line.string];
		[resultString addAttribute:NSFontAttributeName value:[self cothamRegular] range:NSMakeRange(0, [line.string length])];
		
        if (line.type == heading) {
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
				
				// Scene number will be displayed in a slightly darker shade
				[resultString addAttribute:NSForegroundColorAttributeName value:NSColor.grayColor range:NSMakeRange(0,[sceneHeader length])];
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
				
				NSFont *font = [NSFont systemFontOfSize:14.0f];
				NSDictionary * fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, nil];
				
				resultString = [[NSMutableAttributedString alloc] initWithString:string attributes:fontAttributes];
				
				// Italic + white color
				[resultString applyFontTraits:NSItalicFontMask range:NSMakeRange(0,[resultString length])];
				[resultString addAttribute:NSForegroundColorAttributeName value:NSColor.whiteColor range:NSMakeRange(0,[resultString length])];
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
				
				string = [@"  " stringByAppendingString:string];
				
				NSFont *font = [NSFont systemFontOfSize:14.0f];
				NSDictionary * fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, nil];

				resultString = [[NSMutableAttributedString alloc] initWithString:string attributes:fontAttributes];
				
				// Bold + white color
				[resultString addAttribute:NSForegroundColorAttributeName value:NSColor.whiteColor range:NSMakeRange(0,[resultString length])];
				
				[resultString applyFontTraits:NSBoldFontMask range:NSMakeRange(0,[resultString length])];
            } else {
                resultString = [[NSMutableAttributedString alloc] initWithString:line.string];
            }
        }

		if (line.color) {
			
			NSMutableAttributedString * color = [[NSMutableAttributedString alloc] initWithString:@" ⬤" attributes:nil];
			NSString *colorString = [line.color lowercaseString];
			NSColor *colorName = [self colors][colorString];
			//NSColor *colorName = nil;
			
			// If we found a suitable color, let's add it
			if (colorName != nil) {
				[color addAttribute:NSForegroundColorAttributeName value:colorName range:NSMakeRange(0, 2)];
				[resultString appendAttributedString:color];
			}
		}
		
		return resultString;
    }
    return @"";
	
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	if ([item isKindOfClass:[OutlineScene class]]) {
		
		NSRange lineRange = NSMakeRange([item line].position, [item line].string.length);
		[self.textView setSelectedRange:lineRange];
		[self.textView scrollRangeToVisible:lineRange];
		return YES;
	}
	return NO;
}

- (void) reloadOutline {
	[_outlineClosedSections removeAllObjects];
	
	// Save list of sections that have been closed
	for (int i = 0; i < [[self.parser outline] count]; i++) {
		id item = [self.outlineView itemAtRow:i];
		if (![self.outlineView isItemExpanded:item]) {
			[_outlineClosedSections addObject:[item string]];
		}
	}
	
	// Save outline scroll position
	NSPoint scrollPosition = [[self.outlineScrollView contentView] bounds].origin;
	
	[self.outlineView reloadData];
	
	// Expand all
	[self.outlineView expandItem:nil expandChildren:true];
	
	// Then let's close the ones that the user had closed
	for (int i = 0; i < [[self.parser outline] count]; i++) {
		id item = [self.outlineView itemAtRow:i];
		if ([_outlineClosedSections containsObject:[item string]]) {
			[self.outlineView collapseItem:item];
		}
	}
	
	/*
	 // I'll look at this at a later time. I'd like to highlight / scroll to the currently edited outline item

	 if (_currentLine) {
		if (_currentLine.type == heading || _currentLine.type == section || _currentLine.type == synopse) {
			OutlineScene * item = [self.parser getOutlineForLine:_currentLine];
			NSLog(@"Found item: %@", item.string);
			NSInteger row = [self.outlineView rowForItem:item];
			[self.outlineView scrollRowToVisible:row];
		}
	}
	*/
	
	// Scroll back to original position after reload
	[[self.outlineScrollView contentView] scrollPoint:scrollPosition];
	
	[self updateSceneNumberLabels];
}



#pragma mark - Outline context menu

/*
 
 Outline context menu, WIP.
 
 To make this work reliably, we should check for a lot of stuff, such as if there already is a color
 or some other note on the heading line. I don't have the willpower to do it just now, but maybe someday.
 
 The thing is, after this is done, we can also filter the outline view according to color tags. One thing
 to consider is also if we want to have multiple color tags on lines? I kind of hate that usually, 
 especially if it's done badly, but in many cases it could be useful.

 Regexes hurt my brain, and they do so extra much in Objective-C, so maybe I'll just search for
 ranges whenever I decide to do this.
 
 Also, in principle it should be possible to enter custom colors in hex. Such as [[COLOR #d00dd]].

*/
- (void) menuNeedsUpdate:(NSMenu *)menu {
	NSInteger clickedRow = [self.outlineView clickedRow];

	id item = nil;
	item = [self.outlineView itemAtRow:clickedRow];
	
	if (item != nil && [item isKindOfClass:[OutlineScene class]]) {
		// Show context menu
		for (NSMenuItem * menuItem in menu.itemArray) {
			menuItem.hidden = NO;
			// But let's hide this context menu for now as it's WIP
			//menuItem.hidden = YES;
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
	id item = [self.outlineView itemAtRow:[self.outlineView clickedRow]];
	if (item != nil && [item isKindOfClass:[OutlineScene class]]) {
		OutlineScene *scene = item;
		
		[self setColor:color forScene:scene];
	}
}
- (void) setColor:(NSString *) color forScene:(OutlineScene *) scene {
	color = [color uppercaseString];
	
	if (![scene.color isEqualToString:@""] && scene.color != nil) {
		if ([[color lowercaseString] isEqualToString:@"none"]) {
			NSString *oldColorString = [NSString stringWithFormat:@"[[COLOR %@]]", [scene.color uppercaseString]];
			NSRange innerRange = [scene.line.string rangeOfString:oldColorString];
			NSRange range = NSMakeRange([[scene line] position] + innerRange.location, innerRange.length);
			[self replaceCharactersInRange:range withString:@""];
		} else {
			NSString * oldColor = [NSString stringWithFormat:@"COLOR %@", scene.color];
			NSString * newColor = [NSString stringWithFormat:@"COLOR %@", color];
			NSRange innerRange = [scene.line.string rangeOfString:oldColor];
			NSRange range = NSMakeRange([[scene line] position] + innerRange.location, innerRange.length);
			[self replaceCharactersInRange:range withString:newColor];
		}
	} else {
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
			 @"brown": [self colorWithRed:169 green:106 blue:7]
    };
}
- (NSColor *) colorWithRed: (CGFloat) red green:(CGFloat)green blue:(CGFloat)blue {
	return [NSColor colorWithDeviceRed:(red / 255) green:(green / 255) blue:(blue / 255) alpha:1.0f];
}

/*
 if ([line.color  caseInsensitiveCompare:@"red"] == NSOrderedSame) colorName = NSColor.redColor;
 else if ([line.color  caseInsensitiveCompare:@"blue"] == NSOrderedSame) colorName = NSColor.blueColor;
 else if ([line.color  caseInsensitiveCompare:@"green"] == NSOrderedSame) colorName = NSColor.greenColor;
 else if ([line.color  caseInsensitiveCompare:@"yellow"] == NSOrderedSame) colorName = NSColor.yellowColor;
 else if ([line.color  caseInsensitiveCompare:@"black"] == NSOrderedSame) colorName = NSColor.blackColor;
 else if ([line.color  caseInsensitiveCompare:@"gray"] == NSOrderedSame) colorName = NSColor.grayColor;
 else if ([line.color  caseInsensitiveCompare:@"grey"] == NSOrderedSame) colorName = NSColor.grayColor;
 else if ([line.color  caseInsensitiveCompare:@"purple"] == NSOrderedSame) colorName = NSColor.purpleColor;
 else if ([line.color  caseInsensitiveCompare:@"magenta"] == NSOrderedSame) colorName = NSColor.magentaColor;
 else if ([line.color  caseInsensitiveCompare:@"pink"] == NSOrderedSame) colorName = NSColor.magentaColor;
 */



#pragma mark - Card view

- (IBAction) toggleCards: (id)sender {
	if ([self selectedTabViewTab] != 2) {
		_cardsVisible = YES;
		
		[self refreshCards];
		[self setSelectedTabViewTab:2];
//		NSCollectionViewItem * item = [_cardView makeItemWithIdentifier:"item" forIndexPath:<#(nonnull NSIndexPath *)#>
		
	} else {
		_cardsVisible = NO;
		[self setSelectedTabViewTab:0];
		[self updateLayout];
	}
}

// We should do most of the work listed here in the JavaScript, tbh.
// Just load the view contents at the beginning and just inject new JSON data, and let's let the JS function build up the view.
// That way we can also reuse the cards and avoid repositioning the view for no real reason.
// Let's also move all this shit to another file some day.
- (void) setupCards {
	NSError *error = nil;
	
	NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"CardCSS.css" ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"CardView.js" ofType:@""];
	NSString *javaScript = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString* content = [NSString stringWithFormat:@"<html><style>%@</style><body><div id='close'>✕</div><div id='container'>", css];
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
	
	if (self.nightMode) {
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
		return [NSString stringWithFormat:@"'sceneNumber': '%@', 'name': '%@', 'snippet': '%@', 'position': '%lu', 'color': '%@', 'lineIndex': %lu, %@",
				[self JSONString:scene.sceneNumber],
				[self JSONString:scene.string],
				[self JSONString:snippet],
				scene.line.position,
				[scene.color lowercaseString],
				index,
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

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *) message{
	if ([message.body  isEqual: @"exit"]) {
		[self toggleCards:nil];
		return;
	}
	
	if ([message.name isEqualToString:@"cardClick"]) {
		NSRange lineRange = NSMakeRange([message.body intValue], 0);
		[self.textView setSelectedRange:lineRange];
		[self.textView scrollRangeToVisible:lineRange];
		[self toggleCards:nil];
		
		return;
	}
	
	if ([message.name isEqualToString:@"setColor"]) {
		NSLog(@"Body : %@", message.body);
		
		if ([message.body rangeOfString:@":"].location != NSNotFound) {
			NSArray *indexAndColor = [message.body componentsSeparatedByString:@":"];
			NSUInteger index = [[indexAndColor objectAtIndex:0] integerValue];
			NSString *color = [indexAndColor objectAtIndex:1];
			
			Line *line = [[self.parser lines] objectAtIndex:index];
			OutlineScene *scene = [self findSceneByLine:line];
			
			[self setColor:color forScene:scene];
		}
	}
	
	if ([message.name isEqualToString:@"moveScene"]) {
		NSLog(@"Body: %@", message.body);
	}
}


#pragma mark - Scene numbering for NSTextView

/*
 
 WORK IN PROGRESS
 This following section might have problems with memory leaks.
 
 */

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

// This kind of works but might make things a bit slow. I'm not sure. There are CPU spikes on scroll at times, but debouncing the calls to update didn't work as scrolling might end during the debounce cooldown.
// Send help.
- (void) updateSceneNumberLabels {
	
	if (_sceneNumberLabelUpdateOff || !_showSceneNumberLabels) return;
	
	if (![[self.parser outline] count]) {
		[self.parser numberOfOutlineItems];
	}
	
	NSInteger numberOfScenes = [self getNumberOfScenes];
	NSInteger numberOfLabels = [self.sceneNumberLabels count];
	NSInteger difference = numberOfScenes - numberOfLabels;
	
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

/* Listen to scrolling of the view */
- (void)boundsDidChange:(NSNotification*)notification {
	[self updateSceneNumberLabels];
	
	// if(_scrollTimer == nil) [self scrollViewDidScroll];
	[self performSelector:@selector(updateSceneNumberLabels) withDebounceDuration:.1];
	
	if (_scrollTimer != nil && [_scrollTimer isValid])
		[_scrollTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
	else
		_scrollTimer = [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(scrollViewDidEndScrolling) userInfo:nil repeats:NO];
}
- (void)scrollViewDidScroll {
	//[self performSelector:@selector(updateSceneNumberLabels) withDebounceDuration:0.2];
	//[self updateSceneNumberLabels];
}
- (void)scrollViewDidEndScrolling
{
	[self updateSceneNumberLabels];
	if(_scrollTimer != nil) _scrollTimer = nil;
}

@end
