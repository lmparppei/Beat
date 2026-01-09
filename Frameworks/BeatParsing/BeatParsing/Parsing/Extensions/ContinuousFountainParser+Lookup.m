//
//  ContinuousFountainParser+Lookup.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 4.3.2025.
//

#import "ContinuousFountainParser+Lookup.h"

@implementation ContinuousFountainParser (Lookup)

#pragma mark - Line position lookup

/// Returns line at given POSITION, not index.
- (Line*)lineAtIndex:(NSInteger)position
{
    return [self lineAtPosition:position];
}

/**
 Returns the index in lines array for given line. This method might be called multiple times, so we'll cache the result.
 This is a *very* small optimization, we're talking about `0.000001` vs `0.000007`. It's many times faster, but doesn't actually have too big of an effect.
 Note that whenever changes are made, `previousLineIndex` should maybe be set as `NSNotFound`. Currently it's not.
 */
- (NSUInteger)indexOfLine:(Line*)line
{
    return [self indexOfLine:line lines:self.safeLines];
}

- (NSUInteger)indexOfLine:(Line*)line lines:(NSArray<Line*>*)lines
{
    // First check the cached line index (N.B.: previousLineIdnex and previousSceneIndex are ivars)
    if (previousLineIndex >= 0 && previousLineIndex < lines.count && line == (Line*)lines[previousLineIndex]) {
        return previousLineIndex;
    }
    
    // Let's use binary search here. It's much slower in short documents, but about 20-30 times faster in longer ones.
    // We are using integer value for `position` to very quickly verify that this is the item. Position is unique for each item, and if for some odd reason the
    // actual pointer has changed, we are satisfied with *any* object with this position.
    NSInteger index = [self.lines binarySearchForItem:line matchingIntegerValueFor:@"position"];
    previousLineIndex = index;

    return index;
}

/**
 This method returns the line index at given position in document. It uses a cyclical lookup, so the method won't iterate through all the lines every time.
 Instead, it first checks the line it returned the last time, and after that, starts to iterate through lines from its position and given direction. Usually we can find
 the line with 1-2 steps, and as we're possibly iterating through thousands and thousands of lines, it's much faster than finding items by their properties the usual way.
 */
- (NSUInteger)lineIndexAtPosition:(NSUInteger)position
{
    return [self lineIndexAtPosition:position lines:self.safeLines];
}

/**
 This method returns the line index at given position in document. It uses a cyclical lookup, so the method won't iterate through all the lines every time.
 Instead, it first checks the line it returned the last time, and after that, starts to iterate through lines from its position and given direction. Usually we can find
 the line with 1-2 steps, and as we're possibly iterating through thousands and thousands of lines, it's much faster than finding items by their properties the usual way.
 */
- (NSUInteger)lineIndexAtPosition:(NSUInteger)position lines:(NSArray<Line*>*)lines
{
    NSUInteger actualIndex = NSNotFound;
    NSInteger lastFoundPosition = 0;
    
    // First check if we are still on the same line as before
    if (NSLocationInRange(previousLineIndex, NSMakeRange(0, lines.count))) {
        Line* lastEdited = lines[previousLineIndex];
        lastFoundPosition = lastEdited.position;
        
        if (NSLocationInRange(position, lastEdited.range)) {
            return previousLineIndex;
        }
    }
    
    // Cyclical array lookup from the last found position
    Line* result = [self findNeighbourIn:lines origin:previousLineIndex descending:(position < lastFoundPosition) cacheIndex:&actualIndex block:^BOOL(id item, NSInteger idx) {
        Line* l = item;
        return NSLocationInRange(position, l.range);
    }];
    
    if (result != nil) {
        previousLineIndex = actualIndex;
        self.lastEditedLine = result;
        
        return actualIndex;
    } else {
        return (self.lines.count > 0) ? self.lines.count - 1 : 0;
    }
}

/// Cached line for location lookup. Needs a better name.
NSUInteger prevLineAtLocationIndex = 0;

