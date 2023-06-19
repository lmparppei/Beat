//
//  BeatFileImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.9.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This is a generic import-module for Beat. Classes for different import options
 don't (yet) register themselves, so they have to be added as IBActions into
 this class.
 
 Basic functionality:
 Create a new class (FormatImport) and include it in this class. Either make the
 class return a string when importing, or have it set a string called [ClassName].script
 after the open dialog (see examples). Then call [self openFileWithContents:className.script];
 
 Import currently supports:
 - Highland
 - FadeIn (though this is mostly untested)
 - CeltX
 - FDX
 
 Future considerations/TODO:
 - Make the different import methods register themselves without loading them into memory
 - Fix import plugin menu item in App Deegate!!!
 
 */

#import "BeatFileImport.h"
#import "HighlandImport.h"
#import "CeltxImport.h"
#import "FDXImport.h"
#import "FadeInImport.h"

@interface BeatFileImport ()
@property (nonatomic) NSURL *url;
@property (nonatomic) NSMutableArray* checkboxes;
@property (nonatomic) NSView* accessoryView;
@end
@implementation BeatFileImport

- (void)openDialogForFormat:(NSString*)extension completion:(void(^)(void))callback {
	[self openDialogForFormats:@[extension] completion:callback];
}
- (void)openDialogForFormats:(NSArray*)extensions completion:(void(^)(void))callback {
	_url = nil;
	
	NSOpenPanel *openDialog = NSOpenPanel.openPanel;
	
	
	openDialog.accessoryView = _accessoryView;
	openDialog.accessoryViewDisclosed = YES;
	
	[openDialog setAllowedFileTypes:extensions];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK && openDialog.URL) {
			self.url = openDialog.URL;
			callback();
		}
	}];
}

- (void)addCheckbox:(NSButton*)checkbox {
	if (_checkboxes == nil) _checkboxes = NSMutableArray.new;
	[_checkboxes addObject:checkbox];
	
	if (self.accessoryView == nil) {
		self.accessoryView = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 600, 100)];
	}
	
	// Adjust the frame of the checkbox
	
	NSSize size = [checkbox fittingSize];
	NSRect checkboxFrame = checkbox.frame;
	checkboxFrame.origin.x = 20.0;
	checkboxFrame.origin.y = 20.0 * self.accessoryView.subviews.count + 20.0;
	checkboxFrame.size.width = size.width;
	checkboxFrame.size.height = size.height;
	checkbox.frame = checkboxFrame;

	[self.accessoryView addSubview:checkbox];
	
	CGFloat height = 0.0;
	for (NSView* view in self.accessoryView.subviews) {
		height += view.frame.size.height;
	}
	height += 40.0;

	NSRect frame = self.accessoryView.frame;
	frame.size.height = height;
	self.accessoryView.frame = frame;
	

}

- (void)fdx {
	// The XML reader works asynchronously, so we'll put a completion handler inside the completion handler
	__block NSButton* importNotes = NSButton.new;
	[importNotes setButtonType:NSSwitchButton];
	[importNotes setTitle:@"Import Final Draft notes (WARNING: Can cause formatting issues in some cases)"];

	[self addCheckbox:importNotes];
	
	[self openDialogForFormat:@"fdx" completion:^{
	__block FDXImport *fdxImport;
	
		bool notes = (importNotes.state == NSOnState);
		fdxImport = [FDXImport.alloc initWithURL:self.url importNotes:notes completion:^(void) {
			if (fdxImport.script.count > 0) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[self openFileWithContents:fdxImport.scriptAsString];
				});
			}
		}];
	}];
}

- (void)fadeIn {
	[self openDialogForFormat:@"fadein" completion:^{
		FadeInImport *import = [FadeInImport.alloc initWithURL:self.url];
		if (import.script) [self openFileWithContents:import.script];
	}];
}

- (void)highland {
	[self openDialogForFormat:@"highland" completion:^{
		HighlandImport *import = [HighlandImport.alloc initWithURL:self.url];
		if (import.script) [self openFileWithContents:import.script];
	}];
}

- (void)celtx {
	[self openDialogForFormats:@[@"celtx", @"cxscript"] completion:^{
		CeltxImport *import = [CeltxImport.alloc initWithURL:self.url];
		if (import.script) [self openFileWithContents:import.script];
	}];
}

- (void)openFileWithContents:(NSString*)string {
	NSURL *tempURL = [self URLForTemporaryFileWithPrefix:@"fountain"];
	NSError *error;
	
	[string writeToURL:tempURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
	[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:tempURL copying:YES displayName:@"Untitled" error:nil];
}

- (NSURL *)URLForTemporaryFileWithPrefix:(NSString *)prefix
{
	NSURL  *  result;
	CFUUIDRef   uuid;
	CFStringRef uuidStr;

	uuid = CFUUIDCreate(NULL);
	assert(uuid != NULL);

	uuidStr = CFUUIDCreateString(NULL, uuid);
	assert(uuidStr != NULL);
	result = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.%@", prefix, uuidStr, prefix]]];
	
	assert(result != nil);

	CFRelease(uuidStr);
	CFRelease(uuid);

	return result;
}

@end
/*
 
 seisottiin puutarhassa ja katsottiin tähtiä
 enkä ollut nähnyt linnunrataa
 niin kirkkaana
 aikoihin
 
 tunnen itseni pieneksi
 sinua se pelottaa
 mutta olen tässä
 tällä planeetalla
 näinä atomeina
 sinun kanssasi
 tässä puutarhassa
 tänä yönä.
 
 */
