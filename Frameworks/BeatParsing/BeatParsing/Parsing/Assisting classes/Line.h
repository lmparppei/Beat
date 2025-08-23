//
//  Line.h
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatParsing/Storybeat.h>
#import <BeatParsing/BeatNoteData.h>

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
@property (readonly) bool resetsSceneNumber;
@property (readonly) NSString* color;
@property (readonly) NSRange range;
@property (readonly) NSRange textRange;
@property (readonly) bool omitIn;
@property (readonly) bool omitOut;

@property (readonly, atomic) NSString* string;
@property (nonatomic, readonly) NSInteger length;
@property (nonatomic, readonly) NSUInteger index;

@property (nonatomic, readonly) bool noteIn;
@property (nonatomic, readonly) bool noteOut;

@property (nonatomic) NSRange markerRange;
@property (nonatomic, readonly) NSString *marker;
@property (nonatomic, readonly) NSString *markerDescription;

@property (nonatomic, readonly) NSDictionary* ranges;
@property (nonatomic, readonly) NSMutableDictionary <NSNumber*, NSMutableIndexSet*>* revisedRanges;

@property (nonatomic, readonly) NSArray<Storybeat*>* beats;

@property (nonatomic) bool collapsed;

/// Returns line string content with no formatting to be displayed in UI elements.
- (NSString*)stringForDisplay;

- (NSString*)stripFormatting;
- (bool)effectivelyEmpty;

- (NSString*)characterName;
- (NSString*)textContent;
- (NSDictionary*)forSerialization;
- (NSString*)trimmed;

- (id)clone;

// Identity
- (BOOL)matchesUUIDString:(NSString*)uuid;
- (NSString*)uuidString;

JSExportAs(setCustomData, - (NSDictionary*)setCustomData:(NSString*)key value:(id)value);
- (id)getCustomData:(NSString*)key;
@end

@protocol LineDelegate <NSObject>
@property (readonly) NSMutableArray *lines;
@property (nonatomic) NSMutableIndexSet *changedIndices;
- (NSUInteger)indexOfLine:(Line*)line;
- (NSUInteger)indexOfLine:(Line*)line lines:(NSArray<Line*>*)lines;
- (NSArray<Line*>*)linesForScene:(OutlineScene*)outline;
@end


#pragma mark - Line Object

@interface Line: NSObject <LineExports, NSCopying>

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
/// This flag is set during outline creation / scene number update. __Do not touch otherwise.__
@property (nonatomic) BOOL autoNumbered;
/// Color for outline element (`nil` or empty if no color is set)
@property (nonatomic) NSString* color;
/// This line was forced to be a character cue in editor
@property (nonatomic) bool forcedCharacterCue;

@property (nonatomic) bool resetsSceneNumber;

/// Range of the whole line, __including__ line break.
/// @warning This can go out of bounds on last line (which doesn't have a line break), so be careful.
- (NSRange)range;
/// Range of the string only, __excluding__ line break
- (NSRange)textRange;

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
/// Returns line string content with no formatting to be displayed in UI elements. 
- (NSString*)stringForDisplay;
/// Returns a trimmed string
- (NSString*)trimmed;

/// A JSON object for plugin use
- (NSDictionary*)forSerialization;


#pragma mark - Identity

/// Unique identifier for this line (temporary clones of this line in paginated content will hold the same ID)
@property (atomic) NSUUID *uuid;
/// The line in editor/parser from which this one was copied from, can be `nil`
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
@property (nonatomic, readonly) NSArray<Storybeat*>* beats;
/// Tags in this line (once they are baked into lines before export to FDX)
@property (nonatomic) NSMutableArray<NSDictionary*>* tags;
/// Lines can hold any sort of custom data when needed. Used by plugins.
@property (nonatomic) NSMutableDictionary* customDataDictionary;
/// Possible alternative versions of the line 
@property (nonatomic) NSMutableArray<NSDictionary*>* versions;
/// The currently selected iteration of line
@property (nonatomic) NSInteger currentVersion;


#pragma mark Versions

/// Returns the metadata for an alternative version of this line by stepping the given amount from current version
/// - warning: This method **DOES NOT** replace anything, but instead returns the text and possible revisions of the line. You will need to handle the actual replacement yourself in editor.
- (NSDictionary*)switchVersion:(NSInteger)amount;
- (void)addVersion;

#pragma mark Generated metadata

/// Index of line in parser, experimental
@property (nonatomic, readonly) NSUInteger index;



#pragma mark - Editor booleans

/// Set `true` if the contents of this outline element are collapsed (only applies to sections)
@property (nonatomic) bool collapsed;


#pragma mark - Formatting

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
/// Reformats Fountain string inside the line and stores the ranges
- (void)resetFormatting;


#pragma mark Other data ranges

/// Character name, excluding any extensions
- (NSString*)characterName;

/// Range of opening title key (title page elements)
@property (nonatomic) NSRange titleRange;
/// Range of forced scene number (including formatting, ie. `#123#`)
@property (nonatomic) NSRange sceneNumberRange;
/// Range of scene color tag (including note brackets)
@property (nonatomic) NSRange colorRange;

/// Ranges of story beats (note: This is a getter, underlying value is `__beatRanges`)
@property (nonatomic, readonly) NSMutableIndexSet *beatRanges;
/// Actual beat ranges
@property (nonatomic) NSMutableIndexSet* __beatRanges;
/// Ranges of removal suggestions (opposite of revisions)
@property (nonatomic) NSMutableIndexSet* removalSuggestionRanges;


#pragma mark - Omissions

/// Whether the line terminates an unfinished omit
@property (nonatomic) bool omitIn;
/// Whether the line starts a note and doesn't finish it
@property (nonatomic) bool omitOut;

/// Return `true` if the line either bleeds out an omission or closes an existing one
- (bool)opensOrClosesOmission;


#pragma mark - Notes

/// Whether the line terminates an unfinished note
@property (nonatomic) bool noteIn;
/// Whether the line starts a note and doesn't finish it
@property (nonatomic) bool noteOut;
/// Returns all note data in this line (this is a mess, read more inside the method)
@property (nonatomic) NSMutableArray<BeatNoteData*>* noteData;


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
@property (nonatomic) NSMutableDictionary <NSNumber*, NSMutableIndexSet*>* revisedRanges;
/// The highest revision generation for this line.
@property (nonatomic) NSInteger revisionGeneration;



#pragma mark - Convenience methods

/// Returns `true` if the line can be considered as empty. Look into the method to see what this means. (I can't remember)
- (bool)effectivelyEmpty;

/// Returns the last character in string
/// @warning Be careful not to go out of range, always check the length before using this!
- (unichar)lastCharacter;

/// returns `true` if the *visible* content is uppercase, which means that any notes etc. won't be taken into consideration.
- (bool)visibleContentIsUppercase;

/// Page number convenience getter. Note that this can also be SET.
@property (nonatomic) NSString* forcedPageNumber;
@property (nonatomic) NSString* inheritedForcedPageNumber;


#pragma mark - Debugging

-(NSString *)description;
@end
