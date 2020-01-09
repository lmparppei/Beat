//
//  Line.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "Line.h"
#define LINE_HEIGHT 12

@implementation Line

- (Line*)initWithString:(NSString*)string position:(NSUInteger)position
{
    self = [super init];
    if (self) {
        _string = string;
        _type = 0;
        _position = position;
    }
    return self;
}

- (NSString *)toString
{
    return [[[[self typeAsString] stringByAppendingString:@": \"" ] stringByAppendingString:self.string] stringByAppendingString:@"\""];
}

// See if whole block is omited
- (bool)omited {
	__block NSUInteger omitLength = 0;
	[self.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		omitLength += range.length;
	}];
		
	if (omitLength == [self.string length]) {
		return true;
	} else {
		return false;
	}
}

/*
 
 attempts at something
 
- (void)setElementHeight
{
	// This returns an approximated height of an element to count page transitions
	
	switch (self.type) {
		case empty:
			self.height = 1;
		
		// Here we need to account for word wrapping.
		case heading:
			self.height = [self rowsForLine:false] * 1.5; break;
		case lyrics:
		case centered:
		case transitionLine:
		case action:
			self.height = [self rowsForLine:false]; break;
		case character:
			self.height = [self rowsForLine:true]; break;
		case parenthetical:
			self.height = [self rowsForLine:true]; break;
		case dialogue:
			self.height = [self rowsForLine:true]; break;
		case doubleDialogueCharacter:
		case doubleDialogueParenthetical:
		case doubleDialogue:
		default:
			self.height = 0; break;
	}
}

- (NSInteger) rowsForLine:(bool)dialogue {
	// This is a VERY simplified screenplay row height counter for monospace fonts
	NSInteger max = 57;
	if (dialogue) max = 35;

	__block NSString *line = self.string;
	
	// Remove omited characters
	__block NSUInteger omitLength = 0;
	[self.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		omitLength += range.length;
		line = [line stringByReplacingCharactersInRange:range withString:@""];
	}];
	
	if (line.length == 0) {
		return 0;
	}
	
	NSInteger rows = 0;
	NSInteger rowLength = 0;
	
	NSArray *words = [line componentsSeparatedByString:@" "];
	for (NSString *word in words) {
		rowLength += [word length] + 1;
		if (rowLength > max) {
			rows++;
			rowLength = [word length];
		}
	}
	if (rows == 0) rows = 1; else rows++;

	return rows;
}
*/
 
- (NSString*)typeAsString
{
    switch (self.type) {
        case empty:
            return @"Empty";
        case section:
            return @"Section";
        case synopse:
            return @"Synopse";
        case titlePageTitle:
            return @"Title Page Title";
        case titlePageAuthor:
            return @"Title Page Author";
        case titlePageCredit:
            return @"Title Page Credit";
        case titlePageSource:
            return @"Title Page Source";
        case titlePageContact:
            return @"Title Page Contact";
        case titlePageDraftDate:
            return @"Title Page Draft Date";
        case titlePageUnknown:
            return @"Title Page Unknown";
        case heading:
            return @"Heading";
        case action:
            return @"Action";
        case character:
            return @"Character";
        case parenthetical:
            return @"Parenthetical";
        case dialogue:
            return @"Dialogue";
        case doubleDialogueCharacter:
            return @"DD Character";
        case doubleDialogueParenthetical:
            return @"DD Parenthetical";
        case doubleDialogue:
            return @"Double Dialogue";
        case transitionLine:
            return @"Transition";
        case lyrics:
            return @"Lyrics";
        case pageBreak:
            return @"Page Break";
        case centered:
            return @"Centered";
    }
}

@end
