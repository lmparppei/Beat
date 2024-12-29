//
//  Line+Storybeats.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import "Line+Storybeats.h"

@implementation Line (Storybeats)

#pragma mark - Story beats

- (NSArray<Storybeat *> *)beats
{
    self.__beatRanges = NSMutableIndexSet.new;
    NSMutableSet* beats = NSMutableSet.new;
    
    for (BeatNoteData* note in self.noteData) {
        if (note.type != NoteTypeBeat) continue;
        [self.__beatRanges addIndexesInRange:note.range];
        
        // This is an empty note, ignore
        NSInteger i = [note.content rangeOfString:@" "].location;
        if (i == NSNotFound) continue;
        
        NSString* beatContents = [note.content substringFromIndex:i];
        NSArray* singleBeats = [beatContents componentsSeparatedByString:@","];
        
        for (NSString* b in singleBeats) {
            Storybeat* beat = [Storybeat line:self scene:nil string:b.uppercaseString range:note.range];
            [beats addObject:beat];
        }
    }
        
    return beats.allObjects;
}

- (NSMutableIndexSet *)beatRanges
{
    if (self.__beatRanges == nil) [self beats];
    return self.__beatRanges;
}

- (bool)hasBeat
{
    return ([self.string.lowercaseString containsString:@"[[beat "] ||
            [self.string.lowercaseString containsString:@"[[beat:"] ||
            [self.string.lowercaseString containsString:@"[[storyline"]);
}

- (bool)hasBeatForStoryline:(NSString*)storyline
{
    for (Storybeat *beat in self.beats) {
        if ([beat.storyline.lowercaseString isEqualToString:storyline.lowercaseString]) return YES;
    }
    return NO;
}

- (NSArray<NSString*>*)storylines
{
    NSMutableArray *storylines = NSMutableArray.array;
    for (Storybeat *beat in self.beats) {
        [storylines addObject:beat.storyline];
    }
    return storylines;
}

- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline
{
    for (Storybeat *beat in self.beats) {
        if ([beat.storyline.lowercaseString isEqualToString:storyline.lowercaseString]) return beat;
    }
    return nil;
}
 
- (NSRange)firstBeatRange
{
    __block NSRange beatRange = NSMakeRange(NSNotFound, 0);
    
    [self.beatRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        // Find first range
        if (range.length > 0) {
            beatRange = range;
            *stop = YES;
        }
    }];
    
    return beatRange;
}

@end

