//
//  BeatPluginUIView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUIView.h"
#import "BeatColors.h"
#import "BeatWidgetView.h"

@interface BeatPluginUIView ()
@property (nonatomic) JSValue *drawingCall;
@end

@implementation BeatPluginUIView

- (instancetype)initWithHeight:(CGFloat)height {
	self = [super initWithFrame:(NSRect){0, 0, 350, height}];
	return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
	[_drawingCall callWithArguments:@[@(dirtyRect)]];
}

- (BOOL)isFlipped {
	return YES;
}

- (BeatPluginUIButton*)addButton:(NSString*)title action:(JSValue*)action frame:(NSRect)frame {
	BeatPluginUIButton *button = [BeatPluginUIButton buttonWithTitle:title action:action frame:frame];
	[self addSubview:button];
	return button;
}

#pragma mark - HTML view

- (void)addHtmlView:(NSString*)html {
	// Allow only one web view
	if (_webView) return;
	
	WKWebView *webView = [[WKWebView alloc] initWithFrame:self.frame];
	_webView = webView;
	[_webView loadHTMLString:html baseURL:nil];
	
	[self addSubview:webView];
}
- (void)runJS:(NSString*)js callback:(JSValue*)callback {
	if (!_webView) return;
	[_webView evaluateJavaScript:js completionHandler:^(id _Nullable returnValue, NSError * _Nullable error) {
		[callback callWithArguments:returnValue];
	}];
}
- (void)setHtml:(NSString*)html {
	[_webView loadHTMLString:html baseURL:nil];
}
- (void)remove {
	_webView = nil;
	[(BeatWidgetView*)self.superview removeWidget:self];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
	
}

#pragma mark - Drawing

- (void)draw:(JSValue*)value {
	_drawingCall = value;
	[self display];
}

- (void)rectangle:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height color:(NSString*)color {
	NSColor *colorValue = [BeatColors color:color];
	[colorValue setFill];
	
	NSRect rect = (NSRect){ x, y, width, height };
	NSRectFill(rect);
}

@end
