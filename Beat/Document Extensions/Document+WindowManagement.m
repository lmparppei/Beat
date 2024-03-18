//
//  Document+WindowManagement.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+WindowManagement.h"

@implementation Document (WindowManagement)

-(void)windowWillBeginSheet:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	[self.documentWindow makeKeyAndOrderFront:self];
	[self hideAllPluginWindows];
}

-(void)windowDidEndSheet:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	[self showPluginWindowsForCurrentDocument];
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
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

- (void)windowDidResignMain:(NSNotification *)notification {
	if (self.documentIsLoading) return;
	
	// When window resigns it main status, we'll have to hide possible floating windows
	NSWindow *mainWindow = NSApp.mainWindow;
	if (self.documentWindow.isVisible) [self hidePluginWindowsWithMain:mainWindow];
}

- (void)hidePluginWindowsWithMain:(NSWindow*)mainWindow {
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		[self.runningPlugins[pluginName] hideAllWindows];
		[self.runningPlugins[pluginName] documentDidResignMain];
	}
	
	if (!mainWindow.isMainWindow && self.runningPlugins.count > 0) {
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
