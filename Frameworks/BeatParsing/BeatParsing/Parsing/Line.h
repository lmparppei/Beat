//
//  Line.h
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Storybeat.h"
#import "BeatNoteData.h"

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

@class OutlineScene;

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
@property (nonatomic, readonly) NSArray<BeatNoteData*>* notes;

@property (nonatomic, readonly) bool noteIn;
@property (nonatomic, readonly) bool noteOut;

@property (nonatomic) NSRange markerRange;
@property (nonatomic, readonly) NSString *marker;
@property (nonatomic, readonly) NSString *markerDescription;

@property (nonatomic, readonly) NSDictionary* ranges;
@property (nonatomic, readonly) NSMutableDictionary <NSString*, NSMutableIndexSet*>* revisedRanges;

@property (nonatomic) NSArray<Storybeat*>* beats;

@property (nonatomic, readonly) NSInteger heightInPaginator;

@property (nonatomic) bool collapsed;

- (NSString*)stripFormatting;
- (bool)isTitlePage;
- (bool)isInvisible;
- (bool)isDialogue;
- (bool)isDualDialogue;
- (bool)isDialogueElement;
- (bool)isDualDialogueElement;
- (bool)isOutlineElement;
- (bool)effectivelyEmpty;
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

// Identity
- (BOOL)matchesUUIDString:(NSString*)uuid;
- (NSString*)uuidString;

/// Returns a dictionary with the *actual range* (including brackets) as the key
- (NSMutableDictionary<NSNumber*, NSString*>*)noteContentsAndRanges;
/// Returns note content strings as an array
- (NSArray*)noteContents;
- (NSArray*)noteData;
/// Returns the **last** available range adn note with given prefix  (`[range, content]`)
- (NSArray*)contentAndRangeForLastNoteWithPrefix:(NSString*)string;

JSExportAs(setCustomData, - (NSDictionary*)setCustomData:(NSString*)key value:(id)value);
- (id)getCustomData:(NSString*)key;
@end

@protocol LineDelegate <NSObject>
@property (readonly) NSMutableArray *lines;
@property (nonatomic) NSMutableIndexSet *changedIndices;
- (NSArray<Line*>*)linesForScene:(OutlineScene*)outline;
@end

@class Storybeat;

@interface Line : NSObject <LineExports>

#pragma mark - Class methods

/// Returns a dictionary of all available types.
+ (NSDictionary*)typeDictionary;
/// Returns the type name for given string. Type names are basically `LineType`s in a string form, with no spaces. Use `typeAsString` to get a human-readable type string.
+ (NSString*)typeName:(LineType)type;


#pragma mark - Initializers

+ (Line*)withString:(NSString*)string type:(LineType)type;
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
+ (Line*)withString:(NSString*)string type:(LineType)type parser:(id<LineDelegate>)parser;

- (Line*)initWithString:(NSString*)string position:(NSInteger)position;
- (Line*)initWithString:(NSString*)string position:(NSInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSInteger)position parser:(id<LineDelegate>)parser;
- (Line*)initWithString:(NSString*)string type:(LineType)type;
- (Line*)initWithString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit;
- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSInteger)position;


#pragma mark - Basic values

@property LineType type;
@property (strong, atomic) NSString* string;
@property (strong, atomic) NSString* originalString;

@property (nonatomic) NSInteger position;
@property (nonatomic) NSInteger length;

@property (nonatomic) NSUInteger sectionDepth;
@property (nonatomic) NSString* sceneNumber;
@property (nonatomic) NSInteger sceneIndex;
@property (nonatomic) NSString* color;

@property (nonatomic) bool forcedCharacterCue;

/// Range of the whole line, including line break
- (NSRange)range;
/// Range of the string only, excluding line break
- (NSRange)textRange;
/// Converts a global range to the local range insde this string.
- (NSRange)globalRangeToLocal:(NSRange)range;
/// Converts a local range to global range.
- (NSRange)globalRangeFromLocal:(NSRange)range;

/// Legacy method for backwards-compatibility. Use `.stripFormatting` instead.
- (NSString*)textContent;

/// Copies this line
- (Line*)clone;


#pragma mark - String generation

