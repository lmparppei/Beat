//
//  BeatVersionControl.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 23.2.2025.
//

#import "BeatVersionControl.h"
#import <BeatParsing/BeatDocumentSettings.h>
#import <BeatCore/BeatEditorDelegate.h>
#import <BeatCore/NSString+Compression.h>
#import <BeatCore/DiffMatchPatch.h>

@implementation BeatVersionControl

static NSString* key = @"VersionControl";
+ (NSString*)settingKey {
    return key;
}

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}

/// Returns `true` if a version control JSON exists
- (bool)hasVersionControl
{
    return [self.delegate.documentSettings get:@"VersionControl"] != nil;
}

- (NSMutableDictionary*)versionControlDictionary
{
    return ((NSDictionary*)[self.delegate.documentSettings get:BeatVersionControl.settingKey]).mutableCopy;
}

- (NSString*)fullText
{
    return  [self textAt:nil];
}

/// Returns the text state at given timestamp, so in other words builds the full text from previous deltas.
/// - note: If you pass a non-timestamp argument or `nil`, you'll probably get the FULL TEXT with all commits. Passing `"base"` will give you the base text.
- (NSString* _Nullable)textAt:(NSString* _Nullable)timestamp
{
    NSDictionary* versionControl = self.versionControlDictionary;
    NSString* baseText = ((NSString*)versionControl[@"base"]).gzipDecompressedString;
    
    // If no timestamp is given, we'll just return the base text
    if ([timestamp isEqualToString:@"base"] || baseText == nil) return baseText;
    
    // Reconstruct the latest version by applying all underlying patches until given timestamp
    DiffMatchPatch *dmp = [[DiffMatchPatch alloc] init];
    for (NSDictionary *commit in versionControl[@"commits"]) {
        NSError* error;
        NSArray *patches = [dmp patch_fromText:commit[@"patch"] error:&error];
        baseText = [dmp patch_apply:patches toString:baseText][0];
        
        // If this is the last timestamp we want, let's break here
        NSString* commitTime = (NSString*)commit[@"timestamp"];
        if ([timestamp isEqualToString:commitTime]) break;
    }
        
    return baseText;
}


#pragma mark - Committing

- (NSString*)textToCommit
{
    // TODO: Replace this with the full file including settings content
    return self.delegate.text.copy;
}

- (void)createInitialCommit
{
    NSString *text = self.textToCommit.gzipCompressedString;
    NSDictionary* intialVersionControl = @{
        @"base": text,
        @"timestamp": self.currentTimestamp,
        @"commits": @[]
    };
    
    [self.delegate.documentSettings set:BeatVersionControl.settingKey as:intialVersionControl];
}

- (void)addCommit
{
    NSMutableDictionary* versionControl = self.versionControlDictionary;
    
    NSString* text = self.textToCommit;
    NSString* baseText = self.fullText;
    
    // Create new patch
    DiffMatchPatch *dmp = [[DiffMatchPatch alloc] init];
    NSMutableArray *patches = [dmp patch_makeFromOldString:baseText andNewString:text];
    NSString *patchText = [dmp patch_toText:patches];
    
    // Add commit to the array
    NSMutableArray *commits = ((NSArray*)versionControl[@"commits"]).mutableCopy;
    NSDictionary *commit = @{
        @"timestamp": self.currentTimestamp,
        @"patch": patchText
    };
    [commits addObject:commit];
    versionControl[@"commits"] = commits;
    
    [self.delegate.documentSettings set:BeatVersionControl.settingKey as:versionControl];
}

- (void)stopVersionControl
{
    [self.delegate.documentSettings remove:BeatVersionControl.settingKey];
}

- (BOOL)hasUncommittedChanges
{
    NSString* current = self.textToCommit;
    NSString* committed = [self textAt:nil];
    
    return ![current isEqualToString:committed];
}

#pragma mark - Helper methods

- (NSArray<NSString*>*)timestamps
{
    NSDictionary* versionControl = self.versionControlDictionary;
    NSMutableArray<NSString*>* commits = NSMutableArray.new;
    
    for (NSDictionary* commit in versionControl[@"commits"]) {
        NSString* timestamp = commit[@"timestamp"];
        if (timestamp != nil) [commits addObject:timestamp];
    }
    
    return commits;
}

/// Private helper method for current snapshot/commit timestamp
- (NSString*)currentTimestamp
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    [formatter setTimeZone:[NSTimeZone localTimeZone]]; // Use local timezone

    return [formatter stringFromDate:NSDate.date];
}

- (NSString* _Nullable)latestTimestamp
{
    return self.timestamps.lastObject;
}

@end
