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
#import <BeatCore/BeatRevisions.h>
#import <BeatCore/DiffMatchPatch.h>
#import <CommonCrypto/CommonDigest.h>

@implementation BeatVersionControl
static NSString* dateFormat = @"yyyy-MM-dd HH:mm:ss";
static NSString* key = @"VersionControl";
static NSString* settingSeparator = @"<__SETTINGS__>";

+ (NSString*)dateFormat { return dateFormat; }
+ (NSString*)settingKey { return key; }
+ (NSString*)settingSeparator { return settingSeparator; }
+ (NSString*)checksumForData:(NSData *)data
{
    NSString* input = [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
    
    const char* str = input.UTF8String;
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(str, (CC_LONG)strlen(str), result);

    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_SHA256_DIGEST_LENGTH; i++)
        [ret appendFormat:@"%02x",result[i]];

    return ret;
}
/// Returns a checksum for dictionary. We need to sort the keys to get consistent values for sha256.
+ (NSString *)checksumForDictionary:(NSDictionary *)dict
{
    NSError *error;
    
    NSArray *sortedKeys = [dict.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableDictionary* newDict = NSMutableDictionary.new;
    
    for (NSString *key in sortedKeys) {
        newDict[key] = dict[key];
    }
    
    NSData* data = [NSJSONSerialization dataWithJSONObject:newDict options:0 error:&error];
    if (error) return nil;
    else return [self checksumForData:data];
}


#pragma mark - Initializer

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}


#pragma mark - Main helpers and shorthands

/// Returns `true` if a version control JSON exists
- (bool)hasVersionControl
{
    return [self.delegate.documentSettings get:BeatVersionControl.settingKey] != nil;
}

- (NSMutableDictionary*)versionControlDictionary
{
    return ((NSDictionary*)[self.delegate.documentSettings get:BeatVersionControl.settingKey]).mutableCopy;
}

- (NSArray<NSDictionary*>*)commits
{
    NSArray* commits = self.versionControlDictionary[@"commits"];
    return (commits != nil) ? commits : @[];
}


#pragma mark - Version control dictinoary health check

/// Checks the health of the version control dictionary. `false` means something is wrong.
- (bool)doHealthCheck
{
    NSMutableDictionary* vcDict = self.versionControlDictionary.mutableCopy;
    NSString* storedChSum = vcDict[@"checksum"];

    [vcDict removeObjectForKey:@"checksum"];
    
    // If we're just starting, health is always OK
    if (vcDict.count == 0 || storedChSum == nil) return true;
    
    bool result = true;
    NSString* chSum = [BeatVersionControl checksumForDictionary:vcDict];
    
    if (storedChSum != nil)
        result = [chSum isEqualToString:storedChSum];

    if (!result) {
        NSLog(@"🆘 WARNING: Version control health error. Checksum won't be stored.");
    } else {
        [self storeChecksum:chSum];
    }
    
    return result;
}

- (void)resetChecksum
{
    [self storeChecksum:nil];
}

/// Stores a checksum for the version control dictionary to keep up the health
- (void)storeChecksum:(NSString*)checksum
{
    NSMutableDictionary* vcDict = self.versionControlDictionary.mutableCopy;
    if (vcDict.count == 0) return;

    // Don't calculate actual checksum to the checksum
    [vcDict removeObjectForKey:@"checksum"];
    
    if (checksum == nil) {
        // Calculate checksum
        checksum = [BeatVersionControl checksumForDictionary:vcDict];
    }
    
    // Store the new checksum
    vcDict[@"checksum"] = checksum;
    [self.delegate.documentSettings set:BeatVersionControl.settingKey as:vcDict];
}


#pragma mark - Getting versions

- (NSString*)baseText
{
    return [self textAt:nil];
}

/// Returns the __readable__ text state at given timestamp, so in other words builds the full text from previous deltas. If you want to compare actual committed versions, use `committedTextAt:`.
/// - note: If you pass a non-timestamp argument or `nil`, you'll probably get the FULL TEXT with all commits. Passing `"base"` will give you the base text.
- (NSString* _Nullable)textAt:(NSString* _Nullable)timestamp
{
    NSString* baseText = [self committedTextAt:timestamp];
    
    // Reconstruct settings
    NSRange settingsRange = [baseText rangeOfString:BeatVersionControl.settingSeparator];
    if (settingsRange.location != NSNotFound) {
        
        NSString* originalText = [baseText substringToIndex:settingsRange.location];
        NSString* settingsInBase64 = [baseText substringFromIndex:NSMaxRange(settingsRange)];
        NSData* settings = [NSData.alloc initWithBase64EncodedString:settingsInBase64 options:0];
        NSString* decodedSettings = [NSString.alloc initWithData:settings encoding:0];
        
        if (decodedSettings != nil)
            baseText = [originalText stringByAppendingString:decodedSettings];
    }
    
    return baseText;
}

