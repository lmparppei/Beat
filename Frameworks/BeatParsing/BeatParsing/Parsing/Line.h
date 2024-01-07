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

/// Line type enum
/// @note Some types are only used in static parsing and/or exporting, such as `more` and `dualDialogueMore`. `BeatFormatting` class also introduces supplementary types for internal use.
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
	more, /// fake element for exporting
	dualDialogueMore, /// fake element for exporting
	typeCount /// This is the the max number of line types, used in `for` loops and enumerations, can be ignored
};

#pragma mark - Formatting characters

#define FORMATTING_CHARACTERS @[@"/*", @"*/", @"*", @"_", @"[[", @"]]", @"<<", @">>"]

#define ITALIC_PATTERN @"*"
#define ITALIC_CHAR "*"
#define BOLD_PATTERN @"**"
#define BOLD_CHAR "**"
#define UNDERLINE_PATTERN @"_"
#define UNDERLINE_CHAR "_"
#define OMIT_PATTERN @"/*"
#define NOTE_PATTERN @"[["

#define NOTE_OPEN_CHAR "[["
#define NOTE_CLOSE_CHAR "]]"

#define MACRO_OPEN_CHAR "{{"
#define MACRO_CLOSE_CHAR "}}"

#define NOTE_OPEN_PATTERN "[["
#define NOTE_CLOSE_PATTERN "]]"
#define OMIT_OPEN_PATTERN "/*"
#define OMIT_CLOSE_PATTERN "*/"

#define BOLD_PATTERN_LENGTH 2
#define ITALIC_PATTERN_LENGTH 1
#define UNDERLINE_PATTERN_LENGTH 1
#define NOTE_PATTERN_LENGTH 2
#define OMIT_PATTERN_LENGTH 2
#define HIGHLIGHT_PATTERN_LENGTH 2
#define STRIKEOUT_PATTERN_LENGTH 2

#define COLOR_PATTERN "color"
#define STORYLINE_PATTERN "storyline"

#pragma mark FDX style names

// For FDX compatibility & attribution
#define BOLD_STYLE @"Bold"
#define ITALIC_STYLE @"Italic"
#define BOLDITALIC_STYLE @"BoldItalic"
#define UNDERLINE_STYLE @"Underline"
#define STRIKEOUT_STYLE @"Strikeout"
#define OMIT_STYLE @"Omit"
#define NOTE_STYLE @"Note"
#define MACRO_STYLE @"Macro"

@class OutlineScene;
@class BeatExportSettings;
@class Storybeat;

#pragma mark - Plugin API exports

/// Plugin API export protocol. See documentation for each method in public header of this class.
@protocol LineExports <JSExport>
@property (atomic) NSUUID *uuid;

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


#pragma mark - Line Object

@interface Line: NSObject <LineExports, NSCopying>

#pragma mark Class methods

/// Returns a dictionary of all available types.
+ (NSDictionary*)typeDictionary;
/// Returns the type name for given string. Type names are basically `LineType`s in a string form, with no spaces. Use `typeAsString` to get a human-readable type string.
+ (NSString*)typeName:(LineType)type;


#pragma mark Initializers

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

/// Line type (integer enum)
@property LineType type;
/// String content of this line
@property (strong, atomic) NSString* string;
/// The string value when this line was initialized
@property (strong, atomic) NSString* originalString;
/// Position (starting index) )in document
@property (nonatomic) NSInteger position;
/// Getter for string length
@property (nonatomic) NSInteger length;

/// If the line is an outline element (section/heading) this value contains the section depth
@property (nonatomic) NSUInteger sectionDepth;
/// If the line is an outline element, this value contains the scene number, but only after the outline structure has been updated
@property (nonatomic) NSString* sceneNumber;
/// Color for outline element (`nil` or empty if no color is set)
@property (nonatomic) NSString* color;
/// This line was forced to be a character cue in editor
@property (nonatomic) bool forcedCharacterCue;

