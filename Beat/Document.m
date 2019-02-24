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

 Page sizing info:
 
 Character - 32%
 Parenthetical - 30%
 Dialogue - 16%
 Dialogue width - 74%
  
*/

#import <WebKit/WebKit.h>
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

//#import "Beat-Bridging-Header.h"

@interface Document ()

@property (unsafe_unretained) IBOutlet NSToolbar *toolbar;
@property (unsafe_unretained) IBOutlet NCRAutocompleteTextView *textView;
@property (weak) IBOutlet NSScrollView *textScrollView;

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSScrollView *outlineScrollView;
@property (nonatomic) NSWindow *thisWindow;

@property (unsafe_unretained) IBOutlet WebView *webView;
@property (unsafe_unretained) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet ColorView *backgroundView;

@property (unsafe_unretained) IBOutlet NSBox *leftMargin;
@property (unsafe_unretained) IBOutlet NSBox *rightMargin;

@property (weak) IBOutlet NSLayoutConstraint *outlineViewWidth;
@property BOOL outlineViewVisible;
@property (nonatomic) NSMutableArray *outlineClosedSections;

@property (nonatomic) NSMutableArray *sceneNumberLabels;

#pragma mark - Floating outline button
@property (weak) IBOutlet NSButton *outlineButton;

#pragma mark - Toolbar Buttons

@property (weak) IBOutlet NSButton *outlineToolbarButton;
@property (weak) IBOutlet NSButton *boldToolbarButton;
@property (weak) IBOutlet NSButton *italicToolbarButton;
@property (weak) IBOutlet NSButton *underlineToolbarButton;
@property (weak) IBOutlet NSButton *omitToolbarButton;
@property (weak) IBOutlet NSButton *noteToolbarButton;
@property (weak) IBOutlet NSButton *forceHeadingToolbarButton;
@property (weak) IBOutlet NSButton *forceActionToolbarButton;
@property (weak) IBOutlet NSButton *forceCharacterToolbarButton;
@property (weak) IBOutlet NSButton *forceTransitionToolbarButton;
@property (weak) IBOutlet NSButton *forceLyricsToolbarButton;
@property (weak) IBOutlet NSButton *titlepageToolbarButton;
@property (weak) IBOutlet NSButton *pagebreakToolbarButton;
@property (weak) IBOutlet NSButton *previewToolbarButton;
@property (weak) IBOutlet NSButton *printToolbarButton;

@property (strong) NSArray *toolbarButtons;

@property (strong, nonatomic) NSString *contentBuffer; //Keeps the text until the text view is initialized

@property (strong, nonatomic) NSFont *courier;
@property (strong, nonatomic) NSFont *boldCourier;
@property (strong, nonatomic) NSFont *italicCourier;
@property (nonatomic) NSUInteger fontSize;
@property (nonatomic) NSUInteger zoomLevel;
@property (nonatomic) bool livePreview;
@property (nonatomic) bool printPreview;
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


#define MATCH_PARENTHESES_KEY @"Match Parentheses"
#define LIVE_PREVIEW_KEY @"Live Preview"
#define FONTSIZE_KEY @"Fontsize"
#define ZOOMLEVEL_KEY @"Zoomlevel"
#define DEFAULT_ZOOM 17
#define FONT_SIZE_MODIFIER 0.027
#define ZOOM_MODIFIER 40
#define PRINT_SCENE_NUMBERS_KEY @"Print scene numbers"

@implementation Document

#pragma mark - Document Basics

