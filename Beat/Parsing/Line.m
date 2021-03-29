//
//  Line.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  Parts copyright © 2019-2021 KAPITAN! / Lauri-Matti Parppei. All Rights reserved.

/*

 This class is HEAVILY modified for Beat.
 There are multiple, overlapping methods for legacy reasons. I'm working on cleaning them up.
 
 */

#import "Line.h"
#import "RegExCategories.h"
#import "FountainRegexes.h"
#import "DiffMatchPatch.h"

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

// For FDX compatibility (not used right now, mostly for reminder)
#define BOLD_STYLE @"Bold"
#define ITALIC_STYLE @"Italic"
#define UNDERLINE_STYLE @"Underline"

@implementation Line

+ (Line*)withString:(NSString*)string type:(LineType)type {
	return [[Line alloc] initWithString:string type:type];
}
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit {
	return [[Line alloc] initWithString:string type:type pageSplit:YES];
}
+ (NSArray*)markupCharacters {
	return @[@".", @"@", @"~", @"!"];
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
	//if (self.highlightRanges.count) newLine.highlightRanges = [self.highlightRanges copy];
	if (self.strikeoutRanges.count) newLine.strikeoutRanges = [self.strikeoutRanges copy];
	
	if (self.additionRanges.count) newLine.additionRanges = [self.additionRanges copy];
	if (self.removalRanges.count) newLine.removalRanges = [self.removalRanges copy];
	
	if (self.sceneNumber) newLine.sceneNumber = [NSString stringWithString:self.sceneNumber];
	if (self.color) newLine.color = [NSString stringWithString:self.color];
	
	return newLine;
}

- (Line*)initWithString:(NSString*)string position:(NSUInteger)position
{
    self = [super init];
    if (self) {
        _string = string;
		_original = string;
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
- (Line*)initWithString:(NSString *)string type:(LineType)type pageSplit:(bool)pageSplit {
	self = [super init];
	if (self) {
		_string = string;
		_type = type;
		_unsafeForPageBreak = YES;
		
		if (pageSplit) [self resetFormatting];
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
	__block NSInteger invisibleLength = 0;
	
	[self.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
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
	if (self.string.length >= 2) {
		if ([[self.string substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"[["]) return YES;
		else return NO;
	} else {
		return NO;
	}
}

- (bool)centered {
	if (self.string.length < 2) return NO;

	if ([self.string characterAtIndex:0] == '>' &&
		[self.string characterAtIndex:self.string.length - 1] == '<') return YES;
	else return NO;
}

+ (NSString*)removeMarkUpFrom:(NSString*)rawString line:(Line*)line {
	NSMutableString *string = [NSMutableString stringWithString:rawString];
	
	if (string.length > 0 && line.numberOfPreceedingFormattingCharacters > 0 && line.type != centered) {
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

- (NSString*)cleanedString {
	// Return empty string for invisible blocks
	if (self.type == section || self.type == synopse || self.omited) return @"";
		
	NSMutableString *string = [NSMutableString stringWithString:[Line removeMarkUpFrom:[self stripInvisible] line:self]];
	
	return string;
}
- (NSString*)stringForDisplay {
	NSString *string;
	if (!self.omited) string = [Line removeMarkUpFrom:[self stripInvisible] line:self];
	else string = [Line removeMarkUpFrom:self.string line:self];
	
	return [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];

}

- (NSString*)stripFormattingCharacters {
	NSMutableString *string = [NSMutableString stringWithString:self.string];

	// Remove force characters
	if (string.length > 0 && self.numberOfPreceedingFormattingCharacters > 0 && self.type != centered) {
		if (self.type == character) [string setString:[string replace:RX(@"^@") with:@""]];
		else if (self.type == heading) [string setString:[string replace:RX(@"^\\.") with:@""]];
 		else if (self.type == action) [string setString:[string replace:RX(@"^!") with:@""]];
		else if (self.type == lyrics) [string setString:[string replace:RX(@"^~") with:@""]];
		else if (self.type == transitionLine) [string setString:[string replace:RX(@"^>") with:@""]];
		else {
			if (self.numberOfPreceedingFormattingCharacters > 0 && self.string.length >= self.numberOfPreceedingFormattingCharacters) {
				[string setString:[string substringFromIndex:self.numberOfPreceedingFormattingCharacters]];
			}
		}
	}
	
	// Replace formatting characters
	for (NSString* formattingCharacters in FORMATTING_CHARACTERS) {
		[string setString:[string stringByReplacingOccurrencesOfString:formattingCharacters withString:@""]];
	}

	return string;
}
- (NSString*)stripInvisible {
	__block NSMutableString *string = [NSMutableString stringWithString:self.string];
	__block NSUInteger offset = 0;
	
	// To remove any omitted ranges, we need to combine the index sets
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	[indexes addIndexes:self.omitedRanges];
	[indexes addIndexes:self.noteRanges];
	
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
	if (self.omited ||
		self.type == section ||
		self.type == synopse ||
		self.isTitlePage) return YES;
	else return NO;
}
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

-(NSRange)range {
	// Range for the full line (incl. line break)
	return NSMakeRange(self.position, self.string.length + 1);
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
- (NSAttributedString*)attributedStringForFDX {
	// N.B. This is NOT a Cocoa-compatible attributed string.
	// The attributes are used to create a string for FDX/HTML conversion.
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:self.string];
	
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > ITALIC_PATTERN.length * 2) {
			[self addAttr:@"Italic" toString:string range:range];
		}
	}];
	
	// Add font stylization
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > BOLD_PATTERN.length * 2) {
			[self addAttr:@"Bold" toString:string range:range];
		}
	}];
	
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > UNDERLINE_PATTERN.length * 2) {
			[self addAttr:@"Underline" toString:string range:range];
		}
	}];
		
	[self.omitedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > OMIT_PATTERN.length * 2) {
			[self addAttr:@"Omit" toString:string range:range];
		}
	}];
	
	[self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > NOTE_PATTERN.length * 2) {
			[self addAttr:@"Omit" toString:string range:range];
		}
	}];
	
	[self.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > STRIKEOUT_PATTERN.length * 2) {
			[self addAttr:@"Strikeout" toString:string range:range];
		}
	}];
	
	/*
	[self.highlightRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > HIGHLIGHT_PATTERN.length * 2) {
			[self addAttr:@"Highlight" toString:string range:range];
		}
	}];
	*/
	 
	[self.additionRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self addAttr:@"Addition" toString:string range:range];
	}];
	
	[self.removalRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self addAttr:@"Removal" toString:string range:range];
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
	if (range.location + range.length > string.length) {
		range = (NSRange) { range.location, range.location + range.length - string.length };
	}
	if (range.length < 1 || range.location == NSNotFound) return;
	
	NSDictionary *styles = [string attributesAtIndex:0 longestEffectiveRange:nil inRange:range];
	NSString *style;
	if (styles[@"Style"]) style = [NSString stringWithFormat:@"%@,%@", styles[@"Style"], name];
	else style = name;
	
	[string addAttribute:@"Style" value:style range:range];
}

