//
//  ContinuousFountainParser+Notes.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.10.2024.
//

#import <BeatParsing/ContinuousFountainParser.h>
#import "ContinuousFountainParser+Notes.h"

@implementation ContinuousFountainParser (Notes)

#pragma mark - Note parsing

// All hope abandon ye who enter here.

// This is not a place of honor. No highly esteemed deed is commemorated here... nothing valued is here.
// What is here was dangerous and repulsive to us.
// The danger is in a particular location... it increases towards a center... the center of danger is here...
// The danger is still present, in your time, as it was in ours.

/**
 Parses notes for given line at specified index. You also need to specify the type the line had before we are parsing the notes.
 
 - Note: Note parsing is a bit convoluted. Because note rules are unlike any other element in Fountain (they can appear on any line,
 span across multiple lines and have rules for whitespace), parsing notes on the fly has turned out to be a bit clunky, especially with
 my existing code.
 
 This should probably be harmonized with the other parsing, but I had a hard time doing that. Multi-line notes require multiple passes
 through this method and it isn't exactly the most performant approach.
 
 If a line has an unterminated note (either with closing or opening brackets), we'll find the line which might open the block and
 call `parseNoteOutFrom:(NSInteger)lineIndex positionInLine:(NSInteger)positionInLine` to parse the
 whole block. This is done while in a parsing pass, so lines which require reformatting will be registered correctly.
 
 `BeatNoteData` object is created for each note range and stored into `line.noteData` array. For multi-line notes, only the
 line which begins the note will hold the actual content, and a placeholder `BeatNoteData` is created for subsequent lines.
 Note data object contains an empty string for every other line in the note block.
 
 */
- (void)parseNotesFor:(Line*)line at:(NSInteger)lineIndex oldType:(LineType)oldType
{
    // TODO: Make some fucking sense to this
    // This was probably a part of a note block. Let's parse the whole block instead of this single line.
    if (line.noteIn && line.noteOut && line.noteRanges.count == line.length) {
        NSInteger pos;
        NSInteger i = [self findNoteBlockStartIndexFor:line at:lineIndex positionInLine:&pos];
        [self parseNoteBlocksFrom:i];
        return;
    }
        
    // Reset note status
    [line.noteRanges removeAllIndexes];
    line.noteData = NSMutableArray.new;
    
    line.noteIn = false;
    line.noteOut = false;
    
    unichar chrs[line.length];
    [line.string getCharacters:chrs];

    __block NSRange noteRange = NSMakeRange(NSNotFound, 0);
    
    for (NSInteger i = 0; i < line.length - 1; i++) {
        unichar c1 = chrs[i];
        unichar c2 = chrs[i + 1];
        
        if (c1 == '[' && c2 == '[') {
            // A note begins
            noteRange.location = i;
        }
        else if (c1 == ']' && c2 == ']' && noteRange.location != NSNotFound) {
            // We are terminating a normal note
            noteRange.length = i + 2 - noteRange.location;
            NSRange contentRange = NSMakeRange(noteRange.location + 2, noteRange.length - 4);
            NSString* content = [line.string substringWithRange:contentRange];
            
            BeatNoteData* note = [BeatNoteData withNote:content range:noteRange];
            note.line = line;
            [line.noteData addObject:note];
            [line.noteRanges addIndexesInRange:noteRange];
            
            noteRange = NSMakeRange(NSNotFound, 0);
        }
        else if (c1 == ']' && c2 == ']') {
            // We need to look back to see if this note is part of a note block
            line.noteIn = true; // We might change this value later.
        }
    }
        
    // Check if there was an unfinished not (except on the last line)
    if (noteRange.location != NSNotFound && lineIndex != self.lines.count-1) {
        line.noteOut = true;
    }
        
    // Get previous line for later
    Line* prevLine = (lineIndex > 0) ? self.lines[lineIndex - 1] : nil;
    
    // If this line receives a note, let's find out what's going on -- and enter a world of pain.
    if (line.noteIn || line.noteOut) {
        [self parseNoteBlocksFrom:lineIndex];
    }
    else if (!self.firstTime && (oldType == empty || line.type == empty || prevLine.noteOut) && lineIndex < self.lines.count ) {
        // If the line has changed type, let's try to find out if this line creates or cancels an existing note block.
        // This isn't checked when parsing for the first time.
        NSInteger positionInLine;
        NSInteger i = [self findNoteBlockStartIndexFor:line at:lineIndex positionInLine:&positionInLine];
        
        if (i != NSNotFound) [self parseNoteOutFrom:i positionInLine:positionInLine];
    }
}

/// Parses every possible note block from this position
- (void)parseNoteBlocksFrom:(NSInteger)lineIndex
{
    NSInteger idx = lineIndex;
    NSMutableIndexSet* blocks = NSMutableIndexSet.new;
    
    bool stop = false;
    while (!stop && idx >= 0) {
        NSInteger pos;
        NSInteger i = [self findNoteBlockStartIndexFor:self.lines[idx] at:idx positionInLine:&pos];
        if (i == NSNotFound) break;
        
        // Add the index to handled blocks
        [blocks addIndex:i];
        
        // See where we ended up
        Line* l = self.lines[i];
        
        // If we landed on a line which also has ]], it might terminate another block, so let's inspect further
        if (l.canTerminateNoteBlock)  idx = i - 1;
        else stop = true;
    }
    
    // Parse all affected notes.
    [blocks enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        Line* l = self.lines[idx];
        NSInteger positionInLine;
        [l canBeginNoteBlockWithActualIndex:&positionInLine];
        
        if (positionInLine != NSNotFound) [self parseNoteOutFrom:idx positionInLine:positionInLine];
    }];
}

