//
//  Line.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  Parts copyright © 2019-2021 Lauri-Matti Parppei / Lauri-Matti Parppei. All Rights reserved.

/*

 This class is HEAVILY modified for Beat.
 There are multiple, overlapping methods for legacy reasons. I'm working on cleaning them up.
 
 */

#import "Line.h"
#import "RegExCategories.h"
#import "FountainRegexes.h"

#define FORMATTING_CHARACTERS @[@"/*", @"*/", @"*", @"_", @"[[", @"]]", @"<<", @">>"]

#define ITALIC_PATTERN @"*"
#define ITALIC_CHAR "*"
#define BOLD_PATTERN @"**"
#define BOLD_CHAR "**"
#define UNDERLINE_PATTERN @"_"
#define UNDERLINE_CHAR "_"
#define OMIT_PATTERN @"/*"
#define NOTE_PATTERN @"[["

#define HIGHLIGHT_PATTERN @"<<"
#define STRIKEOUT_PATTERN @"{{"
#define STRIKEOUT_CLOSE_PATTERN @"}}"
#define STRIKEOUT_OPEN_CHAR "{{"
#define STRIKEOUT_CLOSE_CHAR "}}"
#define NOTE_OPEN_CHAR "[["
#define NOTE_CLOSE_CHAR "]]"

// For FDX compatibility & attribution
#define BOLD_STYLE @"Bold"
#define ITALIC_STYLE @"Italic"
#define UNDERLINE_STYLE @"Underline"
#define STRIKEOUT_STYLE @"Strikeout"
#define OMIT_STYLE @"Omit"

@implementation Line

#pragma mark - Initialization

- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSUInteger)position parser:(id<LineDelegate>)parser {
	self = [super init];
	if (self) {
		_string = string;
		_type = type;
		_position = position;
		_formattedAs = -1;
		//_parser = parser; // UNCOMMENT WHEN NEEDED
		
		_boldRanges = [NSMutableIndexSet indexSet];
		_italicRanges = [NSMutableIndexSet indexSet];
		_underlinedRanges = [NSMutableIndexSet indexSet];
		_boldItalicRanges = [NSMutableIndexSet indexSet];
		_strikeoutRanges = [NSMutableIndexSet indexSet];
		_noteRanges = [NSMutableIndexSet indexSet];
		_omittedRanges = [NSMutableIndexSet indexSet];
		_escapeRanges = [NSMutableIndexSet indexSet];
	}
	return self;
}

- (Line*)initWithString:(NSString*)string position:(NSUInteger)position
{
	return [[Line alloc] initWithString:string type:0 position:position parser:nil];
}
- (Line*)initWithString:(NSString*)string position:(NSUInteger)position parser:(id<LineDelegate>)parser
{
	return [[Line alloc] initWithString:string type:0 position:position parser:parser];
}
- (Line*)initWithString:(NSString *)string type:(LineType)type position:(NSUInteger)position {
	return [[Line alloc] initWithString:string type:type position:position parser:nil];
}

// For non-continuous parsing
- (Line*)initWithString:(NSString *)string type:(LineType)type {
	return [[Line alloc] initWithString:string type:type position:-1 parser:nil];
}
- (Line*)initWithString:(NSString *)string type:(LineType)type pageSplit:(bool)pageSplit {
	// This is used solely for pagination purposes
	self = [super init];
	if (self) {
		_string = string;
		_type = type;
		_unsafeForPageBreak = YES;
		_formattedAs = -1;
		
		if (pageSplit) [self resetFormatting];
	}
	return self;
}

#pragma mark - Shorthands

// Shorthands (used mostly by the paginator)
+ (Line*)withString:(NSString*)string type:(LineType)type parser:(id<LineDelegate>)parser {
	return [[Line alloc] initWithString:string type:type position:0 parser:parser];
}
+ (Line*)withString:(NSString*)string type:(LineType)type {
	return [[Line alloc] initWithString:string type:type];
}
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit {
	return [[Line alloc] initWithString:string type:type pageSplit:YES];
}
+ (NSArray*)markupCharacters {
	return @[@".", @"@", @"~", @"!"];
}

