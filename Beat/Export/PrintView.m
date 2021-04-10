//
//  PrintView.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Parts copyright © 2016 Hendrik Noeller. All rights reserved.

//

/*
 
 Note: This class still uses the now DEPRECATED WebKit view.

 It can take in either a Document class which acts as a delegate, and
 then also takes care of HTML conversion etc., or alternatively
 the HTML can be created beforehand. In that case, make sure the conversion
 is done using correct paper size to avoid clipping / spilling
 
 Operations:
 BeatToPDF -> export PDF file with save as... prompt
 BeatToPreview -> temporary PDF, URL sent to delegate after finish
 BeatToPrint -> the screenplay will enter physical world through some ancient technology called "printer"

 */

#import "PrintView.h"
#import "BeatHTMLScript.h"
#import "Document.h"
#import "BeatRevisionTracking.h"

@interface PrintView () <WebFrameLoadDelegate>
@property (nonatomic) NSUInteger finishedWebViews;
@property (weak, nonatomic) Document *document;
@property (weak, nonatomic) WebView *webView;
@property bool pdf;
@property bool preview;

@property (nonatomic) NSString *string;

@property (nonatomic, copy, nullable) void (^completion)(void);

@end

@implementation PrintView

// We know the HTML already (probably we're printing a series)
- (id)initWithDocument:(Document*)document script:(NSArray*)lines operation:(BeatPrintOperation)mode compareWith:(NSString*)oldScript {
	return [self initWithDocument:document script:lines operation:mode compareWith:oldScript delegate:nil];
}
- (id)initWithHTML:(NSString*)htmlString document:(NSDocument*)document operation:(BeatPrintOperation)mode {
	return [self initWithHTML:htmlString document:document operation:mode completion:nil];
}
- (id)initWithHTML:(NSString *)htmlString document:(NSDocument *)document operation:(BeatPrintOperation)mode completion:(void (^)(void))completion {
	self = [super init];
	if (mode == BeatToPDF) self.pdf = YES;
	
	if (self) {
		if (htmlString.length) {
			_finishedWebViews = 0;
			_document = (Document*)document;
			_completion = completion;
			[self printHTML:htmlString];
		}
	}
	
	return self;
}

- (id)initWithDocument:(Document*)document script:(NSArray*)lines operation:(BeatPrintOperation)mode compareWith:(NSString*)oldScript delegate:(id<PrintViewDelegate>)delegate {
	self = [super init];

	self.delegate = delegate;
	
	if (mode == BeatToPDF) self.pdf = YES;
	else if (mode == BeatToPreview) {
		self.preview = YES; // Preview returns a temporary pdf file to the delegate
		self.pdf = YES;
	}

	if (self) {
		_finishedWebViews = 0;
		_document = document;
		
		// NOTE: Lines can be nil, in which case this returns the text from delegate/document
		NSString *rawText = [self getRawTextFor:lines];
		NSString *htmlString = [self createPrint:rawText document:document compareWith:oldScript header:(delegate.header) ? delegate.header : @""];
		
		[self printHTML:htmlString];
	}
	
	return self;
}

- (NSString*)getRawTextFor:(NSArray*)lines {
	NSMutableString *rawText = [NSMutableString string];
	
	if (lines.count) {
		rawText = [NSMutableString string];
		for (Line* line in lines) {
			[rawText appendFormat:@"%@\n", line.string];
		}
	} else {
		if (_document) rawText = [NSMutableString stringWithString:[_document getText]];
	}
	return rawText;
}

- (void)printHTML:(NSString*)htmlString {
	WebView *pageWebView = [[WebView alloc] init];
	pageWebView.frameLoadDelegate = self;
	pageWebView.mainFrame.frameView.allowsScrolling = NO;
	[self addSubview:pageWebView];
	
	_webView = pageWebView;
	
	[pageWebView.mainFrame loadHTMLString:htmlString baseURL:nil];
}

- (NSString*) createPrint:(NSString*)rawText document:(Document*)document compareWith:(NSString*)oldScript header:(NSString*)header {
	// Parse the input again
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:rawText delegate:document];

	// Track revisions
	[BeatRevisionTracking bakeRevisionsIntoLines:parser.lines text:document.attrTextCache parser:parser];
	
	// See if we want to compare it with something
	// BeatComparison marks the Line objects as changed
	if (oldScript) {
		BeatComparison *comparison = [[BeatComparison alloc] init];
		[comparison compare:parser.lines with:oldScript];
	}
	
	// Set script data
	NSMutableDictionary *script = [NSMutableDictionary dictionaryWithDictionary:@{
		@"script": [parser preprocessForPrinting],
		@"title page": parser.titlePage
	}];

	// Set header if sent
	if (header.length) [script setValue:header forKey:@"header"];
	
	BeatHTMLScript *html = [[BeatHTMLScript alloc] initForPrint:script document:document printSceneNumbers:document.printSceneNumbers];
	return html.html;
}