- (void)joinWithLine:(Line *)line
{
	NSString *string = line.string;
	NSInteger offset = self.string.length + 1;
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
}
- (NSArray*)splitAndFormatToFountainAt:(NSInteger)index {
	NSAttributedString *string = [self attributedStringForFDX];
	NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
	[self.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[attrStr appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
	
	NSAttributedString *first = [attrStr attributedSubstringFromRange:(NSRange){ 0, index }];
	NSAttributedString *second = [attrStr attributedSubstringFromRange:(NSRange){ index, attrStr.length - index }];
	
	NSArray *result = @[ [self attributedStringToFountain:first], [self attributedStringToFountain:second] ];
	return result;
}
- (NSString*)attributedStringToFountain:(NSAttributedString*)attrStr {
	// NOTE! This only works with the FDX atributed string
	NSMutableString *result = [NSMutableString string];
	[attrStr enumerateAttributesInRange:(NSRange){0, attrStr.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSString *string = [attrStr attributedSubstringFromRange:range].string;
				
		NSString *open = @"";
		NSString *close = @"";
		NSString *openClose = @"";
		
		NSString *styleString = attrs[@"Style"];
		NSArray *styles = [styleString componentsSeparatedByString:@","];
		
		if ([styles containsObject:@"Bold"]) openClose = [openClose stringByAppendingString:BOLD_PATTERN];
		if ([styles containsObject:@"Italic"]) openClose = [openClose stringByAppendingString:ITALIC_PATTERN];
		if ([styles containsObject:@"Underline"]) openClose = [openClose stringByAppendingString:UNDERLINE_PATTERN];
		if ([styles containsObject:@"Strikeout"]) {
			open = [open stringByAppendingString:STRIKEOUT_PATTERN];
			close = [close stringByAppendingString:STRIKEOUT_CLOSE_PATTERN];
		}
		
		[result appendString:open];
		[result appendString:openClose];
		[result appendString:string];
		[result appendString:openClose];
		[result appendString:close];
	}];
	
	return result;
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
- (NSIndexSet*)formattingRanges
{
	// This maps formatting characters into an index set, INCLUDING notes, scene numbers etc.
	// It could be used anywhere, but for now, it's used to create XML formatting for FDX export.
	NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
	NSString* string = self.string;
	
	// Add force element ranges
	if (string.length > 0 && self.numberOfPreceedingFormattingCharacters > 0 && self.type != centered) {
		unichar c = [string characterAtIndex:0];
		
		if ((self.type == character && c == '@') ||
			(self.type == heading && c == '.') ||
			(self.type == action && c == '!') ||
			(self.type == lyrics && c == '~') ||
			(self.type == section && c == '#') ||
			(self.type == synopse && c == '#') ||
			(self.type == transitionLine && c == '>')) {
			[indices addIndex:0];
		}
	}
	
	// Catch dual dialogue force symbol
	if (self.type == dualDialogueCharacter && self.string.length > 0) {
		[indices addIndex:self.string.length - 1];
	}
	
	// Add ranges for > and < (if needed)
	if (self.type == centered && self.string.length >= 2) {
		if ([self.string characterAtIndex:0] == '>' && [self.string characterAtIndex:self.string.length - 1] == '<') {
			[indices addIndex:0];
			[indices addIndex:self.string.length - 1];
		}
	}
	
	// Scene number range
	[indices addIndexesInRange:self.sceneNumberRange];
	
	// Stylization ranges
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, BOLD_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - BOLD_PATTERN.length, BOLD_PATTERN.length)];
	}];
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, ITALIC_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - ITALIC_PATTERN.length, ITALIC_PATTERN.length)];
	}];
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, UNDERLINE_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - UNDERLINE_PATTERN.length, UNDERLINE_PATTERN.length)];
	}];
	[self.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, HIGHLIGHT_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - HIGHLIGHT_PATTERN.length, HIGHLIGHT_PATTERN.length)];
	}];
	
	/*
	[self.highlightRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, HIGHLIGHT_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - HIGHLIGHT_PATTERN.length, HIGHLIGHT_PATTERN.length)];
	}];
	*/

		
	// Add note ranges
	[indices addIndexes:self.noteRanges];
	
	return indices;
}