- (instancetype)init {
    self = [super init];
    if (self) {
        self.printInfo.topMargin = 25;
        self.printInfo.bottomMargin = 55;
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


- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
	_thisWindow = aController.window;
	
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    //    aController.window.titleVisibility = NSWindowTitleHidden; //Makes the title and toolbar unified by hiding the title
	
	/// Hide the welcome screen
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Document open" object:nil];
	
	// Get zoom level & font size
	_zoomLevel = self.zoomLevel;
	_documentWidth = _zoomLevel * ZOOM_MODIFIER;
	
    //Set the width programmatically since w've got the outline visible in IB to work on it, but don't want it visible on launch
    NSWindow *window = aController.window;
    NSRect newFrame = NSMakeRect(window.frame.origin.x,
                                 window.frame.origin.y,
                                 _documentWidth * 1.35,
                                 _documentWidth * 1.3);
    [window setFrame:newFrame display:YES];
	
	// Accept mouse moved events
	[aController.window setAcceptsMouseMovedEvents:YES];
	
	CGRect buttonFrame = self.outlineButton.frame;
	buttonFrame.origin.x = 15;
	self.outlineButton.frame = buttonFrame;
	
    self.outlineViewVisible = false;
    self.outlineViewWidth.constant = 0;
    
    self.toolbarButtons = @[_outlineToolbarButton,_boldToolbarButton, _italicToolbarButton, _underlineToolbarButton, _omitToolbarButton, _noteToolbarButton, _forceHeadingToolbarButton, _forceActionToolbarButton, _forceCharacterToolbarButton, _forceTransitionToolbarButton, _forceLyricsToolbarButton, _titlepageToolbarButton, _pagebreakToolbarButton, _previewToolbarButton, _printToolbarButton];
	
    self.textView.textContainer.widthTracksTextView = false;
	[[self.textScrollView contentView] setPostsBoundsChangedNotifications:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boundsDidChange:) name:NSViewBoundsDidChangeNotification object:[self.textScrollView contentView]];
	
	// Window frame will be the same as text frame width at startup (outline is not visible by default)
	// TextView won't have a frame size before load, so let's use the window width instead to set the insets.
	self.textView.textContainer.size = NSMakeSize(_documentWidth, self.textView.textContainer.size.height);
	self.textView.textContainerInset = NSMakeSize(window.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
	
    self.backgroundView.fillColor = [NSColor colorWithCalibratedRed:0.3
                                                              green:0.3
                                                               blue:0.3
                                                              alpha:1.0];
    [self.textView setFont:[self courier]];
    [self.textView setAutomaticQuoteSubstitutionEnabled:NO];
    [self.textView setAutomaticDataDetectionEnabled:NO];
    [self.textView setAutomaticDashSubstitutionEnabled:NO];
	
	// Set first responder to the text field
	[aController.window makeFirstResponder:self.textView];
	[self.textView setEditable:YES];
    
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
	
    //Initialize Theme Manager (before the formatting, because we need the colors for formatting!)
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
	
	// Let's set a timer for 200ms. This should update the scene number labels before letting the text to render.
	// This doesn't work. Nothing works.
	// [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(afterLoad) userInfo:nil repeats:NO];
}
- (void) afterLoad {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self updateSceneNumberLabels];
	});
}

- (void)windowDidResize:(NSNotification *)notification {
    self.textView.textContainerInset = NSMakeSize(self.textView.frame.size.width / 2 - _documentWidth / 2, TEXT_INSET_TOP);
	
	[self resizeMargins]; // Unused for now
	
	[self updateSceneNumberLabels];
}

