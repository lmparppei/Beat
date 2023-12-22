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

#import <BeatParsing/BeatParsing.h>
#import <PDFKit/PDFKit.h>
#import <Webkit/Webkit.h>
#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2.h>

#import "BeatPrintView.h"
#import "BeatHTMLRenderer.h"
#import "Beat-Swift.h"
//#import "Document.h"

#define WEBKIT true

@interface BeatPrintView () <WKNavigationDelegate>
@property (nonatomic) NSUInteger finishedWebViews;
@property (weak, nonatomic) WKWebView* webView;
@property (nonatomic) BeatExportSettings *settings;

@property bool pdf;
@property bool preview;

@property (nonatomic) NSString *string;

@property (nonatomic, copy, nullable) void (^completion)(void);

@end

@implementation BeatPrintView

static NSURL *pdfURL;

- (id)initWithScript:(NSArray*)lines operation:(BeatPrintOperation)mode settings:(BeatExportSettings*)settings delegate:(id<PrintViewDelegate>)delegate {
	self = [super init];
		
	if (self) {
		if (delegate) self.delegate = delegate;
		self.settings = settings;
		
		// See if we are creating a PDF, and if it's a temporary preview
		self.pdf = (mode == BeatToPDF || mode == BeatToPreview) ? YES : NO;
		self.preview = (mode == BeatToPreview) ? YES : NO;
		
		_finishedWebViews = 0;
		
		NSString *rawText = [self getRawTextFor:lines];
		NSString *htmlString = [self createPrint:rawText settings:settings];
				
		[self printHTML:htmlString];
	}
	
	return self;
}


- (NSString*)getRawTextFor:(NSArray*)lines {
	NSMutableString *rawText = NSMutableString.new;
	
	if (lines.count) {
		rawText = [NSMutableString string];
		for (Line* line in lines) {
			[rawText appendFormat:@"%@\n", line.string];
		}
	}
	
	return rawText;
}

- (void)printHTML:(NSString*)htmlString {
	WKWebView* webView;
	
	webView = WKWebView.new;
	webView.navigationDelegate = self;
	webView.allowsLinkPreview = false;

	[webView loadHTMLString:htmlString baseURL:NSBundle.mainBundle.resourceURL];
	webView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
	
	
	// Set web view size
	CGSize size = (self.settings.paperSize == BeatA4) ? BeatPaperSizing.a4 : BeatPaperSizing.usLetter;
	webView.frame = CGRectMake(0, 0, size.width, size.height);

	[self addSubview:webView];
	self.webView = webView;
}

- (NSString*)createPrint:(NSString*)rawText settings:(BeatExportSettings*)settings {
	
	if (!settings) {
		NSLog(@"NO SETTINGS FOUND WHEN PRINTING.");
		return nil;
	}

	// Parse the input again
	ContinuousFountainParser *parser = [[ContinuousFountainParser alloc] initWithString:rawText delegate:(id<ContinuousFountainParserDelegate>)self.delegate.editorDelegate];

	// Track revisions
	[BeatRevisions bakeRevisionsIntoLines:parser.lines text:self.delegate.editorDelegate.attrTextCache includeRevisions:settings.revisions];
	
	// Set script data
	settings.operation = ForPrint;
	BeatScreenplay *screenplay = [BeatScreenplay from:parser settings:settings];
	
	// For empty documents, return empty HTML document
	if (screenplay.lines.count == 0 && screenplay.titlePage.count == 0) return @"<html></html>";
	
	BeatPaginationManager* pm = [BeatPaginationManager.alloc initWithSettings:settings delegate:nil renderer:nil livePagination:false];
	[pm newPaginationWithScreenplay:screenplay settings:settings forEditor:false changeAt:0];
	
	BeatHTMLRenderer* renderer = [BeatHTMLRenderer.alloc initWithPagination:pm.finishedPagination settings:settings];
	return renderer.html;
}

#pragma mark - Actual printing

- (BOOL)knowsPageRange:(NSRangePointer)range
{
	// Never called?
	range->location = 0;
	range->length = self.subviews.count + 1;
	return YES;
}

- (CGRect)rectForPage:(NSInteger)page
{
	// Never called?
	UIView *subview = self.subviews[page - 1];
	return subview.frame;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	// Delegate method for modern WKWebView
	self.finishedWebViews = self.finishedWebViews + 1;
	
	if (self.finishedWebViews == self.subviews.count) {
		[self setNeedsDisplay];
				
		if (_preview) {
			[self exportPDFforPreview:true];
		} else {
			[self exportPDF];
		}
	}
}

- (void)exportPDF {
	[self exportPDFforPreview:false];
}

- (void)exportPDFforPreview:(bool)preview {
	UIPrintPageRenderer* renderer = UIPrintPageRenderer.new;
	
	CGFloat topPadding = 25.0f;
	CGFloat bottomPadding = 10.0f;
	CGFloat leftPadding = 25.0f;
	CGFloat rightPadding = 10.0f;
	
	CGSize size = (self.settings.paperSize == BeatA4) ? BeatPaperSizing.a4 : BeatPaperSizing.usLetter;
	
	CGRect printableRect = CGRectMake(leftPadding,
									  topPadding,
									  size.width - leftPadding - rightPadding,
									  size.height - topPadding - bottomPadding);
	
	CGRect paperRect = CGRectMake(0, 0, size.width, size.height);
	[renderer setValue:[NSValue valueWithCGRect:paperRect] forKey:@"paperRect"];
	[renderer setValue:[NSValue valueWithCGRect:printableRect] forKey:@"printableRect"];
	
	[renderer addPrintFormatter:_webView.viewPrintFormatter startingAtPageAtIndex:0];

	
	NSData* data = [renderer printToPDF];
	PDFDocument* pdf = [PDFDocument.alloc initWithData:data];
	
	@try {
		NSString* fileName = self.delegate.editorDelegate.fileNameString;
		
		NSURL* url = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
		NSURL* fileURL = [[url URLByAppendingPathComponent:fileName] URLByAppendingPathExtension:@"pdf"];
		[pdf writeToURL:fileURL];
		
		if ([NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) {
			[self.delegate didExportFileAt:fileURL];
		}
		
	} @catch (NSException *exception) {
		NSLog(@"writeToURL error: %@", exception);
	}
}

- (void)printOperationDidRun:(id)operation success:(bool)success contextInfo:(nullable void *)contextInfo {
	// Remove WKWebView from memory
	[self deinitWebView];

	// Remove this print view from queue
	if (_preview) [self.delegate didFinishPreviewAt:pdfURL];
	if (_completion != nil) _completion();

	// We need to manually remove the print view from queue here
	[self.delegate.printViews removeObject:self];
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
