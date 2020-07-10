//
//  Line.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "Line.h"
#import "FNElement.h"

@implementation Line

+ (Line*)withString:(NSString*)string type:(LineType)type {
	return [[Line alloc] initWithString:string type:type];
}
- (Line*)clone {
	Line* newLine = [Line withString:self.string type:self.type];
	newLine.position = self.position;
	
	newLine.isSplitParagraph = self.isSplitParagraph;
	newLine.numberOfPreceedingFormattingCharacters = self.numberOfPreceedingFormattingCharacters;
	
	if (self.italicRanges.count) newLine.italicRanges = [self.italicRanges copy];
	if (self.boldRanges.count) newLine.boldRanges = [self.boldRanges copy];
	if (self.noteRanges.count) newLine.noteRanges = [self.noteRanges copy];
	if (self.omitedRanges.count) newLine.omitedRanges = [self.omitedRanges copy];
	if (self.sceneNumber) newLine.sceneNumber = [NSString stringWithString:self.sceneNumber];
	if (self.color) newLine.color = [NSString stringWithString:self.color];
	
	return newLine;
}

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

// For non-continuous parsing
- (Line*)initWithString:(NSString *)string type:(LineType)type {
	self = [super init];
	if (self) {
		_string = string;
		_type = type;
	}
	return self;
}
- (Line*)initWithString:(NSString *)string type:(LineType)type position:(NSUInteger)position {
	self = [super init];
	if (self) {
		_string = string;
		_type = type;
		_position = position;
	}
	return self;
}

- (NSString *)toString
{
    return [[[[self typeAsString] stringByAppendingString:@": \"" ] stringByAppendingString:self.string] stringByAppendingString:@"\""];
}

// See if whole block is omited
// Btw, this is me writing from the future. I love you, past me!!!
- (bool)omited {
	__block NSUInteger omitLength = 0;
	[self.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		omitLength += range.length;
	}];
			
	// This return YES also for empty lines, which SHOULD NOT be a problem for anything, but yeah, we could check it:
	//if (omitLength == [self.string length] && self.type != empty) {
	if (omitLength == [self.string length]) {
		return true;
	} else {
		return false;
	}
}

- (bool)centered {
	if (self.string.length < 2) return NO;

	if ([self.string characterAtIndex:0] == '>' &&
		[self.string characterAtIndex:self.string.length - 1] == '<') return YES;
	else return NO;
}

- (NSString*)cleanedString {
	// Return empty string for invisible blocks
	if (self.type == section || self.type == synopse || self.omited) return @"";
	
	__block NSMutableString *string = [NSMutableString stringWithString:self.string];
	__block NSUInteger offset = 0;
	
	// Remove any omitted ranges
	[self.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.location + range.length > string.length) {
			range = NSMakeRange(range.location, string.length - range.location);
		}
		[string replaceCharactersInRange:NSMakeRange(range.location - offset, range.length) withString:@""];
		offset -= range.length;
	}];
	
	// Remove markup characters
	if (self.string.length > 0 && self.numberOfPreceedingFormattingCharacters > 0 && self.type != centered) {
		string = [NSMutableString stringWithString:[string substringFromIndex:self.numberOfPreceedingFormattingCharacters]];
	}

	if (self.type == centered) {
		string = [NSMutableString stringWithString:[string substringFromIndex:1]];
		string = [NSMutableString stringWithString:[string substringToIndex:string.length - 1]];
	}
	
	// Clean up scene headings
	if (self.type == heading && self.sceneNumber) {
		[string replaceOccurrencesOfString:[NSString stringWithFormat:@"#%@#", self.sceneNumber] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, string.length)];
	}
	
	return string;
}
- (NSString*)stripSceneNumber {
	NSString *result = [self.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", self.sceneNumber] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, self.string.length)];
	return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}
 
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
        case dualDialogueCharacter:
            return @"DD Character";
        case dualDialogueParenthetical:
            return @"DD Parenthetical";
        case dualDialogue:
            return @"Double Dialogue";
        case transitionLine:
            return @"Transition";
        case lyrics:
            return @"Lyrics";
        case pageBreak:
            return @"Page Break";
        case centered:
            return @"Centered";
		case more:
			return @"More";
    }
}

- (bool)isTitlePage {
	NSArray *titlePageElements = @[@"Title Page Title", @"Title Page Author", @"Title Page Credit", @"Title Page Source", @"Title Page Contact", @"Title Page Draft Date", @"Title Page Unknown"];
	
	if ([titlePageElements containsObject:self.typeAsString]) return YES; else return NO;
}
- (bool)isInvisible {
	if (self.omited ||
		self.type == section ||
		self.type == synopse ||
		self.isTitlePage) return YES;
	else return NO;
}
-(bool)isBoldedAt:(NSInteger)index {
	__block bool inRange = NO;
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSLog(@"range: %lu / %lu", range.location, range.length);
		if (NSLocationInRange(index, range)) inRange = YES;
	}];
	
	return inRange;
}
-(bool)isItalicAt:(NSInteger)index {
	__block bool inRange = NO;
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (NSLocationInRange(index, range)) inRange = YES;
	}];
	
	return inRange;
}

-(bool)isUnderlinedAt:(NSInteger)index {
	__block bool inRange = NO;
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (NSLocationInRange(index, range)) inRange = YES;
	}];
	
	return inRange;
}

// Helper method which returns a Fountain script element
// This bridges ContinuousFountainParser with FNParser.
// Will be deprecated once modules for printing & pagination have been replaced with custom Beat stuff (WIP)
- (FNElement*)fountainElement {
	// Return empty object for title page data
	if ([self isTitlePage]) return nil;
	
	FNElement *element = [[FNElement alloc] init];
	element.elementType = [self typeAsFountainString];
	
	if (self.type == centered) {
		element.elementType = @"Action";
		element.isCentered = YES;
	}
	
	// NOTE: parsing this correctly in FNHTMLScript requires the previous character to be set as dual too
	if (self.type == dualDialogueCharacter) element.isDualDialogue = YES;

	// Set content and clean up notes & omits
	element.elementText = [self cleanedString];
	
	// Set scene number
	if (self.sceneNumber) element.sceneNumber = self.sceneNumber;
	
	return element;
}

// This returns the type as an FNElement compliant string,
// for convoluted backwards compatibility reasons :----)
- (NSString*)typeAsFountainString
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
            return @"Scene Heading";
        case action:
            return @"Action";
        case character:
            return @"Character";
        case parenthetical:
            return @"Parenthetical";
        case dialogue:
            return @"Dialogue";
        case dualDialogueCharacter:
            return @"Character";
        case dualDialogueParenthetical:
            return @"Parenthetical";
        case dualDialogue:
            return @"Dialogue";
        case transitionLine:
            return @"Transition";
        case lyrics:
            return @"Lyrics";
        case pageBreak:
            return @"Page Break";
        case centered:
            return @"Centered";
		case more:
			return @"More";
    }
}
- (bool)isDialogueElement {
	if (self.type == parenthetical || self.type == dialogue) return YES;
	else return NO;
}
- (bool)isDualDialogueElement {
	if (self.type == dualDialogueParenthetical || self.type == dualDialogue) return YES;
	else return NO;
}

@end
