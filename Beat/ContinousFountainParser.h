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
@class OutlineScene;

@protocol ContinuousFountainParserDelegate <NSObject>

- (void)headingChangedToActionAt:(Line*)line;

@end

@interface ContinousFountainParser : NSObject
// A new structure to avoid having thousands of loopbacks & recursion.
// Slowly being implemented into the code.
@property (nonatomic, weak) id 	<ContinuousFountainParserDelegate> delegate;

@property (nonatomic) NSMutableArray *lines; //Stores every line as an element. Multiple lines of stuff
@property (nonatomic) NSMutableArray *changedIndices; //Stores every line that needs to be formatted according to the type
@property (nonatomic) NSMutableArray *outline;
@property (nonatomic) NSMutableArray *titlePage;
@property (nonatomic) bool hasTitlePage;
@property (nonatomic) NSString *openTitlePageKey;

//Parsing methods
- (ContinousFountainParser*)initWithString:(NSString*)string;
- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string;
//- (void)setSceneNumbers:(NSString*)text;
- (void)parseText:(NSString*)text;
- (void)resetParsing;
- (void)createOutline;
- (void)ensurePositions;

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
- (NSString*)cleanedString;

//Convenience Methods for Outlineview data
- (BOOL)getAndResetChangeInOutline;
- (NSUInteger)numberOfOutlineItems; //Returns the number of items for the outline view
- (NSInteger)outlineItemIndex:(Line*)item;
//- (OutlineScene*) getOutlineForLine:(Line*)line;
- (OutlineScene*) getOutlineForLine:(Line*)line;


- (NSString*)description;
@end
