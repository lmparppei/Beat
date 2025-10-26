//
//  Document+Autosave.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 10.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+Autosave.h"
#import "BeatAppDelegate.h"

@implementation Document (Autosave)


#pragma mark - Autosave
/**
 Beat has *three* kinds of autosave: autosave vault, saving in place and automatic macOS autosave. This
 */

/// Returns `true` if user has toggled Beat autosave on
- (BOOL)autosave
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingAutosave];
}

+ (BOOL)autosavesInPlace { return NO; }

+ (BOOL)autosavesDrafts { return YES; }

+ (BOOL)preservesVersions {
	// Versions are only supported from 12.0+ because of a strange bug in older macOSs
	// WHY IS THIS BUGGY? It works but produces weird error messages.
	//if (@available(macOS 13.0, *)) return YES;
	// else return NO;
	return NO;
}

/// Custom autosave in place
- (void)autosaveInPlace
{
	if (self.autosave && self.documentEdited && self.fileURL) {
		[self saveDocument:nil];
	} else {
		if ([NSFileManager.defaultManager fileExistsAtPath:self.autosavedContentsFileURL.path]) {
			bool autosave = [BeatBackup backupWithDocumentURL:self.autosavedContentsFileURL name:self.fileNameString autosave:true];
			if (!autosave) NSLog(@"AUTOSAVE ERROR");
		}
	}
}

/// Before the user chooses where to place a new document, it has an autosaved URL only.
- (NSURL *)mostRecentlySavedFileURL;
{
	NSURL *result = [self autosavedContentsFileURL];
	if (result == nil) result = [self fileURL];
	return result;
}

- (NSURL*)autosavedContentsFileURL
{
	NSString *filename = self.fileNameString;
	NSString* extension = self.fileURL.pathExtension;
	if (!filename) filename = @"Untitled";
	if (!extension) extension = @"fountain";
	
	NSURL *autosavePath = [self autosavePath];
	autosavePath = [autosavePath URLByAppendingPathComponent:filename];
	autosavePath = [autosavePath URLByAppendingPathExtension:extension];
	
	return autosavePath;
}

- (NSURL*)autosavePath
{
	return [BeatPaths appDataPath:@"Autosave"];
}

- (void)autosaveDocumentWithDelegate:(id)delegate didAutosaveSelector:(SEL)didAutosaveSelector contextInfo:(void *)contextInfo
{
	self.autosavedContentsFileURL = [self autosavedContentsFileURL];
	[super autosaveDocumentWithDelegate:delegate didAutosaveSelector:didAutosaveSelector contextInfo:contextInfo];
	
	[NSDocumentController.sharedDocumentController setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
}

- (BOOL)hasUnautosavedChanges
{
	// Always return YES if the file is a draft
	if (self.fileURL == nil) return YES;
	else { return [super hasUnautosavedChanges]; }
}

- (void)setupAutosave
{
	self.autosaveTimer = [NSTimer scheduledTimerWithTimeInterval:AUTOSAVE_INPLACE_INTERVAL target:self selector:@selector(autosaveInPlace) userInfo:nil repeats:YES];
}

- (void)saveDocumentAs:(id)sender
{
	[super saveDocumentAs:sender];
}

-(void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
	[super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}


@end
