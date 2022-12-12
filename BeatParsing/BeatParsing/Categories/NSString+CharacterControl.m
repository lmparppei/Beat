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

- (NSCharacterSet*)uppercaseLetters {
    // Add some symbols which are potentially not recognized out of the box.
    NSMutableCharacterSet* characters = NSCharacterSet.uppercaseLetterCharacterSet.mutableCopy;
    [characters addCharactersInString:@"ŞĞIİÜÅÄÖÇÑŠŽ"];
    
    return characters;
}

- (bool)containsUppercaseLetters
{
    NSCharacterSet* characters = [self uppercaseLetters];
    
    for (int i = 0; i < self.length; i++) {
        char c = [self characterAtIndex:i];
        if ([characters characterIsMember:c]) return YES;
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
	NSRange rangeOfLastWantedCharacter = [self rangeOfCharacterFromSet:characterSet.invertedSet options:NSBackwardsSearch];
	if (rangeOfLastWantedCharacter.location == NSNotFound) {
		return @"";
	}
    if (rangeOfLastWantedCharacter.location + 1 <= self.length) {
        return [self substringToIndex:rangeOfLastWantedCharacter.location+1]; // non-inclusive
    } else {
        return self;
    }
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
        // We need to check past parentheses, too, in case the user started the line with something like:
        // MIA (30) does something...
        bool parenthesisOpen = false;
        NSMutableIndexSet *indexSet = NSMutableIndexSet.new;
        
        for (NSInteger i=0; i<self.length; i++) {
            char c = [self characterAtIndex:i];
            if (c == ')') {
                parenthesisOpen = false;
                continue;
            }
            else if (c == '(') {
                parenthesisOpen = true;
                continue;
            }
            else if (!parenthesisOpen) {
                [indexSet addIndex:i];
            }
        }
        
        __block bool containsLowerCase = false;
        [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
            NSString *substr = [self substringWithRange:range];
            if ([substr containsOnlyWhitespace]) return;
            else if (![substr containsOnlyUppercase]) {
                containsLowerCase = true;
                *stop = true;
            }
        }];
        
        if (containsLowerCase) return false;
        else return true;
	}
	
	return NO;
	
}

@end
