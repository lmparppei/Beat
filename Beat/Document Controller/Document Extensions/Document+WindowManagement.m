//
//  Document+WindowManagement.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+WindowManagement.h"
#import "Document+ThemesAndAppearance.h"
#import "BeatTextView.h"
#import <BeatPlugins/BeatPlugin+Windows.h>

#define MIN_WINDOW_HEIGHT 400
#define MIN_OUTLINE_WIDTH 270

// WARNING: We are suppressing protocol conformance warnings, because of my sloppy protocols. Oh well.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
@implementation Document (WindowManagement)

- (void)setupWindow
{
	[self updateUIColors];
	
	self.tagTextView.enclosingScrollView.hasHorizontalScroller = false;
	self.tagTextView.enclosingScrollView.hasVerticalScroller = false;
	
	self.rightSidebarConstraint.constant = 0;
	
	// Split view
	self.splitHandle.bottomOrLeftMinSize = MIN_OUTLINE_WIDTH;
	self.splitHandle.delegate = self;
	[self.splitHandle collapseBottomOrLeftView];
	
	// Set minimum window size
	[self setMinimumWindowSize];
	
	// Recall window position for saved documents
	if (![self.fileNameString isEqualToString:@"Untitled"]) self.documentWindow.frameAutosaveName = self.fileNameString;
	
	NSRect screen = self.documentWindow.screen.frame;
	NSPoint origin = self.documentWindow.frame.origin;
	NSSize size = NSMakeSize([self.documentSettings getFloat:DocSettingWindowWidth], [self.documentSettings getFloat:DocSettingWindowHeight]);
	
	CGFloat preferredWidth = self.textView.documentWidth * self.textView.zoomLevel + 200;
	
	if (size.width < 1) {
		// Default size for new windows
		size.width = preferredWidth;
		origin.x = (screen.size.width - size.width) / 2;
	} else if (size.width < self.documentWindow.minSize.width || origin.x > screen.size.width || origin.x < 0) {
		// This window had a size saved. Let's make sure it stays inside screen bounds or is larger than minimum size.
		size.width = self.documentWindow.minSize.width;
		origin.x = (screen.size.width - size.width) / 2;
	}
	
	if (size.height < MIN_WINDOW_HEIGHT || origin.y + size.height > screen.size.height) {
		size.height = MAX(MIN_WINDOW_HEIGHT, screen.size.height - 100.0);
		origin.y = (screen.size.height - size.height) / 2;
	}
	
	NSRect newFrame = NSMakeRect(origin.x, origin.y, size.width, size.height);
	[self.documentWindow setFrame:newFrame display:YES];
}

- (void)setMinimumWindowSize
{
	CGFloat width = (self.textView.textContainer.size.width - (2 * BeatTextView.linePadding)) * self.magnification + 30;
	if (self.sidebarVisible) width += self.outlineView.frame.size.width;

	// Clamp the value. I can't use max methods.
	if (width > self.documentWindow.screen.frame.size.width) width = self.documentWindow.screen.frame.size.width;
	
	[self.documentWindow setMinSize:NSMakeSize(width, MIN_WINDOW_HEIGHT)];
}



#pragma mark - Window flags

