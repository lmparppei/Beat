//
//  BeatBrowserView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 A class to show the browser for Patch Notes and the (upcoming) manual
 
 */

#import "BeatBrowserView.h"
#import "BeatAppDelegate.h"
#import <Webkit/Webkit.h>

@interface BeatBrowserView ()
@property (nonatomic, weak) IBOutlet WKWebView *webview;
@end

@implementation BeatBrowserView

- (instancetype) init {
	return [super initWithWindowNibName:self.className owner:self];
}
-(void)resetWebView {
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"openTemplate"];
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"openLink"];
}

- (void)setHTML:(NSString*)string {
	[self.webview loadHTMLString:string baseURL:nil];
}
- (void)showBrowser:(NSURL*)url withTitle:(NSString*)title width:(CGFloat)width height:(CGFloat)height {
	self.window.title = title;
	
	[self.window setFrame:NSMakeRect(
									 (NSScreen.mainScreen.frame.size.width - width) / 2,
									 (NSScreen.mainScreen.frame.size.height - height) / 2,
									 width, height
									 )
						 display:YES];
	
	self.window.minSize = (NSSize){ width, self.window.minSize.height };
	
	[self loadURL:url];
	[self showBrowser];
}

- (void)showBrowserWithString:(NSString*)string withTitle:(NSString*)title width:(CGFloat)width height:(CGFloat)height {
	self.window.title = title;
	
	[self.window setFrame:NSMakeRect(
									 (NSScreen.mainScreen.frame.size.width - width) / 2,
									 (NSScreen.mainScreen.frame.size.height - height) / 2,
									 width, height
									 )
						 display:YES];
	
	[self.webview loadHTMLString:string baseURL:NSBundle.mainBundle.resourceURL];
	[self showBrowser];
}
- (void)showBrowser {
	[self.window setIsVisible:true];
	
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"openTemplate"];
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"openLink"];
	
	[self.webview.configuration.userContentController addScriptMessageHandler:self name:@"openTemplate"];
	[self.webview.configuration.userContentController addScriptMessageHandler:self name:@"openLink"];
	
	self.webview.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
	
	[self showWindow:self.window];
	[self.window makeKeyAndOrderFront:self.window];
}

- (void)close {
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"openTemplate"];
	[self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"openLink"];
	[super close];
}

- (void)loadURL:(NSURL*)url {
	[self.webview loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
}

- (void)windowDidLoad {
    [super windowDidLoad];	
}

-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
	if ([message.name isEqualToString:@"openTemplate"]) {
		[(BeatAppDelegate*)NSApp.delegate showTemplate:message.body];
	}
	else if ([message.name isEqualToString:@"openLink"]) {
		[(BeatAppDelegate*)NSApp.delegate openURLInWebBrowser:message.body];
	}
}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
	NSLog(@"error %@", error);
}
-(void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
	NSLog(@"error %@", error);
}
-(void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
	NSLog(@"terminate %@", webView);
}

@end