/// Returns the line object at given position (btw, why aren't we using the other method?)
- (Line*)lineAtPosition:(NSInteger)position
{
    // Let's check the cached line first
    if (NSLocationInRange(position, self.prevLineAtLocation.range)) return self.prevLineAtLocation;
    
    NSArray *lines = self.safeLines; // Use thread safe lines for this lookup
    if (prevLineAtLocationIndex >= lines.count) prevLineAtLocationIndex = 0;
    
    // Quick lookup for first object
    if (position == 0) return lines.firstObject;
    
    // We'll use a circular lookup here. It's HIGHLY possible that we are not just randomly looking for lines,
    // but that we're looking for close neighbours in a for loop. That's why we'll either loop the array forward
    // or backward to avoid unnecessary looping from beginning, which soon becomes very inefficient.
    
    NSUInteger cachedIndex;
    
    bool descending = NO;
    if (self.prevLineAtLocation && position < self.prevLineAtLocation.position) {
        descending = YES;
    }
        
    Line *line = [self findNeighbourIn:lines origin:prevLineAtLocationIndex descending:descending cacheIndex:&cachedIndex block:^BOOL(id item, NSInteger idx) {
        Line *l = item;
        if (NSLocationInRange(position, l.range)) return YES;
        else return NO;
    }];
    
    if (line) {
        self.prevLineAtLocation = line;
        prevLineAtLocationIndex = cachedIndex;
        return line;
    }
    
    return nil;
}

/// Returns the lines in given range (even overlapping)
- (NSArray<Line*>*)linesInRange:(NSRange)range
{
    NSArray *lines = self.safeLines;
    NSMutableArray *linesInRange = NSMutableArray.array;
    
    NSInteger index = [self lineIndexAtPosition:range.location lines:lines];
    
    for (NSInteger i=index; i<lines.count; i++) {
        Line* line = lines[i];
        
        if (NSIntersectionRange(line.range, range).length > 0) [linesInRange addObject:line];
        else if (line.position > NSMaxRange(range)) break;
    }
    
/*
    for (Line* line in lines) {
        if ((NSLocationInRange(line.position, range) ||
            NSLocationInRange(range.location, line.textRange) ||
            NSLocationInRange(range.location + range.length, line.textRange)) &&
            NSIntersectionRange(range, line.textRange).length > 0) {
            [linesInRange addObject:line];
        } else if (NSMaxRange(range) < NSMaxRange(line.range)) {
            // We've gone past the given range, break
            break;
        }
    }
*/
 
    return linesInRange;
}

/// Returns a range of indices of lines in given range (even overlapping)
- (NSRange)lineIndicesInRange:(NSRange)range
{
    NSArray* lines = self.safeLines;
    NSRange indexRange = NSMakeRange(NSNotFound, 0);
    
    for (NSInteger i=0; i<lines.count; i++) {
        Line* line = lines[i];
        
        // (wtf is this conditional?)
        if ((NSLocationInRange(line.position, range) ||
            NSLocationInRange(range.location, line.textRange) ||
            NSLocationInRange(NSMaxRange(range), line.textRange)) &&
            NSIntersectionRange(range, line.textRange).length > 0) {
            
            // Adjust range
            if (indexRange.location == NSNotFound) indexRange.location = i;
            else indexRange.length += 1;
            
        } else if (NSMaxRange(range) < NSMaxRange(line.range)) {
            // We've gone past the given range, break
            break;
        }
    }
    
    return indexRange;
}

/// Returns a scene with given UUID. We are using a map table to avoid O(n) time.
- (OutlineScene*)sceneWithUUID:(NSString*)uuid
{
    if (self.outlineUuidTable == nil) self.outlineUuidTable = NSMapTable.strongToWeakObjectsMapTable;
    
    OutlineScene* cachedScene = [self.uuidTable objectForKey:uuid];
    if (cachedScene != nil && cachedScene.line != nil) {
        return cachedScene;
    }
    
    for (OutlineScene* scene in self.outline) {
        if ([scene.line.uuidString isEqualToString:uuid]) {
            [self.outlineUuidTable setObject:scene forKey:uuid];
            return scene;
        }
    }
    
    return nil;
}

