//
//  ContinuousFountainParser+Lookup.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 4.3.2025.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol ContinuousFountainParserLookupExports <JSExport>

- (Line*)lineAtIndex:(NSInteger)index;
- (NSUInteger)indexOfLine:(Line*)line;
- (NSArray<Line*>*)linesInRange:(NSRange)range;
- (Line*)lineAtPosition:(NSInteger)position;
- (NSArray<Line*>*)linesForScene:(OutlineScene*)scene;
- (Line *)lineWithUUID:(NSString *)uuid;

- (Line*)previousLine:(Line*)line;
- (Line*)nextLine:(Line*)line;

- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position;
- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth;
- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position;
- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth;

- (NSArray<OutlineScene*>*)scenesInRange:(NSRange)range;
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
- (OutlineScene*)sceneAtPosition:(NSInteger)index;
- (OutlineScene*)sceneWithNumber:(NSString*)sceneNumber;

@end

@interface ContinuousFountainParser (Lookup) <LineDelegate, ContinuousFountainParserLookupExports>

#pragma mark - Line lookup

/// Returns line at given POSITION, not index.
- (Line*)lineAtIndex:(NSInteger)position;
/// Returns the index of line at this position
- (NSUInteger)lineIndexAtPosition:(NSUInteger)position;

- (Line*)lineAtPosition:(NSInteger)position;

/// Returns the index of given line in the given array of of lines. Always use this instead of `indexOfObject:` for performance reasons.
- (NSUInteger)indexOfLine:(Line*)line lines:(NSArray<Line*>*)lines;

/// Returns all lines in the given range (including intersecting lines)
- (NSArray<Line*>*)linesInRange:(NSRange)range;

/// Returns the index of given scene. Uses cached results, so it's more performant than using `indexOfObject:]`.
- (NSUInteger)indexOfScene:(OutlineScene*)scene;

/// Get the line with this UUID
- (Line*)lineWithUUID:(NSString*)uuid;


#pragma mark - Scene lookup

/// Returns all scenes in the given range (including intersecting scenes)
- (NSArray<OutlineScene*>*)scenesInRange:(NSRange)range;

/// Returns the first outline element which contains at least a part of the given range.
- (OutlineScene*)outlineElementInRange:(NSRange)range;

/// Returns a scene which contains the given position
- (OutlineScene*)sceneAtPosition:(NSInteger)index;

/// Returns the scene which contains the __line__ at given index. Deprecated, use `sceneAtPosition:`
- (OutlineScene*)sceneAtIndex:(NSInteger)index;

/// Returns the scene with given number (note that scene numbers are strings)
- (OutlineScene*)sceneWithNumber:(NSString*)sceneNumber;

/// Returns all scenes in the given section.
- (NSArray<OutlineScene*>*)scenesInSection:(OutlineScene*)topSection;

/// Returns the lines in given scene
- (NSArray<Line*>*)linesForScene:(OutlineScene*)scene;


#pragma mark - Sequence lookup

/// Returns the line preceding given line
- (Line*)previousLine:(Line*)line;

/// Returns the line following given line
- (Line*)nextLine:(Line*)line;

/// Returns the next outline item of given type
/// @param type Type of the outline element (heading/section)
/// @param position Position where to start the search
- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position;


#pragma mark - Block lookup

/// Returns a "screenplay block" (items which beling together, such as character cues and dialogue) for the given range.
- (NSArray<Line*>*)blockForRange:(NSRange)range;

/// Returns a "screenplay block" (items which beling together, such as character cues and dialogue) for the given line,
- (NSArray<Line*>*)blockFor:(Line*)line;

/// Returns the both dual dialogue blocks for given line. Pass a pointer to `isDualDialogue` to see if the line *actually* is part of a dual dialogue block.
- (NSArray<NSArray<Line*>*>*)dualDialogueFor:(Line*)line isDualDialogue:(bool*)isDualDialogue;

/// Calculates the range for given block
- (NSRange)rangeForBlock:(NSArray<Line*>*)block;


@end

