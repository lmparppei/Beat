//
//  Line+Versions.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 28.5.2026.
//

#import "Line+Versions.h"

#define ALTERNATIVE_PREFIX @"/** ALTERNATIVES: "

/**
 Line alternative implementation.
 */
@implementation Line (Versions)

/// Steps current version down/up by the given number (either positive or negative). Returns the metadata for an alternative version of this line
/// - warning: This method **DOES NOT** replace anything, but instead returns the text and possible revisions of the line. You will need to handle the actual replacement yourself in editor.
- (NSDictionary*)stepVersion:(NSInteger)amount
{
    NSInteger i = self.currentVersion + amount;
    return [self switchVersion:i];
}

/// Switches to given version. Returns the metadata for an alternative version of this line
/// - warning: This method **DOES NOT** replace anything, but instead returns the text and possible revisions of the line. You will need to handle the actual replacement yourself in editor.
- (NSDictionary*)switchVersion:(NSInteger)index
{
    if (index < 0 || index == NSNotFound || index >= self.versions.count) return nil;
    
    // First, store the previous version
    [self storeVersion];
    
    // Then inform the editor that it should switch to this version
    self.currentVersion = index;
    return self.versions[index];
}

/// Stores the current version of this line
/// - note: You need to have baked the revisions in the text for this to work correctly. The parser is completely detached from the attributed text, so the line object doesn't know whether there are some attributes in its current string range. That's why only baked revisions are stored into the line version data.
- (void)storeVersion
{
    if (self.versions == nil) self.versions = NSMutableArray.new;

    self.versions[self.currentVersion] = @{
        @"text": self.string,
        @"revisions": (self.revisedRanges != nil) ? self.revisedRanges : @{}
    };
}

/// Adds a new version of this text.
/// - note: You need to have baked the revisions in the text for this to work correctly
- (void)addVersion
{
    [self storeVersion];
    [self.versions addObject:@{
        @"text": self.string,
        @"revisions": (self.revisedRanges != nil) ? self.revisedRanges : @{}
    }];
    self.currentVersion = self.versions.count - 1;
}


/// Reads possible line alternatives in the line `** ALTERNATIVES: ... *` and removes that block from the line string content.
- (void)readAlternativesAndCleanString
{
    NSRange rangeOfVersionData = [self.string rangeOfString:ALTERNATIVE_PREFIX];
    if (rangeOfVersionData.location == NSNotFound) return;
    
    NSString* rawString = self.string.copy;
    
    // Remove the alternative data
    self.string = [self.string substringToIndex:rangeOfVersionData.location];
        
    // Get the alternative data
    NSString* versionData = [rawString substringFromIndex:NSMaxRange(rangeOfVersionData)];
    // Remove the * at the end
    NSInteger lastStar = [versionData locationOfLastOccurenceOf:'*'];
    if (lastStar < versionData.length && [versionData characterAtIndex:lastStar+1] == '/') {
        versionData = [versionData substringToIndex:lastStar];
    }
    
    NSData* d = [versionData dataUsingEncoding:NSUTF8StringEncoding];
    NSError* e;
    NSDictionary* versionDict = [NSJSONSerialization JSONObjectWithData:d options:0 error:&e];
    
    if (e != nil) {
        NSLog(@"!!! Error reading version data: %@", e);
        return;
    }
    
    NSArray<NSDictionary*>* alternatives = versionDict[@"versions"];
    NSMutableArray<NSDictionary<NSString*, id>*>* versions = NSMutableArray.new;
    
    for (NSDictionary* alt in alternatives) {
        NSString* text = alt[@"text"];
        NSDictionary* jsonRevisions = alt[@"revisions"];
        
        NSMutableDictionary<NSNumber*,NSMutableIndexSet*>* revisions = NSMutableDictionary.new;
        
        for (NSString* key in jsonRevisions.allKeys) {
            // These arrays contain ranges as two-number arrays: [loc, len]
            NSArray<NSArray*>* values = jsonRevisions[key];
            NSMutableIndexSet* indices = NSMutableIndexSet.new;
            NSInteger generation = key.integerValue;
            
            for (NSArray<NSNumber*>* value in values) {
                if (value.count < 2) continue;
                NSNumber* loc = value[0];
                NSNumber* len = value[1];
                
                NSRange range = NSMakeRange(loc.intValue, len.intValue);
                [indices addIndexesInRange:range];
            }
            
            revisions[@(generation)] = indices;
        }
        
        [versions addObject:@{
            @"text": text,
            @"revisions": revisions
        }];
    }
    
    self.versions = versions;
    self.currentVersion = ((NSNumber*)versionDict[@"current"]).intValue;
    if (self.currentVersion >= self.versions.count) self.currentVersion = self.versions.count-1;
}

/// Returns line versions ready to be serialized to JSON.
- (NSArray<NSDictionary*>*)versionsForSerialization
{
    NSMutableArray<NSDictionary*>* versions = [NSMutableArray.alloc initWithCapacity:self.versions.count];
    
    for (NSDictionary* v in self.versions.copy) {
        NSMutableDictionary<NSString*,id>* version = v.mutableCopy;
        
        NSDictionary* originalRanges = (NSDictionary*)version[@"revisions"];
        NSMutableDictionary<NSString*, NSArray<NSArray<NSNumber*>*>*>* revisedRanges = [NSMutableDictionary.alloc initWithCapacity:originalRanges.count];
        
        for (NSNumber* key in originalRanges.allKeys) {
            NSIndexSet* indices = originalRanges[key];
            NSMutableArray<NSArray<NSNumber*>*>* ranges = NSMutableArray.new;
            
            [indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
                [ranges addObject:@[@(range.location), @(range.length)]];
            }];
                        
            revisedRanges[key.stringValue] = ranges; // The key has to be explicitly a string for JSON serialization to work
        }
        
        version[@"revisions"] = revisedRanges;
        
        [versions addObject:version];
    }
    
    return versions;
}

@end
/*
 
 aika katua tulevia tekoja
 aika anoa itseltä anteeksiantoa
 aika teroittaa kynsiä
 aika kirjoittaa repiviä sanoja
 
 aika ihailla ilotulituksia parkkihallien katoilla
 aika juhlia uutta vuotta
 suudelmilla ja polttamalla autoja
 
 aika ajaa raviradan ohi
 aika paeta murtuvia patoja
 aika tuijottaa mustaan jokeen
 aika varoa liukasta kivikkoa
 
 nyt on aika aloittaa lakkoja
 aika maksaa muiden sakkoja
 aika kaataa RAJAMUUREJA
 aika kaataa hallituksia
 
 mä oon valmis
 ottakaa mut mukaan
 mä vaan odotan ett'
 otatte mut mukaan
 olen valmis
 ottakaa mut mukaan
 olen valmis
 tulkaa
 hakemaan
 
 */
