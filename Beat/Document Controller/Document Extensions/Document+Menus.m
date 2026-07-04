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
@import yswift;

@implementation Document (Menus)

#pragma mark - Toggling user default settings on/off

/// Toggles user default or document setting value on or off. Requires `BeatOnOffMenuItem` with a defined `settingKey`.
- (IBAction)toggleSetting:(BeatOnOffMenuItem*)menuItem
{
	if (menuItem == nil || menuItem.settingKey.length == 0) return;
	
	if (menuItem.documentSetting) [self.documentSettings toggleBool:menuItem.settingKey];
	else [BeatUserDefaults.sharedDefaults toggleBool:menuItem.settingKey];
	
	[self ensureLayout];
	
	// This notification should be the preferred way of updating any views etc. in the future
	[NSNotificationCenter.defaultCenter postNotification:[NSNotification.alloc initWithName:@"SettingToggled" object:nil userInfo:nil]];
}


#pragma mark - Menu item validation

//Empty function, which needs to exists to make the share access the validateMenuItems function
- (IBAction)share:(id)sender {}
- (IBAction)export:(id)sender {}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Set this to false if the item shouldn't be available
	bool valid = true;
	SEL action = menuItem.action;

	// Toggle checks first
	// TODO: (wtf, there are multiple similar, basically overlapping menu item classes. These should be fixed at some point.
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
		if (action == @selector(preview:)) menuItem.state = BXOnState;
		// Some other items are also enabled
		return (action == @selector(zoomIn:) ||
			menuItem.action == @selector(zoomOut:) ||
			menuItem.action == @selector(openPrintPanel:) ||
			menuItem.action == @selector(openPDFPanel:) ||
			menuItem.action == @selector(preview:)
				);
	} else if (self.currentTab == self.cardsTab) {
		if (action == @selector(toggleCards:)) menuItem.state = BXOnState;
		
		// Only toggle cards and undo/redo are available
		return (action == @selector(toggleCards:) ||
				action == @selector(undoEdit:) ||
				action == @selector(redoEdit:));
	}
	
	//
	if (action == @selector(toggleTimeline:)) {
		menuItem.state = BXState(self.timeline.visible);
	}
	else if (action == @selector(toggleSidebarView:)) {
		menuItem.state = BXState(self.sidebarVisible);
	}
	else if (action == @selector(toggleTagging:)) {
		menuItem.state = BXState(self.mode == TaggingMode);
	}
	else if (action == @selector(toggleReview:)) {
		menuItem.state =  BXState(self.mode == ReviewMode);
	}
	else if (action == @selector(reviewSelectedRange:)) {
		valid = (self.selectedRange.length > 0);
	}
	else if (action == @selector(selectSansSerif:)) {
		menuItem.state = BXState(self.fontStyle == 1);
	}
	else if (action == @selector(selectSerif:)) {
		menuItem.state = BXState(self.fontStyle == 0);
	}
	else if (action == @selector(toggleDarkMode:)) {
		menuItem.state = BXState(self.isDark);
	}
	else if (action == @selector(toggleCards:)) {
		menuItem.state = BXOffState;
	}
	else if (action == @selector(showWidgets:)) {
		// Don't show menu item for widget view, if no widgets are visible

		if (self.widgetView.subviews.count > 0) {
			menuItem.hidden = NO;
		} else {
			menuItem.state = BXOffState;
			menuItem.hidden = YES;
			valid = false;
		}
	}
	else if (menuItem.action == @selector(selectStylesheet:)) {
		BeatMenuItemWithStylesheet* m = (BeatMenuItemWithStylesheet*)menuItem;
		NSString* stylesheet = [self.documentSettings getString:DocSettingStylesheet].copy;
		if (stylesheet.length == 0) stylesheet = nil;
		
		m.state = BXState([m.stylesheet isEqualToString:stylesheet]);
	}
	
	// So, I have overriden everything regarding undo (because I couldn't figure it out)
	// That's why we need to handle enabling/disabling undo manually. This sucks.
	else if (menuItem.action == @selector(undoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.undo", nil), [self.undoManager undoActionName]];
		valid = (self.collaborating) ? self.yClient.canUndo : self.undoManager.canUndo;
	}
	else if (menuItem.action == @selector(redoEdit:)) {
		menuItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"general.redo", nil), [self.undoManager redoActionName]];
		valid = (self.collaborating) ? self.yClient.canRedo : self.undoManager.canRedo;
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
	else if (menuItem.action == @selector(markAddition:) || menuItem.action == @selector(markRemoval:) || menuItem.action == @selector(clearMarkings:)) {
		valid = (self.textView.selectedRange.length > 0);
	}
	else if (menuItem.action == @selector(startCollaboration:)) {
		return !self.collaborating;
	}
	
	return valid;
}

- (IBAction)shareFromService:(id)sender
{
	[[sender representedObject] performWithItems:@[self.fileURL]];
}


@end