- (NSString*)stripFormatting {
	// A better version of stripFormattingCharacters
	NSIndexSet *contentRanges = [self contentRanges];
	__block NSMutableString *content = [NSMutableString string];
	[contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[content appendString:[self.string substringWithRange:range]];
	}];
	return content;
}
- (NSString*)characterName
{
	// This removes any extra suffixes from character name, ie. (V.O.), (CONT'D) etc.
	if (self.type != character) return nil;
	
	// Strip formatting (such as symbols for forcing element types)
	NSString *name = [self stripFormatting];
	
	// Find and remove suffix
	NSRange suffixRange = [name rangeOfString:@"("];
	if (suffixRange.location != NSNotFound && suffixRange.location > 0) name = [name substringWithRange:(NSRange){0, suffixRange.location}];
	
	return [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (void)checkChanges {
	if ([self.string isEqualTo:self.original]) {
		self.changed = NO;
	} else {
		self.changed = YES;
	}
	
	[self changes];
}

- (void)changes {
	_changedRanges = [NSMutableIndexSet indexSet];
	DiffMatchPatch *diff = [[DiffMatchPatch alloc] init];
	
	NSMutableArray *diffs = [diff diff_mainOfOldString:self.original andNewString:self.string];
	[diff diff_cleanupEfficiency:diffs];
	//NSArray *diffs = [diff patch_makeFromOldString:self.original andNewString:self.string];
	
	NSInteger index = 0;
	for (Diff* diff in diffs) {
		if (diff.operation == DIFF_INSERT) {
			[_changedRanges addIndexesInRange:(NSRange){ index, diff.text.length }];
		}
		
		// Add to index when the string length has grown
		if (diff.operation == DIFF_EQUAL || diff.operation == DIFF_INSERT)
			index += diff.text.length;
	}
}
- (bool)isUnchanged {
	bool unchanged = NO;
	if ([self.string isEqualTo:self.original]) unchanged = YES;
	else unchanged = NO;
	
	self.changed = unchanged;
	return unchanged;
}

#pragma mark - formatting range lookup

- (void)resetFormatting {
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
									   ofLength:1
										between:UNDERLINE_CHAR
											and:UNDERLINE_CHAR
									 withLength:1];
	
	self.strikeoutRanges = [self rangesInChars:charArray
								 ofLength:length
								  between:STRIKEOUT_OPEN_CHAR
									  and:STRIKEOUT_CLOSE_CHAR
							   withLength:2];
}

- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength
{
	NSMutableIndexSet* indexSet = [[NSMutableIndexSet alloc] init];
	
	NSInteger lastIndex = length - delimLength; //Last index to look at if we are looking for start
	NSInteger rangeBegin = -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
	
	for (int i = 0;;i++) {
		if (i > lastIndex) break;
				
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

#pragma mark - for debugging

-(NSString *)description
{
	return [NSString stringWithFormat:@"Line: %@  - at %lu", self.string, self.position];
}
@end
