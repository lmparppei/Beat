//
//  ContinuousFountainParser+LineIdentifiers.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 8.3.2026.
//

#import "ContinuousFountainParser+LineIdentifiers.h"

@implementation ContinuousFountainParser (LineIdentifiers)

#pragma mark - Line identifiers (UUIDs)

/// Returns every line UUID as an arrayg
- (NSArray<NSUUID*>*)lineIdentifiers:(NSArray<Line*>* _Nullable)lines
{
    if (lines == nil) lines = self.lines;
    
    NSMutableArray *uuids = NSMutableArray.new;
    for (Line *line in lines) {
        [uuids addObject:line.uuid];
    }
    return uuids;
}

/// Sets the given UUIDs to each line at the same index. Note that you can provide either an array of `NSString`s or __REAL__ `NSUUID`s.
- (void)setIdentifiers:(NSArray* _Nullable)uuids
{
    for (NSInteger i = 0; i < uuids.count; i++) {
        id item = uuids[i];
        // We can have either strings or real UUIDs in the array. Make sure we're using the correct type.
        NSUUID *uuid = ([item isKindOfClass:NSString.class]) ? [NSUUID.alloc initWithUUIDString:item] : item;
                
        if (i < self.lines.count && uuid != nil) {
            Line *line = self.lines[i];
            line.uuid = uuid;
        }
    }
}

/// Sets the given UUIDs to each outline element at the same index
- (void)setIdentifiersForOutlineElements:(NSArray<NSDictionary<NSString*, NSString*>*>*)uuids
{
    if (uuids == nil) return;
    
    for (NSInteger i=0; i<self.outline.count; i++) {
        if (i >= uuids.count) break;
        
        OutlineScene* scene = self.outline[i];
        NSDictionary* item = uuids[i];
        
        NSString* uuidString = item[@"uuid"];
        NSString* string = item[@"string"];
        
        if ([scene.string.lowercaseString isEqualToString:string.lowercaseString]) {
            NSUUID* uuid = [NSUUID.alloc initWithUUIDString:uuidString];
            scene.line.uuid = uuid;
        }
    }
}


/// Returns a fully built map with the UUID as key to identify actual line objects. Note that this BUILDS the full map every time. If you are looking for a specific line at runtime, use `lineWithUUID:`.
- (NSMapTable<NSUUID*, Line*>*)uuidsToLines
{
    @synchronized (self.lines) {
        // Return the cached version when possible -- or when we are not in the main thread.

        if ([self.cachedLines isEqualToArray:self.lines]) {
            return self.uuidsToLinesMap;
        }

        NSArray* lines = self.lines.copy;
        
        // Store the current state of lines
        self.cachedLines = lines;

        // Create UUID map with strong UUID references to weak line objects.
        NSMapTable<NSUUID*, Line*>* uuidTable = [NSMapTable.alloc initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:lines.count];
        
        for (Line* line in lines) {
            if (line == nil) continue;
            [uuidTable setObject:line forKey:line.uuid.copy];
        }
        
        self.uuidsToLinesMap = uuidTable;
        return self.uuidsToLinesMap;
    }
}


@end
