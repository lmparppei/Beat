//
//  WebPrinter.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "WebPrinter.h"
#import <WebKit/WebKit.h>

@interface WebPrinter ()
{
    WebView *printView;
//	NSPrintInfo *printInfo;
}
@property (nonatomic) NSPrintInfo *printInfo;
@property (nonatomic) void (^callback)(void);
@end
@implementation WebPrinter


- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings {
	[self printHtml:html printInfo:printSettings callback:nil];
}
- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings callback:(void (^ _Nullable)(void))callbackBlock {
	_printInfo = printSettings.copy;
	_callback = callbackBlock;
		
    NSRect printViewFrame = NSMakeRect(0, 0, _printInfo.paperSize.width, _printInfo.paperSize.height);
    printView = [[WebView alloc] initWithFrame:printViewFrame frameName:@"printFrame" groupName:@"printGroup"];
    printView.shouldUpdateWhileOffscreen = true;
    printView.frameLoadDelegate = self;
    [printView.mainFrame loadHTMLString:html baseURL:NSBundle.mainBundle.resourceURL];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame != sender.mainFrame) {
        return;
    }

    if (sender.isLoading) {
        return;
    }
    if ([[sender stringByEvaluatingJavaScriptFromString:@"document.readyState"] isEqualToString:@"complete"]) {
		
        sender.frameLoadDelegate = nil;

		/*
        NSWindow *window = NSApp.mainWindow;
        if (!window) {
            window = NSApp.windows.firstObject;
        }
		 */
		
		NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.frameView.documentView printInfo:_printInfo];
		[printOperation runOperation];
		//NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.webView printInfo:_printInfo];
		//[printOperation runOperationModalForWindow:_window delegate:nil didRunSelector:nil contextInfo:nil];
        //[printOperation runOperationModalForWindow:window delegate:window didRunSelector:nil contextInfo:nil];
		
		if (_callback) _callback();
    }
}

@end