- (void)resizeMargins {
	/*
	
	 Margins to make an illusion of "page" view. These didn't work because they blocked the find field. Best solution would be just to make a background box and resize the textView accordingly, but I don't have the time or the nerves to count the sizes now. One fine day maybe. I'm not even sure if it would look that good or distracting.
	 
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
        alert.alertStyle = NSWarningAlertStyle;
        [alert beginSheetModalForWindow:self.windowControllers[0].window completionHandler:nil];
    } else {
		if (self.printSceneNumbers) {
			self.preprocessedText = [self preprocessSceneNumbers];
		} else {
			self.preprocessedText = [self.getText copy];
		}
        self.printView = [[PrintView alloc] initWithDocument:self toPDF:NO];
    }
}

- (IBAction)exportPDF:(id)sender
{
	if (self.printSceneNumbers) {
		self.preprocessedText = [self preprocessSceneNumbers];
	} else {
		self.preprocessedText = [self.getText copy];
	}
	
    self.printView = [[PrintView alloc] initWithDocument:self toPDF:YES];
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
    FNScript *script = [[FNScript alloc] initWithString:[self getText]];
    FNHTMLScript *htmpScript = [[FNHTMLScript alloc] initWithScript:script document:self];
    [[self.webView mainFrame] loadHTMLString:[htmpScript html] baseURL:nil];
}

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

/* #### FORMATTING #### */

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
        } else if (line.type == pageBreak) {
            //Set Font to bold
            [attributes setObject:[self boldCourier] forKey:NSFontAttributeName];
            
        } else if (line.type == lyrics) {
            //Set Font to italic
            [attributes setObject:[self italicCourier] forKey:NSFontAttributeName];
        }

        if (!fontOnly) {
            if (line.type == titlePageTitle  ||
                line.type == titlePageAuthor ||
                line.type == titlePageCredit ||
                line.type == titlePageSource) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setAlignment:NSTextAlignmentCenter];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
            } else if (line.type == transition) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setAlignment:NSTextAlignmentRight];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                
            } else if (line.type == centered || line.type == lyrics) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setAlignment:NSTextAlignmentCenter];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                
            } else if (line.type == character) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setFirstLineHeadIndent:CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setHeadIndent:CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                
            } else if (line.type == parenthetical) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setFirstLineHeadIndent:PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setHeadIndent:PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                
            } else if (line.type == dialogue) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setFirstLineHeadIndent:DIALOGUE_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setHeadIndent:DIALOGUE_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                
            } else if (line.type == doubleDialogueCharacter) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setFirstLineHeadIndent:DD_CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setHeadIndent:DD_CHARACTER_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setTailIndent:DD_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                
            } else if (line.type == doubleDialogueParenthetical) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
                [paragraphStyle setFirstLineHeadIndent:DD_PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setHeadIndent:DD_PARENTHETICAL_INDENT_P * ZOOM_MODIFIER * _zoomLevel];
                [paragraphStyle setTailIndent:DD_RIGHT_P * ZOOM_MODIFIER * _zoomLevel];
                
                [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
                
            } else if (line.type == doubleDialogue) {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
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
        if (_zoomLevel == 0) {
            _zoomLevel = DEFAULT_ZOOM;
        }
    }
    
    return _zoomLevel;
}

