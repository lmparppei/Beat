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

/**
 
 Fade In files are actually wrapped OSF files, although they come with incompatible lowercase tags for some reason.
 The actual screenplay is called `document.xml` in the ZIP archive, so this module only fetches the XML from the archive and hands it off to OSF import module.
 
 */
@implementation FadeInImport

+ (bool)asynchronous { return false; }
+ (NSArray<NSString *> * _Nullable)UTIs { return nil; }
+ (NSArray<NSString *> * _Nonnull)formats { return @[@"fadeIn", @"fadein"]; }

- (id)initWithURL:(NSURL*)url options:(NSDictionary* _Nullable)options completion:(void(^ _Nullable)(NSString*))callback
{
    self = [super init];
    if (self) {
        self.callback = callback;
        [self readFromURL:url];
    }
    return self;
}

- (void)readFromURL:(NSURL*)url
{
	NSError *error;
	
	UZKArchive *container = [[UZKArchive alloc] initWithURL:url error:&error];
	if (error || !container) return;
	
	NSData *scriptData;
	NSArray<NSString*> *filesInArchive = [container listFilenames:&error];
    
    // Find the actual file in container
	for (NSString *string in filesInArchive) {
		if ([string rangeOfString:FILENAME].location != NSNotFound) {
			scriptData = [container extractDataFromFile:string error:&error];
			break;
		}
	}
	
    // We can parse XML in sync when providing a data object. I don't know why.
	if (scriptData != nil) {
		OSFImport *import = [[OSFImport alloc] initWithData:scriptData];
		_script = import.script;
	}
}

- (NSString *)fountain
{
    return self.script;
}

@end
