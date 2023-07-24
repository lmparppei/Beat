//
//  TestPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginHTMLWindow.h"
#import "BeatPlugin.h"
#import "Beat-Swift.h"

@interface BeatPluginHTMLWindow ()
@end

@implementation BeatPluginHTMLWindow

-(instancetype)initWithHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height host:(BeatPlugin*)host {
	NSRect frame = NSMakeRect((NSScreen.mainScreen.frame.size.width - width) / 2, (NSScreen.mainScreen.frame.size.height - height) / 2, width, height);
	
	self = [super initWithContentRect:frame styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	
	// Make the window aware of the plugin host
	self.host = host;
	self.delegate = host;
	
	// Window settings
	self.tabbingMode = NSWindowTabbingModeDisallowed;
	self.hidesOnDeactivate = NO;
	self.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
	// We can't release the panel on close, because JSContext might hang onto it and cause a crash
	self.releasedWhenClosed = NO;
	
	self.title = host.pluginName;

	// Create configuration for WKWebView
	WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
	config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
	
	// Message handlers
	if (@available(macOS 11.0, *)) {
		[config.userContentController addScriptMessageHandlerWithReply:self.host contentWorld:WKContentWorld.pageWorld name:@"callAndWait"];
	}
	
	[config.userContentController addScriptMessageHandler:self.host name:@"sendData"];
	[config.userContentController addScriptMessageHandler:self.host name:@"call"];
	[config.userContentController addScriptMessageHandler:self.host name:@"log"];
	if (@available(macOS 12.3, *)) [config.preferences setElementFullscreenEnabled:true];
	
	// Initialize (custom) webkit view
	_webview = [[BeatPluginWebView alloc] initWithFrame:NSMakeRect(0, 0, width, height) configuration:config];
	_webview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

	// Load HTML and add the view into window
	[self setHTML:html];
	[self.contentView addSubview:_webview];
	
	// Window will appear on screen
	[self appear];
	
	return self;
}

/// Returns `true` when window is in full screen mode
- (bool)isFullScreen {
	if ((self.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen) {
		return true;
	} else {
		return false;
	}
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
	[_webview loadHTMLString:html baseURL:nil];
}

/// Sets the HTML content with preloaded styles.
- (void)setHTML:(NSString*)html {
	// Load template
    NSBundle* bundle = [NSBundle bundleForClass:self.class];
	
    NSURL *templateURL = [bundle URLForResource:@"Plugin HTML template" withExtension:@"html"];
	NSString *template = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil];
	template = [template stringByReplacingOccurrencesOfString:@"<!-- CONTENT -->" withString:html];
	
	[_webview loadHTMLString:template baseURL:nil];
}

#pragma mark - Running JS in window instance

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


#pragma mark - Window interactions

- (void)close {
	[self.host closePluginWindow:self];
}

- (void)closeWindow {
	[super close];
}

- (void)focus {
	[self makeFirstResponder:self.contentView];
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
