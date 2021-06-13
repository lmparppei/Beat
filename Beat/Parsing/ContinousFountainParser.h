//
//  ContinousFountainParser.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
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

@end

// Plugin compatibility
@protocol ContinuousFountainParserExports <JSExport>
@property (nonatomic, readonly) NSMutableArray *lines;
@property (nonatomic, readonly) NSMutableArray *outline;
@property (nonatomic, readonly) NSMutableArray *titlePage;
- (void)parseText:(NSString*)text;
@end

@interface ContinousFountainParser : NSObject <ContinuousFountainParserExports>
// A new structure to avoid having thousands of loopbacks & recursion.
// Slowly being implemented into the code.
@property (nonatomic, weak) id 	<ContinuousFountainParserDelegate> delegate;

@property (nonatomic) NSMutableArray *lines; //Stores every line as an element. Multiple lines of stuff
@property (nonatomic) NSMutableArray *changedIndices; //Stores every line that needs to be formatted according to the type
@property (nonatomic) NSMutableArray *outline;
@property (nonatomic) NSMutableArray *titlePage;
@property (nonatomic) NSMutableArray *storylines;
@property (nonatomic) bool hasTitlePage;

// For STATIC parsing without a document
@property (nonatomic) BeatDocumentSettings *staticDocumentSettings;

// Initialization for both CONTINUOUS and STATIC parsing
- (ContinousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate;
- (ContinousFountainParser*)initWithString:(NSString*)string;
- (ContinousFountainParser*)staticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings;

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
- (NSArray*)linesInRange:(NSRange)range;
- (NSString*)cleanedString;
- (NSDictionary*)scriptForPrinting;
- (NSString*)scriptForSaving;
- (NSInteger)numberOfScenes;

//Convenience Methods for Outlineview data
- (BOOL)getAndResetChangeInOutline;
- (NSUInteger)numberOfOutlineItems; //Returns the number of items for the outline view
- (OutlineScene*) getOutlineForLine:(Line*)line;

- (NSString*)description;
@end
