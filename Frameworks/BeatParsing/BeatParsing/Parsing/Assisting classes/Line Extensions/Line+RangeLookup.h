//
//  Line+RangeLookup.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.12.2024.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol LineLookupExports <JSExport>

- (NSRange)characterNameRange;

- (NSIndexSet*)formattingRanges;
- (NSIndexSet*)contentRangesWithNotes;
- (NSIndexSet*)contentRanges;

@end

@interface Line (RangeLookup) <LineLookupExports>

/// Indices of formatting characters
- (NSIndexSet*)formattingRanges;
/// Returns indices of formatting characters.
/// @param globalRange When `true`, the index set will include global (and not local) indices
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes;
/// Returns indices of formatting characters.
/// @param globalRange When `true`, the index set will include global (and not local) indices (default is false)
/// @param includeNotes When `true`, the index set will include note ranges (default is true)
/// @param includeOmissions  When `true`, the index set will include omitted ranges (default is true)
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes includeOmissions:(bool)includeOmissions;
/// Indices of printed content (excluding formatting symbols etc.)
- (NSIndexSet*)contentRanges;
/// Indices of printed content (excluding formatting symbols etc.) *including* given ranges.
- (NSIndexSet*)contentRangesIncluding:(NSIndexSet*)includedRanges;
/// Indices of printed content (excluding formatting symbols etc.), but with notes
- (NSIndexSet*)contentRangesWithNotes;
/// Range of the character name in the cue
- (NSRange)characterNameRange;


@end
