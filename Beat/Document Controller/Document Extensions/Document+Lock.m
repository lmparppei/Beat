//
//  Document+Lock.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 25.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+Lock.h"
#import "BeatLockButton.h"
#import "BeatTextView.h"

@implementation Document (Lock)

#pragma mark - Locking The Document

- (void)showLockStatus
{
	[self.lockButton displayLabel];
}

- (bool)contentLocked
{
	return [self.documentSettings getBool:DocSettingLocked];
}

- (IBAction)lockContent:(id)sender
{
	[self toggleLock];
}

- (void)toggleLock
{
	bool locked = [self.documentSettings getBool:DocSettingLocked];
	[self updateChangeCount:NSChangeDone];
	
	if (locked) [self unlock];
	else [self lock];
}

- (void)lock
{
	self.textView.editable = NO;
	[self.documentSettings setBool:@"Locked" as:YES];
	
	[self.lockButton show];
}

- (void)unlock
{
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"unlock_document.title", nil);
	alert.informativeText = NSLocalizedString(@"unlock_document.confirm", nil);
	
	[alert addButtonWithTitle:NSLocalizedString(@"general.yes", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"general.no", nil)];
	
	NSModalResponse response = [alert runModal];
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		self.textView.editable = YES;
		[self.documentSettings setBool:@"Locked" as:NO];
		[self updateChangeCount:NSChangeDone];
		
		[self.lockButton hide];
	}
}


@end
