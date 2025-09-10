//
//  Document+Menus.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//


// We are checking selectors on menu items, so let's silence warnings here
#pragma GCC diagnostic ignored "-Wundeclared-selector"

#import "Document+Menus.h"
#import "Beat-Swift.h"

@implementation Document (Menus)

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}
- (IBAction)export:(id)sender {}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Set this to false if the item shouldn't be available
	bool valid = true;
	SEL action = menuItem.action;

	// Toggle checks first
	if ([menuItem isKindOfClass:BeatOnOffMenuItem.class]) {
		BeatOnOffMenuItem* validatingItem = (BeatOnOffMenuItem*)menuItem;
		valid = [validatingItem setCheckedWithDocument:self];
	}
	
	if ([menuItem conformsToProtocol:@protocol(BeatMenuItemValidationInstance)]) {
		
	}
	
	// Export menu items
	if ([menuItem isKindOfClass:BeatFileExportMenuItem.class]) {
		BeatFileExportMenuItem* item = (BeatFileExportMenuItem*)menuItem;
		// Check if the file is supported by this export mode
		if (![BeatFileExportManager.shared formatSupportedByStyleWithFormat:item.format style:self.styles.name]) {
			item.hidden = true;
			valid = false;
		} else {
			item.hidden = false;
		}
	}
	
	// Special conditions for other than normal edit view
	if (self.currentTab == self.nativePreviewTab) {
		// Toggle preview item has a checkmark
		if (action == @selector(preview:)) menuItem.state = NSOnState;
		// Some other items are also enabled
		return (action == @selector(zoomIn:) ||
			menuItem.action == @selector(zoomOut:) ||
			menuItem.action == @selector(openPrintPanel:) ||
			menuItem.action == @selector(openPDFPanel:) ||
			menuItem.action == @selector(preview:)
				);
	} else if (self.currentTab == self.cardsTab) {
		if (action == @selector(toggleCards:)) menuItem.state = NSOnState;
		
		// Only toggle cards and undo/redo are available
		return (action == @selector(toggleCards:) ||
				action == @selector(undoEdit:) ||
				action == @selector(redoEdit:));
	}
	
	//
	if (action == @selector(toggleTimeline:)) {
		menuItem.state = (self.timeline.visible) ? NSOnState : NSOffState;
	}
	else if (action == @selector(toggleSidebarView:)) {
		menuItem.state = (self.sidebarVisible) ? NSOnState : NSOffState;
	}
	else if (action == @selector(toggleTagging:)) {
		menuItem.state = (self.mode == TaggingMode) ? NSOnState : NSOffState;
	}
	else if (action == @selector(toggleReview:)) {
		menuItem.state = (self.mode == ReviewMode) ? NSOnState : NSOffState;
	}
	else if (action == @selector(reviewSelectedRange:)) {
		valid = (self.selectedRange.length > 0);
	}
	else if (action == @selector(selectSansSerif:)) {
		menuItem.state = (self.useSansSerif) ? NSOnState : NSOffState;
	}
	else if (action == @selector(selectSerif:)) {
		menuItem.state = (!self.useSansSerif) ? NSOnState : NSOffState;
	}
	else if (action == @selector(toggleDarkMode:)) {
		menuItem.state = (self.isDark) ? NSOnState : NSOffState;
	}
	else if (action == @selector(toggleCards:)) {
		menuItem.state = NSOffState;
	}
	else if (action == @selector(showWidgets:)) {
		// Don't show menu item for widget view, if no widgets are visible

		if (self.widgetView.subviews.count > 0) {
			menuItem.hidden = NO;
		} else {
			menuItem.state = NSOffState;
			menuItem.hidden = YES;
			valid = false;
		}
	}
	else if (menuItem.action == @selector(selectStylesheet:)) {
		BeatMenuItemWithStylesheet* m = (BeatMenuItemWithStylesheet*)menuItem;
		NSString* stylesheet = [self.documentSettings getString:DocSettingStylesheet].copy;
		if (stylesheet.length == 0) stylesheet = nil;
		
		m.state = [m.stylesheet isEqualToString:stylesheet] ? NSOnState : NSOffState;
	}
	
	// So, I have overriden everything regarding undo (because I couldn't figure it out)
	// That's why we need to handle enabling/disabling undo manually. This sucks.
	else if (menuItem.action == @selector(undoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.undo", nil), [self.undoManager undoActionName]];
		valid = self.undoManager.canUndo;
	}
	else if (menuItem.action == @selector(redoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.redo", nil), [self.undoManager redoActionName]];
		valid = self.undoManager.canRedo;
	}
	else if (menuItem.submenu.itemArray.firstObject.action == @selector(shareFromService:)) {
		[menuItem.submenu removeAllItems];
		NSArray *services = @[];
		
		if (self.fileURL) {
			// This produces an error, but still works. Why?
			services = [NSSharingService sharingServicesForItems:@[self.fileURL]];
			
			for (NSSharingService *service in services) {
				NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:service.title action:@selector(shareFromService:) keyEquivalent:@""];
				item.image = service.image;
				service.subject = [self.fileURL lastPathComponent];
				item.representedObject = service;
				[menuItem.submenu addItem:item];
			}
		}
		if (services.count == 0) {
			NSMenuItem *noThingPleaseSaveItem = [[NSMenuItem alloc] initWithTitle:@"Please save the file to share" action:nil keyEquivalent:@""];
			noThingPleaseSaveItem.enabled = NO;
			[menuItem.submenu addItem:noThingPleaseSaveItem];
		}
	}
	else if ([menuItem isKindOfClass:BeatVisibleRevisionMenuItem.class]) {
		NSArray<NSNumber*>* indices = [self.documentSettings get:DocSettingHiddenRevisions];
		[(BeatVisibleRevisionMenuItem*)menuItem validateWithVisibleRevisions:indices];
	}
	
	return valid;
}

- (IBAction)shareFromService:(id)sender
{
	[[sender representedObject] performWithItems:@[self.fileURL]];
}


@end
