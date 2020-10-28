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
#import "BeatHTMLScript.h"
#import "BeatComparison.h"

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
- (id)initWithDocument:(Document*)document script:(NSArray*)lines operation:(BeatPrintOperation)mode compareWith:(NSString*)oldScript delegate:(id<PrintViewDelegate>)delegate {
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
		
		NSString *htmlString = [self createPrint:rawText document:document compareWith:oldScript header:delegate.header];
		
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

- (NSString*) createPrint:(NSString*)rawText document:(Document*)document compareWith:(NSString*)oldScript header:(NSString*)header {
	// Should we show scene numbers?
	bool sceneNumbering = document.printSceneNumbers;
	
	// Parse the input again
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:rawText];
	NSMutableDictionary *script = [NSMutableDictionary dictionaryWithDictionary:@{
		@"script": [NSMutableArray array],
		@"title page": [NSMutableArray array]
	}];
		
	NSMutableArray *elements = [NSMutableArray array];

	// See if we want to compare it with something
	// BeatComparison marks the Line objects as changed
	if (oldScript) {
		BeatComparison *comparison = [[BeatComparison alloc] init];
		[comparison compare:parser.lines with:oldScript];
	}
	
	Line *previousLine;
	
	NSInteger sceneNumber = 1;
	
	for (Line *line in parser.lines) {
		// Skip over certain elements
		if (line.type == synopse || line.type == section || line.omited || [line isTitlePage]) {
			if (line.type == empty) previousLine = line;
			continue;
		}
		
		if (line.type == heading && sceneNumbering) {
			// If scene numbering is ON, let's strip forced numbers and set correct numbers to the line objects
			if (line.sceneNumberRange.length > 0) {
				line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
				line.string = line.stripSceneNumber;
			} else {
				line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
				line.string = line.stripSceneNumber;
				sceneNumber += 1;
			}
		}
		
		// This is a paragraph with a line break,
		// so append the line to the previous one
		
		// NOTE: This should be changed so that there is a possibility of having no-margin elements
		// Just needs some parser-level work.
		// Later me: no idea what that person was going on about? Care to elaborate?
		
		if (line.type == action && line.isSplitParagraph && [parser.lines indexOfObject:line] > 0) {
			Line *previousLine = [elements objectAtIndex:elements.count - 1];

			previousLine.string = [previousLine.string stringByAppendingFormat:@"\n%@", line.string];
			continue;
		}
		
		if (line.type == dialogue && line.string.length < 1) {
			line.type = empty;
			previousLine = line;
			continue;
		}

		[elements addObject:line];
				
		// If this is dual dialogue character cue,
		// we need to search for the previous one too, just in cae
		if (line.isDualDialogueElement) {
			bool previousCharacterFound = NO;
			NSInteger i = elements.count - 2; // Go for previous element
			while (i > 0) {
				Line *previousLine = [elements objectAtIndex:i];
				
				if (!(previousLine.isDialogueElement || previousLine.isDualDialogueElement)) break;
				
				if (previousLine.type == character ) {
					previousLine.nextElementIsDualDialogue = YES;
					previousCharacterFound = YES;
					break;
				}
				i--;
			}
		}
		
		previousLine = line;
	}
	
	// Set script data
	[script setValue:parser.titlePage forKey:@"title page"];
	[script setValue:elements forKey:@"script"];

	// Set header if sent
	if (header.length) [script setValue:header forKey:@"header"];
	
	BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script document:document print:YES];
	return html.html;
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
