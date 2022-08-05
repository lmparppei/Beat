//
//  Line.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Storybeat.h"

typedef NS_ENUM(NSUInteger, LineType) {
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
	typeCount
};

@protocol LineExports <JSExport>
@property (nonatomic) NSUUID *uuid; // You can actually write into the UUID

@property (readonly) LineType type;
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

@property (nonatomic, readonly) bool noteIn;
@property (nonatomic, readonly) bool noteOut;

@property (nonatomic, readonly) NSString *marker;
@property (nonatomic, readonly) NSString *markerDescription;

@property (nonatomic, readonly) NSDictionary* ranges;

@property (nonatomic) NSArray<Storybeat*>* beats;

- (NSString*)stripFormatting;
- (bool)isTitlePage;
- (bool)isInvisible;
- (bool)isDialogue;
- (bool)isDialogueElement;
- (bool)isDualDialogueElement;
- (bool)isOutlineElement;
- (NSString*)typeAsString;
- (NSString*)characterName;
- (NSString*)textContent;
- (NSDictionary*)forSerialization;
- (NSString*)trimmed;
- (bool)forced;
- (id)clone;
- (NSIndexSet*)contentRanges;
- (NSIndexSet*)contentRangesWithNotes;

- (bool)hasBeat;
- (bool)hasBeatForStoryline:(NSString*)storyline;
- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline;

JSExportAs(setCustomData, - (NSDictionary*)setCustomData:(NSString*)key value:(id)value);
- (id)getCustomData:(NSString*)key;

@end

@protocol LineDelegate <NSObject>
@property (readonly) NSMutableArray *lines;
@end

@class Storybeat;

@interface Line : NSObject <LineExports>

@property (nonatomic, weak) id<LineDelegate> parser; // For future generations
@property (nonatomic, weak) id paginator; // For future generations
@property (nonatomic, weak) Line *representedLine; /// The line in editor/parser from which this one was copied from, can be nil

@property LineType type;
@property (strong) NSString* string;

@property (nonatomic) NSUUID *uuid;

@property (nonatomic) NSUInteger position;
@property (nonatomic) NSUInteger numberOfPrecedingFormattingCharacters;
@property (nonatomic) NSUInteger sectionDepth;
@property (nonatomic) NSString* sceneNumber;
@property (nonatomic) NSInteger sceneIndex;
@property (nonatomic) NSString* color;
@property (nonatomic) NSArray* storylines;

@property (nonatomic) LineType formattedAs; /// The type which this line was previously formatted as

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

@property (nonatomic) NSMutableIndexSet* removalSuggestionRanges;

@property (nonatomic) NSRange titleRange;
@property (nonatomic) NSRange markerRange;
@property (nonatomic) NSRange sceneNumberRange;
@property (nonatomic) NSRange colorRange;
//@property (nonatomic) NSMutableIndexSet *storylineRanges;
@property (nonatomic) NSMutableIndexSet *beatRanges;

@property (nonatomic, readonly) NSUInteger index; /// Index of line in parser, experimental

@property (nonatomic) NSMutableArray *tags;

@property (nonatomic) NSInteger length;

@property (nonatomic) bool omitIn; /// Whether the line terminates an unfinished omit
@property (nonatomic) bool omitOut; /// Whether the line starts a note and doesn't finish it

@property (nonatomic) bool noteIn; /// Whether the line terminates an unfinished note
@property (nonatomic) bool noteOut; /// Whether the line starts a note and doesn't finish it
@property (nonatomic) bool cancelsNoteBlock;
@property (nonatomic) bool beginsNoteBlock;
@property (nonatomic) bool endsNoteBlock;
@property (nonatomic) NSMutableIndexSet *noteOutIndices;
@property (nonatomic) NSMutableIndexSet *noteInIndices;

@property (nonatomic) NSMutableDictionary* customDataDictionary;

@property (nonatomic) NSInteger heightInPaginator;


- (Line*)initWithString:(NSString*)string position:(NSUInteger)position;
- (Line*)initWithString:(NSString*)string position:(NSUInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSUInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type;
- (Line*)initWithString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSUInteger)position;
- (NSString*)typeAsString;
- (bool)omitted; /// The line is omitted completely from print — either inside an omission block or a note
- (bool)note; /// The line is completely a note
- (bool)centered;
- (NSString*)trimmed;
- (bool)forced;

- (unichar)lastCharacter; /// Return last character (NOTE: Be careful not to go out of range!)

- (NSRange)range; /// Range of the whole line, including line break
- (NSRange)textRange; /// The range of string only, excluding line break
- (NSRange)globalRangeToLocal:(NSRange)range;
- (NSString*)textContent;

+ (Line*)withString:(NSString*)string type:(LineType)type;
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
+ (Line*)withString:(NSString*)string type:(LineType)type parser:(id<LineDelegate>)parser;
+ (NSDictionary*)typeDictionary;

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
- (bool)isOutlineElement; /// returns true for scene heading, section and synopsis
- (bool)isAnyCharacter; /// returns true for single and dual dialogue character cue
- (bool)isAnyParenthetical; /// returns true for single and dual dialogue parenthetical
- (bool)isAnyDialogue; /// returns true for single and dual dialogue

- (NSString*)stripSceneNumber;
- (NSString*)stripFormatting;
- (NSString*)stripNotes;
- (NSString*)stringForDisplay;

@property (nonatomic) bool isSplitParagraph; /// This element contains line breaks
@property (nonatomic) bool nextElementIsDualDialogue; /// Note: this is ONLY used for non-continuous parsing

// Properties for pagination
@property (nonatomic) bool unsafeForPageBreak; /// EXPERIMENTAL

// Markers
@property (nonatomic) NSString *marker;
@property (nonatomic) NSString *markerDescription;

// Beats
@property (nonatomic) NSArray<Storybeat*>* beats;

// For FDX export
- (NSAttributedString*)attributedStringForFDX;
- (NSIndexSet*)formattingRanges;
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes;
- (NSIndexSet*)contentRanges;
- (NSIndexSet*)contentRangesWithNotes;
- (NSString*)characterName;
- (NSRange)characterNameRange;

- (void)resetFormatting;
- (void)joinWithLine:(Line*)line;
- (NSArray*)splitAndFormatToFountainAt:(NSInteger)index;

- (NSDictionary*)forSerialization; /// A JSON object for plugin use

// For revision data
@property (nonatomic) bool changed;
@property (nonatomic) NSMutableDictionary <NSString*, NSMutableIndexSet*>* revisedRanges;
@property (nonatomic) NSString *revisionColor;

// Story beats
- (bool)hasBeat;
- (bool)hasBeatForStoryline:(NSString*)storyline;
- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline;
- (NSRange)firstBeatRange;

-(NSString *)description;
@end
