//
//  InlineFormatting.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 16.1.2026.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FormattedRange) {
    FormattingRangeBold = 0,
    FormattingRangeItalic,
    FormattingRangeUnderlined,
    FormattingRangeMacro,
    FormattingRangeEscape,
    FormattingRangeHighlight,
    FormattingRangeOmission,
    FormattingRangeNote,
    FormattingRangeRemovalSuggestion,
    FormattingRangeSceneNumber,
    FormattingRangeBoldItalic, // NOTE!!! This is NOT stored to a line, but is a computed property. Only used for attributed strings.
    FormattingRangeCount
};

#pragma mark - Formatting characters

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

// For FDX compatibility & attribution.
#define BOLD_STYLE @"Bold"
#define ITALIC_STYLE @"Italic"
#define BOLDITALIC_STYLE @"BoldItalic"
#define UNDERLINE_STYLE @"Underline"
#define STRIKEOUT_STYLE @"Strikeout"
#define OMIT_STYLE @"Omit"
#define NOTE_STYLE @"Note"
#define MACRO_STYLE @"Macro"
#define HIGHLIGHT_STYLE @"Highlight"

NS_ASSUME_NONNULL_BEGIN

/**
 This is a helper class for handling Fountain inline formatting rules and converting them to string attributes.
 Remember to set all of the values, because we don't know the `char` length.
 
 @warning Note that you CAN NOT use `unichar` values as open/close values. Dread lightly.
 */
@interface InlineFormatting : NSObject

@property (nonatomic) char* open;
@property (nonatomic) NSInteger openLength;

@property (nonatomic) char* close;
@property (nonatomic) NSInteger closeLength;

@property (nonatomic) FormattedRange formatType;

/// Creates an inline parsing rule/policy.
/// @note You **need** to set the delim length manually, because we are not using zero-terminated strings here and can't use `strlen`.
+ (instancetype)type:(FormattedRange)type delim:(char*)delim delimLength:(NSUInteger)delimLength;

/// Creates an inline parsing rule/policy.
/// @note You **need** to set the delim length manually, because we are not using zero-terminated strings here and can't use `strlen`.
+ (instancetype)type:(FormattedRange)type open:(char*)open close:(char*)close delimLength:(NSUInteger)delimLength;

/// Creates an inline parsing rule/policy.
/// @note You **need** to set open and close delimiter lengths manually, because we are not using zero-terminated strings here and can't use `strlen`.
+ (instancetype)type:(FormattedRange)type open:(char*)open openLength:(NSUInteger)openLength close:(char*)close closeLength:(NSUInteger)closeLength;

/// Returns the attributed string (FDX-compatible) style name for given inline formatting style.
+ (NSString* _Nullable)styleNameFor:(FormattedRange)formatting;

/// The inline markup ranges we will be parsing and formatting in the editor.
/// @note This doesn't contain note and omission, because they have their own parsing rules.
+ (NSArray<InlineFormatting*>*)rangesToFormat;

/// All inline parsing formats. Note that these should NOT be used for parsing, they are only helpful when applying attributes to strings. 
+ (NSDictionary<NSNumber*,InlineFormatting*>*)inlineFormats;

@end

NS_ASSUME_NONNULL_END