- (NSUInteger)fontSize
{
    /*
    if (_fontSize == 0) {
        _fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:FONTSIZE_KEY];
        if (_fontSize == 0) {
            _fontSize = _documentWidth * FONT_SIZE_MODIFIER;
        }
    }
    */
    _fontSize = _zoomLevel * FONT_SIZE_MODIFIER * ZOOM_MODIFIER;
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

- (IBAction)clearSceneNumbers:(id)sender
{
	// Backup text
	NSString *rawText = [self.getText copy];
	
	// Regex for scene testing
	NSString * pattern = @"^(([iI][nN][tT]|[eE][xX][tT]|[^\\w][eE][sS][tT]|\\.|[iI]\\.?\\[eE]\\.?)).+";
	NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
	
	NSError *error = nil;
	NSRegularExpression *sceneNumberPattern = [NSRegularExpression regularExpressionWithPattern: @" (\\#([0-9A-Za-z\\.\\)-]+)\\#)" options: NSRegularExpressionCaseInsensitive error: &error];
	
	NSArray *lines = [self.getText componentsSeparatedByString:@"\n"];
	NSString *fullText = @"";
	
	for (__strong NSString *rawLine in lines) {
		NSString *cleanedLine = [rawLine stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		// Test if this is a scene header
		if ([test evaluateWithObject: cleanedLine]) {
			// Remove scene numbers
			cleanedLine = [sceneNumberPattern stringByReplacingMatchesInString:rawLine options:0 range:NSMakeRange(0, [rawLine length]) withTemplate:@""];
			
			// Make scene heading strings
			NSString *newLine = [NSString stringWithFormat:@"%@", cleanedLine];
			
			fullText = [NSString stringWithFormat:@"%@%@\n", fullText, newLine];
		} else {
			fullText = [NSString stringWithFormat:@"%@%@\n", fullText, cleanedLine];
		}
	}
	
	[self setText:fullText];
	
	[self textDidChange:[NSNotification notificationWithName:@"" object:nil]];
	self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
	[self applyFormatChanges];
	
	[[[self undoManager] prepareWithInvocationTarget:self] undoSceneNumbering:rawText];
}

- (IBAction)sceneNumbering:(id)sender
{
	// Backup text
	NSString *rawText = [self.getText copy];
	
	// Regex for scene testing
	NSString * pattern = @"^(([iI][nN][tT]|[eE][xX][tT]|[^\\w][eE][sS][tT]|\\.|[iI]\\.?\\[eE]\\.?)).+";
	NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
	
	NSString *sceneNumberPattern = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPattern];
	
	NSUInteger sceneCount = 1; // Track scene amount
	
	NSArray *lines = [self.getText componentsSeparatedByString:@"\n"];
	NSString *fullText = @"";
	
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
	
	[self setText:fullText];
	[self textDidChange:[NSNotification notificationWithName:@"" object:nil]];
	self.parser = [[ContinousFountainParser alloc] initWithString:[self getText]];
	[self applyFormatChanges];
	
	
	[[[self undoManager] prepareWithInvocationTarget:self] undoSceneNumbering:rawText];
}

/* Uh... yeah. I couldn't figure out how to make this a separate method, so here we go again */
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
    }
}

// WIP
-(void)updateSizes:(id)sender
{
    
}

/*
 
Zooming in / out

This no longer just adjusts font size, but rather the zoom level, and the 
font size is calculated as a percentage of the width. This is a dirty and quirky
approach, but seems to work fine at larger zoom levels. Page layout insets and
margins are also defined as percentages (ie. CHARACTER_INDENT_P 0.36), and
the calculation is as follows: 

Zoom level * zoom modifier * element size

*/

- (IBAction)increaseFontSize:(id)sender
{
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


#pragma mark - User Interaction

#define TREE_VIEW_WIDTH 350

- (IBAction)toggleOutlineView:(id)sender
{
    self.outlineViewVisible = !self.outlineViewVisible;
    
    if (self.outlineViewVisible) {
		//[self.outlineButton setTranslatesAutoresizingMaskIntoConstraints:true];
		
		[self reloadOutline];
		
		[self.outlineView expandItem:nil expandChildren:true];
		
        [self.outlineViewWidth.animator setConstant:TREE_VIEW_WIDTH];
        NSWindow *window = self.windowControllers[0].window;
        NSRect newFrame = NSMakeRect(window.frame.origin.x,
                                     window.frame.origin.y,
                                     window.frame.size.width + TREE_VIEW_WIDTH + 20,
                                     window.frame.size.height);
        [window.animator setFrame:newFrame display:YES];
		
		CGRect buttonFrame = self.outlineButton.frame;
		buttonFrame.origin.x = TREE_VIEW_WIDTH + 15;
		[self.outlineButton.animator setFrame:buttonFrame];

    } else {
		CGRect buttonFrame = self.outlineButton.frame;
		buttonFrame.origin.x = 15;
		[self.outlineButton.animator setFrame:buttonFrame];
		
        [self.outlineViewWidth.animator setConstant:0];
        NSWindow *window = self.windowControllers[0].window;
        NSRect newFrame = NSMakeRect(window.frame.origin.x - 20,
                                     window.frame.origin.y,
                                     window.frame.size.width - TREE_VIEW_WIDTH - 50,
                                     window.frame.size.height);
        [window.animator setFrame:newFrame display:YES];
    }
}

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}

