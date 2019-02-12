//
//  Line.h
//  Writer
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
    transition,
    lyrics,
    pageBreak,
    centered,
} LineType;


@interface Line : NSObject

@property LineType type;
@property (strong, nonatomic) NSString* string;
@property NSUInteger position;
@property NSUInteger numberOfPreceedingFormattingCharacters;
@property NSString* sceneNumber;

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

@end
