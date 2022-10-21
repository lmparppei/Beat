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

 This class still supports both legacy WebView and WKWebView to maintain
 backwards compatibility with macOS <11.0.
 
 */

#import "BeatPrintView.h"
#import "BeatHTMLScript.h"
#import "Document.h"
#import "BeatRevisions.h"
#import "BeatExportSettings.h"
#import <PDFKit/PDFKit.h>
#import <Webkit/Webkit.h>

#define WEBKIT true

@interface BeatPrintView () <WebFrameLoadDelegate, WKNavigationDelegate>
@property (nonatomic) NSUInteger finishedWebViews;
@property (weak, nonatomic) Document *document;
@property (weak, nonatomic) id webView;
@property (nonatomic) BeatExportSettings *settings;
@property (nonatomic) NSPrintInfo *printInfo;
@property bool pdf;
@property bool preview;

@property (nonatomic) NSString *string;

@property (nonatomic, copy, nullable) void (^completion)(void);

@end

@implementation BeatPrintView

static NSURL *pdfURL;

- (id)initWithDocument:(Document*)document script:(NSArray*)lines operation:(BeatPrintOperation)mode settings:(BeatExportSettings*)settings delegate:(id<PrintViewDelegate>)delegate {
	self = [super init];
		
	if (self) {
		if (delegate) self.delegate = delegate;
		
		// See if we are creating a PDF, and if it's a temporary preview
		self.pdf = (mode == BeatToPDF || mode == BeatToPreview) ? YES : NO;
		self.preview = (mode == BeatToPreview) ? YES : NO;
				
		_finishedWebViews = 0;
		_document = document;
		_printInfo = document.printInfo.copy;
		
		// NOTE: Lines can be nil, in which case this returns the text from delegate/document
		// Later we bake revisions into the text
		NSString *rawText = [self getRawTextFor:lines];
		NSString *htmlString = [self createPrint:rawText settings:settings];
		
		[self printHTML:htmlString];
	}
	
	return self;
}

- (id)initWithHTML:(NSString*)htmlString settings:(BeatExportSettings*)settings operation:(BeatPrintOperation)mode completion:(void (^)(void))completion {
	self = [super init];
	
	if (self) {
		if (mode == BeatToPDF) self.pdf = YES;
		
		_finishedWebViews = 0;
		_document = (Document*)settings.document;
		_printInfo = _document.printInfo.copy;
		_completion = completion;
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
		if (_document) rawText = [NSMutableString stringWithString:_document.text];
	}
	return rawText;
}

- (void)printHTML:(NSString*)htmlString {
	id webView;
	
	if (@available(macOS 11.0, *)) {
		webView = WKWebView.new;
		((WKWebView*)webView).navigationDelegate = self;
		[(WKWebView*)webView loadHTMLString:htmlString baseURL:NSBundle.mainBundle.resourceURL];
		
		((WKWebView*)webView).configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
	}
	else {
		webView = WebView.new;
		((WebView*)webView).frameLoadDelegate = self;
		((WebView*)webView).mainFrame.frameView.allowsScrolling = NO;
		[((WebView*)webView).mainFrame loadHTMLString:htmlString baseURL:NSBundle.mainBundle.resourceURL];
	}
	
	[self addSubview:webView];
	self.webView = webView;
}

- (NSString*)createPrint:(NSString*)rawText settings:(BeatExportSettings*)settings {
	Document *document = (Document*)settings.document;
	
	// Parse the input again
	ContinuousFountainParser *parser = [[ContinuousFountainParser alloc] initWithString:rawText delegate:document];

	// Track revisions
	[BeatRevisions bakeRevisionsIntoLines:parser.lines text:document.attrTextCache includeRevisions:settings.revisions];
	
	// Set script data
	BeatScreenplay *script = [BeatScreenplay from:parser settings:settings];

	// This is a silly fix for when no printer is installed on macOS
	if ([_printInfo.printer.name isEqualToString:@" "]) {
		_printInfo.topMargin = 12.5;
		//settings.customCSS = [settings.customCSS stringByAppendingString:@"body { zoom: 95%; } section { padding-top: 1cm !important; }"];
	}
	
	if (!settings) {
		NSLog(@"NO SETTINGS FOUND WHEN PRINTING.");
		return nil;
	}
	
	// For empty documents, return empty HTML document
	if (script.lines.count == 0 && script.titlePage.count == 0) return @"<html></html>";
	
	BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script settings:settings];
	return html.html;
}

#pragma mark - Actual printing

- (BOOL)knowsPageRange:(NSRangePointer)range
{
	// Never called?
	range->location = 0;
	range->length = self.subviews.count + 1;
	return YES;
}

- (NSRect)rectForPage:(NSInteger)page
{
	// Never called?
	NSView *subview = self.subviews[page - 1];
	return subview.frame;
}