#pragma mark - Type

+ (NSDictionary*)typeDictionary /// Used by plugin API to create constants
{
	NSMutableDictionary *types = NSMutableDictionary.dictionary;
	
	NSInteger max = typeCount;
	for (NSInteger i = 0; i < max; i++) {
		LineType type = i;
		
		NSString *typeName = @"";
		
		switch (type) {
			case empty:
				typeName = @"empty"; break;
			case section:
				typeName = @"section"; break;
			case synopse:
				typeName = @"synopsis"; break;
			case titlePageTitle:
				typeName = @"titlePageTitle"; break;
			case titlePageAuthor:
				typeName = @"titlePageAuthor"; break;
			case titlePageCredit:
				typeName = @"titlePageCredit"; break;
			case titlePageSource:
				typeName = @"titlePageSource"; break;
			case titlePageContact:
				typeName = @"titlePageContact"; break;
			case titlePageDraftDate:
				typeName = @"titlePageDraftDate"; break;
			case titlePageUnknown:
				typeName = @"titlePageUnknown"; break;
			case heading:
				typeName = @"heading"; break;
			case action:
				typeName = @"action"; break;
			case character:
				typeName = @"character"; break;
			case parenthetical:
				typeName = @"parenthetical"; break;
			case dialogue:
				typeName = @"dialogue"; break;
			case dualDialogueCharacter:
				typeName = @"dualDialogueCharacter"; break;
			case dualDialogueParenthetical:
				typeName = @"dualDialogueParenthetical"; break;
			case dualDialogue:
				typeName = @"dualDialogue"; break;
			case transitionLine:
				typeName = @"transition"; break;
			case lyrics:
				typeName = @"lyrics"; break;
			case pageBreak:
				typeName = @"pageBreak"; break;
			case centered:
				typeName = @"centered"; break;
			case more:
				typeName = @"more"; break;
			case dualDialogueMore:
				typeName = @"dualDialogueMore"; break;
			case typeCount:
				typeName = @""; break;
		}
		
		[types setValue:@(i) forKey:typeName];
	}
	
	return types;
}

+ (NSString*)typeAsString:(LineType)type {
	switch (type) {
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
			return @"DD Dialogue";
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
		case dualDialogueMore:
			return @"DD More";
		case typeCount:
			return @"";
	}
}

- (NSString*)typeAsString
{
	return [Line typeAsString:self.type];
}

- (NSString*)typeAsFountainString
{
	// This returns the type as an FNElement compliant string,
	// for convoluted backwards compatibility reasons :----)

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
		case dualDialogueMore:
			return @"More";
		case typeCount:
			return @"";
	}
}

#pragma mark - Cloning

/* This should be implemented as NSCopying */

- (Line*)clone {
	Line* newLine = [Line withString:self.string type:self.type];
	newLine.position = self.position;
	
	newLine.changed = self.changed;
	newLine.isSplitParagraph = self.isSplitParagraph;
	newLine.numberOfPrecedingFormattingCharacters = self.numberOfPrecedingFormattingCharacters;
	newLine.unsafeForPageBreak = self.unsafeForPageBreak;
	
	if (self.changedRanges) newLine.changedRanges = self.changedRanges.copy;
	if (self.italicRanges.count) newLine.italicRanges = self.italicRanges.mutableCopy;
	if (self.boldRanges.count) newLine.boldRanges = self.boldRanges.mutableCopy;
	if (self.boldItalicRanges.count) newLine.boldItalicRanges = self.boldItalicRanges.mutableCopy;
	if (self.noteRanges.count) newLine.noteRanges = self.noteRanges.mutableCopy;
	if (self.omittedRanges.count) newLine.omittedRanges = self.omittedRanges.mutableCopy;
	if (self.underlinedRanges.count) newLine.underlinedRanges = self.underlinedRanges.mutableCopy;
	
	if (self.strikeoutRanges.count) newLine.strikeoutRanges = self.strikeoutRanges.mutableCopy;
	
	if (self.additionRanges.count) newLine.additionRanges = self.additionRanges.mutableCopy;
	if (self.removalRanges.count) newLine.removalRanges = self.removalRanges.mutableCopy;
	if (self.escapeRanges.count) newLine.escapeRanges = self.escapeRanges.mutableCopy;
	
	if (self.sceneNumber) newLine.sceneNumber = [NSString stringWithString:self.sceneNumber];
	if (self.color) newLine.color = [NSString stringWithString:self.color];
	
	newLine.nextElementIsDualDialogue = self.nextElementIsDualDialogue;
	
	return newLine;
}

