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
#import "FNScript.h"
#import "FNPaginator.h"
#import "FNHTMLScript.h"
#import "FNElement.h"
@interface PrintView () <WebFrameLoadDelegate>
@property (nonatomic) NSUInteger finishedWebViews;
@property (weak, nonatomic) Document *document;
@property (weak, nonatomic) WebView *webView;
@property bool pdf;
@end
@implementation PrintView

- (id)initWithDocument:(Document*)document toPDF:(bool)pdf toPrint:(bool)print
{
	self = [super init];
	self.pdf = pdf;
	if (self) {
		
		_finishedWebViews = 0;
		_document = document;
		
		//Create a script from the Document
		FNScript *script = [[FNScript alloc] initWithString:document.preprocessedText];
		FNHTMLScript *htmlScript = [[FNHTMLScript alloc] initWithScript:script document:document print:true];
		htmlScript.forRendering = @YES;
		
		CGSize paperSize = CGSizeMake(document.printInfo.paperSize.width, document.printInfo.paperSize.height);
		
		WebView *pageWebView = [[WebView alloc] init];
		pageWebView.frameLoadDelegate = self;
		pageWebView.mainFrame.frameView.allowsScrolling = NO;
		[self addSubview:pageWebView];
		
		_webView = pageWebView;
		
		[pageWebView.mainFrame loadHTMLString:[htmlScript html] baseURL:nil];
		//pageWebView.frame = NSMakeRect(0, 0, paperSize.width, [htmlScript pages] * paperSize.height);
		
		self.frame = CGRectMake(0, 0, paperSize.width, [htmlScript pages] * paperSize.height);
	}
	return self;
}

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
					NSPrintOperation *printOperation = [_webView.mainFrame.frameView printOperationWithPrintInfo:printInfo];
					
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


@end