- (void)webView:(id)sender didFinishLoadForFrame:(WebFrame *)frame {
	NSLog(@" 			web view did finish");
	
	// Delegate method for legacy WebView
	self.finishedWebViews = self.finishedWebViews + 1;
	
	if (self.finishedWebViews == self.subviews.count) {
		[self display];
				
		// Print
		if (!self.pdf) [self printDocument];
		// Export PDF
		else {
			if (_preview) {
				NSURL *tempURL = [NSURL fileURLWithPath:[self pathForTemporaryFileWithPrefix:@"pdf"]];
				[self exportPDFtoURL:tempURL forPreview:YES];
			} else {
				[self savePDF];
			}
		}
	}
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	// Delegate method for modern WKWebView
	self.finishedWebViews = self.finishedWebViews + 1;
	
	if (self.finishedWebViews == self.subviews.count) {
		[self display];
				
		// Print
		if (!self.pdf) [self printDocument];
		// Export PDF
		else {
			if (_preview) {
				NSURL *tempURL = [NSURL fileURLWithPath:[self pathForTemporaryFileWithPrefix:@"pdf"]];
				[self exportPDFtoURL:tempURL forPreview:YES];
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
			if (result == NSModalResponseOK) [self exportPDFtoURL:saveDialog.URL];
		}];
	} else {
		NSInteger result = [saveDialog runModal];
		if (result == NSModalResponseOK) [self exportPDFtoURL:saveDialog.URL];
	}
}

- (void)printDocument {
	NSPrintInfo *printInfo = [self.document.printInfo copy];
	printInfo.verticalPagination = NSFitPagination;
	printInfo.horizontalPagination = NSFitPagination;
	
	NSPrintOperation *printOperation;
	
	if (@available(macOS 11.0, *)) {
		printOperation = [(WKWebView*)_webView printOperationWithPrintInfo:printInfo];
		printOperation.view.frame = NSMakeRect(0,0, printInfo.paperSize.width, printInfo.paperSize.height);
	} else {
		printOperation = [((WebView*)_webView).mainFrame.frameView printOperationWithPrintInfo:printInfo];
	}
	
	printOperation.showsPrintPanel = YES;
	
	if (self.document.windowControllers.count) {
		[printOperation runOperationModalForWindow:self.document.documentWindow delegate:nil didRunSelector:nil contextInfo:nil];
	} else {
		[printOperation runOperation];
	}
	
	if (_completion) _completion();
}

- (void)exportPDFtoURL:(NSURL*)url {
	[self exportPDFtoURL:url forPreview:NO];
}

- (void)exportPDFtoURL:(NSURL*)url forPreview:(bool)preview {
	// Save the url for asynchronous operation
	pdfURL = url;
	
	NSPrintInfo *printInfo = self.document.printInfo.copy;
	printInfo.verticalPagination = NSFitPagination;
	printInfo.horizontalPagination = NSClipPagination;
	[printInfo.dictionary addEntriesFromDictionary:@{
													 NSPrintJobDisposition: NSPrintSaveJob,
													 NSPrintJobSavingURL: url
													 }];
	
	NSPrintOperation *printOperation;
		
	if (@available(macOS 11.0, *)) {
		printOperation = [(WKWebView*)_webView printOperationWithPrintInfo:printInfo];
		printOperation.view.frame = NSMakeRect(0,0, printInfo.paperSize.width, printInfo.paperSize.height);
	} else {
		printOperation = [((WebView*)_webView).mainFrame.frameView printOperationWithPrintInfo:printInfo];
	}

	printOperation.showsPrintPanel = NO;
	printOperation.showsProgressPanel = YES;
	
	// Support for both WebView (legacy) and WKWebView (modern systems)
	if (@available(macOS 11.0, *)) {
		// Modern webkit runs asynchronously
		[printOperation runOperationModalForWindow:self.window delegate:self didRunSelector:@selector(printOperationDidRun:success:contextInfo:) contextInfo:nil];
	} else {
		// Legacy WebKit runs in sync
		[printOperation runOperation];
		if (preview) [self.delegate didFinishPreviewAt:url];
		if (_completion) _completion();
		[self.document.printViews removeObject:self];
	}
}

- (void)printOperationDidRun:(id)operation success:(bool)success contextInfo:(nullable void *)contextInfo {
	// Remove WKWebView from memory
	if ([_webView isKindOfClass:WKWebView.class]) [self deinitWebView];

	// Remove this print view from queue
	if (_preview) [self.delegate didFinishPreviewAt:pdfURL];
	if (_completion) _completion();

	// We need to manually remove the print view from queue here
	[self.document.printViews removeObject:self];
}

- (void)deinitWebView {
	WKWebView *webView = _webView;
	webView.navigationDelegate = nil;
	[webView.configuration.userContentController removeAllUserScripts];
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
