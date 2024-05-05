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

@end