- (void)parseNoteOutFrom:(NSInteger)lineIndex positionInLine:(NSInteger)position
{
    if (lineIndex == NSNotFound) return;

    bool cancel = false; // A flag to determine if we should remove the note block from existence
    
    // We might not know the actual position, so let's retrieve it
    if (position == NSNotFound) position = [(Line*)self.lines[lineIndex] canBeginNoteBlockWithActualIndex:&position];
    
    NSMutableIndexSet* affectedLines = NSMutableIndexSet.new;
    Line* lastLine;
    
    for (NSInteger i=lineIndex; i<self.lines.count; i++) {
        Line* l = self.lines[i];
        
        if (l.type == empty) cancel = true;
        
        [affectedLines addIndex:i];
        
        if (l.canTerminateNoteBlock && i != lineIndex) {
            // Note block might be terminated here
            lastLine = l;
            break;
        }
        else if (l.canBeginNoteBlock && i != lineIndex) {
            // Another block might begin here
            [affectedLines removeIndex:i];
            break;
        }
    }
    
    __block NSMutableString* noteContent = NSMutableString.new;
    __block NSString* color = @"";
    
    if (lastLine == nil) cancel = true;
    
    // Go through the note content
    [affectedLines enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        Line* l = self.lines[idx];
        NSRange range;
        
        // For the first line, we'll use the previously determined position
        NSInteger p = NSNotFound;
        if (idx == affectedLines.firstIndex && [l canBeginNoteBlockWithActualIndex:&p]) {
            // First line
            range = NSMakeRange(p, l.length - p);
            
            // Find color in the first line of a note
            if (!cancel) {
                NSString* firstNote = [l.string substringWithRange:range];
                NSInteger cIndex = [firstNote rangeOfString:@":"].location;
                if (cIndex != NSNotFound) color = [firstNote substringWithRange:NSMakeRange(2, cIndex - 2 )];
            }
            
        } else if ([l canTerminateNoteBlockWithActualIndex:&p]) {
            // Last line
            range = NSMakeRange(0, p+2);
        } else {
            // Line in the middle
            range = NSMakeRange(0, l.length);
        }
        
        if (range.location == NSNotFound || range.length == NSNotFound) return;
        
        if (cancel) {
            [self.changedIndices addIndex:idx];
            
            if (!l.noteIn && idx != affectedLines.firstIndex && l.type != empty) {
                *stop = true;
                return;
            }
            
            [l.noteRanges removeIndexesInRange:range];
        } else {
            [l.noteRanges addIndexesInRange:range];
            [self.changedIndices addIndex:idx];
            
            // Add correct noteIn/noteOut properties.
            if (idx == affectedLines.firstIndex) {
                l.noteOut = true; // First line always bleeds out
                if (l.noteData.lastObject.multiline) [l.noteData removeLastObject];
            } else if (idx == affectedLines.lastIndex) {
                // Last line always receives a note
                l.noteIn = true;
                // Remove the leading multiline note if needed
                if (l.noteData.firstObject.multiline) [l.noteData removeObjectAtIndex:0];
            } else {
                l.noteIn = true;
                l.noteOut = true;
                
                [l.noteData removeAllObjects];
            }
            
            if (!cancel) {
                if (idx > affectedLines.firstIndex) {
                    [noteContent appendString:@"\n"];
                    
                    BeatNoteData* note = [BeatNoteData withNote:@"" range:range];
                    note.multiline = true;
                    note.color = color;
                    note.line = l;
                    
                    if (idx != affectedLines.firstIndex && idx < affectedLines.lastIndex) [l.noteData addObject:note];
                    else if (idx == affectedLines.lastIndex) [l.noteData insertObject:note atIndex:0];
                }

                [noteContent appendString:[l.string substringWithRange:range]];
            }
        }
    }];
        
    // Remove the last parsed multiline note
    Line* firstLine = self.lines[lineIndex];
    BeatNoteData* lastNote = firstLine.noteData.lastObject;
    if (lastNote.multiline) [firstLine.noteData removeLastObject];
    
    if (cancel || noteContent.length <= 4) return;
    
    // Create the actual note
    [noteContent setString:[noteContent substringWithRange:NSMakeRange(2, noteContent.length - 4 )]];
        
    BeatNoteData* note = [BeatNoteData withNote:noteContent range:NSMakeRange(position, firstLine.length - position)];
    note.multiline = true;
    note.color = color;
    note.line = firstLine;
    
    [firstLine.noteData addObject:note];
}

- (NSInteger)findNoteBlockStartIndexFor:(Line*)line at:(NSInteger)idx positionInLine:(NSInteger*)position
{
    NSArray* lines = self.lines;
    
    if (idx == NSNotFound) idx = [self.lines indexOfObject:line]; // Get index if needed
    else if (idx == NSNotFound) return NSNotFound;
    
    NSInteger noteStartLine = NSNotFound;
    
    for (NSInteger i=idx; i>=0; i--) {
        Line* l = lines[i];
        if (l.type == empty && i < idx) break;   // Stop if we're not in a block
        
        unichar chrs[l.length];
        [l.string getCharacters:chrs];
        
        for (NSInteger k=l.string.length-1; k>=0; k--) {
            if (k > 0) {
                unichar c1 = chrs[k];
                unichar c2 = chrs[k-1];
                
                if (c1 == ']' && c2 == ']') {
                    break; // Cancel right away at terminating note
                }
                else if (c1 == '[' && c2 == '[') {
                    // The note opening was found
                    noteStartLine = i;
                    *position = k - 1;
                    break;
                }
            }
        }
        
        // We found the line, no reason to look backwards anymore
        if (noteStartLine != NSNotFound) break;
    }
        
    return noteStartLine;
}

@end