/// Returns `true` if the document window is full screen
- (bool)isFullscreen
{
	return ((self.documentWindow.styleMask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
}


#pragma mark - Tabs

/// Move to another editor view
- (void)showTab:(NSTabViewItem*)tab
{
	[self.tabView selectTabViewItem:tab];
	[tab.view.subviews.firstObject becomeFirstResponder];
	
	// Update containers in tabs
	for (id<BeatPluginContainer> view in self.registeredPluginContainers) {
		if (![tab.view.subviews containsObject:(NSView*)view]) [view containerViewDidHide];
	}
}



#pragma mark - Managing views

/// Restores sidebar status on launch
- (void)restoreSidebar
{
	if ([self.documentSettings getBool:DocSettingSidebarVisible]) {
		self.sidebarVisible = YES;
		[self.splitHandle restoreBottomOrLeftView];
		self.splitHandle.mainConstraint.constant = MAX([self.documentSettings getInt:DocSettingSidebarWidth], MIN_OUTLINE_WIDTH);
	}
}


#pragma mark - Registering assisting windows

- (void)registerWindow:(NSWindow*)window owner:(id)owner
{
	if (self.assistingWindows == nil) self.assistingWindows = NSMutableDictionary.new;
	
	NSValue* object = [NSValue valueWithNonretainedObject:owner];
	self.assistingWindows[object] = window;
}


#pragma mark - Window events

/// Update sizes and layout on resize
- (void)windowDidResize:(NSNotification *)notification
{
	CGFloat width = self.documentWindow.frame.size.width;
	
	[self.documentSettings setFloat:DocSettingWindowWidth as:width];
	[self.documentSettings setFloat:DocSettingWindowHeight as:self.documentWindow.frame.size.height];
	[self updateLayout];
}

-(void)windowWillBeginSheet:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	[self.documentWindow makeKeyAndOrderFront:self];
	[self hideAllPluginWindows];
}

-(void)windowDidEndSheet:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	[self showPluginWindowsForCurrentDocument];
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	// Show all plugin windows associated with the current document
	[self showPluginWindowsForCurrentDocument];
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document changed" object:self];
	
	if (self.currentKeyWindow != nil && self.currentKeyWindow.visible) {
		[self.currentKeyWindow makeKeyAndOrderFront:nil];
	}
}

-(void)windowDidBecomeKey:(NSNotification *)notification {
	self.currentKeyWindow = nil;
	// Show all plugin windows associated with the current document
	if (notification.object == self.documentWindow && self.documentWindow.sheets.count == 0) {
		[self showPluginWindowsForCurrentDocument];
	}
	[self.userActivity becomeCurrent];
}

-(void)windowDidResignKey:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	self.currentKeyWindow = NSApp.keyWindow;
	
	if ([self.currentKeyWindow isKindOfClass:NSOpenPanel.class]) {
		[self hideAllPluginWindows];
	} else if ([self.currentKeyWindow isKindOfClass:NSSavePanel.class] || self.documentWindow.sheets.count > 0) {
		[self hideAllPluginWindows];
		[self.documentWindow makeKeyAndOrderFront:nil];
	}
}

bool avoidLoop = false;
- (void)windowDidResignMain:(NSNotification *)notification {
	//if (self.documentIsLoading || notification.object == NSApp.mainWindow || NSApp.mainWindow == nil) return;
	if (avoidLoop || self.documentIsLoading || notification.object == NSApp.mainWindow) return;
	
	avoidLoop = true;
	// When window resigns it main status, we'll have to hide possible floating windows
	if (self.documentWindow.isVisible) [self hidePluginWindowsWithMain:NSApp.mainWindow];
	avoidLoop = false;
	
	[self.userActivity resignCurrent];
}

- (void)hidePluginWindowsWithMain:(NSWindow*)mainWindow {
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		[self.runningPlugins[pluginName] hideAllWindows];
		[self.runningPlugins[pluginName] documentDidResignMain];
	}
	
	// If the new main window didn't become key, let's order it front to avoid plugin windows from earlier document floating above it.
	if (!mainWindow.isMainWindow && mainWindow != self.documentWindow && self.runningPlugins.count > 0) {
		[mainWindow makeKeyAndOrderFront:nil];
	}
}

- (void)showPluginWindowsForCurrentDocument
{
	// When document becomes main window, iterate through all documents.
	// If they have plugin windows open, hide those windows behind the current document window.
	for (Document *doc in NSDocumentController.sharedDocumentController.documents) {
		if (doc == self) continue;
		for (NSString *pluginName in doc.runningPlugins.allKeys) {
			[doc.runningPlugins[pluginName] hideAllWindows];
		}
	}
	
	// Reveal all plugin windows for the current document
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		[self.runningPlugins[pluginName] showAllWindows];
	}
	
	[self.documentWindow orderFront:nil];
	
	// Notify running plugins that the window became main after the document *actually* is main window
	[self.pluginAgent notifyPluginsThatWindowBecameMain];
}

- (void)hideAllPluginWindows
{
	for (Document *doc in NSDocumentController.sharedDocumentController.documents) {
		for (NSString *pluginName in doc.runningPlugins.allKeys) {
			[(BeatPlugin*)doc.runningPlugins[pluginName] hideAllWindows];
		}
	}
}

-(void)spaceDidChange
{
	if (!self.documentWindow.onActiveSpace) [self.documentWindow resignMainWindow];
}

@end
