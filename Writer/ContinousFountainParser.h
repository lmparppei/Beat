//
//  ContinousFountainParser.h
//  Writer
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Line.h"

@interface ContinousFountainParser : NSObject

@property (nonatomic) NSMutableArray *lines; //Stores every line as an element. Multiple lines of stuff
@property (nonatomic) NSMutableArray *changedIndices; //Stores every line that needs to be formatted according to the type

//Parsing methods
- (ContinousFountainParser*)initWithString:(NSString*)string;
- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string;
- (void)setSceneNumbers:(NSString*)text;

//Convenience Methods for Testing
- (NSString*)stringAtLine:(NSUInteger)line;
- (LineType)typeAtLine:(NSUInteger)line;
- (NSUInteger)positionAtLine:(NSUInteger)line;
- (NSString*)sceneNumberAtLine:(NSUInteger)line;

//Convenience Methods for Outlineview data
- (BOOL)getAndResetChangeInOutline;
- (NSUInteger)numberOfOutlineItems; //Returns the number of items for the outline view
- (Line*)outlineItemAtIndex:(NSUInteger)index; //Returns an items for the outline view
- (NSInteger)outlineItemIndex:(Line*)item;

- (NSString*)description;
@end
