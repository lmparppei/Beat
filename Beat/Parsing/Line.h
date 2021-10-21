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
	more,
	dualDialogueMore,
} LineType;

@protocol LineExports <JSExport>
@property (readonly) NSUInteger position;
@property (readonly) NSString* sceneNumber;
@property (readonly) NSString* color;
@property (readonly) NSRange range;
@property (readonly) NSRange textRange;
@property (readonly) bool omitIn;
@property (readonly) bool omitOut;
@property (readonly) bool omitted;
@property (readonly) bool note;
@property (readonly) bool centered;
@property (readonly) NSString* string;
@property (nonatomic, readonly) NSInteger length;
@property (nonatomic, readonly) NSUInteger index;

@property (nonatomic, readonly) bool noteIn; /// Wether the line terminates an unfinished note
@property (nonatomic, readonly) bool noteOut; /// Wether the line starts a note and doesn't finish it

- (NSString*)cleanedString;
- (NSString*)stripFormattingCharacters;
- (NSString*)stripFormatting;
- (bool)isTitlePage;
- (bool)isInvisible;
- (bool)isDialogueElement;
- (bool)isDualDialogueElement;
- (NSString*)typeAsString;
- (NSString*)characterName;
- (NSString*)stripInvisible;
- (NSString*)textContent;
- (NSDictionary*)forSerialization;
- (NSString*)trimmed;
- (bool)forced;
- (id)clone;
@end

@protocol LineDelegate <NSObject>
@property (readonly) NSMutableArray *lines;
@end

@interface Line : NSObject <LineExports>
@property (nonatomic, weak) id<LineDelegate> parser;
@property LineType type;
@property (strong) NSString* string;
@property (nonatomic) NSString* previousString;
@property (nonatomic) NSString* original;
@property (nonatomic) NSUInteger position;
@property (nonatomic) NSUInteger numberOfPrecedingFormattingCharacters;
@property (nonatomic) NSUInteger sectionDepth;
@property (nonatomic) NSString* sceneNumber;
@property (nonatomic) NSInteger sceneIndex;
@property (nonatomic) NSString* color;
@property (nonatomic) NSArray* storylines;

@property (nonatomic) bool forcedCharacterCue;

@property (nonatomic) NSMutableIndexSet* boldRanges;
@property (nonatomic) NSMutableIndexSet* italicRanges;
@property (nonatomic) NSMutableIndexSet* boldItalicRanges;
@property (nonatomic) NSMutableIndexSet* underlinedRanges;
@property (nonatomic) NSMutableIndexSet* noteRanges;
@property (nonatomic) NSMutableIndexSet* omittedRanges;
@property (nonatomic) NSMutableIndexSet* highlightRanges;
@property (nonatomic) NSMutableIndexSet* strikeoutRanges;
@property (nonatomic) NSMutableIndexSet* escapeRanges;

@property (nonatomic) NSMutableIndexSet* additionRanges;
@property (nonatomic) NSMutableIndexSet* removalRanges;

@property (nonatomic) NSRange titleRange;
@property (nonatomic) NSRange sceneNumberRange;
@property (nonatomic) NSRange storylineRange;
@property (nonatomic) NSRange colorRange;

@property (nonatomic, readonly) NSUInteger index; /// Index of line in parser, experimental

@property (nonatomic) NSMutableArray *tags;

@property (nonatomic) NSInteger length;

@property (nonatomic) bool omitIn; /// Wether the line terminates an unfinished omit
@property (nonatomic) bool omitOut; /// Wether the line starts a note and doesn't finish it

@property (nonatomic) bool noteIn; /// Wether the line terminates an unfinished note
@property (nonatomic) bool noteOut; /// Wether the line starts a note and doesn't finish it
@property (nonatomic) bool cancelsNoteBlock;
@property (nonatomic) bool beginsNoteBlock;
@property (nonatomic) bool endsNoteBlock;
@property (nonatomic) NSMutableIndexSet *noteOutIndices;
@property (nonatomic) NSMutableIndexSet *noteInIndices;

- (Line*)initWithString:(NSString*)string position:(NSUInteger)position;
- (Line*)initWithString:(NSString*)string position:(NSUInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSUInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type;
- (Line*)initWithString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSUInteger)position;
- (NSString*)typeAsString;
- (NSString*)typeAsFountainString; /// Type as the original Fountain repo type
- (NSString*)cleanedString;
- (NSString*)stripInvisible;
- (bool)omitted; /// The line is omitted completely from print — either inside an omission block or a note
- (bool)note; /// The line is completely a note
- (bool)centered;
- (NSString*)trimmed;
- (bool)forced;

- (NSRange)range; /// Range of the whole line, including line break
- (NSRange)textRange; /// The range of string only, excluding line break
- (NSRange)globalRangeToLocal:(NSRange)range;
- (NSString*)textContent;

+ (Line*)withString:(NSString*)string type:(LineType)type;
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
+ (Line*)withString:(NSString*)string type:(LineType)type parser:(id<LineDelegate>)parser;

// Copy element
- (Line*)clone;

// Helper methods
- (bool)isBoldedAt:(NSInteger)index;
- (bool)isItalicAt:(NSInteger)index;
- (bool)isUnderlinedAt:(NSInteger)index;

// Note: Following stuff is intended ONLY for non-continuous parsing
- (bool)isTitlePage;
- (bool)isInvisible;
- (bool)isDialogue; /// returns TRUE for character cues too
- (bool)isDialogueElement; /// returns TRUE for elements other than a character cue
- (bool)isDualDialogue; /// returns TRUE for dual dialogue characters too
- (bool)isDualDialogueElement;  /// returns TRUE for elements other than a character cue

- (NSString*)stripSceneNumber;
- (NSString*)stripFormattingCharacters;
- (NSString*)stripNotes;
- (NSString*)stringForDisplay;

@property (nonatomic) bool isSplitParagraph; /// This element contains line breaks
@property (nonatomic) bool nextElementIsDualDialogue; /// Note: this is ONLY used for non-continuous parsing

// Properties for pagination
@property (nonatomic) bool unsafeForPageBreak; /// EXPERIMENTAL

// Markers
@property (nonatomic) NSString *marker;

// For FDX export
- (NSAttributedString*)attributedStringForFDX;
- (NSIndexSet*)formattingRanges;
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes;
- (NSIndexSet*)contentRanges;
- (NSString*)characterName;
- (NSRange)characterNameRange;

- (void)resetFormatting;
- (void)joinWithLine:(Line*)line;
- (NSArray*)splitAndFormatToFountainAt:(NSInteger)index;

- (NSDictionary*)forSerialization; /// A JSON object for plugin use

// For comparing with another version
// (Is this still used?)
@property (nonatomic) bool changed;
@property (nonatomic) NSMutableIndexSet *changedRanges;

// For some undo operations
- (void)savePreviousVersion;

-(NSString *)description;
@end
