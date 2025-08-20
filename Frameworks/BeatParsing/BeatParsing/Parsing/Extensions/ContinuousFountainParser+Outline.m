//
//  ContinuousFountainParser+Outline.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 22.1.2024.
//

#import "ContinuousFountainParser+Outline.h"
#import <BeatParsing/Line+ConvenienceTypeChecks.h>

@implementation ContinuousFountainParser (Outline)


#pragma mark - Fetching Outline Data

/// Returns a tree structure for the outline. Only top-level elements are included, get the rest using `element.chilren`.
- (NSArray*)outlineTree
{
    NSMutableArray* tree = NSMutableArray.new;
    
    NSInteger topLevelDepth = 0;
    
    for (OutlineScene* scene in self.outline) {
        if (scene.type == section) {
            // First define top level depth
            if (scene.sectionDepth > topLevelDepth && topLevelDepth == 0) {
                topLevelDepth = scene.sectionDepth;
            }
            else if (scene.sectionDepth < topLevelDepth) {
                topLevelDepth = scene.sectionDepth;
            }
            
            // Add section to tree if applicable
            if (scene.sectionDepth == topLevelDepth) {
                [tree addObject:scene];
            }

        } else if (scene.sectionDepth == 0) {
            // Add bottom-level objects (scenes) by default
            [tree addObject:scene];
        }
    }
    
    return tree;
}

/// Updates scene numbers for scenes. Autonumbered will get incremented automatically.
/// - note: the arrays can contain __both__ `OutlineScene` or `Line` items to be able to update line content individually without building an outline. This causes a lot of inconvenient stuff, but... this is how we do it  for now. The problem here is that the forced and auto-numbered values are not in order.
- (void)updateSceneNumbers:(NSArray*)autoNumbered forcedNumbers:(NSSet*)forcedNumbers
{
    static NSArray* postfixes;
    if (postfixes == nil) postfixes = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G"];

    NSInteger sceneNumber = self.sceneNumberOrigin;
    
    for (id item in autoNumbered) {
        Line* line; OutlineScene* scene;
        
        if ([item isKindOfClass:OutlineScene.class]) {
            // This was a scene
            line = ((OutlineScene*)item).line;
            scene = item;
        } else {
            // This was a plain Line object
            line = item;
        }
                
        if (line.omitted) {
            line.sceneNumber = @"";
            continue;
        }
        
        NSString* oldSceneNumber = line.sceneNumber;
        NSString* s = [NSString stringWithFormat:@"%lu", sceneNumber];
                
        if ([forcedNumbers containsObject:s]) {
            for (NSInteger i=0; i<postfixes.count; i++) {
                s = [NSString stringWithFormat:@"%lu%@", sceneNumber, postfixes[i]];
                if (![forcedNumbers containsObject:s]) break;
            }
        }
        
        if (![oldSceneNumber isEqualToString:s]) {
            if (scene != nil) [self.outlineChanges.updated addObject:scene];
        }
        
        line.sceneNumber = s;
        sceneNumber++;
        
        // Check if we should reset scene number
        if (line.resetsSceneNumber) {
            NSInteger newSceneNumber = line.sceneNumber.integerValue;
            if (newSceneNumber == 0) newSceneNumber = 1;
            sceneNumber = newSceneNumber;
        }
    }
}

/// Returns a set of all scene numbers in the outline
- (NSSet*)sceneNumbersInOutline
{
    NSMutableSet<NSString*>* sceneNumbers = NSMutableSet.new;
    for (OutlineScene* scene in self.outline) {
        [sceneNumbers addObject:scene.sceneNumber];
    }
    return sceneNumbers;
}

/// Returns the number from which automatic scene numbering should start from
- (NSInteger)sceneNumberOrigin
{
    NSInteger i = [self.documentSettings getInt:DocSettingSceneNumberStart];
    if (i > 0) return i;
    else return 1;
}

/// Call this after text was changed. This in turn calls `outlineDidChange` in your document controller when needed.
- (void)checkForChangesInOutline
{
    [self getAndResetChangesInOutline];
}

/// Gets and resets the changes to outline. Document controller base class provides a method called `outlineDidChange` to handle these.
- (OutlineChanges*)getAndResetChangesInOutline
{
    // Refresh the changed outline elements
    for (OutlineScene* scene in self.outlineChanges.updated) {
        [self updateScene:scene at:NSNotFound lineIndex:NSNotFound];
    }
    for (OutlineScene* scene in self.outlineChanges.added) {
        [self updateScene:scene at:NSNotFound lineIndex:NSNotFound];
    }
    
    // If any changes were made to the outline, rebuild the hierarchy.
    if (self.outlineChanges.hasChanges) [self updateOutlineHierarchy];
        
    OutlineChanges* changes = self.outlineChanges.copy;
    self.outlineChanges = OutlineChanges.new;
    
    return changes;
}

