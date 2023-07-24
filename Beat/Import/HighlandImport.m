//
//  HighlandImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "HighlandImport.h"
#import <UnzipKit/UnzipKit.h>

@implementation HighlandImport

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
		// We only gather the ones which are SCRIPTS
		if ([string rangeOfString:@"fountain"].location != NSNotFound) {
			scriptData = [container extractDataFromFile:string error:&error];
			break;
		}
	}
	
	_script = [[NSString alloc] initWithData:scriptData encoding:NSUTF8StringEncoding];
}

@end