#pragma mark - Delegate methods

- (NSUInteger)index {
	if (!self.parser) return NSNotFound;
	return [self.parser.lines indexOfObject:self];
}


#pragma mark - String methods

- (NSString*)cleanedString {
	// Return empty string for invisible blocks
	if (self.type == section || self.type == synopse || self.omitted) return @"";
		
	NSMutableString *string = [NSMutableString stringWithString:[Line removeMarkUpFrom:[self stripInvisible] line:self]];
	
	return string;
}

- (NSString*)stringForDisplay {
	// String for UI use
	NSString *string;
	if (!self.omitted) string = [Line removeMarkUpFrom:[self stripInvisible] line:self];
	else string = [Line removeMarkUpFrom:self.string line:self];
	
	return [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSString*)stringCopy:(id)sender {
	return [NSString stringWithString:_string];
}

- (NSString*)textContent {
	// Pure text content
	NSMutableString *string = [NSMutableString stringWithString:self.string];

	// Remove force characters
	if (string.length > 0 && self.numberOfPrecedingFormattingCharacters > 0 && self.type != centered) {
		if (self.type == character) [string setString:[string replace:RX(@"^@") with:@""]];
		else if (self.type == heading) [string setString:[string replace:RX(@"^\\.") with:@""]];
		else if (self.type == action) [string setString:[string replace:RX(@"^!") with:@""]];
		else if (self.type == lyrics) [string setString:[string replace:RX(@"^~") with:@""]];
		else if (self.type == transitionLine) [string setString:[string replace:RX(@"^>") with:@""]];
		else {
			if (self.numberOfPrecedingFormattingCharacters > 0 && self.string.length >= self.numberOfPrecedingFormattingCharacters) {
				[string setString:[string substringFromIndex:self.numberOfPrecedingFormattingCharacters]];
			}
		}
	}
	
	// Replace formatting characters
	for (NSString* formattingCharacters in FORMATTING_CHARACTERS) {
		[string setString:[string stringByReplacingOccurrencesOfString:formattingCharacters withString:@""]];
	}

	return string;
}

#pragma mark - Strip formatting

/*
 
 So, uhhhhh. I'm not sure which of these methods are used where.
 Line.stripFormatting is the most reliable way of getting a clean string and
 should be used everywhere. The old methods linger around, because their quirks
 might be essential to some use cases, and I hope to fix this in the future.
 
 */

- (NSString*)stripFormatting {
	// A better version of stripFormattingCharacters
	NSIndexSet *contentRanges = self.contentRanges;

	__block NSMutableString *content = [NSMutableString string];
	[contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[content appendString:[self.string substringWithRange:range]];
	}];
	return content;
}

