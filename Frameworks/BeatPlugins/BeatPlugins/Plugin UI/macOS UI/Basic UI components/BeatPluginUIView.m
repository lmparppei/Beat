//
//  BeatPluginUIView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This is the view for a SINGLE WIDGET
 
 */

#import "BeatPluginUIView.h"
#import <BeatCore/BeatColors.h>
#import "BeatWidgetView.h"

@interface BeatPluginUIView ()
@property (nonatomic) JSValue *drawingCall;
@end

@implementation BeatPluginUIView

- (instancetype)initWithHeight:(CGFloat)height {
	self = [super initWithFrame:(CGRect){0, 0, 350, height}];
	return self;
}

- (BOOL)isFlipped {
	return YES;
}

#if !TARGET_OS_IOS
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
	@try {
		[_drawingCall callWithArguments:@[@(dirtyRect)]];
	}
	@catch (NSException *e) {
		NSLog(@"Drawing error: %@", e);
	}
}

- (void)setHeight:(CGFloat)height {
	NSRect frame = self.frame;
	frame.size.height = height;
	[self.animator setFrame:frame];
	
	[(BeatWidgetView*)self.superview repositionWidgets];
}

- (BeatPluginUIButton*)addButton:(NSString*)title action:(JSValue*)action frame:(NSRect)frame {
	BeatPluginUIButton *button = [BeatPluginUIButton buttonWithTitle:title action:action frame:frame];
	[self addSubview:button];
	return button;
}

- (void)show {
	[(BeatWidgetView*)self.superview show:self];
}

#pragma mark - HTML view

- (void)addElement:(NSView*)view {
	[self addSubview:view];
}

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
	_drawingCall = nil;
	[(BeatWidgetView*)self.superview removeWidget:self];
	[self removeFromSuperview];
}

#pragma mark - Drawing

- (void)onDraw:(JSValue*)value {
	_drawingCall = value;
	[self display];
}

- (void)rectangle:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height fillColor:(NSString*)color borderColor:(NSString*)border stroke:(CGFloat)strokeWidth {
	NSRect rect = (NSRect){ x, y, width, height };
	
	NSColor *fillColor = [BeatColors color:color];
	if (color && fillColor) {
		[fillColor setFill];
		NSRectFill(rect);
	}
	
	NSColor *borderColor = [BeatColors color:border];
	if (border && borderColor) {
		[borderColor setStroke];
		NSFrameRectWithWidth(rect, strokeWidth);
	}
}

- (void)roundedRectangle:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height radius:(CGFloat)radius fillColor:(NSString*)color borderColor:(NSString*)border stroke:(CGFloat)strokeWidth {
	
	NSRect rect = (NSRect){ x, y, width, height };
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];

	NSColor *fillColor = [BeatColors color:color];
	if (color && fillColor) {
		[fillColor setFill];
		[path fill];
	}
	
	NSColor *borderColor = [BeatColors color:border];
	if (border && borderColor) {
		[borderColor setStroke];
		path.lineWidth = strokeWidth;
		[path stroke];
	}
}

- (void)circle:(CGFloat)x y:(CGFloat)y radius:(CGFloat)radius fillColor:(NSString*)color borderColor:(NSString*)border stroke:(CGFloat)strokeWidth {
	NSRect rect = NSMakeRect(x - radius / 2, y - radius / 2, radius, radius);
	NSBezierPath* circlePath = [NSBezierPath bezierPath];
	[circlePath appendBezierPathWithOvalInRect:rect];
	
	NSColor *fillColor = [BeatColors color:color];
	if (color && fillColor) {
		[fillColor setFill];
		[circlePath fill];
	}
	
	NSColor *borderColor = [BeatColors color:border];
	if (border && borderColor) {
		[borderColor setStroke];
		circlePath.lineWidth = strokeWidth;
		[circlePath stroke];
	}
}

#else

// Placeholder methods for iOS

- (void)remove {
	
}
- (void)show {
	
}

#endif

#pragma mark - User content controller

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
}


@end
