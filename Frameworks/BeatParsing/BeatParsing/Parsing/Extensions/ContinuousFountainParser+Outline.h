//
//  ContinuousFountainParser+Outline.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 22.1.2024.
//

#import <BeatParsing/ContinuousFountainParser.h>
#import <BeatParsing/OutlineChanges.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol ContinuousFountainParserOutlineExports <JSExport>
/// Returns a tree structure for the outline. Only top-level elements are included, get the rest using `element.chilren`.
- (NSArray*)outlineTree;
@end

@interface ContinuousFountainParser (Outline) <ContinuousFountainParserOutlineExports>

#pragma mark - Outline creation

/// Creates a full new outline.
- (void)updateOutline;
/// Rebuilds the outline hierarchy (section depths) and calculates scene numbers.
- (void)updateOutlineHierarchy;
/// NOTE: This method is used by line preprocessing to avoid recreating the outline. It has some overlapping functionality with `updateOutlineHierarchy` and `updateSceneNumbers:forcedNumbers:`.
- (void)updateSceneNumbersInLines;

/// Updates the whole outline from scratch with given lines.
- (void)updateOutlineWithLines:(NSArray<Line*>*)lines;
/// Updates the outline element for given line. If you don't know the index for the outline element or line, pass `NSNotFound`.
- (void)updateSceneForLine:(Line*)line at:(NSInteger)index lineIndex:(NSInteger)lineIndex;
/// Updates the given scene and gathers its notes and synopsis lines. If you don't know the line/scene index pass them as `NSNotFound` .
- (void)updateScene:(OutlineScene*)scene at:(NSInteger)index lineIndex:(NSInteger)lineIndex;

/// Adds an update to this line, but only if needed
- (void)addUpdateToOutlineIfNeededAt:(NSInteger)lineIndex;
/// Forces an update to the outline element which contains the given line. No additional checks.
- (void)addUpdateToOutlineAtLine:(Line*)line didChangeType:(bool)didChangeType;

/// Inserts a new outline element with given line.
- (void)addOutlineElement:(Line*)line;
/// Remove outline element for given line
- (void)removeOutlineElementForLine:(Line*)line;


#pragma mark - Fetching outline data

/// Call this after text was changed. This in turn calls `outlineDidChange` in your document controller when needed.
- (void)checkForChangesInOutline;
/// Returns a tree structure for the outline. Only top-level elements are included, get the rest using `element.chilren`.
- (NSArray*)outlineTree;
/// Updates scene numbers for scenes. Autonumbered will get incremented automatically.
/// - note: the arrays can contain __both__ `OutlineScene` or `Line` items to be able to update line content individually without building an outline.
- (void)updateSceneNumbers:(NSArray*)autoNumbered forcedNumbers:(NSSet*)forcedNumbers;
/// Returns a set of all scene numbers in the outline
- (NSSet*)sceneNumbersInOutline;
/// Returns the number from which automatic scene numbering should start from
- (NSInteger)sceneNumberOrigin;
/// Gets and resets the changes to outline
//- (OutlineChanges*)changesInOutline;
/// Returns an array of dictionaries with UUID mapped to the actual string.
-(NSArray<NSDictionary<NSString*,NSString*>*>*)outlineUUIDs;

@end
