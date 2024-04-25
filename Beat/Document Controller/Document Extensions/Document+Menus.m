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

- (void)setupMenuItems
{
	// Menu items which need to check their on/off state against bool properties in this class
	self.itemsToValidate = @[
		//[BeatValidationItem.alloc initWithAction:@selector(toggleRevisionMode:) setting:@"revisionMode" target:self],
		[BeatValidationItem.alloc initWithAction:@selector(toggleTimeline:) setting:@"visible" target:self.timeline],
		[BeatValidationItem.alloc initWithAction:@selector(toggleSidebarView:) setting:@"sidebarVisible" target:self],
		[BeatValidationItem.alloc initWithMatchedValue:DocSettingStylesheet setting:DocSettingStylesheet action:@selector(selectStylesheet:) target:self.documentSettings]
	];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Toggle checks first
	if ([menuItem isKindOfClass:BeatOnOffMenuItem.class]) {
		BeatOnOffMenuItem* validatingItem = (BeatOnOffMenuItem*)menuItem;
		return [validatingItem setCheckedWithDocument:self];
	}
	
	// Validate some items which need to access selectors in this class or something
	// BeatValidationItem class matches given methods against a property in this class, ie. toggleSomething -> .something
	for (BeatValidationItem *item in self.itemsToValidate) {
		if (menuItem.action == item.selector) {
			menuItem.state = ([item validate]) ? NSOnState : NSOffState;
		}
	}
	
	// Export items
	if ([menuItem isKindOfClass:BeatFileExportMenuItem.class]) {
		BeatFileExportMenuItem* item = (BeatFileExportMenuItem*)menuItem;
		// Check if the file is supported by this export mode

		if (![BeatFileExportManager.shared formatSupportedByStyleWithFormat:item.format style:self.styles.name]) {
			item.hidden = true;
			return false;
		} else {
			item.hidden = false;
		}
	}
	
	// Special conditions for other than normal edit view
	if (self.currentTab != self.editorTab) {
		// If PRINT PREVIEW is enabled
		if (self.currentTab == self.previewTab || self.currentTab == self.nativePreviewTab) {
			if (menuItem.action == @selector(preview:)) {
				[menuItem setState:NSOnState];
				return YES;
			} else if (menuItem.action == @selector(zoomIn:) ||
				menuItem.action == @selector(zoomOut:) ||
				menuItem.action == @selector(openPrintPanel:) ||
				menuItem.action == @selector(openPDFPanel:)
				) return YES;
		}
		
		// If CARD VIEW is enabled
		if (self.currentTab == self.cardsTab) {
			if (menuItem.action == @selector(toggleCards:)) {
				menuItem.state = NSOnState;
				return YES;
			}
			
			if (menuItem.action == @selector(undoEdit:) ||
				menuItem.action == @selector(redoEdit:)) {
				return YES;
			}
		}
		
		// Rest of the items are disabled for non-editor views
		return NO;
	}
	
	if (menuItem.action == @selector(toggleTagging:)) {
		if (self.mode == TaggingMode) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(toggleReview:)) {
		if (self.mode == ReviewMode) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	
	else if (menuItem.action == @selector(reviewSelectedRange:)) {
		if (self.selectedRange.length == 0) return NO;
		else return YES;
	}
	else if (menuItem.action == @selector(selectSansSerif:)) {
		bool sansSerif = [BeatUserDefaults.sharedDefaults getBool:BeatSettingUseSansSerif];
		if (sansSerif) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(selectSerif:)) {
		bool sansSerif = [BeatUserDefaults.sharedDefaults getBool:BeatSettingUseSansSerif];
		if (!sansSerif) menuItem.state = NSOnState;
		else menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(toggleDarkMode:)) {
		if (self.isDark) [menuItem setState:NSOnState];
		else [menuItem setState:NSOffState];
		
	}
	else if (menuItem.action == @selector(toggleCards:)) {
		menuItem.state = NSOffState;
	}
	else if (menuItem.action == @selector(showWidgets:)) {
		// Don't show menu item for widget view, if no widgets are visible

		if (self.widgetView.subviews.count > 0) {
			menuItem.hidden = NO;
			return YES;
		} else {
			menuItem.state = NSOffState;
			menuItem.hidden = YES;
			return NO;
		}
	}
	else if (menuItem.action == @selector(selectStylesheet:)) {
		BeatMenuItemWithStylesheet* m = (BeatMenuItemWithStylesheet*)menuItem;
		NSString* stylesheet = [self.documentSettings getString:DocSettingStylesheet];
		if (stylesheet == nil) stylesheet = @"";
		
		m.state = [m.stylesheet isEqualToString:stylesheet] ? NSOnState : NSOffState;
		
		return true;
	}
	
	// So, I have overriden everything regarding undo (because I couldn't figure it out)
	// That's why we need to handle enabling/disabling undo manually. This sucks.
	else if (menuItem.action == @selector(undoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.undo", nil), [self.undoManager undoActionName]];
		if (!self.undoManager.canUndo) return NO;
	}
	else if (menuItem.action == @selector(redoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.redo", nil), [self.undoManager redoActionName]];
		if (!self.undoManager.canRedo) return NO;
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
	
	return YES;
}

- (IBAction)shareFromService:(id)sender
{
	[[sender representedObject] performWithItems:@[self.fileURL]];
}


@end
