//
//  NSString+Whitespace.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Parts copyright © 2019-2021 Lauri-Matti Parppei. All rights reserved.
//

#import "NSString+CharacterControl.h"

@implementation NSString (CharacterControl)

- (bool)containsOnlyWhitespace
{
    NSUInteger length = [self length];
    NSCharacterSet* whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (int i = 0; i < length; i++) {
        char c = [self characterAtIndex:i];
        if (![whitespaceSet characterIsMember:c]) {
            return NO;
        }
    }
    return YES;
}

- (bool)containsUppercaseLetters
{
    NSUInteger length = [self length];
    NSCharacterSet* characters = [NSCharacterSet uppercaseLetterCharacterSet];
    for (int i = 0; i < length; i++) {
        char c = [self characterAtIndex:i];
        if ([characters characterIsMember:c]) {
            return YES;
        }
    }
    return NO;
}

- (NSInteger)numberOfOccurencesOfCharacter:(unichar)symbol {
	NSInteger occurences = 0;
	
	for (NSInteger i=0; i<self.length; i++) {
		if ([self characterAtIndex:i] == symbol) occurences += 1;
	}
	
	return occurences;
}

- (bool)containsOnlyUppercase
{
	return [self.uppercaseString isEqualToString:self] && [self containsUppercaseLetters];
}

- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet {
	NSRange rangeOfLastWantedCharacter = [self rangeOfCharacterFromSet:[characterSet invertedSet]
															   options:NSBackwardsSearch];
	if (rangeOfLastWantedCharacter.location == NSNotFound) {
		return @"";
	}
	return [self substringToIndex:rangeOfLastWantedCharacter.location+1]; // non-inclusive
}

- (bool)onlyUppercaseUntilParenthesis
{
	NSInteger parenthesisLoc = [self rangeOfString:@"("].location;
	NSInteger noteLoc = [self rangeOfString:@"[["].location;
	
	if (noteLoc == 0 || parenthesisLoc == 0) return NO;
	
	
	if (parenthesisLoc == NSNotFound) {
		// No parenthesis
		return self.containsOnlyUppercase;
	}
	else {
		NSString *head = [self substringToIndex:parenthesisLoc];

		if ([head.uppercaseString isEqualToString:head] && head.containsOnlyUppercase) {
			// Parenthesis found
			return YES;
		}
	}
	
	return NO;
	
}

@end