- (IBAction)themes:(id)sender {}

- (IBAction)zoom:(id)sender {}

- (IBAction)export:(id)sender {}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
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
    } else if ([menuItem.title isEqualToString:@"Theme"]) {
		// Deprecated
		/*
        [menuItem.submenu removeAllItems];
        
        NSUInteger selectedTheme = [self.themeManager selectedTheme];
        NSUInteger count = [self.themeManager numberOfThemes];
        for (int i = 0; i < count; i++) {
            NSString *themeName = [self.themeManager nameForThemeAtIndex:i];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:themeName action:@selector(selectTheme:) keyEquivalent:@""];
            if (i == selectedTheme) {
                [item setState:NSOnState];
            }
            [menuItem.submenu addItem:item];
        }
		 */
        if ([self selectedTabViewTab] == 1) {
            return NO;
        }
    } else if ([menuItem.title isEqualToString:@"Automatically Match Parentheses"]) {
        if (self.matchParentheses) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        if ([self selectedTabViewTab] == 1) {
            return NO;
        }
	} else if ([menuItem.title isEqualToString:@"Print Automatic Scene Numbers"]) {
		if (self.printSceneNumbers) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
		if ([self selectedTabViewTab] == 1) {
			return NO;
		}
    } else if ([menuItem.title isEqualToString:@"Live Preview"]) {
        if (self.livePreview) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        if ([self selectedTabViewTab] == 1) {
            return NO;
        }
    } else if ([menuItem.title isEqualToString:@"Show Outline"]) {
        if (self.outlineViewVisible) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        if ([self selectedTabViewTab] == 1) {
            return NO;
        }
	} else if ([menuItem.title isEqualToString:@"Night Mode"]) {
		if (self.nightMode) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
		if ([self selectedTabViewTab] == 1) {
			return NO;
		}
    } else if ([menuItem.title isEqualToString:@"Zoom In"] || [menuItem.title isEqualToString:@"Zoom Out"] || [menuItem.title isEqualToString:@"Reset Zoom"]) {
        if ([self selectedTabViewTab] == 1) {
            return NO;
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
		
        //Disable everything in the toolbar except print and preview and pdf
        for (NSButton *button in self.toolbarButtons) {
            if (button != _printToolbarButton && button != _previewToolbarButton) {
                button.enabled = NO;
            }
        }
        
    } else {
        [self setSelectedTabViewTab:0];
		_printPreview = NO;
		
        //Enable everything in the toolbar except print and preview and pdf
        for (NSButton *button in self.toolbarButtons) {
            if (button != _printToolbarButton && button != _previewToolbarButton) {
                button.enabled = YES;
            }
        }
    }
	[self updateSceneNumberLabels];
}
- (void)cancelOperation:(id) sender
{
	if (_printPreview) {
		[self preview:nil];
	}
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
		NSUInteger childIndex = [[self.parser outline] indexOfObject:item];
		OutlineScene *outlineSection = [[self.parser outline] objectAtIndex:childIndex];
		return [outlineSection.scenes objectAtIndex:index];
	 
		//return nil;
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
				NSString *sceneHeader = [NSString stringWithFormat:@"    %@:", line.sceneNumber];
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
			NSColor *colorName = nil;

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
	/*
    if ([item isKindOfClass:[Line class]]) {
        Line* line = item;
        NSRange lineRange = NSMakeRange(line.position, line.string.length);
        [self.textView setSelectedRange:lineRange];
        [self.textView scrollRangeToVisible:lineRange];
        return YES;
    }
    return NO;
	*/
	
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

/*
 
 Outline context menu, WIP.
 
 To make this work reliably, we should check for a lot of stuff, such as if there already is a color or some other note on the heading line. I don't have the willpower to do it just now, but maybe someday.
 
 The thing is, after this is done, we can also filter the outline view according to color tags. One thing to consider is also if we want to have multiple color tags on lines? I kind of hate that usually, especially if it's done badly, but in many cases it should be useful.

Regexes hurt my brain, and they do so extra much in Objective-C, so maybe I'll just search for ranges whenever I decide to do this.
 
 In principle it should be possible that to enter custom colors in hex. Such as [[COLOR #d00dd]].
 
*/
- (void) menuNeedsUpdate:(NSMenu *)menu {
	NSInteger clickedRow = [self.outlineView clickedRow];

	id item = nil;
	item = [self.outlineView itemAtRow:clickedRow];
	
	if (item != nil && [item isKindOfClass:[OutlineScene class]]) {
		// Show context menu
		for (NSMenuItem * menuItem in menu.itemArray) {
			// menuItem.hidden = NO;
			// But let's hide this context menu for now as it's WIP
			menuItem.hidden = YES;
		}

	} else {
		// Hide every item
		for (NSMenuItem * menuItem in menu.itemArray) {
			menuItem.hidden = YES;
		}
	}
}

- (IBAction) setRedColor:(id) sender {
	NSLog(@"Color red");
	[self setColor:@"RED"];
}

- (void) setColor:(NSString *) color {
	id item = [self.outlineView itemAtRow:[self.outlineView clickedRow]];
	if (item != nil && [item isKindOfClass:[OutlineScene class]]) {
		NSString * colorString = [NSString stringWithFormat:@" [[COLOR %@]]", color];
		NSUInteger position = [[item line] position] + [[item line].string length];
		[self addString:colorString atIndex:position];
	}
}

#pragma  mark - Scene numbering for NSTextView

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
		rect.origin.x = self.textView.textContainerInset.width - 2 * ZOOM_MODIFIER;
		rect.size.width = 10 * [scene.sceneNumber length];
	}
	
	[label setBezeled:NO];
	[label setSelectable:NO];
	[label setDrawsBackground:NO];
	[label setFont:self.courier];
	[self.textView addSubview:label];
	
	[self.sceneNumberLabels addObject:label];
	return label;
}

