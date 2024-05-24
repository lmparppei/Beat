//
//  FadeInImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "FadeInImport.h"
#import <UnzipKit/UnzipKit.h>
#import "OSFImport.h"

#define FILENAME @"document.xml"

@implementation FadeInImport

- (id)initWithURL:(NSURL*)url {
	self = [super init];
	if (self) {
		[self readFromURL:url];
	}
	return self;
}

- (void)readFromURL:(NSURL*)url {
	NSError *error;
	
	UZKArchive *container = [[UZKArchive alloc] initWithURL:url error:&error];
	if (error || !container) return;
	
	NSData *scriptData;
	NSArray<NSString*> *filesInArchive = [container listFilenames:&error];
	for (NSString *string in filesInArchive) {
		// Find the file in container
		if ([string rangeOfString:FILENAME].location != NSNotFound) {
			scriptData = [container extractDataFromFile:string error:&error];
			break;
		}
	}
	
	if (scriptData != nil) {
		OSFImport *import = [[OSFImport alloc] initWithData:scriptData];
		_script = import.script;
	}
}

@end