/// Returns a line with given UUID. We are using a map table to avoid O(n) time.
- (Line *)lineWithUUID:(NSString *)uuid
{
    if (self.uuidTable == nil) self.uuidTable = NSMapTable.strongToWeakObjectsMapTable;
        
    // First check our UUID table
    Line* cachedResult = [self.uuidTable objectForKey:uuid];
    if (cachedResult != nil) return cachedResult;
    
    for (Line* line in self.lines) {
        if ([line.uuidString isEqualToString:uuid]) {
            [self.uuidTable setObject:line forKey:uuid];
            return line;
        }
    }
    
    return nil;
}


#pragma mark - Find the next / previous scene

/// Returns the previous line from the given line
- (Line*)previousLine:(Line*)line
{
    NSInteger i = [self lineIndexAtPosition:line.position]; // Note: We're using lineIndexAtPosition because it's *way* faster
    
    if (i > 0 && i != NSNotFound) return self.safeLines[i - 1];
    else return nil;
}

/// Returns the following line from the given line
- (Line*)nextLine:(Line*)line
{
    NSArray* lines = self.safeLines;
    NSInteger i = [self lineIndexAtPosition:line.position]; // Note: We're using lineIndexAtPosition because it's *way* faster
    
    if (i != NSNotFound && i < lines.count - 1) return lines[i + 1];
    else return nil;
}

/// Returns the next outline item of given type
/// @param type Type of the outline element (heading/section)
/// @param position Position where to start the search
- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position
{
    return [self nextOutlineItemOfType:type from:position depth:NSNotFound];
}

/// Returns the next outline item of given type
/// @param type Type of the outline element (heading/section)
/// @param position Position where to start the search
/// @param depth Desired hierarchical depth (ie. 0 for top level objects of this type)
- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth
{
    NSInteger idx = [self lineIndexAtPosition:position] + 1;
    NSArray* lines = self.safeLines;
    
    for (NSInteger i=idx; i<lines.count; i++) {
        Line* line = lines[i];
        
        // If no depth was specified, we'll just pass this check.
        NSInteger wantedDepth = (depth == NSNotFound) ? line.sectionDepth : depth;
        
        if (line.type == type && wantedDepth == line.sectionDepth) {
            return line;
        }
    }
    
    return nil;
}

/// Returns the previous outline item of given type
/// @param type Type of the outline element (heading/section)
/// @param position Position where to start the seach
- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position {
    return [self previousOutlineItemOfType:type from:position depth:NSNotFound];
}
/// Returns the previous outline item of given type
/// @param type Type of the outline element (heading/section)
/// @param position Position where to start the search
/// @param depth Desired hierarchical depth (ie. 0 for top level objects of this type)
- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth
{
    NSInteger idx = [self lineIndexAtPosition:position] - 1;
    if (idx == NSNotFound || idx < 0) return nil;
    
    NSArray* lines = self.safeLines;
    
    for (NSInteger i=idx; i>=0; i--) {
        Line* line = lines[i];

        // If no depth was specified, we'll just pass this check.
        NSInteger wantedDepth = (depth == NSNotFound) ? line.sectionDepth : depth;
        
        if (line.type == type && wantedDepth == line.sectionDepth) {
            return line;
        }
    }
    
    return nil;
}



#pragma mark - Look for lines in a scene

/// Returns the lines in given scene
- (NSArray<Line*>*)linesForScene:(OutlineScene*)scene
{
    // Return minimal results for non-scene elements
    if (scene == nil) return @[];
    else if (scene.type == synopse) return @[scene.line];
    
    NSArray *lines = self.safeLines;
        
    NSInteger lineIndex = [self indexOfLine:scene.line];
    if (lineIndex == NSNotFound) return @[];
    
    // Automatically add the heading line and increment the index
    NSMutableArray *linesInScene = NSMutableArray.new;
    [linesInScene addObject:scene.line];
    lineIndex++;
    
    // Iterate through scenes and find the next terminating outline element.
    @try {
        while (lineIndex < lines.count) {
            Line *line = lines[lineIndex];

            if (line.type == heading || line.type == section) break;
            [linesInScene addObject:line];
            
            lineIndex++;
        }
    }
    @catch (NSException *e) {
        NSLog(@"No lines found");
    }
    
    return linesInScene;
}


#pragma mark - Scene lookup

