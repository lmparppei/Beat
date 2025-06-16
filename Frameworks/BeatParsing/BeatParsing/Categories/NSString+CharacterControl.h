//
//  NSString+CharacterControl.h
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (CharacterControl)

- (bool)containsOnlyWhitespace;
- (bool)containsOnlyUppercase;
/// Returns `true` if the string is uppercase UNTIL parentheses
- (bool)onlyUppercaseUntilParenthesis;
/// Trims only string tail
- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet;
- (NSInteger)numberOfOccurencesOfCharacter:(unichar)symbol;
- (NSRange)rangeBetweenFirstAndLastOccurrenceOf:(unichar)chr;
- (NSString*)stringByRemovingRange:(NSRange)range;
/// Trims whitespace
- (NSString*)trim;
- (NSInteger)locationOfLastOccurenceOf:(unichar)chr;
/// Recognizes Arabic and Hebrew
- (bool)hasRightToLeftText;
/// Returns first character which is not a tab or space
- (unichar)firstNonWhiteSpaceCharacter;
/// Returns the index of first character which is not a tab or space
- (NSInteger)indexOfFirstNonWhiteSpaceCharacter;
/// Returns last character which is not a tab or space
- (unichar)lastNonWhiteSpaceCharacter;
/// Returns the index of character which is not a tab or space
- (NSInteger)indexOfLastNonWhiteSpaceCharacter;
- (bool)inRange:(NSRange)range;

- (NSMutableIndexSet*)rangesBetween:(NSString*)open and:(NSString*)close excludingIndices:(NSMutableIndexSet*)excludes escapedIndices:(NSMutableIndexSet*)escapes;

/// Removes unwated Windows line breaks
- (NSString*)stringByCleaningUpWindowsLineBreaks;
/// Removes unwanted control characters (including Windows line breaks etc.)
- (NSString*)stringByCleaningUpBadControlCharacters;

/// Check for Devanagari text. This is used by FDX export.
- (BOOL)containsHindi;

@end
