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
	shot,
	more, // fake element for exporting
	dualDialogueMore, // fake element for exporting
	typeCount // This is the the max number of line types, for data storing purposes
};

@protocol LineExports <JSExport>
@property (nonatomic) NSUUID *uuid; // You can actually write into the UUID

@property (readonly) LineType type;
@property (readonly) NSInteger position;
@property (readonly) NSString* sceneNumber;
@property (readonly) NSString* color;
@property (readonly) NSRange range;
@property (readonly) NSRange textRange;
@property (readonly) bool omitIn;
@property (readonly) bool omitOut;
@property (readonly) bool omitted;
@property (readonly) bool note;
@property (readonly) bool centered;
@property (readonly, atomic) NSString* string;
@property (nonatomic, readonly) NSInteger length;
@property (nonatomic, readonly) NSUInteger index;

@property (nonatomic, readonly) bool noteIn;
@property (nonatomic, readonly) bool noteOut;

@property (nonatomic, readonly) NSString *marker;
@property (nonatomic, readonly) NSString *markerDescription;

@property (nonatomic, readonly) NSDictionary* ranges;
@property (nonatomic, readonly) NSMutableDictionary <NSString*, NSMutableIndexSet*>* revisedRanges;

@property (nonatomic) NSArray<Storybeat*>* beats;

@property (nonatomic, readonly) NSInteger heightInPaginator;

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

- (BOOL)hasExtension;

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
@property (strong, atomic) NSString* string;

@property (nonatomic) NSUUID *uuid;

@property (nonatomic) NSInteger position;
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

/// Returns and caches the line with attributes.
/// @warning This string will be created ONCE. You can't update the line properties and expect this method to reflect those changes.
@property (nonatomic) NSAttributedString *attrString;

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


- (Line*)initWithString:(NSString*)string position:(NSInteger)position;
- (Line*)initWithString:(NSString*)string position:(NSInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type;
- (Line*)initWithString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSInteger)position;
- (NSString*)typeAsString;
- (bool)omitted; /// The line is omitted completely from print — either inside an omission block or a note
- (bool)note; /// The line is completely a note
- (bool)centered;
- (NSString*)trimmed;
- (bool)forced;
- (bool)opensOrClosesOmission;
- (bool)effectivelyEmpty;

- (unichar)lastCharacter; /// Return last character (NOTE: Be careful not to go out of range!)

- (NSRange)range; /// Range of the whole line, including line break
- (NSRange)textRange; /// The range of string only, excluding line break
- (NSRange)globalRangeToLocal:(NSRange)range;
- (NSString*)textContent;

+ (Line*)withString:(NSString*)string type:(LineType)type;
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
+ (Line*)withString:(NSString*)string type:(LineType)type parser:(id<LineDelegate>)parser;
+ (NSDictionary*)typeDictionary;
+ (NSString*)typeName:(LineType)type;
- (NSString*)typeName;

// Copy element
- (Line*)clone;

// Helper methods
- (bool)isBoldedAt:(NSInteger)index;
- (bool)isItalicAt:(NSInteger)index;
- (bool)isUnderlinedAt:(NSInteger)index;

/// returns TRUE for any title page element
- (bool)isTitlePage;
/// returns TRUE when the line is non-printed
- (bool)isInvisible;
/// returns TRUE for character cues too
- (bool)isDialogue;
/// returns TRUE for elements other than a character cue
- (bool)isDialogueElement;
/// returns TRUE for dual dialogue characters too
- (bool)isDualDialogue;
/// returns TRUE for elements other than a character cue
- (bool)isDualDialogueElement;
/// returns true for scene heading, section and synopsis
- (bool)isOutlineElement;
/// returns true for single and dual dialogue character cue
- (bool)isAnyCharacter;
/// returns true for single and dual dialogue parenthetical
- (bool)isAnyParenthetical;
/// returns true for single and dual dialogue
- (bool)isAnyDialogue;
- (BOOL)hasExtension;

- (NSString*)stripSceneNumber;
- (NSString*)stripFormatting;
- (NSString*)stripNotes;
- (NSString*)stringForDisplay;

@property (nonatomic) bool isSplitParagraph; // This element contains line breaks
@property (nonatomic) bool nextElementIsDualDialogue; // Note: used for non-continuous parsing ONLY
@property (nonatomic) bool beginsNewParagraph; // Note: Used for non-continuous parsing ONLY

// Properties for pagination
@property (nonatomic) bool unsafeForPageBreak; /// EXPERIMENTAL

/// Marker color
@property (nonatomic) NSString *marker;
/// Marker text
@property (nonatomic) NSString *markerDescription;

/// An array of story beats contained by this line
@property (nonatomic) NSArray<Storybeat*>* beats;

/// An attributed string with Final Draft compatible attribute names for styling
- (NSAttributedString*)attributedStringForFDX;

/// Indices of formatting characters
- (NSIndexSet*)formattingRanges;
/// Returns the formatting ranges as *global* (document-wide) ranges
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes;
/// Indices of printed content (excluding formatting symbols etc.)
- (NSIndexSet*)contentRanges;
/// Indices of printed content (excluding formatting symbols etc.), but with notes
- (NSIndexSet*)contentRangesWithNotes;
/// Character name, excluding any extensions
- (NSString*)characterName;
/// Range of the character name in the cue
- (NSRange)characterNameRange;
/// Reformats Fountain string inside the line and stores the ranges
- (void)resetFormatting;
/// Join this line with another `Line` object, and combine the attributes of th two
- (void)joinWithLine:(Line*)line;
/// Does what it says
- (NSArray<Line*>*)splitAndFormatToFountainAt:(NSInteger)index;
/// A JSON object for plugin use
- (NSDictionary*)forSerialization;

-(bool)noFormatting;

// For revision data
@property (nonatomic) bool changed;
@property (nonatomic) NSMutableDictionary <NSString*, NSMutableIndexSet*>* revisedRanges;
@property (nonatomic) NSString *revisionColor;

// Title page
/// Returns a lowercase title page key (ie. `Draft Date: ...` -> `draft date`
- (NSString*)titlePageKey;
/// Returns a title page value (ie. `Title: Something -> `something`
- (NSString*)titlePageValue;

// Story beats
/// The line contains a story beat
- (bool)hasBeat;
/// Returns TRUE if the line contains a story beat for the given storyline
- (bool)hasBeatForStoryline:(NSString*)storyline;
- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline;
- (NSRange)firstBeatRange;

- (BOOL)matchesUUID:(NSUUID*)uuid;

-(NSString *)description;
@end