- (NSUInteger)indexOfScene:(OutlineScene*)scene
{
    NSArray *outline = self.safeOutline;
    
    if (previousSceneIndex < outline.count && previousSceneIndex >= 0) {
        if (scene == outline[previousSceneIndex]) return previousSceneIndex;
    }
    
    NSInteger index = [self.outline indexOfObject:scene];
    previousSceneIndex = index;

    return index;
}


/// Returns the scenes which intersect with given range.
- (NSArray<OutlineScene*>*)scenesInRange:(NSRange)range
{
    // When length is zero, return just the scene at the beginning of range (and avoid iterating over the whole outline)
    if (range.length == 0) {
        OutlineScene* scene = [self sceneAtPosition:range.location];
        return (scene != nil) ? @[scene] : @[];
    }

    NSMutableArray *scenes = NSMutableArray.new;
    for (OutlineScene* scene in self.safeOutline) {
        NSRange intersection = NSIntersectionRange(range, scene.range);
        if (intersection.length > 0) [scenes addObject:scene];
    }
    
    return scenes;
}

/// Returns the first outline element which contains at least a part of the given range.
- (OutlineScene*)outlineElementInRange:(NSRange)range
{
    for (OutlineScene *scene in self.safeOutline) {
        if (NSIntersectionRange(range, scene.range).length > 0 || NSLocationInRange(range.location, scene.range)) {
            return scene;
        }
    }
    return nil;
}

/// Returns a scene which contains the given character index (position). An alias for `sceneAtPosition` for legacy compatibility.
- (OutlineScene*)sceneAtIndex:(NSInteger)index { return [self sceneAtPosition:index]; }

/// Returns a scene which contains the given position
- (OutlineScene*)sceneAtPosition:(NSInteger)index
{
    for (OutlineScene *scene in self.safeOutline) {
        if (NSLocationInRange(index, scene.range) && scene.line != nil) return scene;
    }
    return nil;
}

/// Returns all scenes contained by this section. You should probably use `OutlineScene.children` though.
/// - note: Legacy compatibility. Remove when possible.
- (NSArray*)scenesInSection:(OutlineScene*)topSection
{
    if (topSection.type != section) return @[];
    return topSection.children;
}

/// Returns the scene with given number (string)
- (OutlineScene*)sceneWithNumber:(NSString*)sceneNumber
{
    for (OutlineScene *scene in self.outline) {
        if ([scene.sceneNumber.lowercaseString isEqualToString:sceneNumber.lowercaseString]) {
            return scene;
        }
    }
    return nil;
}


#pragma mark - Neighbouring item lookup helper

/**
 This method finds an element in array that statisfies a certain condition, compared in the block. To optimize the search, you should provide `searchOrigin`  and the direction.
 @returns Returns either the found element or nil if none was found.
 @param array The array to be searched.
 @param searchOrigin Starting index of the search, preferrably the latest result you got from this same method.
 @param descending Set the direction of the search: true for descending, false for ascending.
 @param cacheIndex Pointer for retrieving the index of the found element. Set to NSNotFound if the result is nil.
 @param compare The block for comparison, with the inspected element as argument. If the element statisfies your conditions, return true.
 */
- (id _Nullable)findNeighbourIn:(NSArray*)array origin:(NSUInteger)searchOrigin descending:(bool)descending cacheIndex:(NSUInteger*)cacheIndex block:(BOOL (^)(id item, NSInteger idx))compare
{
    // Don't go out of range
    if (array.count == 0 || NSLocationInRange(searchOrigin, NSMakeRange(-1, array.count))) {
        /** Uh, wtf, how does this work?
            We are checking if the search origin is in range from -1 to the full array count,
            so I don't understand how and why this could actually work, and why are we getting
            the correct behavior. The magician surprised themself, too.
         */
        return nil;
    }
    
    NSInteger i = searchOrigin;
    NSInteger origin = (descending) ? i - 1 : i + 1;
    if (origin == -1) origin = array.count - 1;
    
    bool stop = NO;
    
    do {
        if (!descending) {
            i++;
            if (i >= array.count) i = 0;
        } else {
            i--;
            if (i < 0) i = array.count - 1;
        }
                
        id item = array[i];
        
        if (compare(item, i)) {
            *cacheIndex = i;
            return item;
        }
        
        // We have looped around the array (unsuccessfuly)
        if (i == searchOrigin || origin == -1) {
            NSLog(@"Failed to find match for %@ - origin: %lu / searchorigin: %lu  -- %@", self.lines[searchOrigin], origin, searchOrigin, compare);
            break;
        }
        
    } while (stop != YES);
    
    *cacheIndex = NSNotFound;
    return nil;
}


