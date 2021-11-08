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


- (bool)containsOnlyUppercase
{
	return [[self uppercaseString] isEqualToString:self] && [self containsUppercaseLetters];
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
	NSInteger noteLoc = [self rangeOfString:@"[["].location;
	NSInteger parenthesisLoc = [self rangeOfString:@"("].location;
	NSInteger parenthesisEnd = [self rangeOfString:@")"].location;
	
	// Don't let note lines become characters
	if (noteLoc == 0) return NO;
	
	if (parenthesisLoc == NSNotFound) {
		// No parenthesis
		return [self containsOnlyUppercase];
	}
	else if (parenthesisEnd != NSNotFound &&
			 parenthesisEnd + 1 < self.length) {
		// The line continues after parenthesis
		NSString* tail = [self substringFromIndex:parenthesisEnd + 1];
		
		if ([tail containsOnlyWhitespace]) return YES;
		else if ([self characterAtIndex:self.length - 1] == '^') return YES;
		else return NO;
	}
	else if (parenthesisLoc < 3) {
		return NO;
	} else {
		NSString *head = [self substringToIndex:parenthesisLoc];
		
		if ([head containsOnlyUppercase]) return YES;
		else return NO;
	}
}

@end