/// Range of the whole line, __including__ line break.
/// @warning This can go out of bounds on last line (which doesn't have a line break), so be careful.
- (NSRange)range;
/// Range of the string only, __excluding__ line break
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
/// Returns a string with all formatting removed, taking export settings into account. Also removes any hidden ranges.
- (NSString*)stripFormattingWithSettings:(BeatExportSettings*)settings;
/// Returns a string with all of the note ranges removed.
- (NSString*)stripNotes;
/// Returns line string content with no formatting, but doesn't return an empty string if the line is omitted in the screenplay.
- (NSString*)stringForDisplay;
/// Returns a trimmed string
- (NSString*)trimmed;

/// An attributed string with Final Draft compatible attribute names.
- (NSAttributedString*)attributedStringForFDX;
/// An attributed string with Final Draft compatible attribute names.
- (NSAttributedString*)attributedString;
/// An attributed string with macros resolved and formatting ranges removed
- (NSAttributedString*)attributedStringForOutputWith:(BeatExportSettings*)settings;

/// Returns and caches the line with attributes.
/// @warning This string will be created ONCE. You can't update the line properties and expect this method to reflect those changes.
@property (nonatomic) NSAttributedString *attrString;


#pragma mark - Identity

/// Unique identifier for this line (temporary clones of this line in paginated content will hold the same ID)
@property (atomic) NSUUID *uuid;
/// The line in editor/parser from which this one was copied from, can be nil
@property (nonatomic, weak) Line *representedLine;
/// String representation of the UUID
- (NSString*)uuidString;

- (BOOL)matchesUUID:(NSUUID*)uuid;
- (BOOL)matchesUUIDString:(NSString*)uuid;


#pragma mark - Outside entities

/// Parser associated with this line. For future generations.
@property (nonatomic, weak) id<LineDelegate> parser;
/// Pagination associated with this line. For future generations.
@property (nonatomic, weak) id paginator;


#pragma mark - Metadata

/// All storyline NAMES (string) in this line
@property (nonatomic) NSArray<NSString*>* storylines;
/// All story beats in this line
@property (nonatomic) NSArray<Storybeat*>* beats;
/// Tags in this line (once they are baked into lines before export to FDX)
@property (nonatomic) NSMutableArray *tags;
/// Lines can hold any sort of custom data when needed. Used by plugins.
@property (nonatomic) NSMutableDictionary* customDataDictionary;

/// No idea
// @property (nonatomic) NSMutableDictionary<NSIndexSet*, NSArray*>* attachments;


#pragma mark Generated metadata

/// Index of line in parser, experimental
@property (nonatomic, readonly) NSUInteger index;


#pragma mark - Editor booleans

/// Set `true` if the contents of this outline element are collapsed (only applies to sections)
@property (nonatomic) bool collapsed;


#pragma mark - Ranges

#pragma mark Formatting

/// The type which this line was previously formatted as. Can be used for checking if the type has changed before reformatting.
@property (atomic) LineType formattedAs;
/// The resulting formatting in custom format (not compatible with AppKit/UIKit formatting)
@property (nonatomic) NSAttributedString* formattedString;
/// Number of preceding formatting characters for a forced line type. Usually `1`.
@property (nonatomic, readonly) NSUInteger numberOfPrecedingFormattingCharacters;

@property (nonatomic) NSMutableIndexSet* boldRanges;
@property (nonatomic) NSMutableIndexSet* italicRanges;
@property (nonatomic) NSMutableIndexSet* boldItalicRanges;
@property (nonatomic) NSMutableIndexSet* underlinedRanges;
@property (nonatomic) NSMutableIndexSet* noteRanges;
@property (nonatomic) NSMutableIndexSet* omittedRanges;
@property (nonatomic) NSMutableIndexSet* highlightRanges;
@property (nonatomic) NSMutableIndexSet* strikeoutRanges;
@property (nonatomic) NSMutableIndexSet* escapeRanges;
@property (nonatomic) NSMutableIndexSet* macroRanges;

/// Returns `true` if the line doesn't have any formatting characters.
-(bool)noFormatting;


#pragma mark Other data ranges

/// Range of opening title key (title page elements)
@property (nonatomic) NSRange titleRange;
/// Range of forced scene number (including formatting, ie. `#123#`)
@property (nonatomic) NSRange sceneNumberRange;
/// Range of scene color tag (including note brackets)
@property (nonatomic) NSRange colorRange;