/// Returns the __committed__ text at given timestamp. Committed text has the settings block gzipped. If you want to get the actual, readable text, use `textAt:`.
- (NSString*)committedTextAt:(NSString* _Nullable)timestamp {
    NSDictionary* versionControl = self.versionControlDictionary;
    NSString* baseText = ((NSString*)versionControl[@"base"]).gzipDecompressedString;
    
    if (![timestamp isEqualToString:@"base"] && baseText != nil) {
        // Reconstruct the current version
        DiffMatchPatch *dmp = [[DiffMatchPatch alloc] init];
        NSString *currentText = baseText;
        
        for (NSDictionary *commit in versionControl[@"commits"]) {
            NSError* error;
            NSArray *patches = [dmp patch_fromText:commit[@"patch"] error:&error];
            if (error) {
                NSLog(@"Error parsing patch: %@", error.localizedDescription);
                continue;
            }

            // Apply patch to the last successfully patched text
            NSArray *patchResult = [dmp patch_apply:patches toString:currentText];
            currentText = patchResult[0];

            // If this is the requested timestamp, return it
            NSString* commitTime = (NSString*)commit[@"timestamp"];
            if ([timestamp isEqualToString:commitTime]) break;
        }
        
        return currentText;
    }
    
    return baseText;
}


#pragma mark - Committing

- (NSString*)textToCommit
{
    // Create a dummy setting block with only the essential stuff. We'll encode the JSON to avoid confusion
    NSString* text = self.delegate.text;
    NSString* settings = [self.delegate.documentSettings getSettingsStringWithKeys:BeatDocumentSettings.essentialValues];
    // base64 version
    NSData* settingsData = [settings dataUsingEncoding:NSUTF8StringEncoding];
    
    text = [text stringByAppendingFormat:@"%@%@", BeatVersionControl.settingSeparator, (settingsData != nil) ? [settingsData base64EncodedDataWithOptions:0]: @""];
    
    return text;
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
    [self addCommitWithMessage:@""];
}

- (void)addCommitWithMessage:(NSString* _Nullable)message
{
    NSMutableDictionary* versionControl = self.versionControlDictionary;
    
    NSString* text = self.textToCommit;
    NSString* latestText = [self committedTextAt:self.latestTimestamp];
    
    // Create new patch
    DiffMatchPatch *dmp = [[DiffMatchPatch alloc] init];
    NSMutableArray *patches = [dmp patch_makeFromOldString:latestText andNewString:text];
    NSString *patchText = [dmp patch_toText:patches];
    
    // Add commit to the array
    NSMutableArray *commits = ((NSArray*)versionControl[@"commits"]).mutableCopy;
    NSMutableDictionary *commit = @{
        @"timestamp": self.currentTimestamp,
        @"patch": patchText
    }.mutableCopy;
    // Add message if provided
    if (message != nil && message.length > 0) commit[@"message"] = message;
    
    [commits addObject:commit];
    versionControl[@"commits"] = commits;
    
    [self.delegate.documentSettings set:BeatVersionControl.settingKey as:versionControl];
    [self storeChecksum:nil];
}

- (void)stopVersionControl
{
    [self.delegate.documentSettings remove:BeatVersionControl.settingKey];
}

- (BOOL)hasUncommittedChanges
{
    NSString* current = self.textToCommit;
    NSString* committed = [self committedTextAt:nil];

    return ![current isEqualToString:committed];
}

- (NSString* _Nullable)revertTo:(NSString*)timestamp
{
    NSMutableArray* commits = self.commits.mutableCopy;
    NSString* result = [self textAt:timestamp];
    
    bool found = false;
    // If the timestamp is nil, we'll delete ALL commits and just spare the base
    if (timestamp == nil || [timestamp isEqualToString:@"base"]) found = true;
    
    // Delete all timestamps after this one
    for (NSDictionary* commit in commits.copy) {
        if (found) {
            [commits removeObject:commit];
            continue;
        }
        
        NSString* commitTime = commit[@"timestamp"];
        if ([commitTime isEqualToString:timestamp]) found = true;
    }
    
    // The stored deltas DO NOT have version control data, so we need to reconstruct that.
    // 1) First save the truncated commits
    NSMutableDictionary* vc = self.versionControlDictionary;
    vc[@"commits"] = commits;
    [self.delegate.documentSettings set:BeatVersionControl.settingKey as:vc];

    // 2) Read the settings block from restored text to a setting object and store current version control data (up to selected point)
    BeatDocumentSettings* settings = BeatDocumentSettings.new;
    NSRange settingsRange = [settings readSettingsAndReturnRange:result];
    // Remove the old settings (if applicable)
    if (settingsRange.length > 0) {
        result = [result substringToIndex:settingsRange.location];
    }
    
    
    // Inject version control data
    NSString* checksum = [BeatVersionControl checksumForDictionary:vc];
    vc[@"checksum"] = checksum;
    [settings set:BeatVersionControl.settingKey as:vc];

    // Rebuild the content
    NSString* settingsString = settings.getSettingsString;
    result = [result stringByAppendingString:settingsString];
    
    return result;
}


#pragma mark - Get commit metadata