// This kind of works but might make things a bit slow. I'm not sure. There are CPU spikes on scroll at times, but debouncing the calls to update didn't work as scrolling might end during the debounce cooldown.
// Send help.
- (void) updateSceneNumberLabels {
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
			NSTextField * label = [self.sceneNumberLabels objectAtIndex:index];
			
			label = [self.sceneNumberLabels objectAtIndex:index];
			if (scene.sceneNumber) { [label setStringValue:scene.sceneNumber]; }
						
			NSRange characterRange = NSMakeRange([scene.line position], [scene.line.string length]);
			NSRange range = [[self.textView layoutManager] glyphRangeForCharacterRange:characterRange actualCharacterRange:nil];
			NSRect rect = [[self.textView layoutManager] boundingRectForGlyphRange:range inTextContainer:[self.textView textContainer]];
			
			rect.origin.x = self.textView.textContainerInset.width - 2 * ZOOM_MODIFIER;
			rect.size.width = 1.5 * ZOOM_MODIFIER * [scene.sceneNumber length];
			
			rect.origin.y += TEXT_INSET_TOP;
			label.frame = rect;
				
		
			index++;
		}

		// Remove unused labels from the end of the array.
		if (difference < 0) {
			for (NSInteger d = 0; d > difference; d--) {
				NSTextField * label = [self.sceneNumberLabels objectAtIndex:[self.sceneNumberLabels count] - 1];
				
				//[label performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
				[self.sceneNumberLabels removeObject:label];
				[label removeFromSuperview];
				
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

/* Listen to scrolling of the view */
- (void)boundsDidChange:(NSNotification*)notification {
	[self updateSceneNumberLabels];
}
@end