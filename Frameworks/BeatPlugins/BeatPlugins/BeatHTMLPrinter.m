//
//  WebPrinter.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020-2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatHTMLPrinter.h"
#import <WebKit/WebKit.h>

@interface BeatHTMLPrinter () <WebFrameLoadDelegate>
@property (nonatomic) WebView *printView;
@property (nonatomic) NSPrintInfo *printInfo;
@property (nonatomic) void (^callback)(void);

@property (nonatomic) NSUInteger finishedWebViews;
@end
@implementation BeatHTMLPrinter

- (instancetype)init {
	return [self initWithName:@"Unnamed"];
}
- (instancetype)initWithName:(NSString*)name {
	self = [super init];
	if (self) {
		_finishedWebViews = 0;
		_name = name;
	}
	return self;
}

- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings {
	[self printHtml:html printInfo:printSettings callback:nil];
}
- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings callback:(void (^ _Nullable)(void))callbackBlock {
	_printInfo = printSettings.copy;
	_callback = callbackBlock;
		
    NSRect printViewFrame = NSMakeRect(0, 0, _printInfo.paperSize.width, _printInfo.paperSize.height);
	WebView *printView = [[WebView alloc] initWithFrame:printViewFrame frameName:@"printFrame" groupName:@"printGroup"];
	printView.shouldUpdateWhileOffscreen = true;
	printView.frameLoadDelegate = self;
	printView.mainFrame.frameView.allowsScrolling = NO;
	_printView = printView;
	
	[self addSubview:printView];
	
	// Load HTML string
    [_printView.mainFrame loadHTMLString:html baseURL:nil];
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame != sender.mainFrame) return;
    if (sender.isLoading) return;
    
    //if ([[sender stringByEvaluatingJavaScriptFromString:@"document.readyState"] isEqualToString:@"complete"]) {
	self.finishedWebViews = self.finishedWebViews + 1;
		
	if (self.finishedWebViews == self.subviews.count) {
        if (sender.frameLoadDelegate == self) sender.frameLoadDelegate = nil;
		
		NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.frameView.documentView printInfo:self.printInfo];
		[printOperation runOperation];
		
		if (self.callback) _callback();
    }
}

- (BOOL)knowsPageRange:(NSRangePointer)range
{
	range->location = 0;
	range->length = self.subviews.count + 1;
	return YES;
}

- (NSRect)rectForPage:(NSInteger)page
{
	NSView *subview = self.subviews[page - 1];
	return subview.frame;
}


@end