/// Returns an array of dictionaries with UUID mapped to the actual string.
-(NSArray<NSDictionary<NSString*,NSString*>*>*)outlineUUIDs
{
    NSMutableArray* outline = NSMutableArray.new;
    for (OutlineScene* scene in self.outline) {
        [outline addObject:@{
            @"uuid": scene.line.uuid.UUIDString,
            @"string": scene.line.string
        }];
    }
    
    return outline;
}



#pragma mark - Handling changes to outline

/// Updates the current outline from scratch. Use sparingly.
- (void)updateOutline
{
    [self updateOutlineWithLines:self.safeLines];
}

/// Updates the whole outline from scratch with given lines.
- (void)updateOutlineWithLines:(NSArray<Line*>*)lines
{
    self.outline = NSMutableArray.new;
        
    for (NSInteger i=0; i<lines.count; i++) {
        Line* line = self.lines[i];
        if (!line.isOutlineElement) continue;
        
        [self updateSceneForLine:line at:self.outline.count lineIndex:i];
    }
    
    [self updateOutlineHierarchy];
}

/// Adds an update to this line, but only if needed
- (void)addUpdateToOutlineIfNeededAt:(NSInteger)lineIndex
{
    // Don't go out of range
    if (self.lines.count == 0) return;
    else if (lineIndex >= self.lines.count) lineIndex = self.lines.count - 1;
    
    Line* line = self.safeLines[lineIndex];

    // Nothing to update
    if (line.type != synopse && !line.isOutlineElement && line.noteRanges.count == 0 && line.markerRange.length == 0) return;

    // Find the containing outline element and add an update to it
    NSArray* lines = self.safeLines;
    
    for (NSInteger i = lineIndex; i >= 0; i--) {
        Line* line = lines[i];
        
        if (line.isOutlineElement) {
            [self addUpdateToOutlineAtLine:line didChangeType:false];
            return;
        }
    }
}


/// Forces an update to the outline element which contains the given line. No additional checks.
- (void)addUpdateToOutlineAtLine:(Line*)line didChangeType:(bool)didChangeType
{
    OutlineScene* scene = [self outlineElementInRange:line.textRange];
    if (scene != nil) [self.outlineChanges.updated addObject:scene];
    
    // In some cases we also need to update the surrounding elements
    if (didChangeType) {
        OutlineScene* previousScene = [self outlineElementInRange:NSMakeRange(line.position - 1, 0)];
        OutlineScene* nextScene = [self outlineElementInRange:NSMakeRange(NSMaxRange(scene.range) + 1, 0)];
        
        if (previousScene != nil) [self.outlineChanges.updated addObject:previousScene];
        if (nextScene != nil) [self.outlineChanges.updated addObject:nextScene];
    }
}


/// Updates the outline element for given line. If you don't know the index for the outline element or line, pass `NSNotFound`.
- (void)updateSceneForLine:(Line*)line at:(NSInteger)index lineIndex:(NSInteger)lineIndex
{
    if (index == NSNotFound) {
        OutlineScene* scene = [self outlineElementInRange:line.textRange];
        index = [self indexOfScene:scene];
    }
    if (lineIndex == NSNotFound) lineIndex = [self indexOfLine:line];
    
    OutlineScene* scene;
    if (index >= self.outline.count || index == NSNotFound) {
        scene = [OutlineScene withLine:line delegate:self];
        [self.outline addObject:scene];
    } else {
        scene = self.outline[index];
    }
    
    [self updateScene:scene at:index lineIndex:lineIndex];
}

/// Updates the given scene and gathers its notes and synopsis lines. If you don't know the line/scene index pass them as `NSNotFound` .
- (void)updateScene:(OutlineScene*)scene at:(NSInteger)index lineIndex:(NSInteger)lineIndex
{
    // We can call this method without specifying the indices
    if (index == NSNotFound) index = [self indexOfScene:scene];
    if (lineIndex == NSNotFound) lineIndex = [self indexOfLine:scene.line];
    
    // Reset everything
    scene.synopsis = NSMutableArray.new;
    scene.beats = NSMutableArray.new;
    scene.notes = NSMutableArray.new;
    scene.markers = NSMutableArray.new;
    
    NSMutableSet* beats = NSMutableSet.new;
    
    for (NSInteger i=lineIndex; i<self.lines.count; i++) {
        Line* line = self.lines[i];
        
        if (line != scene.line && line.isOutlineElement) break;
        
        if (line.type == synopse) {
            [scene.synopsis addObject:line];
        }
        
        if (line.noteRanges.count > 0) {
            [scene.notes addObjectsFromArray:line.noteData];
        }
        
        if (line.beats.count) {
            [beats addObjectsFromArray:line.beats];
        }
        
        if (line.markerRange.length > 0) {
            [scene.markers addObject:@{
                @"description": (line.markerDescription) ? line.markerDescription : @"",
                @"color": (line.marker) ? line.marker : @"",
                @"range": [NSValue valueWithRange:line.markerRange],
                @"globalRange": [NSValue valueWithRange:NSMakeRange(line.position + line.markerRange.location, line.markerRange.length)],
                @"line": [NSValue valueWithNonretainedObject:line]
            }];
        }
    }
    
    scene.beats = [NSMutableArray arrayWithArray:beats.allObjects];
}