- (NSString*)stripFormattingCharacters {
	// Strip any formatting
	return [self stripInvisible];
}
- (NSString*)stripInvisible {
	__block NSMutableString *string = [NSMutableString stringWithString:self.string];
	__block NSUInteger offset = 0;
	
	// To remove any omitted ranges, we need to combine the index sets
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	[indexes addIndexes:self.omittedRanges];
	[indexes addIndexes:self.noteRanges];
	[indexes addIndexes:self.escapeRanges];
	
	// Strip section markup characters
	if (self.type == section) {
		int s = 0;
		while (s < self.string.length && [self.string characterAtIndex:s] == '#') {
			[indexes addIndex:s];
			s++;
		}
	}
	
	[indexes enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.location - offset + range.length > string.length) {
			range = NSMakeRange(range.location, string.length - range.location - offset);
		}
		
		@try {
			[string replaceCharactersInRange:NSMakeRange(range.location - offset, range.length) withString:@""];
		}
		@catch (NSException* exception) {
			NSLog(@"cleaning out of range: %@ / (%lu, %lu) / offset %lu", self.string, range.location, range.length, offset);
		}
		@finally {
			offset += range.length;
		}
	}];
	
	return string;
}
- (NSString*)stripNotes {
	__block NSMutableString *string = [NSMutableString stringWithString:self.string];
	__block NSUInteger offset = 0;
	
	[self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.location - offset + range.length > string.length) {
			range = NSMakeRange(range.location, string.length - range.location - offset);
		}
		
		@try {
			[string replaceCharactersInRange:NSMakeRange(range.location - offset, range.length) withString:@""];
		}
		@catch (NSException* exception) {
			NSLog(@"cleaning out of range: %@ / (%lu, %lu) / offset %lu", self.string, range.location, range.length, offset);
		}
		@finally {
			offset += range.length;
		}
	}];
	
	return string;
}

- (NSString*)stripSceneNumber {
	NSString *result = [self.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", self.sceneNumber] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, self.string.length)];
	return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

-(NSRange)range {
	// Range for the full line (incl. line break)
	return NSMakeRange(self.position, self.string.length + 1);
}
-(NSInteger)length {
	return self.string.length;
}
-(NSRange)textRange {
	// Range for the text only
	return NSMakeRange(self.position, self.string.length);
}
-(NSRange)globalRangeToLocal:(NSRange)range {
	// Insert a range and get a LOCAL range in the line
	NSRange lineRange = (NSRange){ self.position, self.string.length };
	NSRange intersection = NSIntersectionRange(range, lineRange);
	
	return (NSRange){ intersection.location - self.position, intersection.length };
}


#pragma mark - Element booleans

- (bool)isOutlineElement {
	if (self.type == heading ||
		self.type == section ||
		self.type == synopse) return YES;
	else return NO;
}

- (bool)isTitlePage {
	if (self.type == titlePageTitle ||
		self.type == titlePageCredit ||
		self.type == titlePageAuthor ||
		self.type == titlePageDraftDate ||
		self.type == titlePageContact ||
		self.type == titlePageSource ||
		self.type == titlePageUnknown) return YES;
	else return NO;
}

- (bool)isInvisible {
	if (self.omitted ||
		self.type == section ||
		self.type == synopse ||
		self.isTitlePage) return YES;
	else return NO;
}

- (bool)forced {
	if (self.numberOfPrecedingFormattingCharacters > 0) return YES;
	else return NO;
}

#pragma mark Dialogue

- (bool)isDialogue {
	if (self.type == character || self.type == parenthetical || self.type == dialogue) return YES;
	else return NO;
}
- (bool)isDialogueElement {
	// Is SUB-DIALOGUE element
	if (self.type == parenthetical || self.type == dialogue) return YES;
	else return NO;
}
- (bool)isDualDialogue {
	if (self.type == dualDialogue || self.type == dualDialogueCharacter || self.type == dualDialogueParenthetical) return YES;
	else return NO;
}
- (bool)isDualDialogueElement {
	if (self.type == dualDialogueParenthetical || self.type == dualDialogue) return YES;
	else return NO;
}


#pragma mark Omissions & notes

- (bool)omitted {
	// See if whole block is omited
	// WARNING: This also includes lines that have 0 length, meaning
	// the method will return YES for empty lines too.
	
	// Btw, this is me writing from the future. I love you, past me!!!
	
	__block NSInteger invisibleLength = 0;
	
	[self.omittedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		invisibleLength += range.length;
	}];

	[self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		invisibleLength += range.length;
	}];
		
	// This returns YES also for empty lines, which SHOULD NOT be a problem for anything, but yeah, we could check it:
	//if (omitLength == [self.string length] && self.type != empty) {
	if (invisibleLength >= self.string.length)  return true;
	else return false;
}

