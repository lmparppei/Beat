//
//  BeatPluginWindow.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.5.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatPluginWindow.h"

@interface BeatPluginWindow ()
@property (assign) BeatScriptParser *parser;
@end

@implementation BeatPluginWindow

-(instancetype)initWithHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height parser:(BeatScriptParser*)parser {
	NSRect frame = NSMakeRect((NSScreen.mainScreen.frame.size.width - width) / 2, (NSScreen.mainScreen.frame.size.height - height) / 2, width, height);
	
	self = [super initWithContentRect:frame styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskUtilityWindow | NSWindowStyleMaskResizable | NSWindowStyleMaskTitled backing:NSBackingStoreNonretained defer:NO];
	self.level = NSDockWindowLevel;
	self.delegate = parser;
	self.releasedWhenClosed = YES;
	
	_parser = parser;
	self.title = parser.pluginName;

	WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
	config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
	
	[config.userContentController addScriptMessageHandler:self.parser name:@"sendData"];
	[config.userContentController addScriptMessageHandler:self.parser name:@"call"];
	[config.userContentController addScriptMessageHandler:self.parser name:@"log"];

	_webview = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, width, height) configuration:config];
	_webview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

	[self setHTML:html];
	[self.contentView addSubview:_webview];
	
	return self;
}

+ (BeatPluginWindow*)withHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height parser:(id)parser {
	return [[BeatPluginWindow alloc] initWithHTML:html width:width height:height parser:(BeatScriptParser*)parser];
}

- (void)setTitle:(NSString *)title {
	[super setTitle:title];
}
- (void)setHTML:(NSString*)html {
	// Load template
	NSURL *templateURL = [NSBundle.mainBundle URLForResource:@"Plugin HTML template" withExtension:@"html"];
	NSString *template = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil];
	template = [template stringByReplacingOccurrencesOfString:@"<!-- CONTENT -->" withString:html];
	
	[_webview loadHTMLString:template baseURL:nil];
}

- (void)runJS:(nonnull NSString *)js callback:(nullable JSValue *)callback {
	if (callback && !callback.isUndefined) {
		[_webview evaluateJavaScript:js completionHandler:^(id _Nullable data, NSError * _Nullable error) {
			[callback callWithArguments:data];
		}];
	} else {
		[_webview evaluateJavaScript:js completionHandler:nil];
	}
}

- (void)focus {
	[self makeFirstResponder:self.contentView];
}

- (void)setPositionX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
	NSRect screen = self.screen.frame;
	// Don't allow moving the windows out of view
	if (x > screen.size.width) x = screen.size.width - 100;
	if (y > screen.size.height) x = screen.size.height - height;
	
	if (x < 0) x = 0;
	if (y < 0) y = 0;
	
	NSRect frame = NSMakeRect(x, y, width, height);
	[self setFrame:frame display:YES];
}

- (NSRect)getFrame {
	//NSRect rect = self.frame;
	return self.frame;
}
- (NSSize)screenSize {
	return self.screen.frame.size;
	//return @[ @(self.screen.frame.size.width), @(self.screen.frame.size.height) ];
}

@end