/// Ranges of story beats
@property (nonatomic) NSMutableIndexSet *beatRanges;
/// Ranges of removal suggestions (opposite of revisions)
@property (nonatomic) NSMutableIndexSet* removalSuggestionRanges;


#pragma mark Range methods

/// Indices of formatting characters
- (NSIndexSet*)formattingRanges;
/// Returns the formatting ranges as *global* (document-wide) ranges
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes;
/// Indices of printed content (excluding formatting symbols etc.)
- (NSIndexSet*)contentRanges;
/// Indices of printed content (excluding formatting symbols etc.) *including* given ranges.
- (NSIndexSet*)contentRangesIncluding:(NSIndexSet*)includedRanges;
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

/// The line is omitted completely from print — either inside an omission block or a note. Legacy compatibility.
- (bool)omitted;
/// This line is actually only omitted (wrapped between `/* */`.
- (bool)isOmitted;
/// The line is centered (wtf)
- (bool)centered;
/// Return `true` if the line either bleeds out an omission or closes an existing one
- (bool)opensOrClosesOmission;


#pragma mark - Notes

/// Whether the line terminates an unfinished note
@property (nonatomic) bool noteIn;
/// Whether the line starts a note and doesn't finish it
@property (nonatomic) bool noteOut;
/// Returns all note data in this line (this is a mess, read more inside the method)
@property (nonatomic) NSMutableArray<BeatNoteData*>* noteData;

/// Returns `true` if the note is able to succesfully terminate a multi-line note block (contains `]]`)
- (bool)canTerminateNoteBlock;
/// Returns `true` if the note is able to succesfully terminate a multi-line note block (contains `]]`), and can also return the index of closing element
- (bool)canTerminateNoteBlockWithActualIndex:(NSInteger*)position;
/// Returns `true` if the line can begin a note block, and can also return the index of the possible opening element
- (bool)canBeginNoteBlockWithActualIndex:(NSInteger*)index;
/// Returns `true` if the line can begin a note block
- (bool)canBeginNoteBlock;

/// The line is filled by a note and has no other content
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


#pragma mark - Preprocessing macros

/// Preprocessor stores these values in the line for rendering
@property (nonatomic) NSMutableDictionary<NSValue*,NSString*>* resolvedMacros;


#pragma mark - Pagination information

/// Notes that the next dialogue element is a pair to this one. **Note**: used for non-continuous parsing ONLY
@property (nonatomic) bool nextElementIsDualDialogue;
/// This line begins a new paragraph and is not joined with another one. **Note:** Used for non-continuous parsing ONLY, has to be explicitly set `true` by parser.
@property (nonatomic) bool beginsNewParagraph;
/// This line begins a title page block. **Note:** Used for non-continuous parsing ONLY, has to be explicitly set `true` by parser.
@property (nonatomic) bool beginsTitlePageBlock;
/// This line closes a title page block. **Note:** Used for non-continuous parsing ONLY, has to be explicitly set `true` by parser.
@property (nonatomic) bool endsTitlePageBlock;
/// This line is unsafe as a starting point for live pagination operations. **Note:** Used for non-continuous parsing ONLY, has to be explicitly set `true` by parser.
@property (nonatomic) bool unsafeForPageBreak;

/// This line was cut from top
@property (nonatomic) bool paragraphIn;
/// This line was cut from bottom
@property (nonatomic) bool paragraphOut;


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

/// Returns type based on type _name_ (not `typeAsString` value)
+ (LineType)typeFromName:(NSString *)name;

/// Returns the line type in a human-readable form.
- (NSString*)typeAsString;
/// Returns the type name for this line. It's basically `LineType` as string, useful for variables, CSS styles etc. To get a human-readable version, use `typeAsString`.
- (NSString*)typeName;

/// Returns `true` if the line has a forced type
- (bool)forced;

/// Returns `true` if the line can be considered as empty. Look into the method to see what this means. (I can't remember)
- (bool)effectivelyEmpty;

/// Returns the last character in string
/// @warning Be careful not to go out of range, always check the length before using this!
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
