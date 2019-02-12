//
//  PrintView.m
//  Writer
//
//  Created by Hendrik Noeller on 06.10.14.
//  Copyright (c) 2016 Hendrik Noeller. All rights reserved.

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
@property bool pdf;
@end
@implementation PrintView

- (id)initWithDocument:(Document*)document toPDF:(bool)pdf
{
    self = [super init];
    self.pdf = pdf;
    if (self) {
        
        _finishedWebViews = 0;
        _document = document;
		
        //Create a script from the Document
        FNScript *script = [[FNScript alloc] initWithString:[[document getText] copy]];
        
        //Remove the title page and put it into an extra script, if there is any title page information
        FNScript *titleScript;
        if ([script.titlePage count] > 0) {
            titleScript = [[FNScript alloc] init];
            titleScript.titlePage = script.titlePage;
            script.titlePage = @[];
        }
        
        //Paginate the script and create a script for each page
        FNPaginator *paginator = [[FNPaginator alloc] initWithScript:script document:document];
        [paginator paginate];
        
        NSMutableArray *scripts = [[NSMutableArray alloc] init];
        
        if ([paginator numberOfPages] == 0) {
            return nil;
        }
        
        for (int i = 0; i < [paginator numberOfPages]; i++) {
            FNScript *pageScript = [[FNScript alloc] init];
            pageScript.elements = [paginator pageAtIndex:i];
            //Remove any page breaks at the beginning of the pages
            while ([pageScript.elements count] > 0) {
                if ([((FNElement*)(pageScript).elements[0]).elementType isEqualToString:@"Page Break"]) {
                    NSMutableArray *mutableElements = [pageScript.elements mutableCopy];
                    [mutableElements removeObjectAtIndex:0];
                    pageScript.elements = mutableElements;
                } else {
                    break;
                }
            }
            [scripts addObject:pageScript];
        }
        
        //Add the Title Page to the beginning of the array if it exists
        if (titleScript) {
            [scripts insertObject:titleScript atIndex:0];
        }
        
        //Create HTML from each script, put it in a webView, and put the webview under the one before onto the PrintView
        CGSize paperSize = CGSizeMake(document.printInfo.paperSize.width, document.printInfo.paperSize.height);
        NSUInteger lastObjectLowerRim = 0;
        
        for (int i = 0; i < [scripts count]; i++) {
            if (titleScript && i == 0) {
                //If there is a title page and we should be putting it on the view, we go into this piece of code that creates a nice rendering without everything stuck to the top
                NSArray *titleElements = titleScript.titlePage;
                NSMutableArray *middleElements = [[NSMutableArray alloc] init];
                NSMutableArray *bottomElements = [[NSMutableArray alloc] init];
                for (NSDictionary *element in titleElements) {
                    if (element[@"title"] || element[@"authors"] || element[@"credit"] || element[@"source"]) {
                        [middleElements addObject:element];
                    } else {
                        [bottomElements addObject:element];
                    }
                }
                //We need to add an empty title, because else the second script (the one on the bottom) will print "UNTITLED". that would be not so good
                //(also, title needs to be an array for whatever reason. Probably there can not only be one. In case you are indecisive.
                
                [bottomElements addObject:@{@"title" : @[@" "]}];
                FNScript *middleScript = [[FNScript alloc] init];
                FNScript *bottomScript = [[FNScript alloc] init];
                middleScript.titlePage = middleElements;
                bottomScript.titlePage = bottomElements;
                
                WebView *middleWebView = [[WebView alloc] init];
                WebView *bottomWebView = [[WebView alloc] init];
                middleWebView.frameLoadDelegate = self;
                middleWebView.mainFrame.frameView.allowsScrolling = NO;
                bottomWebView.frameLoadDelegate = self;
                bottomWebView.mainFrame.frameView.allowsScrolling = NO;
                
                //We put the two webviews in one superview because every subview of this object will be printed as one page
                NSView *containingView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, paperSize.width, paperSize.height)];
                [containingView addSubview:middleWebView];
                [containingView addSubview:bottomWebView];
                [self addSubview:containingView];
                
                FNHTMLScript *middleHTMLScript = [[FNHTMLScript alloc] initWithScript:middleScript];
                FNHTMLScript *bottomHTMLScript = [[FNHTMLScript alloc] initWithScript:bottomScript];
                middleHTMLScript.forRendering = @YES;
                bottomHTMLScript.forRendering = @YES;
                
                [middleWebView.mainFrame loadHTMLString:middleHTMLScript.html baseURL:nil];
                [bottomWebView.mainFrame loadHTMLString:bottomHTMLScript.html baseURL:nil];
                
                NSUInteger lineHeight = 12;
                NSUInteger numberOfLinesInMiddle = ([middleElements count] * 2) - 1;
                NSUInteger numberOfLinesInBottom = 9;
                NSUInteger topInset = self.document.printInfo.topMargin;
                NSUInteger bottomInset = self.document.printInfo.bottomMargin;
                
                middleWebView.frame = NSMakeRect(0, (paperSize.height - lineHeight*numberOfLinesInMiddle + topInset) / 2, paperSize.width, lineHeight*numberOfLinesInMiddle + topInset + bottomInset);
                bottomWebView.frame = NSMakeRect(0, (lineHeight*numberOfLinesInBottom + bottomInset), paperSize.width, (lineHeight*numberOfLinesInBottom) + topInset);
                
            } else {
                FNScript *pageScript = scripts[i];
                WebView *pageWebView = [[WebView alloc] init];
                pageWebView.frameLoadDelegate = self;
                pageWebView.mainFrame.frameView.allowsScrolling = NO;
                [self addSubview:pageWebView];
                FNHTMLScript *pageHTMLScript = [[FNHTMLScript alloc] initWithScript:pageScript document:document];
                pageHTMLScript.customPage = [NSNumber numberWithInt:i];
                pageHTMLScript.forRendering = @YES;
                [pageWebView.mainFrame loadHTMLString:[pageHTMLScript html] baseURL:nil];
                pageWebView.frame = NSMakeRect(0, lastObjectLowerRim, paperSize.width, paperSize.height);
            }
            lastObjectLowerRim = lastObjectLowerRim + paperSize.height;
        }
        self.frame = CGRectMake(0, 0, paperSize.width, lastObjectLowerRim);
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
        
    }
}


@end
