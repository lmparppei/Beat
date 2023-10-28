//
//  TestPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginHTMLWindow.h"
#import "BeatPlugin.h"
#import <BeatPlugins/BeatPlugins-Swift.h>

@interface BeatPluginHTMLWindow ()
@end

@implementation BeatPluginHTMLWindow

-(instancetype)initWithHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height host:(BeatPlugin*)host {
	NSRect frame = NSMakeRect((NSScreen.mainScreen.frame.size.width - width) / 2, (NSScreen.mainScreen.frame.size.height - height) / 2, width, height);
	
	self = [super initWithContentRect:frame styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	
	// Make the window aware of the plugin host
	self.host = (id<PluginWindowHost>)host;
	self.delegate = (id<NSWindowDelegate>)host;
	
	// Window settings
	self.tabbingMode = NSWindowTabbingModeDisallowed;
	self.hidesOnDeactivate = NO;
	self.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
	// We can't release the panel on close, because JSContext might hang onto it and cause a crash
	self.releasedWhenClosed = NO;
	
	self.title = host.pluginName;
    _webView = [BeatPluginWebView createWithHtml:html width:width height:height host:(BeatPlugin*)self.host];

	[self.contentView addSubview:_webView];
	
	// Window will appear on screen
	[self appear];
	
	return self;
}

/// Returns `true` when window is in full screen mode
- (bool)isFullScreen {
	if ((self.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen) return true;
	else return false;
}

/// Toggles between full screen mode
- (void)toggleFullScreen {
	[self toggleFullScreen:nil];
}

#pragma mark - Set content

/// Sets the window title
- (void)setTitle:(NSString *)title {
	if (!title) title = @"";
	[super setTitle:title];
}

/// Sets the HTML content with no preloaded styles. Also kills support for in-window methods.
- (void)setRawHTML:(NSString*)html {
	[_webView loadHTMLString:html baseURL:nil];
}

/// Sets the HTML content with preloaded styles.
- (void)setHTML:(NSString*)html {
    [self.webView setHTML:html];
}

#pragma mark - Running JS in window instance

- (void)runJS:(nonnull NSString *)js callback:(nullable JSValue *)callback {
	if (callback && !callback.isUndefined) {
		[_webView evaluateJavaScript:js completionHandler:^(id _Nullable data, NSError * _Nullable error) {
			// Make sure we are on the main thread
			dispatch_async(dispatch_get_main_queue(), ^{
				[callback callWithArguments:data];
			});
		}];
	} else {
		[self.webView evaluateJavaScript:js completionHandler:nil];
	}
}


#pragma mark - Window interactions

- (void)close {
	[self.host closePluginWindow:self];
}

- (void)closeWindow {
    [self.webView removeFromSuperview];
    self.webView = nil;
	[super close];
}

- (void)focus {
    [self makeKeyAndOrderFront:self];
	[self makeFirstResponder:self.webView];
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

- (void)keyDown:(NSEvent *)event{
    return;
}

#pragma mark - Organizing windows

/// This doesn't actually hide the window, but makes it drop behind current key window
- (void)hide {
	self.level = NSNormalWindowLevel;
	self.orderedIndex += 1; // Hide behind new stuff, just in case
}
- (void)appear {
	self.level = NSFloatingWindowLevel;
}


#pragma mark - Window and sceren frame sizes

- (CGRect)getFrame {
	return self.frame;
}
- (CGRect)getWindowFrame {
	return self.frame;
}

- (void)setPositionX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
	@try {
		NSRect frame = (NSRect){ x, y, width, height };
		[self setFrame:frame display:YES];
		
	}
	@catch (NSException* error) {
		[self.host log:@"Error setting frame. Use .setFrame(x, y, width, height), not .setFrame(frame)"];
	}
}

- (NSRect)screenFrame {
	return self.screen.frame;
}
- (NSSize)screenSize {
	return self.screen.frame.size;
}


#pragma mark - Gang / detach from document window

#if !TARGET_OS_IOS
- (void)gangWithDocumentWindow {
	[self.host gangWithDocumentWindow:self];
}
- (void)detachFromDocumentWindow {
	[self.host detachFromDocumentWindow:self];
}
#endif

@end
