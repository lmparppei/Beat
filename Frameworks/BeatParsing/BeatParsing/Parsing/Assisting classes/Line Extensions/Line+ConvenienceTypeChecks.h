//
//  Line+ConvenienceTypeChecks.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol LineConvenienceTypeChecksExports <JSExport>

@property (readonly) bool omitted;

- (bool)canBeSplitParagraph;
- (bool)isOutlineElement;
- (bool)isTitlePage;
- (bool)isInvisible;
- (bool)forced;
- (bool)isAnySortOfDialogue;
- (bool)isDialogue;
- (bool)isDialogueElement;
- (bool)isDualDialogue;
- (bool)isDualDialogueElement;
- (bool)isAnyCharacter;
- (bool)isAnyParenthetical;
- (bool)isAnyDialogue;
- (bool)isBoneyardSection;
- (bool)isOmitted;
- (bool)omitted;
- (BOOL)hasExtension;

@end

@interface Line (ConvenienceTypeChecks) <LineConvenienceTypeChecksExports>

/// returns `true` for anything that can be part of a split paragraph block
- (bool)canBeSplitParagraph;
/// returns `true` for any title page element
- (bool)isTitlePage;
/// returns `true` when the line is non-printed
- (bool)isInvisible;
/// A shorthand for either an invisible or effectively empty line
- (bool)isNonPrinting;
/// Returns `true` for any sort of dialogue, no matter if single or dual, cue or dialogue/parenthetical
- (bool)isAnySortOfDialogue;
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
/// returns `true` if this begins a boneyard section
- (bool)isBoneyardSection;
/// Returns `true` if the line has a forced type
- (bool)forced;
/// The line is omitted completely from print — either inside an omission block or a note. Legacy compatibility.
- (bool)omitted;
/// This line is actually only omitted (wrapped inside a `/* */` block)
- (bool)isOmitted;

/// returns `true` when the character cue has an extension (CONT'D), (V.O.) etc.
- (BOOL)hasExtension;


@end
