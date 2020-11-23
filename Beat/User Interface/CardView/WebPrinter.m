//
//  WebPrinter.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import "WebPrinter.h"
#import <WebKit/WebKit.h>

@interface WebPrinter ()
{
    WebView *printView;
	NSPrintInfo *printInfo;
}
@end
@implementation WebPrinter

- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings {
	_printSettings = [NSPrintInfo sharedPrintInfo];
	_printSettings.topMargin = 5;
	
	printInfo = [NSPrintInfo sharedPrintInfo];
	printInfo.topMargin = 5;
	printInfo.bottomMargin = 5;
	printInfo.leftMargin = 5;
	printInfo.rightMargin = 5;
	printInfo.paperSize = printSettings.paperSize;
	printInfo.orientation = NSPaperOrientationLandscape;
		
    NSRect printViewFrame = NSMakeRect(0, 0, printInfo.paperSize.width, printInfo.paperSize.height);
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

        NSWindow *window = NSApp.mainWindow;
        if (!window) {
            window = NSApp.windows.firstObject;
        }
		NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.frameView.documentView printInfo:printInfo];
		[printOperation runOperation];
		//NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.webView printInfo:_printInfo];
		//[printOperation runOperationModalForWindow:_window delegate:nil didRunSelector:nil contextInfo:nil];
        //[printOperation runOperationModalForWindow:window delegate:window didRunSelector:nil contextInfo:nil];
    }
}

@end