- (NSDictionary<NSString*, id>* _Nullable)getCommitWithTimestamp:(NSString*)timestamp
{
    if (timestamp == nil) return nil;
    
    NSDictionary* versionControl = self.versionControlDictionary;
    NSArray* commits = versionControl[@"commits"];
    for (NSDictionary* commit in commits) {
        NSString* commitTime = commit[@"timestamp"];
        if ([commitTime isEqualToString:timestamp]) return commit;
    }
    
    return nil;
}

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

- (NSString* _Nullable)latestTimestamp
{
    return self.timestamps.lastObject;
}

/// Private helper method for current snapshot/commit timestamp
- (NSString*)currentTimestamp
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:BeatVersionControl.dateFormat];
    [formatter setTimeZone:[NSTimeZone localTimeZone]]; // Use local timezone

    return [formatter stringFromDate:NSDate.date];
}


#pragma mark - Generate revisions

- (void)generateRevisedRangesFrom:(NSString*)timestamp generation:(NSInteger)generation
{
    NSString* oldText = [self textWithoutEncodedSettingsAt:timestamp];
    [self generateRevisedRangesFromText:oldText generation:generation];
}

- (void)generateRevisedRangesFromText:(NSString *)oldText generation:(NSInteger)generation
{
    NSString* currentText = self.delegate.text;
    
    NSArray<Diff*>* diffs = [self diffsFrom:currentText with:oldText];
    
    // Go through the changed indices and calculate their positions
    NSMutableIndexSet *changedIndices = NSMutableIndexSet.new;
    NSInteger i = 0;

    for (Diff* d in diffs) {
        if (d.operation == DIFF_EQUAL) {
            i += d.text.length;
        } else if (d.operation == DIFF_INSERT) {
            [changedIndices addIndexesInRange:NSMakeRange(i, d.text.length)];
            i += d.text.length;
        }
    }
    
    [self.delegate.revisionTracking addRevisions:changedIndices generation:generation];
}

- (NSString*)textWithoutEncodedSettingsAt:(NSString*)timestamp
{
    NSString* text = [self committedTextAt:timestamp];
    NSInteger settingLocation = [text rangeOfString:BeatVersionControl.settingSeparator].location;
    if (settingLocation != NSNotFound) {
        text = [text substringToIndex:settingLocation];
    }
    
    return text;
}

- (NSArray*)diffsFrom:(NSString*)newString with:(NSString*)oldString {
    DiffMatchPatch *dmp = DiffMatchPatch.new;
    NSMutableArray *diffs = [dmp diff_mainOfOldString:oldString andNewString:newString];
    [dmp diff_cleanupSemantic:diffs];
    return diffs;
}


/*
 - (NSAttributedString*)getRevisionsComparing:(NSArray*)script with:(NSString*)oldScript fromIndex:(NSInteger)startIndex {
     NSMutableString *newScript = [NSMutableString string];
     for (Line *line in script) {
         if (line.position >= startIndex) {
             [newScript appendString:line.string];
             if (line != script.lastObject) [newScript appendString:@"\n"];
         }
     }
     
     oldScript = [oldScript substringFromIndex:startIndex];
     NSArray *diffs = [self diffReportFrom:newScript with:oldScript];
     
     NSMutableAttributedString *attrStr = [NSMutableAttributedString.alloc initWithString:(newScript) ? newScript : @""];
     
     // Go through the changed indices and calculate their positions
     // NB: We are running diff-match-patch in line mode, so basically the line indices for inserts should do.
     NSInteger index = 0;
     NSMutableIndexSet *changedIndices = [NSMutableIndexSet indexSet];
     
     NSMutableArray *changedRanges = [NSMutableArray array];
     
     for (Diff *d in diffs) {
         if (d.operation == DIFF_EQUAL) {
             index += d.text.length;
         }
         else if (d.operation == DIFF_INSERT) {
             // This is a new line
             [changedIndices addIndex:index];
             NSRange changedRange = NSMakeRange(index, d.text.length);
             [changedRanges addObject:[NSNumber valueWithRange:changedRange]];
             
             index += d.text.length;
         } else {
             // ... and ignore deletions.
         }
         
     }
     
     // Go through the parsed lines and look if they are contained within changed ranges
     for (Line *l in script) {
         // Skip some elements (and ignore anything unchanged)
         if ((l.position < startIndex) ||
             (l.type == empty || l.isTitlePage)) {
             l.changed = NO;
             continue;
         }
                 
         NSRange lineRange = l.textRange;
         for (NSNumber *rangeNum in changedRanges) {
             NSRange range = rangeNum.rangeValue;
             range = (NSRange){ range.location + startIndex, range.length };
             
             if (NSIntersectionRange(range, lineRange).length > 0) {
                 BeatRevisionItem *revision = [BeatRevisionItem type:RevisionAddition generation:0];
                 [attrStr addAttribute:BeatRevisions.attributeKey value:revision range:range];
             }
         }
     }
     
     return attrStr;
 }
 */


@end
