//
//  Line.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    empty = 0,
    section,
    synopse,
    titlePageTitle,
    titlePageAuthor,
    titlePageCredit,
    titlePageSource,
    titlePageContact,
    titlePageDraftDate,
    titlePageUnknown,
    heading,
    action,
    character,
    parenthetical,
    dialogue,
    doubleDialogueCharacter,
    doubleDialogueParenthetical,
    doubleDialogue,
    transitionLine,
    lyrics,
    pageBreak,
    centered,
} LineType;


@interface Line : NSObject

@property LineType type;
@property (strong, nonatomic) NSString* string;
@property NSUInteger position;
@property NSUInteger numberOfPreceedingFormattingCharacters;
@property NSUInteger sectionDepth;
@property NSString* sceneNumber;
@property NSString* color;
//@property double height;

@property NSMutableIndexSet* boldRanges;
@property NSMutableIndexSet* italicRanges;
@property NSMutableIndexSet* underlinedRanges;
@property NSMutableIndexSet* noteRanges;
@property NSMutableIndexSet* omitedRanges;
@property bool omitIn; //wether the line terminates an unfinished omit
@property bool omitOut; //Wether the line starts an omit and doesn't finish it

- (Line*)initWithString:(NSString*)string position:(NSUInteger)position;
- (NSString*)toString;
- (NSString*)typeAsString;
- (bool)omited;

//- (NSInteger)rowsForLine;
//- (void)setElementHeight;

@end
