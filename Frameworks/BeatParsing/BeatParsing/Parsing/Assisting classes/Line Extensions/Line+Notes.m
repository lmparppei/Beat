//
//  Line+Notes.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.12.2024.
//

#import "Line+Notes.h"

@implementation Line (Notes)

#pragma mark - Note handling

/**
 Returns true for a line which is a note. Should be used only in conjuction with .omitted to check that, yeah, it's omitted but it's a note:
 `if (line.omitted && !line.isNote) { ... }`
 
 Checked using trimmed length, to make lines like `  [[note]]` be notes.
 */
- (bool)isNote
{
    return (self.noteRanges.count >= self.trimmed.length && self.noteRanges.count && self.string.length >= 2);
}
- (bool)note { return self.isNote; }


/// Returns `true` if the note is able to succesfully terminate a multi-line note block (contains `]]`)
- (bool)canTerminateNoteBlock {
    return [self canTerminateNoteBlockWithActualIndex:nil];
}
- (bool)canTerminateNoteBlockWithActualIndex:(NSInteger*)position
{
    if (self.length > 30000) return false;
    else if (![self.string containsString:@"]]"]) return false;
    
    unichar chrs[self.string.length];
    [self.string getCharacters:chrs];
    
    for (NSInteger i=0; i<self.length - 1; i++) {
        unichar c1 = chrs[i];
        unichar c2 = chrs[i+1];
        
        if (c1 == ']' && c2 == ']') {
            if (position != nil) *position = i;
            return true;
        }
        else if (c1 == '[' && c2 == '[') return false;
    }
    
    return false;
}

/// Returns `true` if the line can begin a note block
- (bool)canBeginNoteBlock
{
    return [self canBeginNoteBlockWithActualIndex:nil];
}

/// Returns `true` if the lien can begin a note block
/// @param index Pointer to the index where the potential note block begins.
- (bool)canBeginNoteBlockWithActualIndex:(NSInteger*)index
{
    if (self.length > 30000) return false;
    
    unichar chrs[self.string.length];
    [self.string getCharacters:chrs];
    
    for (NSInteger i=self.length - 1; i > 0; i--) {
        unichar c1 = chrs[i];
        unichar c2 = chrs[i-1];
        
        if (c1 == '[' && c2 == '[') {
            if (index != nil) *index = i - 1;
            return true;
        }
        else if (c1 == ']' && c2 == ']') return false;
    }
    
    return false;
}

- (NSArray<NSString*>*)noteContents
{
    return [self noteContentsWithRanges:false];
}

- (NSMutableDictionary<NSValue*, NSString*>*)noteContentsAndRanges
{
    return [self noteContentsWithRanges:true];
}

- (NSArray*)contentAndRangeForLastNoteWithPrefix:(NSString*)string
{
    string = string.lowercaseString;

    NSDictionary* notes = self.noteContentsAndRanges;
    NSRange noteRange = NSMakeRange(0, 0);
    NSString* noteContent = nil;
    
    // Iterate through notes and only accept the last one.
    for (NSValue* r in notes.allKeys) {
        NSRange range = r.rangeValue;
        NSString* noteString = notes[r];
        NSInteger location = [noteString.lowercaseString rangeOfString:string].location;
        
        // Only accept notes which are later than the one already saved, and which begin with the given string
        if (range.location < noteRange.location || location != 0 ) continue;
        
        // Check the last character, which can be either ' ' or ':'. If it's note, carry on.
        if (noteString.length > string.length) {
            unichar followingChr = [noteString characterAtIndex:string.length];
            if (followingChr != ' ' && followingChr != ':') continue;
        }
        
        noteRange = range;
        noteContent = noteString;
    }
    
    NSArray* result = nil;
    // For notes with a prefix, we need to check that the note isn't bleeding out.
    if (noteContent != nil && NSMaxRange(noteRange) == self.length && !self.noteOut) {
        result = @[ [NSValue valueWithRange:noteRange], noteContent ];
    }
    
    return result;
}

- (id)noteContentsWithRanges:(bool)withRanges {
    __block NSMutableDictionary<NSValue*, NSString*>* rangesAndStrings = NSMutableDictionary.new;
    __block NSMutableArray* strings = NSMutableArray.new;
    
    NSArray* notes = [self noteData];
    for (BeatNoteData* note in notes) {
        if (withRanges) rangesAndStrings[[NSValue valueWithRange:note.range]] = note.content;
        else [strings addObject:note.content];
    }
    
    return (withRanges) ? rangesAndStrings : strings;
}

- (NSArray*)notes
{
    return self.noteData;
}

- (NSArray<NSDictionary*>*)notesAsJSON
{
    NSMutableArray<NSDictionary*>* notes = NSMutableArray.new;
    for (BeatNoteData* note in self.noteData) {
        [notes addObject:note.json];
    }
    return notes;
}


@end
