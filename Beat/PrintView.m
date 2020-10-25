//
//  PrintView.m
//  Writer / Beat
//
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  Parts copyright © 2019 Lauri-Matti Parppei. All rights reserved.

//

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

#import "PrintView.h"
#import "BeatPrint.h"
	
@interface PrintView () <WebFrameLoadDelegate>
@property (nonatomic) NSUInteger finishedWebViews;
@property (weak, nonatomic) Document *document;
@property (weak, nonatomic) WebView *webView;
@property bool pdf;
@property bool preview;

@property (nonatomic) NSString *string;
@end

@implementation PrintView

- (id)initWithDocument:(Document*)document script:(NSArray*)lines operation:(BeatPrintOperation)mode compareWith:(NSString*)oldScript {
	return [self initWithDocument:document script:lines operation:mode compareWith:oldScript delegate:nil];
}
- (id)initWithDocument:(Document*)document script:(NSArray*)lines operation:(BeatPrintOperation)mode compareWith:(NSString*)oldScript delegate:(id)delegate {
	self = [super init];

	self.delegate = delegate;
		
	if (mode == BeatToPDF) self.pdf = YES;
	else if (mode == BeatToPreview) {
		self.preview = YES;
		self.pdf = YES;
	}

	if (self) {
		_finishedWebViews = 0;
		_document = document;
		
		NSMutableString *rawText;
		
		if (lines.count) {
			rawText = [NSMutableString string];
			for (Line* line in lines) {
				[rawText appendFormat:@"%@\n", line.string];
			}
		} else {
			rawText = [NSMutableString stringWithString:[document getText]];
		}
		
		NSString *htmlString = [BeatPrint createPrint:rawText document:document compareWith:oldScript];
		
		WebView *pageWebView = [[WebView alloc] init];
		pageWebView.frameLoadDelegate = self;
		pageWebView.mainFrame.frameView.allowsScrolling = NO;
		[self addSubview:pageWebView];
		
		_webView = pageWebView;
		
		[pageWebView.mainFrame loadHTMLString:htmlString baseURL:nil];

		// Why was this used in Writer?
		// self.frame = CGRectMake(0, 0, paperSize.width, [htmlScript pages] * paperSize.height);
	}
	
	return self;
}
/*
 - (id)initWithDocument:(Document*)document toPDF:(bool)pdf toPrint:(bool)print preview:(bool)preview
{
	self = [super init];
	
	self.pdf = pdf;
	self.preview = preview;
	
	if (self) {

		_finishedWebViews = 0;
		_document = document;
		
		NSString *htmlString = [BeatPrint createPrint:document.preprocessedText document:document compareWith:nil];
		
		WebView *pageWebView = [[WebView alloc] init];
		pageWebView.frameLoadDelegate = self;
		pageWebView.mainFrame.frameView.allowsScrolling = NO;
		[self addSubview:pageWebView];
		
		_webView = pageWebView;
		
		[pageWebView.mainFrame loadHTMLString:htmlString baseURL:nil];

		// Why was this used in Writer?
		// self.frame = CGRectMake(0, 0, paperSize.width, [htmlScript pages] * paperSize.height);
	}
	return self;
}
*/

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
	if (self.finishedWebViews == [self.subviews count]) {
		[self display];
		
		// Print
		if (!self.pdf) {
			NSPrintInfo *printInfo = [self.document.printInfo copy];
			NSPrintOperation *printOperation = [_webView.mainFrame.frameView printOperationWithPrintInfo:printInfo];
			//[printOperation runOperation];
			[printOperation runOperationModalForWindow:((NSWindowController*)self.document.windowControllers[0]).window delegate:nil didRunSelector:nil contextInfo:nil];
		}
		// Export PDF
		else {
			// Just export a temporary PDF
			if (_preview) {
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
				return;
			}
			
			NSSavePanel *saveDialog = [NSSavePanel savePanel];
			[saveDialog setAllowedFileTypes:@[@"pdf"]];
			[saveDialog setNameFieldStringValue:[self.document fileNameString]];
			
			[saveDialog beginSheetModalForWindow:self.document.windowControllers[0].window completionHandler:^(NSInteger result) {
				if (result == NSFileHandlingPanelOKButton) {
					NSPrintInfo *printInfo = [self.document.printInfo copy];
					
					[printInfo.dictionary addEntriesFromDictionary:@{
																	 NSPrintJobDisposition: NSPrintSaveJob,
																	 NSPrintJobSavingURL: saveDialog.URL
																	 }];
					
					//NSPrintOperation* printOperation = [NSPrintOperation printOperationWithView:self printInfo:printInfo];
					NSPrintOperation *printOperation = [self.webView.mainFrame.frameView printOperationWithPrintInfo:printInfo];
					
					printOperation.showsPrintPanel = NO;
					printOperation.showsProgressPanel = YES;
					
					[printOperation runOperation];
					
				}
			}];
			
		}
		/*
		[self display];
		if (self.pdf) {
			NSSavePanel *saveDialog = [NSSavePanel savePanel];
			[saveDialog setAllowedFileTypes:@[@"pdf"]];
			[saveDialog setNameFieldStringValue:[self.document fileNameString]];
			[saveDialog beginSheetModalForWindow:self.document.windowControllers[0].window completionHandler:^(NSInteger result) {
				if (result == NSFileHandlingPanelOKButton) {
					NSPrintInfo *printInfo = [self.document.printInfo copy];
					[printInfo.dictionary addEntriesFromDictionary:@{
																	 NSPrintJobDisposition: NSPrintSaveJob,
																	 NSPrintJobSavingURL: saveDialog.URL
																	 }];
					NSPrintOperation* printOperation = [NSPrintOperation printOperationWithView:self printInfo:printInfo];
					printOperation.showsPrintPanel = NO;
					printOperation.showsProgressPanel = YES;
					
					[printOperation runOperation];
					
				}
			}];
			
			
		} else {
			NSPrintOperation* printOperation = [NSPrintOperation printOperationWithView:self];
			printOperation.jobTitle = [[[self.document.fileURL lastPathComponent] componentsSeparatedByString:@"."] firstObject];
			[printOperation runOperationModalForWindow:((NSWindowController*)self.document.windowControllers[0]).window delegate:nil didRunSelector:nil contextInfo:nil];
			self.finishedWebViews = 0;
			self.document = nil;
		}
		 */
		
	}
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
