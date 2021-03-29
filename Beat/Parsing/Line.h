//
//  Line.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

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


@protocol LineExports <JSExport>
@property NSUInteger position;
@property NSString* sceneNumber;
@property NSString* color;
@property (strong, nonatomic) NSString* string;

- (NSString*)cleanedString;
- (NSString*)stripFormattingCharacters;
- (bool)isTitlePage;
- (bool)isInvisible;
- (bool)isDialogueElement;
- (bool)isDualDialogueElement;
- (NSString*)typeAsString;
@end

@interface Line : NSObject <LineExports>

@property LineType type;
@property (strong, nonatomic) NSString* string;
@property (nonatomic) NSString* original;
@property NSUInteger position;
@property NSUInteger numberOfPreceedingFormattingCharacters;
@property NSUInteger sectionDepth;
@property NSString* sceneNumber;
@property NSInteger sceneIndex;
@property NSString* color;
@property NSArray* storylines;

@property NSMutableIndexSet* boldRanges;
@property NSMutableIndexSet* italicRanges;
@property NSMutableIndexSet* underlinedRanges;
@property NSMutableIndexSet* noteRanges;
@property NSMutableIndexSet* omitedRanges;
@property NSMutableIndexSet* highlightRanges;
@property NSMutableIndexSet* strikeoutRanges;

@property NSMutableIndexSet* additionRanges;
@property NSMutableIndexSet* removalRanges;

@property NSRange titleRange;
@property NSRange sceneNumberRange;
@property NSRange storylineRange;

@property NSMutableArray *tags;

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
- (NSRange)textRange;
- (NSRange)globalRangeToLocal:(NSRange)range;

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
- (NSString*)stringForDisplay;

@property bool isSplitParagraph;
@property bool nextElementIsDualDialogue; // Note: this is ONLY used for non-continuous parsing

// Properties for pagination
@property bool unsafeForPageBreak;

// For FDX export
- (NSAttributedString*)attributedStringForFDX;
- (NSIndexSet*)formattingRanges;
- (NSIndexSet*)contentRanges;
- (NSString*)characterName;

- (void)resetFormatting;
- (void)joinWithLine:(Line*)line;
- (NSArray*)splitAndFormatToFountainAt:(NSInteger)index;

// For comparing with another version
@property bool changed;
@property (nonatomic) NSMutableIndexSet *changedRanges;
- (void)checkChanges;
- (bool)isUnchanged;

-(NSString *)description;
@end