/// Inserts a new outline element with given line.
- (void)addOutlineElement:(Line*)line
{
    NSInteger index = NSNotFound;

    for (NSInteger i=0; i<self.outline.count; i++) {
        OutlineScene* scene = self.outline[i];

        if (line.position <= scene.position) {
            index = i;
            break;
        }
    }

    OutlineScene* scene = [OutlineScene withLine:line delegate:self];
    if (index == NSNotFound) [self.outline addObject:scene];
    else [self.outline insertObject:scene atIndex:index];

    // Add the scene
    [self.outlineChanges.added addObject:scene];
    // We also need to update the previous scene
    if (index > 0 && index != NSNotFound) [self.outlineChanges.updated addObject:self.outline[index - 1]];
}

/// Remove outline element for given line
- (void)removeOutlineElementForLine:(Line*)line
{
    OutlineScene* scene;
    NSInteger index = NSNotFound;
    for (NSInteger i=0; i<self.outline.count; i++) {
        scene = self.outline[i];
        if (scene.line == line) {
            index = i;
            break;
        }
    }
    
    if (index == NSNotFound) return;
        
    [self.outlineChanges.removed addObject:scene];
    [self.outline removeObjectAtIndex:index];

    // We also need to update the previous scene
    if (index > 0) [self.outlineChanges.updated addObject:self.outline[index - 1]];
}

/// Rebuilds the outline hierarchy (section depths) and calculates scene numbers.
- (void)updateOutlineHierarchy
{
    
    NSUInteger sectionDepth = 0;
    NSMutableArray *sectionPath = NSMutableArray.new;
    OutlineScene* currentSection;
    
    NSMutableArray* autoNumbered = NSMutableArray.new;
    NSMutableSet<NSString*>* forcedNumbers = NSMutableSet.new;
            
    for (OutlineScene* scene in self.outline) {
        scene.children = NSMutableArray.new;
        scene.parent = nil;
        
        scene.line.autoNumbered = false;
        
        // There are two types of "scenes", sections and actual scenes. Handle sections first.
        if (scene.type == section) {
            if (sectionDepth < scene.line.sectionDepth) {
                // Sections are nesting. When we encounter a deeper section, let's make that the parent,
                scene.parent = sectionPath.lastObject;
                [sectionPath addObject:scene];
            } else {
                // Higher-level section encountered. Find the previous level from section path.
                while (sectionPath.count > 0) {
                    OutlineScene* prevSection = sectionPath.lastObject;
                    [sectionPath removeLastObject];
                    
                    // Break at higher/equal level section
                    if (prevSection.sectionDepth <= scene.line.sectionDepth) break;
                }
                
                scene.parent = sectionPath.lastObject;
                [sectionPath addObject:scene];
            }
            
            // Any time section depth has changed, we need probably need to update the whole outline structure in UI
            if (scene.sectionDepth != scene.line.sectionDepth) {
                self.outlineChanges.needsFullUpdate = true;
            }
            
            sectionDepth = scene.line.sectionDepth;
            scene.sectionDepth = sectionDepth;
            
            currentSection = scene;
        } else {
            // Manage scene numbers
            if (scene.line.sceneNumberRange.length > 0) {
                [forcedNumbers addObject:scene.sceneNumber];
            } else {
                scene.line.autoNumbered = true;
                [autoNumbered addObject:scene];
            }
            
            // Update section depth for scene
            scene.sectionDepth = sectionDepth;
            if (currentSection != nil) scene.parent = currentSection;
        }
        
        // Add this object to the children of its parent
        if (scene.parent)
            [scene.parent.children addObject:scene];
    }
    
    // Do the actual scene number update.
    [self updateSceneNumbers:autoNumbered forcedNumbers:forcedNumbers];
    
    if (self.outlineChanges.hasChanges) {
        [self.delegate outlineDidUpdateWithChanges:self.outlineChanges];
    }
    self.outlineChanges = nil;
}


/// NOTE: This method is used by line preprocessing to avoid recreating the outline. It has some overlapping functionality with `updateOutlineHierarchy` and `updateSceneNumbers:forcedNumbers:`.
- (void)updateSceneNumbersInLines
{
    NSMutableArray* autoNumbered = NSMutableArray.new;
    NSMutableSet<NSString*>* forcedNumbers = NSMutableSet.new;
    for (Line* line in self.safeLines) {
        if (line.type == heading && !line.omitted) {
            if (line.sceneNumberRange.length > 0) [forcedNumbers addObject:line.sceneNumber];
            else [autoNumbered addObject:line];
        }
    }
    
    /// `updateSceneNumbers` supports both `Line` and `OutlineScene` objects.
    [self updateSceneNumbers:autoNumbered forcedNumbers:forcedNumbers];
}


@end
