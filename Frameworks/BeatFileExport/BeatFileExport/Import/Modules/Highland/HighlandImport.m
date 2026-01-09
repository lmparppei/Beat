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

+ (NSArray<NSString *> * _Nullable)UTIs { return nil; }
+ (NSArray<NSString *> * _Nonnull)formats { return @[@"highland"]; }

- (id)initWithURL:(NSURL*)url options:(NSDictionary* _Nullable)options completion:(void(^ _Nullable)(NSString* _Nullable))callback
{
    self = [super init];
    if (self) {
        [self readFromURL:url];
        if (callback != nil) callback(_script);
    }
    
    return self;
}

- (void)readFromURL:(NSURL*)url {
	NSError *error;
	
	UZKArchive *container = [[UZKArchive alloc] initWithURL:url error:&error];
    if (error || !container) {
        _errorMessage = [NSString stringWithFormat:@"Error opening Highland text bundle: %@", error];
        return;
    }
	
	NSData *scriptData;
	NSArray<NSString*> *filesInArchive = [container listFilenames:&error];
    
    if (filesInArchive.count > 0) {
        for (NSString *string in filesInArchive) {
            // We only gather the ones which are SCRIPTS
            if ([string rangeOfString:@"fountain"].location != NSNotFound) {
                scriptData = [container extractDataFromFile:string error:&error];
                break;
            }
        }
        
        if (scriptData != nil)
            _script = [[NSString alloc] initWithData:scriptData encoding:NSUTF8StringEncoding];
    }
}

- (NSString *)fountain
{
    return self.script;
}

@end
