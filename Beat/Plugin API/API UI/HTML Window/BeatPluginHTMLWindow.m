//
//  TestPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginHTMLWindow.h"
#import "BeatPlugin.h"

@interface BeatPluginHTMLWindow ()
@end

@implementation BeatPluginHTMLWindow

-(instancetype)initWithHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height host:(BeatPlugin*)host {
	NSRect frame = NSMakeRect((NSScreen.mainScreen.frame.size.width - width) / 2, (NSScreen.mainScreen.frame.size.height - height) / 2, width, height);
	
	self = [super initWithContentRect:frame styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	self.level = NSFloatingWindowLevel;
	
	self.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary;
	self.delegate = host;
	
	// Disable tabs for these types of windows
	self.tabbingMode = NSWindowTabbingModeDisallowed;
	
	// We can't release the panel on close, because JSContext might hang onto it and cause a crash
	self.releasedWhenClosed = NO;
	
	_host = host;
	self.title = host.pluginName;

	
	WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
	config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
	
	[config.userContentController addScriptMessageHandler:self.host name:@"sendData"];
	[config.userContentController addScriptMessageHandler:self.host name:@"call"];
	[config.userContentController addScriptMessageHandler:self.host name:@"log"];

	_webview = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, width, height) configuration:config];
	_webview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

	[self setHTML:html];
	[self.contentView addSubview:_webview];
	
	return self;
}

- (void)setHTML:(NSString*)html {
	// Load template
	NSURL *templateURL = [NSBundle.mainBundle URLForResource:@"Plugin HTML template" withExtension:@"html"];
	NSString *template = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil];
	template = [template stringByReplacingOccurrencesOfString:@"<!-- CONTENT -->" withString:html];
	
	[_webview loadHTMLString:template baseURL:nil];
}

- (void)close {
	[self.host closePluginWindow:self];
}

- (void)closeWindow {
	[super close];
}

- (void)focus {
	[self makeFirstResponder:self.contentView];
}

- (void)setTitle:(NSString *)title {
	if (!title) title = @"";
	[super setTitle:title];
}

- (CGRect)getFrame {
	return self.frame;
}

- (void)setDark:(bool)dark {
	_dark = dark;

	if (@available(macOS 10.14, *)) {
		if (_dark) self.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
		else self.appearance = NSAppearance.currentAppearance;
	}
}

- (void)setResizable:(BOOL)resizable {
	_resizable = resizable;
	
	if (resizable) {
		self.styleMask |= NSWindowStyleMaskResizable;
		[[self standardWindowButton:NSWindowMiniaturizeButton] setHidden:NO];
		[[self standardWindowButton:NSWindowZoomButton] setHidden:NO];
	} else {
		self.styleMask &= ~NSWindowStyleMaskResizable;
		[[self standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
		[[self standardWindowButton:NSWindowZoomButton] setHidden:YES];
	}
}

- (void)runJS:(nonnull NSString *)js callback:(nullable JSValue *)callback {
	if (callback && !callback.isUndefined) {
		[_webview evaluateJavaScript:js completionHandler:^(id _Nullable data, NSError * _Nullable error) {
			// Make sure we are on the main thread
			dispatch_async(dispatch_get_main_queue(), ^{
				[callback callWithArguments:data];
			});
		}];
	} else {
		[self.webview evaluateJavaScript:js completionHandler:nil];
	}
}

- (NSSize)screenSize {
	return self.screen.frame.size;
}

- (void)setPositionX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
	NSRect frame = (NSRect){ x, y, width, height };
	[self setFrame:frame display:YES];
}

- (void)gangWithDocumentWindow {
	[self.host gangWithDocumentWindow:self];
}
- (void)detachFromDocumentWindow {
	[self.host detachFromDocumentWindow:self];
}

@end