#pragma mark - Actual printing

- (BOOL)knowsPageRange:(NSRangePointer)range
{
	range->location = 0;
	range->length = [self.subviews count] + 1;
	return YES;
}

- (NSRect)rectForPage:(NSInteger)page
{
	NSView *subview = self.subviews[page - 1];
	return subview.frame;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	self.finishedWebViews = self.finishedWebViews + 1;
	
	if (self.finishedWebViews == self.subviews.count) {
		[self display];
		
		// Print
		if (!self.pdf) {
			[self printDocument];
		}
		// Export PDF
		else {
			if (_preview) {
				[self createTemporaryPDF];
			} else {
				[self savePDF];
			}
		}
	}
}

- (void)savePDF {
	NSSavePanel *saveDialog = [NSSavePanel savePanel];
	[saveDialog setAllowedFileTypes:@[@"pdf"]];
	
	// Default filename when printing a single document
	if ([self.document isKindOfClass:Document.class]) [saveDialog setNameFieldStringValue:self.document.fileNameString];
	else [saveDialog setNameFieldStringValue:@"Untitled"];
	
	// Display sheet for documents, normal modal for other cases
	if (self.document.windowControllers.count) {
		[saveDialog beginSheetModalForWindow:self.document.windowControllers[0].window completionHandler:^(NSInteger result) {
			if (result == NSFileHandlingPanelOKButton) [self exportPDftoURL:saveDialog.URL];
		}];
	} else {
		NSInteger result = [saveDialog runModal];
		if (result == NSFileHandlingPanelOKButton) [self exportPDftoURL:saveDialog.URL];
	}
}
- (void)exportPDftoURL:(NSURL*)url {
	NSPrintInfo *printInfo = [self.document.printInfo copy];
	
	[printInfo.dictionary addEntriesFromDictionary:@{
													 NSPrintJobDisposition: NSPrintSaveJob,
													 NSPrintJobSavingURL: url
													 }];

	NSPrintOperation *printOperation = [self.webView.mainFrame.frameView printOperationWithPrintInfo:printInfo];
	
	printOperation.showsPrintPanel = NO;
	printOperation.showsProgressPanel = YES;
	
	[printOperation runOperation];
	
	if (_completion) _completion();
}

- (void)printDocument {
	NSPrintInfo *printInfo = [self.document.printInfo copy];
	NSPrintOperation *printOperation = [_webView.mainFrame.frameView printOperationWithPrintInfo:printInfo];
	
	//[printOperation runOperationModalForWindow:((NSWindowController*)self.document.windowControllers[0]).window delegate:nil didRunSelector:nil contextInfo:nil];
	if (self.document.windowControllers.count) {
		[printOperation runOperationModalForWindow:((NSWindowController*)self.document.windowControllers[0]).window delegate:nil didRunSelector:nil contextInfo:nil];
	} else {
		[printOperation runOperation];
	}
	
	if (_completion) _completion();
}

- (void)createTemporaryPDF {
	NSPrintInfo *printInfo = [self.document.printInfo copy];
	
	NSURL *tempURL = [NSURL fileURLWithPath:[self pathForTemporaryFileWithPrefix:@"pdf"]];
	
	[printInfo.dictionary addEntriesFromDictionary:@{
													 NSPrintJobDisposition: NSPrintSaveJob,
													 NSPrintJobSavingURL: tempURL
													 }];
	
	NSPrintOperation *printOperation = [self.webView.mainFrame.frameView printOperationWithPrintInfo:printInfo];
	
	printOperation.showsPrintPanel = NO;
	printOperation.showsProgressPanel = YES;
	
	[printOperation runOperation];
	[self.delegate didFinishPreviewAt:tempURL];
}

- (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix
{
	NSString *  result;
	CFUUIDRef   uuid;
	CFStringRef uuidStr;

	uuid = CFUUIDCreate(NULL);
	assert(uuid != NULL);

	uuidStr = CFUUIDCreateString(NULL, uuid);
	assert(uuidStr != NULL);

	result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuidStr]];
	assert(result != nil);

	CFRelease(uuidStr);
	CFRelease(uuid);

	return result;
}

@end
