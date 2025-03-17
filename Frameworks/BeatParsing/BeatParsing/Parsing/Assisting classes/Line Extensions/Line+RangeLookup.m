//
//  Line+RangeLookup.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.12.2024.
//
/**
 
 Calculated ranges from line content. Note that most static ranges are set during parsing, these methods mostly use those ranges as metadata to create more complicated compound ranges: all formatting ranges excluding some elements, character name range, etc.
 
 */

#import "Line+RangeLookup.h"

@implementation Line (RangeLookup)

#pragma mark - Ranges

/// Converts a global (document-wide) range into local range inside the line
-(NSRange)globalRangeToLocal:(NSRange)range
{
    // Insert a range and get a LOCAL range in the line
    NSRange lineRange = (NSRange){ self.position, self.string.length };
    NSRange intersection = NSIntersectionRange(range, lineRange);
    
    return (NSRange){ intersection.location - self.position, intersection.length };
}

/// Converts a a local range in this line into a global (document-wide) one
-(NSRange)globalRangeFromLocal:(NSRange)range
{
    return NSMakeRange(range.location + self.position, range.length);
}

/// Returns ranges with content ONLY (useful for reconstructing the string with no Fountain stylization)
- (NSIndexSet*)contentRanges
{
    return [self contentRangesIncluding:nil];
}
/// Returns ranges with content ONLY (useful for reconstructing the string with no Fountain stylization), with given extra ranges included.
- (NSIndexSet*)contentRangesIncluding:(NSIndexSet*)includedRanges
{
    NSMutableIndexSet *contentRanges = NSMutableIndexSet.indexSet;
    [contentRanges addIndexesInRange:NSMakeRange(0, self.string.length)];
    
    // Get formatting ranges.
    // We can provide ranges that are excluded from formatting ranges and included in the resulting string.
    NSMutableIndexSet *formattingRanges = self.formattingRanges.mutableCopy;
    [formattingRanges removeIndexes:includedRanges];
    
    // Remove formatting indices from content indices.
    [contentRanges removeIndexes:formattingRanges];
    
    return contentRanges;
}

/// Returns content ranges, including notes
- (NSIndexSet*)contentRangesWithNotes
{
    // Returns content ranges WITH notes included
    NSMutableIndexSet *contentRanges = [NSMutableIndexSet indexSet];
    [contentRanges addIndexesInRange:NSMakeRange(0, self.string.length)];
    
    NSIndexSet *formattingRanges = [self formattingRangesWithGlobalRange:NO includeNotes:NO];
    [contentRanges removeIndexes:formattingRanges];
    
    return contentRanges;
}

/**
 This method returns the number of formatting characters at the beginning of the line, ie. symbols for forced types. It also DOUBLE-CHECKS the type to be on the safe side.
 We really should create some sort of dictionary or something for the forced symbols vs. types.
 */
- (NSUInteger)numberOfPrecedingFormattingCharacters
{
    if (self.string.length < 1) return 0;
    
    NSInteger firstCharIndex = self.string.indexOfFirstNonWhiteSpaceCharacter;
    if (firstCharIndex == NSNotFound) firstCharIndex = 0;
    unichar c = [self.string characterAtIndex:firstCharIndex];
    
    // First check if this is a shot (!!) or action
    if (self.string.length > 1 && self.type == shot && [self.string characterAtIndex:0] == '!') {
        if ([self.string characterAtIndex:1] == '!') return 2;
    } else if ([self.string characterAtIndex:0] == '!') {
        return 1;
    }
        
    // Other types
    if ((self.type == character && c == '@') ||
        (self.type == heading && c == '.') ||
        (self.type == lyrics && c == '~') ||
        (self.type == synopse && c == '=') ||
        (self.type == centered && c == '>') ||
        (self.type == transitionLine && c == '>')) {
        return firstCharIndex+1;
    }
    // Section
    else if (self.type == section) {
        return self.sectionDepth;
    }
    
    return 0;
}

/// Maps formatting characters into an index set, INCLUDING notes, scene numbers etc. to convert it to another style of formatting
- (NSIndexSet*)formattingRanges {
    return [self formattingRangesWithGlobalRange:NO includeNotes:YES includeOmissions:YES];
}

- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes
{
    return [self formattingRangesWithGlobalRange:globalRange includeNotes:includeNotes includeOmissions:YES];
}

