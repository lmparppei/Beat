//
//  BeatAppDelegate+Backups.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate+Backups.h"
#import <BeatCore/BeatCore-Swift.h>
#import "Beat-Swift.h"

@implementation BeatAppDelegate (Backups)

#pragma mark - Version control

/// Adds backup menu items and management actions to given menu
- (void)addBackupMenuItemsTo:(NSMenu*)menu
{
	[menu removeAllItems];
	
	NSDocument *doc = NSDocumentController.sharedDocumentController.currentDocument;
	NSURL *url = doc.fileURL;
	
	if (url) {
		NSArray *versions = [BeatBackup backupsWithName:url.lastPathComponent.stringByDeletingPathExtension];
		
		NSDateFormatter* df = NSDateFormatter.new;
		[df setDateStyle:NSDateFormatterShortStyle];
		[df setTimeStyle:NSDateFormatterShortStyle];
		
		// Revert to saved
		BeatMenuItemWithURL *toSaved = [BeatMenuItemWithURL.alloc initWithTitle:NSLocalizedString(@"backup.revertToSaved", nil) action:@selector(revertTo:) keyEquivalent:@""];
		toSaved.url = doc.fileURL;
		toSaved.tag = NSNotFound;
		[menu addItem:toSaved];
		
		// Browse versions
		if (@available(macOS 13.0, *)) {
			// NSMenuItem *browse = [NSMenuItem.alloc initWithTitle:NSLocalizedString(@"backup.browseVersions", nil) action:@selector(browseVersions:) keyEquivalent:@""];
			// [menu addItem:browse];
		}
		
		[menu addItem:NSMenuItem.separatorItem];
		
		for (BeatBackupFile *version in versions) {
			NSString *modificationTime = [df stringFromDate:version.date];
			BeatMenuItemWithURL *item = [BeatMenuItemWithURL.alloc initWithTitle:modificationTime action:@selector(restoreBackup:) keyEquivalent:@""];
			item.url = [NSURL fileURLWithPath:version.path];
			[menu addItem:item];
		}
		
		if (versions.count) {
			[menu addItem:NSMenuItem.separatorItem];
		}
	}
	
	NSMenuItem *backupVault = [NSMenuItem.alloc initWithTitle:[BeatLocalization key:@"backup.backupVault"] action:@selector(openBackupFolder:) keyEquivalent:@""];
	[menu addItem:backupVault];
}

- (IBAction)restoreBackup:(id)sender
{
	BeatModalInput *input = BeatModalInput.alloc.init;
	[input confirmBoxWithMessage:[BeatLocalization key:@"backup.reverting.title"]
							text:[BeatLocalization key:@"backup.reverting.message"] forWindow:NSDocumentController.sharedDocumentController.currentDocument.windowForSheet completion:^(bool result) {
		if (!result) return;
		
		BeatMenuItemWithURL *item = sender;
		if (item.url == nil) {
			NSLog(@"ERROR, no URL found");
			return;
		}
		
		NSError *error;
		if (item.url == NSDocumentController.sharedDocumentController.currentDocument.fileURL) {
			// Revert to saved
			[NSDocumentController.sharedDocumentController.currentDocument revertDocumentToSaved:nil];
		} else {
			[NSDocumentController.sharedDocumentController.currentDocument revertToContentsOfURL:item.url ofType:NSPlainTextDocumentType error:&error];
			if (error) NSLog(@"Error: %@", error);
		}
	}];
}

- (IBAction)openBackupFolder:(id)sender
{
	[BeatBackup openBackupFolder];
}

- (void)versionMenuItems
{
	[self.revertMenu removeAllItems];
	
	NSDocument *doc = NSDocumentController.sharedDocumentController.currentDocument;
	NSURL *url = doc.fileURL;
	if (!url) return;
	
	// Get available versions
	NSArray *versions = [NSFileVersion otherVersionsOfItemAtURL:url];
	
	NSDateFormatter* df = NSDateFormatter.new;
	[df setDateStyle:NSDateFormatterShortStyle];
	[df setTimeStyle:NSDateFormatterShortStyle];
	
	// Add revert to saved
	NSMenuItem *toSaved = [[NSMenuItem alloc] initWithTitle:[BeatLocalization key:@"backup.saved"] action:@selector(revertTo:) keyEquivalent:@""];
	toSaved.state = (!doc.isDocumentEdited) ? NSOnState : NSOffState;
	toSaved.tag = NSNotFound;
	
	[self.revertMenu addItem:toSaved];
	[self.revertMenu addItem:NSMenuItem.separatorItem];
	
	// Only allow 10
	NSInteger count = 0;
	
	for (NSInteger i = versions.count - 1; i >= 0; i--) {
		// Don't allow more than 10 versions
		if (count > 10) break;
		
		NSFileVersion *version = versions[i];
		NSString *modificationTime = [df stringFromDate:version.modificationDate];
		
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:modificationTime action:@selector(revertTo:) keyEquivalent:@""];
		item.tag = i;
		
		if ([[(Document*)doc revertedTo] isEqualTo:version.URL]) item.state = NSOnState;
		
		[self.revertMenu addItem:item];
		
		count++;
	}
	
	[self.revertMenu addItem:NSMenuItem.separatorItem];
	[self.revertMenu addItemWithTitle:[BeatLocalization key:@"backup.browseVersions"] action:@selector(browseVersions:) keyEquivalent:@""];
}

- (void)browseVersions:(id)sender
{
	[NSDocumentController.sharedDocumentController.currentDocument browseDocumentVersions:self];
}

- (void)revertTo:(id)sender
{
	BeatModalInput *input = BeatModalInput.alloc.init;
	[input confirmBoxWithMessage:[BeatLocalization key:@"backup.reverting.title"] text:[BeatLocalization key:@"backup.reverting.message"] forWindow:NSDocumentController.sharedDocumentController.currentDocument.windowForSheet completion:^(bool result) {
		if (!result) return;
		
		NSMenuItem *item = sender;
	
		NSError *error;
		
		if (item.tag == NSNotFound) {
			// Revert to saved
			[NSDocumentController.sharedDocumentController.currentDocument revertDocumentToSaved:nil];
			return;
		}
		
		NSArray *versions = [NSFileVersion otherVersionsOfItemAtURL:NSDocumentController.sharedDocumentController.currentDocument.fileURL];
		NSFileVersion *version = versions[item.tag];
		
		[NSDocumentController.sharedDocumentController.currentDocument revertToContentsOfURL:version.URL ofType:NSPlainTextDocumentType error:&error];
		if (error) NSLog(@"Error: %@", error);
		
	} buttons:@[[BeatLocalization key:@"revert.revertAction"], [BeatLocalization key:@"general.cancel"]]];
}


@end
