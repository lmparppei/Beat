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
#import <math.h>   // for isnan()


@interface BeatPluginHTMLWindow ()
@end

@implementation BeatPluginHTMLWindow



-(instancetype)initWithHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height headers:(NSString*)headers host:(BeatPlugin*)host
{
    if (isnan(width) || isnan(height)) {
        width = 300.0; height = 300.0;
    }
    
	NSRect frame = NSMakeRect((NSScreen.mainScreen.frame.size.width - width) / 2, (NSScreen.mainScreen.frame.size.height - height) / 2, width, height);
    //if (frame.size.width == NAN) frame.size.width = NSScreen.mainScreen.frame.size.width;
    
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
    
    NSDictionary* content = @{ @"content":(html) ? html : @"", @"headers":(headers) ? headers : @"" };
    _webView = [BeatPluginWebView createWithHtml:content width:width height:height host:(BeatPlugin*)self.host];

	[self.contentView addSubview:_webView];
	
	// Window will appear on screen
	[self appear];
	
	return self;
}

/// Returns `true` when window is in full screen mode
- (bool)isFullScreen {
    return ((self.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
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

- (void)call:(JSValue*)val arguments:(NSArray*)arguments
{
    NSString* args = @"";
    for (id a in arguments) {
        if (a != arguments.firstObject) args = [args stringByAppendingString:@", "];
        args = [args stringByAppendingFormat:@"%@", a];
    }
    
    NSString* js = [NSString stringWithFormat:@"(%@)(%@)", val.toString, args];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

#pragma mark - Window interactions

/// Rather than actually closing the window, we're sending a message to host to close the window. I'm not sure why, we could handle running the callback here, but whatever.
- (void)close {
	[self.host closePluginWindow:self];
}

/// The actual method to forcibly close the window
- (void)closeWindow {
    if (!_stayInMemory) {
        [self.webView removeFromSuperview];
        [self.webView purge];
        self.webView = nil;
    }
    
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

- (void)keyDown:(NSEvent *)event{
    return;
}


#pragma mark - Window sizing

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

- (void)setDisableFullScreen:(bool)disableFullScreen
{
    _disableFullScreen = disableFullScreen;
    
    self.collectionBehavior = (disableFullScreen) ? NSWindowCollectionBehaviorFullScreenAuxiliary : NSWindowCollectionBehaviorFullScreenPrimary;
}

- (void)setDisableMinimize:(bool)disableMinimize
{
    _disableMinimize = true;
    
    [[self standardWindowButton:NSWindowMiniaturizeButton] setHidden:disableMinimize];
    if (disableMinimize) self.styleMask &= ~NSWindowStyleMaskMiniaturizable;
    else self.styleMask |= ~NSWindowStyleMaskMiniaturizable;
}

- (void)setDisableMaximize:(bool)disableMaximize
{
    _disableMaximize = true;
    
    [[self standardWindowButton:NSWindowZoomButton] setHidden:disableMaximize];
    if (disableMaximize) self.styleMask &= ~NSWindowStyleMaskFullScreen;
    else self.styleMask |= ~NSWindowStyleMaskFullScreen;
}


#pragma mark - Organizing windows

- (void)hide {
    [self setIsVisible:false];
}
- (void)show {
    [self setIsVisible:true];
}

/// This doesn't actually hide the window, but makes it drop behind current key window
- (void)hideBehindOthers {
	self.level = NSNormalWindowLevel;
	self.orderedIndex += 1; // Hide behind new stuff, just in case
}
/// Tells the window to become floating-level when the document was activated
- (void)appear {
    self.level = NSFloatingWindowLevel;
}


#pragma mark - Window and screen frame sizes

- (CGRect)getFrame {
	return self.frame;
}

- (CGRect)getWindowFrame {
	return self.frame;
}

- (void)setPositionX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
    if (isnan(x) || isnan(y) || isnan(width) || isnan(height)) {
        [self.host log:@"Error setting window frame. One of the values was NaN"];
        return;
    }
    
	@try {
		NSRect frame = (NSRect){ x, y, width, height };
		[self setFrame:frame display:YES];
	} @catch (NSException* error) {
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