- (bool)note {
	// This should be used only in conjuction with .omited to check that, yeah, it's omited but it's a note:
	// if (line.omited && !line.note) ...
	// Compared also using trimmed length, to make lines like "[[note]] " be notes.
	
	if (self.noteRanges.count >= self.trimmed.length && self.noteRanges.count && self.string.length >= 2) {
		return YES;
	} else {
		return NO;
	}
}


#pragma mark Centered

- (bool)centered {
	if (self.string.length < 2) return NO;

	if ([self.string characterAtIndex:0] == '>' &&
		[self.string characterAtIndex:self.string.length - 1] == '<') return YES;
	else return NO;
}


#pragma mark Formatting range booleans

-(bool)isBoldedAt:(NSInteger)index {
	__block bool inRange = NO;
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
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


#pragma mark - Formatting & attribution

- (void)resetFormatting {
	// Read Fountain stylization inside this single string
	
	NSUInteger length = self.string.length;
	unichar charArray[length];
	[self.string getCharacters:charArray];
	
	self.boldRanges = [self rangesInChars:charArray
								 ofLength:length
								  between:BOLD_CHAR
									  and:BOLD_CHAR
							   withLength:2];
	self.italicRanges = [self rangesInChars:charArray
								 ofLength:length
								  between:ITALIC_CHAR
									  and:ITALIC_CHAR
							   withLength:1];
	self.underlinedRanges = [self rangesInChars:charArray
									   ofLength:length
										between:UNDERLINE_CHAR
											and:UNDERLINE_CHAR
									 withLength:1];
			
	self.strikeoutRanges = [self rangesInChars:charArray
								 ofLength:length
								  between:STRIKEOUT_OPEN_CHAR
									  and:STRIKEOUT_CLOSE_CHAR
							   withLength:2];
	self.noteRanges = [self rangesInChars:charArray
								 ofLength:length
								  between:NOTE_OPEN_CHAR
									  and:NOTE_CLOSE_CHAR
							   withLength:2];
}

- (NSString*)attributedStringToFountain:(NSAttributedString*)attrStr {
	return [self attributedStringToFountain:attrStr saveRanges:NO];
}
- (NSString*)attributedStringToFountain:(NSAttributedString*)attrStr saveRanges:(bool)saveRanges {
	// NOTE! This only works with the FDX atributed string
	NSMutableString *result = [NSMutableString string];
	
	__block NSInteger pos = 0;
	
	[attrStr enumerateAttributesInRange:(NSRange){0, attrStr.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSString *string = [attrStr attributedSubstringFromRange:range].string;
				
		NSString *open = @"";
		NSString *close = @"";
		NSString *openClose = @"";
		
		NSString *styleString = attrs[@"Style"];
		NSArray *styles = [styleString componentsSeparatedByString:@","];
		
		if ([styles containsObject:BOLD_STYLE]) openClose = [openClose stringByAppendingString:BOLD_PATTERN];
		if ([styles containsObject:ITALIC_STYLE]) openClose = [openClose stringByAppendingString:ITALIC_PATTERN];
		if ([styles containsObject:UNDERLINE_STYLE]) openClose = [openClose stringByAppendingString:UNDERLINE_PATTERN];
		if ([styles containsObject:STRIKEOUT_STYLE]) {
			open = [open stringByAppendingString:STRIKEOUT_PATTERN];
			close = [close stringByAppendingString:STRIKEOUT_CLOSE_PATTERN];
		}
		
		[result appendString:open];
		[result appendString:openClose];
		[result appendString:string];
		[result appendString:openClose];
		[result appendString:close];

		pos += open.length + openClose.length + string.length + openClose.length + close.length;
	}];
	
	return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSAttributedString*)attributedStringForFDX {
	// N.B. This is NOT a Cocoa-compatible attributed string.
	// The attributes are used to 	create a string for FDX/HTML conversion.
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:self.string];
	
	// Make (forced) character names uppercase
	if (self.type == character || self.type == dualDialogueCharacter) {
		[string replaceCharactersInRange:self.characterNameRange withString:[self.string substringWithRange:self.characterNameRange].uppercaseString];
	}
	
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > ITALIC_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:ITALIC_STYLE toString:string range:range];
		}
	}];
	
	// Add font stylization
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > BOLD_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:BOLD_STYLE toString:string range:range];
		}
	}];
	
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > UNDERLINE_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:UNDERLINE_STYLE toString:string range:range];
		}
	}];
		
	[self.omittedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > OMIT_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:OMIT_STYLE toString:string range:range];
		}
	}];
	
	[self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > NOTE_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:OMIT_STYLE toString:string range:range];
		}
	}];
		
	[self.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > STRIKEOUT_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:STRIKEOUT_STYLE toString:string range:range];
		}
	}];
	
	[self.escapeRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if ([self rangeInStringRange:range]) [self addAttr:OMIT_STYLE toString:string range:range];
	}];
	
	/*
	[self.highlightRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > HIGHLIGHT_PATTERN.length * 2) {
			[self addAttr:@"Highlight" toString:string range:range];
		}
	}];
	*/
	 
	[self.additionRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if ([self rangeInStringRange:range]) [self addAttr:@"Addition" toString:string range:range];
	}];
	
	[self.removalRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if ([self rangeInStringRange:range]) [self addAttr:@"Removal" toString:string range:range];
	}];
	
	// Loop through tags and apply
	for (NSDictionary *tag in self.tags) {
		NSString* tagValue = tag[@"tag"];
		if (!tagValue) continue;
		
		NSRange range = [(NSValue*)tag[@"range"] rangeValue];
		[string addAttribute:@"BeatTag" value:tagValue range:range];
	}
		
	return string;
}