#pragma mark - Element block lookup

/// Returns the lines for a full dual dialogue block
- (NSArray<NSArray<Line*>*>*)dualDialogueFor:(Line*)line isDualDialogue:(bool*)isDualDialogue {
    if (!line.isDialogue && !line.isDualDialogue) return @[];
    
    NSMutableArray<Line*>* left = NSMutableArray.new;
    NSMutableArray<Line*>* right = NSMutableArray.new;
    
    NSInteger i = [self indexOfLine:line];
    if (i == NSNotFound) return @[];
    
    NSArray* lines = self.safeLines;
    
    while (i >= 0) {
        Line* l = lines[i];
        
        // Break at first normal character
        if (l.type == character) break;
        
        i--;
    }
    
    // Iterate forward
    for (NSInteger j = i; j < lines.count; j++) {
        Line* l = lines[j];
        
        // Break when encountering a character cue (which is not the first line), and whenever seeing anything else than dialogue.
        if (j > i && l.type == character) break;
        else if (!l.isDialogue && !l.isDualDialogue && l.type != empty) break;
        
        if (l.isDialogue) [left addObject:l];
        else [right addObject:l];
    }
    
    // Trim left & right
    while (left.firstObject.type == empty && left.count > 0) [left removeObjectAtIndex:0];
    while (right.lastObject.length == 0 && right.count > 0) [right removeObjectAtIndex:right.count-1];
    
    *isDualDialogue = (left.count > 0 && right.count > 0);
    
    return @[left, right];
}

/// Returns the lines for screenplay block in given range.
- (NSArray<Line*>*)blockForRange:(NSRange)range {
    NSMutableArray *blockLines = NSMutableArray.new;
    NSArray *lines;
    
    if (range.length > 0) lines = [self linesInRange:range];
    else lines = @[ [self lineAtPosition:range.location] ];

    for (Line *line in lines) {
        if ([blockLines containsObject:line]) continue;
        
        NSArray *block = [self blockFor:line];
        [blockLines addObjectsFromArray:block];
    }
    
    return blockLines;
}

/// Returns the lines for full screenplay block associated with this line – a dialogue block, for example.
- (NSArray<Line*>*)blockFor:(Line*)line
{
    NSArray *lines = self.lines;
    NSMutableArray *block = NSMutableArray.new;
    NSInteger blockBegin = [self indexOfLine:line];
    
    // If the line is empty, iterate upwards to find the start of the block
    if (line.type == empty) {
        NSInteger h = blockBegin - 1;
        while (h >= 0) {
            Line *l = lines[h];
            if (l.type == empty) {
                blockBegin = h + 1;
                break;
            }
            h--;
        }
    }
    
    // If the line is part of a dialogue block but NOT a character cue, find the start of the block.
    if ( (line.isDialogueElement || line.isDualDialogueElement) && !line.isAnyCharacter) {
        NSInteger i = blockBegin - 1;
        while (i >= 0) {
            // If the preceding line is not a dialogue element or a dual dialogue element,
            // or if it has a length of 0, set the block start index accordingly
            Line *precedingLine = lines[i];
            if (!(precedingLine.isDualDialogueElement || precedingLine.isDialogueElement) || precedingLine.length == 0) {
                blockBegin = i;
                break;
            }
            
            i--;
        }
    }
    
    // Add lines until an empty line is found. The empty line belongs to the block too.
    NSInteger i = blockBegin;
    while (i < lines.count) {
        Line *l = lines[i];
        [block addObject:l];
        if (l.type == empty || l.length == 0) break;
        
        i++;
    }
    
    return block;
}

- (NSRange)rangeForBlock:(NSArray<Line*>*)block
{
    NSRange range = NSMakeRange(block.firstObject.position, NSMaxRange(block.lastObject.range) - block.firstObject.position);
    return range;
}


@end
