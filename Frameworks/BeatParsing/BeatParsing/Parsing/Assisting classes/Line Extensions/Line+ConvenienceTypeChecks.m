//
//  Line+ConvenienceTypeChecks.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import "Line+ConvenienceTypeChecks.h"

@implementation Line (ConvenienceTypeChecks)

- (bool)canBeSplitParagraph
{
    return (self.type == action || self.type == lyrics || self.type == centered);
}

/// Returns TRUE for scene, section and synopsis elements
- (bool)isOutlineElement
{
    return (self.type == heading || self.type == section);
}

/// Returns TRUE for any title page element
- (bool)isTitlePage
{
    return (self.type == titlePageTitle ||
            self.type == titlePageCredit ||
            self.type == titlePageAuthor ||
            self.type == titlePageDraftDate ||
            self.type == titlePageContact ||
            self.type == titlePageSource ||
            self.type == titlePageUnknown);
}

/// Checks if the line is completely non-printing __in the eyes of parsing__.
- (bool)isInvisible
{
    return (self.omitted || self.type == section || self.type == synopse || self.isTitlePage);
}

/// A shorthand for either an invisible or effectively empty line
- (bool)isNonPrinting
{
    return (self.isInvisible || self.effectivelyEmpty);
}

/// Returns TRUE if the line type is forced
- (bool)forced
{
    return (self.numberOfPrecedingFormattingCharacters > 0);
}


#pragma mark Dialogue

/// Returns `true` for ANY SORT OF dialogue element, including dual dialogue
- (bool)isAnySortOfDialogue
{
    return (self.isDialogue || self.isDualDialogue);
}

/// Returns `true` for any dialogue element, including character cue
- (bool)isDialogue
{
    return (self.type == character || self.type == parenthetical || self.type == dialogue || self.type == more);
}

/// Returns `true` for dialogue block elements, excluding character cues
- (bool)isDialogueElement
{
    // Is SUB-DIALOGUE element
    return (self.type == parenthetical || self.type == dialogue);
}

/// Returns `true` for any dual dialogue element, including character cue
- (bool)isDualDialogue
{
    return (self.type == dualDialogue || self.type == dualDialogueCharacter || self.type == dualDialogueParenthetical || self.type == dualDialogueMore);
}

/// Returns `true` for dual dialogue block elements, excluding character cues
- (bool)isDualDialogueElement
{
    return (self.type == dualDialogueParenthetical || self.type == dualDialogue || self.type == dualDialogueMore);
}

/// Returns `true` for ANY character cue (single or dual)
- (bool)isAnyCharacter
{
    return (self.type == character || self.type == dualDialogueCharacter);
}

/// Returns `true` for ANY parenthetical line (single or dual)
- (bool)isAnyParenthetical
{
    return (self.type == parenthetical || self.type == dualDialogueParenthetical);
}

/// Returns `true` for ANY dialogue line (single or dual)
- (bool)isAnyDialogue
{
    return (self.type == dialogue || self.type == dualDialogue);
}

- (bool)isBoneyardSection
{
    return (self.type == section && [[self.string substringFromIndex:self.numberOfPrecedingFormattingCharacters].lowercaseString.trim isEqualToString:@"boneyard"]);
}


#pragma mark Omissions & notes
// What a silly mess. TODO: Please fix this.

/// Returns `true` for ACTUALLY omitted lines, so not only for effectively omitted. This is a silly thing for legacy compatibility.
- (bool)isOmitted
{
    return (self.omittedRanges.count >= self.string.length);
}

/// Returns `true` if the line is omitted, kind of. This is a silly mess because of historical reasons.
/// @warning This also includes lines that have 0 length or are completely a note, meaning the method will return YES for empty and/or note lines too.
- (bool)omitted
{
    bool omitted = false;
    
    NSMutableIndexSet* allOmissions = [NSMutableIndexSet.alloc initWithIndexSet:self.omittedRanges];
    [allOmissions addIndexes:self.noteRanges];
    
    if (allOmissions.count == self.string.length) {
        // The line is wrapped in an omission
        omitted = true;
    } else if (self.omittedRanges.count > 0 && self.omittedRanges.count == self.string.length - 1) {
        // Out of convenience, if there's a *single* space left somewhere on the line, we'll consider it omitted.
        NSMutableIndexSet* visibleIndices = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.length)];
        [visibleIndices removeIndexes:self.omittedRanges];
        
        // We should now have a single index left
        if (visibleIndices.count == 1 && [self.string characterAtIndex:visibleIndices.firstIndex] == ' ') return true;
    }
    
    return omitted;
}

- (BOOL)hasExtension {
    /// Returns  `TRUE` if the character cue has an extension
    if (!self.isAnyCharacter) return false;
    
    NSInteger parenthesisLoc = [self.string rangeOfString:@"("].location;
    if (parenthesisLoc == NSNotFound) return false;
    else return true;
}

@end