- (void)addAttr:(NSString*)name toString:(NSMutableAttributedString*)string range:(NSRange)range {
	// We are going out of range. Abort.
	if (range.location + range.length > string.length || range.length < 1 || range.location == NSNotFound) return;
	
	NSDictionary *styles = [string attributesAtIndex:range.location longestEffectiveRange:nil inRange:range];

	NSString *style;
	if (styles[@"Style"]) style = [NSString stringWithFormat:@"%@,%@", styles[@"Style"], name];
	else style = name;
	
	[string addAttribute:@"Style" value:style range:range];
}

- (NSArray*)splitAndFormatToFountainAt:(NSInteger)index {
	NSAttributedString *string = [self attributedStringForFDX];
	NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
	
	[self.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > 0) [attrStr appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
	
	NSAttributedString *second = [[NSMutableAttributedString alloc] initWithString:@""];
	
	// Safeguard index (this could happen to numerous reasons, extra spaces etc.)
	if (index > attrStr.length) index = attrStr.length;
		
	NSAttributedString *first = [attrStr attributedSubstringFromRange:(NSRange){ 0, index }];
	if (index <= attrStr.length) second = [attrStr attributedSubstringFromRange:(NSRange){ index, attrStr.length - index }];
	
	Line *retain = [Line withString:[self attributedStringToFountain:first] type:self.type pageSplit:YES];
	Line *split = [Line withString:[self attributedStringToFountain:second] type:self.type pageSplit:YES];
		
	if (self.changed) {
		retain.changed = YES;
		split.changed = YES;
	}
	retain.position = self.position;
	split.position = self.position + retain.string.length;
	
	return @[ retain, split ];
}

+ (NSString*)removeMarkUpFrom:(NSString*)rawString line:(Line*)line {
	NSMutableString *string = [NSMutableString stringWithString:rawString];
	
	if (string.length > 0 && line.numberOfPrecedingFormattingCharacters > 0 && line.type != centered) {
		if (line.type == character) [string setString:[string replace:RX(@"^@") with:@""]];
		else if (line.type == heading) [string setString:[string replace:RX(@"^\\.") with:@""]];
		else if (line.type == action) [string setString:[string replace:RX(@"^!") with:@""]];
		else if (line.type == lyrics) [string setString:[string replace:RX(@"^~") with:@""]];
		else if (line.type == section) [string setString:[string replace:RX(@"^#") with:@""]];
		else if (line.type == synopse) [string setString:[string replace:RX(@"^=") with:@""]];
		else if (line.type == transitionLine) [string setString:[string replace:RX(@"^>") with:@""]];
	}

	if (line.type == centered) {
		// Let's not clean any formatting characters in case they are cleaned already.
		if (line.string.length > 0 && [string characterAtIndex:0] == '>') {
			string = [NSMutableString stringWithString:[string substringFromIndex:1]];
			string = [NSMutableString stringWithString:[string substringToIndex:string.length - 1]];
		}
	}
	
	// Clean up scene headings
	// Note that the scene number can still be read from the element itself (.sceneNumber) when needed.
	if (line.type == heading && line.sceneNumber) {
		[string replaceOccurrencesOfString:[NSString stringWithFormat:@"#%@#", line.sceneNumber] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, string.length)];
	}
	
	return string;
}