/// Maps formatting characters into an index set, INCLUDING notes, scene numbers etc.
/// You can use global range flag to return ranges relative to the *whole* document.
/// Notes are included in formatting ranges by default.
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes includeOmissions:(bool)includeOmissions
{
    NSMutableIndexSet *indices = NSMutableIndexSet.new;
    NSInteger offset = 0;
    
    if (globalRange) offset = self.position;
    
    // Add any ranges that are used to force elements. First handle the elements which don't work without markup characters.
    NSInteger precedingCharacters = self.numberOfPrecedingFormattingCharacters;
    if (precedingCharacters > 0) {
        [indices addIndexesInRange:NSMakeRange(offset, precedingCharacters)];
    }
    
    // Catch dual dialogue force symbol
    if (self.type == dualDialogueCharacter && self.string.length > 0 && self.string.lastNonWhiteSpaceCharacter == '^') {
        [indices addIndex:self.string.indexOfLastNonWhiteSpaceCharacter + offset];
    }
    
    // Add ranges for > and < (if needed)
    if (self.type == centered && self.string.length >= 2) {
        if ([self.string characterAtIndex:0] == '>' && [self.string characterAtIndex:self.string.length - 1] == '<') {
            [indices addIndex:0+offset];
            [indices addIndex:self.string.length - 1+offset];
        }
    }
    
    // Title page keys will be included in formatting ranges
    if (self.isTitlePage && self.beginsTitlePageBlock && self.titlePageKey.length) {
        NSInteger i = self.titlePageKey.length+1;
        [indices addIndexesInRange:NSMakeRange(0, i)];
        
        // Also add following spaces to formatting ranges
        while (i < self.length) {
            unichar c = [self.string characterAtIndex:i];
            
            if (c == ' ') [indices addIndex:i];
            else break;
            
            i++;
        }
    }
    
    // Escape ranges
    [indices addIndexes:[[NSIndexSet alloc] initWithIndexSet:self.escapeRanges]];
    
    // Scene number range
    if (self.sceneNumberRange.length) {
        [indices addIndexesInRange:(NSRange){ self.sceneNumberRange.location + offset, self.sceneNumberRange.length }];
        // Also remove the surrounding #'s
        [indices addIndex:self.sceneNumberRange.location + offset - 1];
        [indices addIndex:self.sceneNumberRange.location + self.sceneNumberRange.length + offset];
    }
    
    // Stylization ranges
    [self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [indices addIndexesInRange:NSMakeRange(range.location + offset, BOLD_PATTERN.length)];
        [indices addIndexesInRange:NSMakeRange(range.location + range.length - BOLD_PATTERN.length +offset, BOLD_PATTERN.length)];
    }];
    [self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [indices addIndexesInRange:NSMakeRange(range.location + offset, ITALIC_PATTERN.length)];
        [indices addIndexesInRange:NSMakeRange(range.location + range.length - ITALIC_PATTERN.length +offset, ITALIC_PATTERN.length)];
    }];
    [self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [indices addIndexesInRange:NSMakeRange(range.location + offset, UNDERLINE_PATTERN.length)];
        [indices addIndexesInRange:NSMakeRange(range.location + range.length - UNDERLINE_PATTERN.length +offset, UNDERLINE_PATTERN.length)];
    }];
    
    if (includeOmissions) {
        [self.omittedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
            [indices addIndexesInRange:NSMakeRange(range.location + offset, range.length)];
        }];
    }
    
    if (includeNotes) {
        [self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
            [indices addIndexesInRange:NSMakeRange(range.location + offset, range.length)];
        }];
    }
    
    return indices;
}

- (NSRange)characterNameRange
{
    if (!self.isAnyCharacter) return NSMakeRange(NSNotFound, 0);
    
    NSInteger location = self.numberOfPrecedingFormattingCharacters;
    
    NSInteger parenthesisLoc = [self.string rangeOfString:@"("].location;
    NSInteger length = ((parenthesisLoc != NSNotFound) ? parenthesisLoc : self.string.length) - location;
    
    return NSMakeRange(location, length);
}

/// Ranges of emojis (o the times we live in)
- (NSArray<NSValue*>*)emojiRanges
{
    return self.string.emo_emojiRanges;
}

- (bool)hasEmojis
{
    if (self.string == nil) return false;
    return self.string.emo_containsEmoji;
}

@end