/// Returns the line string with scene number removed.
- (NSString*)stripSceneNumber;
/// Returns a string with all formatting removed. Also removes any hidden ranges.
- (NSString*)stripFormatting;
/// Returns a string with all of the note ranges removed.
- (NSString*)stripNotes;
/// Returns line string content with no formatting, but doesn't return an empty string if the line is omitted in the screenplay.
- (NSString*)stringForDisplay;
/// Returns a trimmed string
- (NSString*)trimmed;

/// An attributed string with Final Draft compatible attribute names for styling
- (NSAttributedString*)attributedStringForFDX;

/// Returns and caches the line with attributes.
/// @warning This string will be created ONCE. You can't update the line properties and expect this method to reflect those changes.
@property (nonatomic) NSAttributedString *attrString;


#pragma mark - Identity

@property (nonatomic) NSUUID *uuid;
@property (nonatomic, weak) Line *representedLine; /// The line in editor/parser from which this one was copied from, can be nil

- (BOOL)matchesUUID:(NSUUID*)uuid;
- (BOOL)matchesUUIDString:(NSString*)uuid;
- (NSString*)uuidString;


#pragma mark - Outside entities

@property (nonatomic, weak) id<LineDelegate> parser; // For future generations
@property (nonatomic, weak) id paginator; // For future generations


#pragma mark - Metadata

@property (nonatomic) NSArray* storylines;
@property (nonatomic) NSArray<Storybeat*>* beats;
@property (nonatomic) NSMutableArray *tags;
@property (nonatomic) NSMutableDictionary<NSIndexSet*, NSArray*>* attachments;

@property (nonatomic) NSMutableDictionary* customDataDictionary;


#pragma mark Generated metadata

@property (nonatomic, readonly) NSUInteger index; /// Index of line in parser, experimental


#pragma mark - Editor booleans

@property (nonatomic) bool collapsed;


#pragma mark - Ranges

#pragma mark Formatting

/// The type which this line was previously formatted as. Can be used for checking if the type has changed before reformatting.
@property (nonatomic) LineType formattedAs;
/// The resulting formatting in custom format (not compatible with AppKit/UIKit formatting)
@property (nonatomic) NSAttributedString* formattedString;

@property (nonatomic) NSUInteger numberOfPrecedingFormattingCharacters;

@property (nonatomic) NSMutableIndexSet* boldRanges;
@property (nonatomic) NSMutableIndexSet* italicRanges;
@property (nonatomic) NSMutableIndexSet* boldItalicRanges;
@property (nonatomic) NSMutableIndexSet* underlinedRanges;
@property (nonatomic) NSMutableIndexSet* noteRanges;
@property (nonatomic) NSMutableIndexSet* omittedRanges;
@property (nonatomic) NSMutableIndexSet* highlightRanges;
@property (nonatomic) NSMutableIndexSet* strikeoutRanges;
@property (nonatomic) NSMutableIndexSet* escapeRanges;

- (bool)isBoldedAt:(NSInteger)index;
- (bool)isItalicAt:(NSInteger)index;
- (bool)isUnderlinedAt:(NSInteger)index;

/// Returns `true` if the line doesn't have any formatting characters.
-(bool)noFormatting;


#pragma mark Other data ranges

@property (nonatomic) NSRange titleRange;
@property (nonatomic) NSRange sceneNumberRange;
@property (nonatomic) NSRange colorRange;

@property (nonatomic) NSMutableIndexSet *beatRanges;
@property (nonatomic) NSMutableIndexSet* removalSuggestionRanges;


#pragma mark Range methods

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
/// Joins a line into this line. Copies all stylization and offsets the formatting ranges.
- (void)joinWithLine:(Line*)line;
/// Splits the line at given index, and also formats it back to a Fountain string, even if the split happens inside a formatted range.
- (NSArray<Line*>*)splitAndFormatToFountainAt:(NSInteger)index;
/// A JSON object for plugin use
- (NSDictionary*)forSerialization;


#pragma mark - Omissions

/// Whether the line terminates an unfinished omit
@property (nonatomic) bool omitIn;
/// Whether the line starts a note and doesn't finish it
@property (nonatomic) bool omitOut;

/// The line is omitted completely from print — either inside an omission block or a note
- (bool)omitted;
/// The line is centered (wtf)
- (bool)centered;
/// Return `true` if the line either bleeds out an omission or closes an existing one
- (bool)opensOrClosesOmission;


#pragma mark - Notes

/// Whether the line terminates an unfinished note
@property (nonatomic) bool noteIn;
/// Whether the line starts a note and doesn't finish it
@property (nonatomic) bool noteOut;