#pragma mark - formatting range lookup

- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength
{
	NSMutableIndexSet* indexSet = [[NSMutableIndexSet alloc] init];
	
	NSInteger lastIndex = length - delimLength; //Last index to look at if we are looking for start
	NSInteger rangeBegin = -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
	

	for (NSInteger i = 0;;i++) {
		if (i > lastIndex) {
			break;
		}
				
		// No range is currently inspected
		if (rangeBegin == -1) {
			bool match = YES;
			for (int j = 0; j < delimLength; j++) {
				// Check for escape character (like \*)
				if (i > 0 && string[j + i - 1] == '\\') {
					match = NO;
					break;
				}
			
				if (string[j+i] != startString[j]) {
					match = NO;
					break;
				}
			}
			if (match) {
				rangeBegin = i;
				i += delimLength - 1;
			}
		// We have found a range
		} else {
			bool match = YES;
			for (int j = 0; j < delimLength; j++) {
				if (string[j+i] != endString[j]) {
					match = NO;
					break;
				}
			}
			if (match) {
				[indexSet addIndexesInRange:NSMakeRange(rangeBegin, i - rangeBegin + delimLength)];
				rangeBegin = -1;
				i += delimLength - 1;
			}
		}
	}
		
	return indexSet;
}

#pragma mark - Ranges

- (bool)rangeInStringRange:(NSRange)range {
	if (range.location + range.length <= self.string.length) return YES;
	else return NO;
}

- (NSIndexSet*)contentRanges
{
	// Returns ranges with content ONLY (useful for reconstruction the string with no Fountain stylization)
	NSMutableIndexSet *contentRanges = [NSMutableIndexSet indexSet];
	[contentRanges addIndexesInRange:NSMakeRange(0, self.string.length)];
		
	NSIndexSet *formattingRanges = self.formattingRanges;
	[contentRanges removeIndexes:formattingRanges];
	
	return contentRanges;
}

- (NSIndexSet*)formattingRanges {
	return [self formattingRangesWithGlobalRange:NO includeNotes:YES];
}

- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes
{
	// This maps formatting characters into an index set, INCLUDING notes, scene numbers etc.
	// It could be used anywhere, but for now, it's used to create XML formatting for FDX export.
	
	NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
	NSString* string = self.string;
	NSInteger offset = 0;
	
	if (globalRange) offset = self.position;
	
	// Add force element ranges
	if (string.length > 0 && self.numberOfPrecedingFormattingCharacters > 0 && self.type != centered) {
		unichar c = [string characterAtIndex:0];
		
		if ((self.type == character && c == '@') ||
			(self.type == heading && c == '.') ||
			(self.type == action && c == '!') ||
			(self.type == lyrics && c == '~') ||
			(self.type == section && c == '#') ||
			(self.type == synopse && c == '#') ||
			(self.type == transitionLine && c == '>')) {
			[indices addIndex:0+offset];
		}
	}
	
	// Catch dual dialogue force symbol
	if (self.type == dualDialogueCharacter && self.string.length > 0) {
		[indices addIndex:self.string.length - 1 +offset];
	}
	
	// Add ranges for > and < (if needed)
	if (self.type == centered && self.string.length >= 2) {
		if ([self.string characterAtIndex:0] == '>' && [self.string characterAtIndex:self.string.length - 1] == '<') {
			[indices addIndex:0+offset];
			[indices addIndex:self.string.length - 1+offset];
		}
	}
	
	// Escape ranges
	[indices addIndexes:[[NSIndexSet alloc] initWithIndexSet:self.escapeRanges]];
	
	// Scene number range
	if (self.sceneNumberRange.length) {
		[indices addIndexesInRange:self.sceneNumberRange];
		// Also remove the surrounding #'s
		[indices addIndex:self.sceneNumberRange.location - 1 +offset];
		[indices addIndex:self.sceneNumberRange.location + self.sceneNumberRange.length +offset];
	}
	
	// Stylization ranges
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location +offset, BOLD_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - BOLD_PATTERN.length +offset, BOLD_PATTERN.length)];
	}];
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location +offset, ITALIC_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - ITALIC_PATTERN.length +offset, ITALIC_PATTERN.length)];
	}];
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location +offset, UNDERLINE_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - UNDERLINE_PATTERN.length +offset, UNDERLINE_PATTERN.length)];
	}];
	[self.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, HIGHLIGHT_PATTERN.length +offset)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - HIGHLIGHT_PATTERN.length +offset, HIGHLIGHT_PATTERN.length)];
	}];
	
	/*
	[self.highlightRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, HIGHLIGHT_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - HIGHLIGHT_PATTERN.length, HIGHLIGHT_PATTERN.length)];
	}];
	*/

		
	// Add note ranges
	if (includeNotes) [indices addIndexes:self.noteRanges];
	[indices addIndexes:self.omittedRanges];
	
	return indices;
}

- (NSRange)characterNameRange
{
	NSInteger parenthesisLoc = [self.string rangeOfString:@"("].location;
	
	if (parenthesisLoc == NSNotFound) {
		return (NSRange){ 0, self.string.length };
	} else {
		return (NSRange){ 0, parenthesisLoc };
	}
}


#pragma mark - Helper methods

- (NSString*)trimmed {
	return [self.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)joinWithLine:(Line *)line
{
	if (!line) return;
	
	NSString *string = line.string;
	if (line.numberOfPrecedingFormattingCharacters > 0 && string.length > 0) {
		string = [string substringFromIndex:line.numberOfPrecedingFormattingCharacters];
	}
	
	NSInteger offset = self.string.length + 1 - line.numberOfPrecedingFormattingCharacters;
	if (line.changed) self.changed = YES;
	
	self.string = [self.string stringByAppendingString:[NSString stringWithFormat:@"\n%@", string]];
	
	[line.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.boldRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	
	[line.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.italicRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.underlinedRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.strikeoutRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.additionRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.additionRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.noteRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
}

- (NSString*)characterName
{
	// This removes any extra suffixes from character name, ie. (V.O.), (CONT'D) etc.
	// We'll allow the method to run for lines under 4 characters, even if not parsed as character cues
	if (self.type != character && self.string.length > 3) return nil;
	
	// Strip formatting (such as symbols for forcing element types)
	NSString *name = [self stripFormatting];
	
	// Find and remove suffix
	NSRange suffixRange = [name rangeOfString:@"("];
	if (suffixRange.location != NSNotFound && suffixRange.location > 0) name = [name substringWithRange:(NSRange){0, suffixRange.location}];
	
	return [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}
 

#pragma mark - JSON serialization

-(NSDictionary*)forSerialization {
	return @{
		@"string": (self.string.length) ? self.string.copy : @"",
		@"sceneNumber": (self.sceneNumber) ? self.sceneNumber.copy : @"",
		@"position": @(self.position),
		@"range": @{ @"location": @(self.range.location), @"length": @(self.range.length) },
		@"sectionDepth": @(self.sectionDepth),
		@"textRange": @{ @"location": @(self.textRange.location), @"length": @(self.textRange.length) },
		@"typeAsString": self.typeAsString,
		@"omitted": @(self.omitted)
	};
}

#pragma mark - for debugging

-(NSString *)description
{
	return [NSString stringWithFormat:@"Line: %@  (%@ at %lu) %@", self.string, self.typeAsString, self.position, (self.nextElementIsDualDialogue) ? @"Next is dual" : @"" ];
}
@end
