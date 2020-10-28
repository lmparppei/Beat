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
    dualDialogueCharacter,
    dualDialogueParenthetical,
    dualDialogue,
    transitionLine,
    lyrics,
    pageBreak,
    centered,
	more
} LineType;


@interface Line : NSObject

@property LineType type;
@property (strong, nonatomic) NSString* string;
@property NSUInteger position;
@property NSUInteger numberOfPreceedingFormattingCharacters;
@property NSUInteger sectionDepth;
@property NSString* sceneNumber;
@property NSInteger sceneIndex;
@property NSString* color;
@property NSArray* storylines;
//@property double height;

@property NSMutableIndexSet* boldRanges;
@property NSMutableIndexSet* italicRanges;
@property NSMutableIndexSet* underlinedRanges;
@property NSMutableIndexSet* noteRanges;
@property NSMutableIndexSet* omitedRanges;
@property NSRange titleRange;
@property NSRange sceneNumberRange;
@property bool omitIn; //wether the line terminates an unfinished omit
@property bool omitOut; //Wether the line starts an omit and doesn't finish it

- (Line*)initWithString:(NSString*)string position:(NSUInteger)position;
- (Line*)initWithString:(NSString*)string type:(LineType)type;
- (Line*)initWithString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSUInteger)position;
- (NSString*)toString;
- (NSString*)typeAsString;
- (NSString*)typeAsFountainString;
- (NSString*)cleanedString;
- (NSString*)stripInvisible;
- (bool)omited;
- (bool)note;
- (bool)centered;
- (NSRange)range;

+ (Line*)withString:(NSString*)string type:(LineType)type;
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;

// Copy element
- (Line*)clone;

// Helper
- (bool)isBoldedAt:(NSInteger)index;
- (bool)isItalicAt:(NSInteger)index;
- (bool)isUnderlinedAt:(NSInteger)index;

// Note: Following stuff is intended ONLY for non-continuous parsing
- (bool)isTitlePage;
- (bool)isInvisible;
- (bool)isDialogueElement;
- (bool)isDualDialogueElement;

- (NSString*)stripSceneNumber;
- (NSString*)stripFormattingCharacters;
- (NSString*)stripNotes;

@property bool isSplitParagraph;
@property bool nextElementIsDualDialogue; // Note: this is ONLY used for non-continuous parsing

// Properties for pagination
@property bool unsafeForPageBreak;

// For comparing with another version
@property bool changed;


@end
