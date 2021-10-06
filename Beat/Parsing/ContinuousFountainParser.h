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
@class OutlineScene;

@protocol ContinuousFountainParserDelegate <NSObject>
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) BeatDocumentSettings *documentSettings;
@property (nonatomic, readonly) Line* characterInputForLine;

- (NSInteger)sceneNumberingStartsFrom;
- (NSRange)selectedRange;
- (void)headingChangedToActionAt:(Line*)line;
- (void)actionChangedToHeadingAt:(Line*)line;
- (void)reformatLinesAtIndices:(NSMutableIndexSet*)indices;
- (void)applyFormatChanges;
@end

// Plugin compatibility
@protocol ContinuousFountainParserExports <JSExport>
@property (nonatomic, readonly) NSMutableArray *lines;
@property (nonatomic, readonly) NSMutableArray *outline;
@property (nonatomic, readonly) NSMutableArray *scenes;
@property (nonatomic, readonly) NSMutableArray *titlePage;
@property (nonatomic, readonly) NSMutableArray *storylines;
@property (nonatomic, readonly) bool hasTitlePage;
- (void)parseText:(NSString*)text;
- (Line*)lineAtPosition:(NSInteger)position;
- (NSArray*)linesInRange:(NSRange)range;
- (NSString*)cleanedString;
- (NSDictionary*)scriptForPrinting;
- (NSString*)scriptForSaving;
- (NSInteger)numberOfScenes;
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
@end

@interface ContinuousFountainParser : NSObject <ContinuousFountainParserExports, LineDelegate>
// A new structure to avoid having thousands of loopbacks & recursion.
// Slowly being implemented into the code.
@property (nonatomic, weak) id 	<ContinuousFountainParserDelegate> delegate;

@property (nonatomic) NSMutableArray *lines; //Stores every line as an element. Multiple lines of stuff
@property (nonatomic) NSMutableIndexSet *changedIndices; //Stores every line that needs to be formatted according to the type
@property (nonatomic) NSMutableArray *outline;
@property (nonatomic) NSMutableArray *titlePage;
@property (nonatomic) NSMutableArray *storylines;
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
- (NSArray*)scenes;
- (void)ensurePositions;
- (NSArray*)linesForScene:(OutlineScene*)scene;
- (Line*)nextLine:(Line*)line;
- (void)correctParsesForLines:(NSArray*)lines;

// Preprocess for printing
- (NSArray*)preprocessForPrinting;
- (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines;

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
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
- (NSArray*)linesInRange:(NSRange)range;
- (NSString*)cleanedString;
- (NSDictionary*)scriptForPrinting;
- (NSString*)scriptForSaving;
- (NSInteger)numberOfScenes;
- (LineType)lineTypeAt:(NSInteger)index;

//Convenience Methods for Outlineview data
- (BOOL)getAndResetChangeInOutline;
- (NSUInteger)numberOfOutlineItems; //Returns the number of items for the outline view
- (OutlineScene*) getOutlineForLine:(Line*)line;

- (NSString*)description;
@end
