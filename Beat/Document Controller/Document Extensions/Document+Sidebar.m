//
//  Document+Sidebar.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 25.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+Sidebar.h"
#import "Document+WindowManagement.h"

@implementation Document (Sidebar)

- (IBAction)toggleSidebarView:(id)sender
{
	bool visible = !self.sidebarVisible;
	
	// Save sidebar state to settings
	[self.documentSettings setBool:DocSettingSidebarVisible as:visible];
	
	if (visible) {
		[self.outlineButton setState:NSOnState];
		
		// Show outline
		[self.outlineView reloadOutline];
		
		self.outlineView.enclosingScrollView.hasVerticalScroller = YES;
		
		if (!self.isFullscreen && !self.documentWindow.isZoomed) {
			CGFloat sidebarWidth = self.outlineView.enclosingScrollView.frame.size.width;
			CGFloat newWidth = self.documentWindow.frame.size.width + sidebarWidth;
			CGFloat newX = self.documentWindow.frame.origin.x - sidebarWidth / 2;
			CGFloat screenWidth = [NSScreen mainScreen].frame.size.width;
			
			// Ensure the main document won't go out of screen bounds when opening the sidebar
			if (newWidth > screenWidth) {
				newWidth = screenWidth;
				newX = screenWidth / 2 - newWidth / 2;
			}
			
			if (newX + newWidth > screenWidth) {
				newX = newX - (newX + newWidth - screenWidth);
			}
			
			if (newX < 0) newX = 0;
			
			NSRect newFrame = NSMakeRect(newX,
										 self.documentWindow.frame.origin.y,
										 newWidth,
										 self.documentWindow.frame.size.height);
			[self.documentWindow setFrame:newFrame display:YES];
		}
		
		// Show sidebar
		[self.splitHandle restoreBottomOrLeftView];
	} else {
		[self.outlineButton setState:NSOffState];
		
		// Hide outline
		self.outlineView.enclosingScrollView.hasVerticalScroller = NO;
		
		if (!self.isFullscreen && !self.documentWindow.isZoomed) {
			CGFloat sidebarWidth = self.outlineView.enclosingScrollView.frame.size.width;
			CGFloat newX = self.documentWindow.frame.origin.x + sidebarWidth / 2;
			NSRect newFrame = NSMakeRect(newX,
										 self.documentWindow.frame.origin.y,
										 self.documentWindow.frame.size.width - sidebarWidth,
										 self.documentWindow.frame.size.height);
			
			[self.documentWindow setFrame:newFrame display:YES];
		}
		
		[self.splitHandle collapseBottomOrLeftView];
	}
	
	// Fix layout
	[self.documentWindow layoutIfNeeded];
	
	[self updateLayout];
}

- (IBAction)showOutline:(id)sender {
	if (!self.sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:self.tabOutline];
}
- (IBAction)showNotepad:(id)sender {
	if (!self.sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:self.tabNotepad];
}
- (IBAction)showCharactersAndDialogue:(id)sender {
	if (!self.sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:self.tabDialogue];
}
- (IBAction)showReviews:(id)sender {
	if (!self.sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:self.tabReviews];
}

@end
