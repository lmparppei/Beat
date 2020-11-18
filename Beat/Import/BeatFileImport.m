//
//  BeatFileImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.9.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//
/*
 
 Generic reader for:
 - Highland
 - FadeIn
 - FDX
 
 */

#import "BeatFileImport.h"
#import "HighlandImport.h"
#import "CeltxImport.h"
#import "FDXImport.h"
#import "FadeInImport.h"

@interface BeatFileImport ()
@property (nonatomic) NSURL *url;
@end
@implementation BeatFileImport

//- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback

- (void)openDialogForFormat:(NSString*)extension completion:(void(^)(void))callback {
	_url = nil;
	
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	[openDialog setAllowedFileTypes:@[extension]];
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result == NSFileHandlingPanelOKButton) {
			if (openDialog.URL) {
				self.url = openDialog.URL;
				callback();
			}
		}
	}];
}

- (void)fdx {
	// The XML reader works asynchronously, so we completion handlers inside completion handlers
	[self openDialogForFormat:@"fdx" completion:^{
	__block FDXImport *fdxImport;
	
		fdxImport = [[FDXImport alloc] initWithURL:self.url completion:^(void) {
			if ([fdxImport.script count] > 0) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[self openFileWithContents:fdxImport.scriptAsString];
				});
			}
		}];
	}];
}

- (void)fadeIn {
	[self openDialogForFormat:@"fadein" completion:^{
		FadeInImport *import = [[FadeInImport alloc] initWithURL:self.url];
		if (import.script) [self openFileWithContents:import.script];
	}];
}

- (void)highland {
	[self openDialogForFormat:@"highland" completion:^{
		HighlandImport *import = [[HighlandImport alloc] initWithURL:self.url];
		if (import.script) [self openFileWithContents:import.script];
	}];
}

- (void)celtx {
	[self openDialogForFormat:@"celtx" completion:^{
		CeltxImport *import = [[CeltxImport alloc] initWithURL:self.url];
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