@property (nonatomic) bool cancelsNoteBlock;
@property (nonatomic) bool beginsNoteBlock;
@property (nonatomic) bool endsNoteBlock;

@property (nonatomic) NSMutableIndexSet *noteOutIndices;
@property (nonatomic) NSMutableIndexSet *noteInIndices;

- (NSArray*)noteDataWithLineIndex:(NSInteger)lineIndex;

/// The line is filled by a note
- (bool)note;

/// Returns a dictionary with the *actual range* (including brackets) as the key
- (NSMutableDictionary<NSValue*, NSString*>*)noteContentsAndRanges;
/// Returns note content strings as an array
- (NSArray*)noteContents;


#pragma mark - Title page lines

/// Returns a lowercase title page key (ie. `Draft Date: ...` -> `draft date`
- (NSString*)titlePageKey;
/// Returns  title page line value (ie. `Title: Something -> `something`
- (NSString*)titlePageValue;



#pragma mark - Pagination information

@property (nonatomic) NSInteger heightInPaginator;
/// This element contains line breaks
@property (nonatomic) bool isSplitParagraph;
/// Notes that the next dialogue element is a pair to this one. **Note**: used for non-continuous parsing ONLY
@property (nonatomic) bool nextElementIsDualDialogue;
/// This line begins a new paragraph and is not joined with another one. **Note:** Used for non-continuous parsing ONLY
@property (nonatomic) bool beginsNewParagraph;
/// This line is unsafe as a starting point for live pagination operations.
@property (nonatomic) bool unsafeForPageBreak;


#pragma mark - Markers

/// Marker color
@property (nonatomic) NSString *marker;
/// Marker text content
@property (nonatomic) NSString *markerDescription;
/// Marker range
@property (nonatomic) NSRange markerRange;


#pragma mark - Revisions

/// A line-wide modifier for tracking changes. No idea if it's stil in use.
@property (nonatomic) bool changed;
/// Ranges with revisions. Revision generation is used as the key.
@property (nonatomic) NSMutableDictionary <NSString*, NSMutableIndexSet*>* revisedRanges;
/// The highest revision generation (color) for this line.
@property (nonatomic) NSString *revisionColor;


#pragma mark - Story beats

/// The line contains a story beat
- (bool)hasBeat;
/// Returns `true` if the line contains a story beat for the given storyline.
- (bool)hasBeatForStoryline:(NSString*)storyline;
/// Returns the story beat item for given storyline name.
- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline;
/// Returns the range for first story beat on this line.
- (NSRange)firstBeatRange;


#pragma mark - Convenience methods

/// Returns the line type in a human-readable form.
- (NSString*)typeAsString;
/// Returns the type name for this line. It's basically `LineType` as string, useful for variables, CSS styles etc. To get a human-readable version, use `typeAsString`.
- (NSString*)typeName;

/// Returns `true` if the line has a forced type
- (bool)forced;

/// Returns `true` if the line can be considered as empty. Look into the method to see what this means. (I can't remember)
- (bool)effectivelyEmpty;

/// Returns the last character in string
/// @warning Be careful not to go out of range!
- (unichar)lastCharacter;

/// returns `true` for anything that can be part of a split paragraph block
- (bool)canBeSplitParagraph;
/// returns `true` for any title page element
- (bool)isTitlePage;
/// returns `true` when the line is non-printed
- (bool)isInvisible;
/// returns `true` for character cues too
- (bool)isDialogue;
/// returns `true` for elements other than a character cue
- (bool)isDialogueElement;
/// returns `true` for dual dialogue characters too
- (bool)isDualDialogue;
/// returns `true` for elements other than a character cue
- (bool)isDualDialogueElement;
/// returns `true` for scene heading, section and synopsis
- (bool)isOutlineElement;
/// returns `true` for single and dual dialogue character cue
- (bool)isAnyCharacter;
/// returns `true` for single and dual dialogue parenthetical
- (bool)isAnyParenthetical;
/// returns `true` for single and dual dialogue
- (bool)isAnyDialogue;
/// returns `true` when the character cue has an extension (CONT'D), (V.O.) etc.
- (BOOL)hasExtension;

- (bool)hasEmojis;
- (NSArray<NSValue*>*)emojiRanges;



#pragma mark - Debugging

-(NSString *)description;
@end
