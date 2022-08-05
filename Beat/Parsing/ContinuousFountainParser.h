//
//  ContinousFountainParser.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Line.h"
#import "OutlineScene.h"
#import "BeatDocumentSettings.h"
#import "BeatExportSettings.h"
@class OutlineScene;

@interface BeatScreenplay : NSObject
+(instancetype)from:(ContinuousFountainParser*)parser;
+(instancetype)from:(ContinuousFountainParser*)parser settings:(BeatExportSettings*)settings;
@property (nonatomic) NSArray <Line*>* lines;
@property (nonatomic) NSArray *titlePage;
@end

@protocol ContinuousFountainParserDelegate <NSObject>
@property (nonatomic) bool printSceneNumbers;
@property (atomic) BeatDocumentSettings *documentSettings;
@property (nonatomic, readonly) Line* characterInputForLine;

- (NSInteger)sceneNumberingStartsFrom;
- (NSRange)selectedRange;
- (void)reformatLinesAtIndices:(NSMutableIndexSet*)indices;
- (void)applyFormatChanges;

@end

// Plugin compatibility
@protocol ContinuousFountainParserExports <JSExport>
@property (readonly) NSMutableArray<Line*>* lines;
@property (nonatomic, readonly) NSMutableArray *outline;
@property (nonatomic, readonly) NSMutableArray *scenes;
@property (nonatomic, readonly) NSMutableArray *titlePage;
@property (nonatomic, readonly) NSMutableSet *storylines;
@property (nonatomic, readonly) NSMutableDictionary *storybeats;
@property (nonatomic, readonly) bool hasTitlePage;
- (NSString*)screenplayForSaving;
- (void)parseText:(NSString*)text;
- (Line*)lineAtIndex:(NSInteger)index;
- (Line*)lineAtPosition:(NSInteger)position;
- (NSArray*)linesInRange:(NSRange)range;
- (NSDictionary*)scriptForPrinting;
- (BeatScreenplay*)forPrinting;
- (NSInteger)numberOfScenes;
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
- (OutlineScene*)sceneAtPosition:(NSInteger)index;
- (NSArray*)scenesInRange:(NSRange)range;

- (Line*)previousLine:(Line*)line;
- (Line*)nextLine:(Line*)line;

@end

@interface ContinuousFountainParser : NSObject <ContinuousFountainParserExports, LineDelegate>
@property (nonatomic, weak) id 	<ContinuousFountainParserDelegate> delegate; /// Parser delegate. Basically it's the document.

@property (atomic) NSMutableArray *lines; //Stores every line as an element. Multiple lines of stuff
@property (nonatomic) NSMutableIndexSet *changedIndices; //Stores every line that needs to be formatted according to the type
@property (nonatomic) NSMutableArray *outline;
@property (nonatomic) NSMutableArray *titlePage;
@property (nonatomic) NSMutableSet *storylines;
@property (nonatomic) NSMutableDictionary <NSString*, NSMutableArray<Storybeat*>*>*storybeats;
@property (nonatomic) bool hasTitlePage;

// For STATIC parsing without a document
@property (nonatomic) BeatDocumentSettings *staticDocumentSettings;
@property (nonatomic) bool staticParser;

// Initialization for both CONTINUOUS and STATIC parsing
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate;
- (ContinuousFountainParser*)initWithString:(NSString*)string;
- (ContinuousFountainParser*)initStaticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings;
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate nonContinuous:(bool)nonContinuous;

//Parsing methods
- (void)parseText:(NSString*)text;
- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string;
//- (void)setSceneNumbers:(NSString*)text;
- (void)resetParsing;
- (void)createOutline;
- (void)updateOutlineWithChangeInRange:(NSRange)range;
- (NSArray*)scenes;
- (void)ensurePositions;
- (NSArray*)linesForScene:(OutlineScene*)scene;
- (Line*)previousLine:(Line*)line;
- (Line*)nextLine:(Line*)line;
- (void)correctParsesForLines:(NSArray*)lines;

// Thread safety convenience methods
- (NSArray*)safeLines;
- (NSArray*)safeOutline;

// Preprocess for printing & saving
- (NSString*)screenplayForSaving;
- (NSArray*)preprocessForPrinting;
- (NSArray*)preprocessForPrintingPrintNotes:(bool)printNotes;

// Parselinetype is available for some testing
- (LineType)parseLineType:(Line*)line atIndex:(NSUInteger)index recursive:(bool)recursive;
- (LineType)parseLineType:(Line*)line atIndex:(NSUInteger)index currentlyEditing:(bool)currentLine;
- (LineType)parseLineType:(Line*)line atIndex:(NSUInteger)index recursive:(bool)recursive currentlyEditing:(bool)currentLine;

//Convenience Methods for Testing
- (NSString*)stringAtLine:(NSUInteger)line;
- (LineType)typeAtLine:(NSUInteger)line;
- (NSUInteger)positionAtLine:(NSUInteger)line;
- (NSString*)sceneNumberAtLine:(NSUInteger)line;

//Convenience Methods for Other Stuff
- (Line*)lineAtPosition:(NSInteger)position;
- (NSUInteger)lineIndexAtPosition:(NSUInteger)position;
- (NSUInteger)outlineIndexAtLineIndex:(NSUInteger)index;
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
- (NSArray*)scenesInRange:(NSRange)range;
- (NSArray*)linesInRange:(NSRange)range;
- (NSArray*)scenesInSection:(OutlineScene*)topSection;

- (BeatScreenplay*)forPrinting;
- (NSInteger)numberOfScenes;
- (LineType)lineTypeAt:(NSInteger)index;

- (NSArray<Line*>*)blockForRange:(NSRange)range;
- (NSArray<Line*>*)blockFor:(Line*)line;

- (NSArray*)lineIdentifiers:(NSArray<Line*>*)lines;
- (void)setIdentifiers:(NSArray*)uuids;

//Convenience Methods for Outlineview data
- (BOOL)getAndResetChangeInOutline;
- (NSArray*)changesInOutline;
- (NSUInteger)numberOfOutlineItems; //Returns the number of items for the outline view
- (Line*)closestPrintableLineFor:(Line*)line;

- (NSString*)description;
@end
