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
#define BOLDITALIC_STYLE @"BoldItalic"
#define UNDERLINE_STYLE @"Underline"
#define STRIKEOUT_STYLE @"Strikeout"
#define OMIT_STYLE @"Omit"
#define NOTE_STYLE @"Note"

@interface Line()
@property (nonatomic) NSUInteger oldHash;
@end

@implementation Line

#pragma mark - Initialization

- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSInteger)position parser:(id<LineDelegate>)parser {
	self = [super init];
	if (self) {
		if (string == nil) string = @"";
		
		_string = string;
		_type = type;
		_position = position;
		_formattedAs = -1;
		//_parser = parser; // UNCOMMENT WHEN NEEDED
		
		_boldRanges = NSMutableIndexSet.indexSet;
		_italicRanges = NSMutableIndexSet.indexSet;
		_underlinedRanges = NSMutableIndexSet.indexSet;
		_boldItalicRanges = NSMutableIndexSet.indexSet;
		_strikeoutRanges = NSMutableIndexSet.indexSet;
		_noteRanges = NSMutableIndexSet.indexSet;
		_omittedRanges = NSMutableIndexSet.indexSet;
		_escapeRanges = NSMutableIndexSet.indexSet;
		_removalSuggestionRanges = NSMutableIndexSet.indexSet;
		_uuid = NSUUID.UUID;
	}
	return self;
}

- (Line*)initWithString:(NSString*)string position:(NSInteger)position
{
	return [[Line alloc] initWithString:string type:0 position:position parser:nil];
}
- (Line*)initWithString:(NSString*)string position:(NSInteger)position parser:(id<LineDelegate>)parser
{
	return [[Line alloc] initWithString:string type:0 position:position parser:parser];
}
- (Line*)initWithString:(NSString *)string type:(LineType)type position:(NSInteger)position {
	return [[Line alloc] initWithString:string type:type position:position parser:nil];
}

/// Init a line for non-continuous parsing
- (Line*)initWithString:(NSString *)string type:(LineType)type {
	return [[Line alloc] initWithString:string type:type position:-1 parser:nil];
}

/// Use this ONLY for creating temporary lines while paginating.
- (Line*)initWithString:(NSString *)string type:(LineType)type pageSplit:(bool)pageSplit {
	self = [super init];
	if (self) {
		_string = string;
		_type = type;
		_unsafeForPageBreak = YES;
		_formattedAs = -1;
		_uuid = NSUUID.UUID;
		
		if (pageSplit) [self resetFormatting];
	}
	return self;
}

#pragma mark - Shorthands

+ (Line*)withString:(NSString*)string type:(LineType)type parser:(id<LineDelegate>)parser {
	return [[Line alloc] initWithString:string type:type position:0 parser:parser];
}
+ (Line*)withString:(NSString*)string type:(LineType)type {
	return [[Line alloc] initWithString:string type:type];
}

/// Use this ONLY for creating temporary lines while paginating
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit {
	return [[Line alloc] initWithString:string type:type pageSplit:YES];
}

+ (NSArray*)markupCharacters {
	return @[@".", @"@", @"~", @"!"];
}

#pragma mark - Type

/// Used by plugin API to create constants for matching line types to enumerated integer values
+ (NSDictionary*)typeDictionary
{
	NSMutableDictionary *types = NSMutableDictionary.dictionary;
	
	NSInteger max = typeCount;
	for (NSInteger i = 0; i < max; i++) {
		LineType type = i;
        NSString *typeName = [Line typeName:type];
        
		[types setValue:@(i) forKey:typeName];
	}
	
	return types;
}

+ (NSString*)typeName:(LineType)type {
    switch (type) {
        case empty:
            return @"empty";
        case section:
            return @"section";
        case synopse:
            return @"synopsis";
        case titlePageTitle:
            return @"titlePageTitle";
        case titlePageAuthor:
            return @"titlePageAuthor";
        case titlePageCredit:
            return @"titlePageCredit";
        case titlePageSource:
            return @"titlePageSource";
        case titlePageContact:
            return @"titlePageContact";
        case titlePageDraftDate:
            return @"titlePageDraftDate";
        case titlePageUnknown:
            return @"titlePageUnknown";
        case heading:
            return @"heading";
        case action:
            return @"action";
        case character:
            return @"character";
        case parenthetical:
            return @"parenthetical";
        case dialogue:
            return @"dialogue";
        case dualDialogueCharacter:
            return @"dualDialogueCharacter";
        case dualDialogueParenthetical:
            return @"dualDialogueParenthetical";
        case dualDialogue:
            return @"dualDialogue";
        case transitionLine:
            return @"transition";
        case lyrics:
            return @"lyrics";
        case pageBreak:
            return @"pageBreak";
        case centered:
            return @"centered";
        case more:
            return @"more";
        case dualDialogueMore:
            return @"dualDialogueMore";
        case shot:
            return @"shot";
        case typeCount:
            return @"";
    }
}
- (NSString*)typeName {
    return [Line typeName:self.type];
}

/// Returns line type as string
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
		case shot:
			return @"Shot";
		case more:
			return @"More";
		case dualDialogueMore:
			return @"DD More";
		case typeCount:
			return @"";
	}
}

/// Retuns line type as string
- (NSString*)typeAsString
{
	return [Line typeAsString:self.type];
}


#pragma mark - Cloning

/* This should be implemented as NSCopying */

-(id)copy {
	return [self clone];
}

- (Line*)clone {
	Line* newLine = [Line withString:self.string type:self.type];
	newLine.representedLine = self; // For live pagination, refers to the line in PARSER
	newLine.uuid = self.uuid;
	newLine.position = self.position;
	
	newLine.changed = self.changed;
	
	newLine.isSplitParagraph = self.isSplitParagraph;
	newLine.numberOfPrecedingFormattingCharacters = self.numberOfPrecedingFormattingCharacters;
	newLine.unsafeForPageBreak = self.unsafeForPageBreak;
	newLine.sceneIndex = self.sceneIndex;
	
	
	newLine.revisionColor = self.revisionColor.copy; // This is the HIGHEST revision color on the line
	if (self.revisedRanges) newLine.revisedRanges = self.revisedRanges.mutableCopy; // This is a dictionary of revision color names and their respective ranges
	
	if (self.italicRanges.count) newLine.italicRanges = self.italicRanges.mutableCopy;
	if (self.boldRanges.count) newLine.boldRanges = self.boldRanges.mutableCopy;
	if (self.boldItalicRanges.count) newLine.boldItalicRanges = self.boldItalicRanges.mutableCopy;
	if (self.noteRanges.count) newLine.noteRanges = self.noteRanges.mutableCopy;
	if (self.omittedRanges.count) newLine.omittedRanges = self.omittedRanges.mutableCopy;
	if (self.underlinedRanges.count) newLine.underlinedRanges = self.underlinedRanges.mutableCopy;
	if (self.sceneNumberRange.length) newLine.sceneNumberRange = self.sceneNumberRange;
	if (self.strikeoutRanges.count) newLine.strikeoutRanges = self.strikeoutRanges.mutableCopy;
	if (self.removalSuggestionRanges.count) newLine.removalSuggestionRanges = self.removalSuggestionRanges.mutableCopy;
	if (self.escapeRanges.count) newLine.escapeRanges = self.escapeRanges.mutableCopy;
	
	if (self.sceneNumber) newLine.sceneNumber = [NSString stringWithString:self.sceneNumber];
	if (self.color) newLine.color = [NSString stringWithString:self.color];
	
	newLine.nextElementIsDualDialogue = self.nextElementIsDualDialogue;
	
	return newLine;
}

#pragma mark - Delegate methods

/// Returns the index of this line in the parser.
/// @warning VERY slow, this should be fixed to conform with the new, circular search methods.
- (NSUInteger)index {
	if (!self.parser) return NSNotFound;
	return [self.parser.lines indexOfObject:self];
}


#pragma mark - String methods
	
- (NSString*)stringForDisplay {
	if (!self.omitted)	return [self.stripFormatting stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	else {
		Line *line = self.clone;
		[line.omittedRanges removeAllIndexes];
		return [line.stripFormatting stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	}
}

/// @warning Legacy method. Use `line.stripFormatting`
- (NSString*)textContent {
	return self.stripFormatting;
}

/// Returns the last character as `unichar`
-(unichar)lastCharacter {
    if (_string.length > 0) {
        return [_string characterAtIndex:self.length - 1];
    } else {
        // Return error value
        return 0;
    }
}

#pragma mark - Strip formatting

/// Strip any Fountain formatting from the line
- (NSString*)stripFormatting {
	NSIndexSet *contentRanges;
	
	// This is an experimental thing
	if (self.paginator) {
		if ([_paginator boolForKey:@"printNotes"]) contentRanges = self.contentRangesWithNotes;
		else contentRanges = self.contentRanges;
	} else {
		contentRanges = self.contentRanges;
	}
	
	__block NSMutableString *content = NSMutableString.string;
	[contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[content appendString:[self.string substringWithRange:range]];
	}];

	return content;
}

/// Returns a string with notes removed
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

/// Returns a string with the scene number stripped
- (NSString*)stripSceneNumber {
	NSString *result = [self.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", self.sceneNumber] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, self.string.length)];
	return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

/// Range for the full line (incl. line break)
-(NSRange)range {
	return NSMakeRange(self.position, self.string.length + 1);
}

/// Range for text content only (excl. line break)
-(NSRange)textRange {
	// Range for the text only
	return NSMakeRange(self.position, self.string.length);
}

/// Converts a global (document-wide) range into local range inside the line
-(NSRange)globalRangeToLocal:(NSRange)range {
	// Insert a range and get a LOCAL range in the line
	NSRange lineRange = (NSRange){ self.position, self.string.length };
	NSRange intersection = NSIntersectionRange(range, lineRange);
	
	return (NSRange){ intersection.location - self.position, intersection.length };
}

/// Length of the string
-(NSInteger)length {
	return self.string.length;
}


#pragma mark - Element booleans

/// Returns TRUE for scene, section and synopsis elements
- (bool)isOutlineElement {
	if (self.type == heading
		|| self.type == section
		// || self.type == synopse
        ) return YES;
	else return NO;
}

/// Returns TRUE for any title page element
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

/// Checks if the line is completely non-printing
- (bool)isInvisible {
	if (self.omitted ||
		self.type == section ||
		self.type == synopse ||
		self.isTitlePage) return YES;
	else return NO;
}

/// Returns TRUE if the line type is forced
- (bool)forced {
	if (self.numberOfPrecedingFormattingCharacters > 0) return YES;
	else return NO;
}

#pragma mark Dialogue

/// Returns `true` for any dialogue element, including character cue
- (bool)isDialogue {
	if (self.type == character || self.type == parenthetical || self.type == dialogue || self.type == more) return YES;
	else return NO;
}

/// Returns `true` for dialogue block elements, excluding character cues
- (bool)isDialogueElement {
	// Is SUB-DIALOGUE element
	if (self.type == parenthetical || self.type == dialogue) return YES;
	else return NO;
}

/// Returns `true` for any dual dialogue element, including character cue
- (bool)isDualDialogue {
	if (self.type == dualDialogue || self.type == dualDialogueCharacter || self.type == dualDialogueParenthetical || self.type == dualDialogueMore) return YES;
	else return NO;
}

/// Returns `true` for dual dialogue block elements, excluding character cues
- (bool)isDualDialogueElement {
	if (self.type == dualDialogueParenthetical || self.type == dualDialogue || self.type == dualDialogueMore) return YES;
	else return NO;
}

/// Returns `true` for ANY character cue (single or dual)
- (bool)isAnyCharacter {
	if (self.type == character || self.type == dualDialogueCharacter) return YES;
	else return NO;
}

/// Returns `true` for ANY parenthetical line (single or dual)
- (bool)isAnyParenthetical {
	if (self.type == parenthetical || self.type == dualDialogueParenthetical) return YES;
	return NO;
}

/// Returns `true` for ANY dialogue line (single or dual)
- (bool)isAnyDialogue {
	if (self.type == dialogue || self.type == dualDialogue) return YES;
	else return NO;
}

#pragma mark Omissions & notes

/// Returns TRUE if the block is omitted
/// @warning This also includes lines that have 0 length, meaning the method will return YES for empty lines too.
- (bool)omitted {
	__block NSInteger invisibleLength = 0;
	
	[self.omittedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		invisibleLength += range.length;
	}];

	[self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		invisibleLength += range.length;
	}];
		
	if (invisibleLength >= self.string.length)  return true;
	else return false;
}

/**
 Returns true for a line which is a note. Should be used only in conjuction with .omited to check that, yeah, it's omited but it's a note:
 `if (line.omited && !line.note) { ... }`
 
 Checked using trimmed length, to make lines like `  [[note]]` be notes.
 */
- (bool)note {
	if (self.noteRanges.count >= self.trimmed.length && self.noteRanges.count && self.string.length >= 2) {
		return YES;
	} else {
		return NO;
	}
}

- (NSArray*)noteContents {
    return [self noteContentsWithRanges:false];
}

- (NSMutableDictionary<NSNumber*, NSString*>*)noteContentsAndRanges {
    return [self noteContentsWithRanges:true];
}

- (id)noteContentsWithRanges:(bool)withRanges {
    __block NSMutableDictionary<NSNumber*, NSString*>* rangesAndStrings = NSMutableDictionary.new;
    __block NSMutableArray* strings = NSMutableArray.new;
    
    [self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length == @"[[".length * 2) return;
        
        NSInteger inspectedRange = -1;
        NSRange contentRange = NSMakeRange(0, 0);
        
        for (NSInteger i = range.location; i<NSMaxRange(range); i++) {
            unichar c = [self.string characterAtIndex:i];
            
            if (c == '[') {
                inspectedRange += 1;
                
                if (inspectedRange == 1) {
                    // A beginning of a new note
                    contentRange.location = i + 1;
                }
            }
            
            else if (c == ']' && inspectedRange > 0) {
                contentRange.length = i - contentRange.location;
                inspectedRange = -1;
                
                NSString* string = [self.string substringWithRange:contentRange];
                if (string.length > 0) {
                    NSRange actualRange = NSMakeRange(contentRange.location - 2, contentRange.length + 4);
                    
                    rangesAndStrings[[NSNumber valueWithRange:actualRange]] = string;
                    [strings addObject:string];
                }
            }
        }
    }];
    
    if (self.noteInIndices.count) {
        NSRange range = NSMakeRange(0, self.noteInIndices.count);
        NSString* string = [self.string substringToIndex:self.noteInIndices.count - 2];
        
        rangesAndStrings[[NSNumber valueWithRange:range]] = string;
        [strings insertObject:string atIndex:0];
    }
    
    if (self.noteOutIndices.count) {
        NSRange range = NSMakeRange(self.noteOutIndices.firstIndex, self.noteOutIndices.count);
        NSString* string = [self.string substringFromIndex:self.noteOutIndices.firstIndex + 2];
        
        rangesAndStrings[[NSNumber valueWithRange:range]] = string;
        [strings addObject:string];
    }
    
    NSLog(@"strings: %@", strings);
    
    if (withRanges) return rangesAndStrings;
    else return strings;
}

#pragma mark Centered

/// Returns TRUE if the line is *actually* centered.
- (bool)centered {
	if (self.string.length < 2) return NO;

	if ([self.string characterAtIndex:0] == '>' &&
		[self.string characterAtIndex:self.string.length - 1] == '<') return YES;
	else return NO;
}


#pragma mark Formatting range booleans

/// Returns TRUE if the line is bolded at the given local index
-(bool)isBoldedAt:(NSInteger)index {
	__block bool inRange = NO;
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (NSLocationInRange(index, range)) inRange = YES;
	}];
	
	return inRange;
}

/// Returns TRUE if the line is italic at the given local index
-(bool)isItalicAt:(NSInteger)index {
	__block bool inRange = NO;
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (NSLocationInRange(index, range)) inRange = YES;
	}];
	
	return inRange;
}

/// Returns TRUE if the line is underlined at the given local index
-(bool)isUnderlinedAt:(NSInteger)index {
	__block bool inRange = NO;
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (NSLocationInRange(index, range)) inRange = YES;
	}];
	
	return inRange;
}

#pragma mark - Section depth

- (NSUInteger)sectionDepth {
    NSInteger depth = 0;

    for (int c = 0; c < self.string.length; c++) {
        if ([self.string characterAtIndex:c] == '#') depth++;
        else break;
    }
    
    _sectionDepth = depth;
    return _sectionDepth;
}

#pragma mark - Story beats

- (bool)hasBeat {
	if ([self.string.lowercaseString containsString:@"[[beat "] ||
		[self.string.lowercaseString containsString:@"[[beat:"])
		return YES;
	else
		return NO;
}
- (bool)hasBeatForStoryline:(NSString*)storyline {
	for (Storybeat *beat in self.beats) {
		if ([beat.storyline.lowercaseString isEqualToString:storyline.lowercaseString]) return YES;
	}
	return NO;
}
- (NSArray*)storylines {
	NSMutableArray *storylines = NSMutableArray.array;
	for (Storybeat *beat in self.beats) {
		[storylines addObject:beat.storyline];
	}
	return storylines;
}
- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline {
	for (Storybeat *beat in self.beats) {
		if ([beat.storyline.lowercaseString isEqualToString:storyline.lowercaseString]) return beat;
	}
	return nil;
}
 
- (NSRange)firstBeatRange {
	__block NSRange beatRange = NSMakeRange(NSNotFound, 0);
	
	[self.beatRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		// Find first range
		if (range.length > 0) {
			beatRange = range;
			*stop = YES;
		}
	}];
	
	return beatRange;
}


#pragma mark - Formatting & attribution

/// Parse and apply Fountain stylization inside the string contained by this line
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
				
		NSMutableString *open = [NSMutableString stringWithString:@""];
		NSMutableString *close = [NSMutableString stringWithString:@""];
		NSMutableString *openClose = [NSMutableString stringWithString:@""];
		
		NSString *styleString = attrs[@"Style"];
		NSArray *styles = [styleString componentsSeparatedByString:@","];
		
		if ([styles containsObject:BOLD_STYLE]) [openClose appendString:BOLD_PATTERN];
		if ([styles containsObject:ITALIC_STYLE]) [openClose appendString:ITALIC_PATTERN];
		if ([styles containsObject:UNDERLINE_STYLE]) [openClose appendString:UNDERLINE_PATTERN];
		
		if ([styles containsObject:STRIKEOUT_STYLE]) {
			[open appendString:STRIKEOUT_PATTERN];
			[close appendString:STRIKEOUT_CLOSE_PATTERN];
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

- (NSAttributedString*)attrString {
	if (_attrString == nil) {
		NSAttributedString *string = [self attributedStringForFDX];
		NSMutableAttributedString *result = NSMutableAttributedString.new;
		
		[self.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			[result appendAttributedString:[string attributedSubstringFromRange:range]];
		}];
		
		_attrString = result;
	}
	
	return _attrString;
}

/// N.B. Does NOT return a Cocoa-compatible attributed string. The attributes are used to create a string for FDX/HTML conversion.
- (NSAttributedString*)attributedStringForFDX {
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:(self.string) ? self.string : @""];
		
	// Make (forced) character names uppercase
	if (self.type == character || self.type == dualDialogueCharacter) {
		NSString *name = [self.string substringWithRange:self.characterNameRange].uppercaseString;
		if (name) [string replaceCharactersInRange:self.characterNameRange withString:name];
	}
    
	// Add font stylization
    
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > ITALIC_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:ITALIC_STYLE toString:string range:range];
		}
	}];

	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > BOLD_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:BOLD_STYLE toString:string range:range];
		}
	}];
	
	[self.boldItalicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > ITALIC_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addAttr:BOLDITALIC_STYLE toString:string range:range];
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
			if ([self rangeInStringRange:range]) [self addAttr:NOTE_STYLE toString:string range:range];
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
		
	[self.removalSuggestionRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if ([self rangeInStringRange:range]) [self addAttr:@"RemovalSuggestion" toString:string range:range];
	}];
	
	if (self.revisedRanges.count) {
		for (NSString *key in _revisedRanges.allKeys) {
			[_revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
				NSString *attrName = [NSString stringWithFormat:@"Revision:%@", key];
                if ([self rangeInStringRange:range]) {
                    [self addAttr:attrName toString:string range:range];
                    [string addAttribute:@"Revision" value:key range:range];
                }
			}];
		}
	}
	
	// Loop through tags and apply
	for (NSDictionary *tag in self.tags) {
		NSString* tagValue = tag[@"tag"];
		if (!tagValue) continue;
		
		NSRange range = [(NSValue*)tag[@"range"] rangeValue];
		[string addAttribute:@"BeatTag" value:tagValue range:range];
	}
	
	return string;
}

/// N.B. Does NOT return a Cocoa-compatible attributed string. The attributes are used to create a string for FDX/HTML conversion.
- (void)addAttr:(NSString*)name toString:(NSMutableAttributedString*)string range:(NSRange)range {
	// We are going out of range. Abort.
	if (range.location + range.length > string.length || range.length < 1 || range.location == NSNotFound) return;
	
	// Make a copy and enumerate attributes.
	// Add style to the corresponding range while retaining the existing attributes, if applicable.
	[string.copy enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSString *style = @"";
		if (attrs[@"Style"]) style = [NSString stringWithFormat:@"%@,%@", attrs[@"Style"], name];
		else style = name;
		
		[string addAttribute:@"Style" value:style range:range];
	}];
}

/**
 
 Splits a line at a given PRINTING index, meaning that the index was calculated from
 the actually printing string, with all formatting removed. That's why we'll first create an attributed string,
 and then format it back to Fountain.
 
 The whole practice is silly, because we could actually just put attributed strings into the paginated
 result — with revisions et al. I don't know why I'm just thinking about this now. Well, Beat is not
 the result of clever thinking and design, but trial and error. Fuck you, past me, for leaving all
 this to me.
 
 We could actually send attributed strings to the PAGINATOR and make it easier to calculate the ----
 it's 22.47 in the evening, I have to work tomorrow and I'm sitting alone in my kitchen. It's not
 a problem for present me.
 
 See you in the future.
 
 */
- (NSArray<Line*>*)splitAndFormatToFountainAt:(NSInteger)index {
	NSAttributedString *string = [self attributedStringForFDX];
	NSMutableAttributedString *attrStr = NSMutableAttributedString.new;
	
	[self.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > 0) [attrStr appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
	
	NSAttributedString *first  = [NSMutableAttributedString.alloc initWithString:@""];
	NSAttributedString *second = [NSMutableAttributedString.alloc initWithString:@""];
	
	// Safeguard index (this could happen to numerous reasons, extra spaces etc.)
	if (index > attrStr.length) index = attrStr.length;
	
	// Put strings into the split strings
	first = [attrStr attributedSubstringFromRange:(NSRange){ 0, index }];
	if (index <= attrStr.length) second = [attrStr attributedSubstringFromRange:(NSRange){ index, attrStr.length - index }];
	
	// Remove whitespace from the beginning if needed
	if (second.length > 0) {
		if ([second.string characterAtIndex:0] == ' ') {
			while (second.string.length > 0) {
				if ([second.string characterAtIndex:0] == ' ') {
					second = [second attributedSubstringFromRange:NSMakeRange(1, second.length - 1)];
				} else {
					break;
				}
			}
		}
	}
	
	Line *retain = [Line withString:[self attributedStringToFountain:first] type:self.type pageSplit:YES];
	Line *split = [Line withString:[self attributedStringToFountain:second] type:self.type pageSplit:YES];
	
	if (self.changed) {
		retain.changed = YES;
		split.changed = YES;
	}
	
	retain.uuid = self.uuid;
	retain.position = self.position;
	
	split.uuid = self.uuid;
	split.position = self.position + retain.string.length;
	
	// Now we'll have to go through some extra trouble to keep the revised ranges intact.
	if (self.revisedRanges.count) {
		NSRange firstRange = NSMakeRange(0, index);
		NSRange secondRange = NSMakeRange(index, split.string.length);
		split.revisedRanges = NSMutableDictionary.new;
		retain.revisedRanges = NSMutableDictionary.new;
		
		for (NSString *key in self.revisedRanges.allKeys) {
			retain.revisedRanges[key] = NSMutableIndexSet.indexSet;
			split.revisedRanges[key] = NSMutableIndexSet.indexSet;
			
			// Iterate through revised ranges, calculate intersections and add to their respective line items
			[self.revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
				NSRange firstIntersct = NSIntersectionRange(range, firstRange);
				NSRange secondIntersct = NSIntersectionRange(range, secondRange);
				
				if (firstIntersct.length > 0) {
					[retain.revisedRanges[key] addIndexesInRange:firstIntersct];
				}
				if (secondIntersct.length > 0) {
					// Substract offset from the split range to get it back to zero
					NSRange actualRange = NSMakeRange(secondIntersct.location - index, secondIntersct.length);
					[split.revisedRanges[key] addIndexesInRange:actualRange];
				}
			}];
		}
	}
	
	return @[ retain, split ];
}


#pragma mark - Formatting helpers

/*
// Idea
- (void)enumerateFormattingRanges:(void (^)(bool result))block {
}
*/

#pragma mark Formatting range lookup

/// Returns ranges between given strings. Used to return attributed string formatting to Fountain markup. The same method can be found in the parser, too.
- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength
{
	NSMutableIndexSet* indexSet = NSMutableIndexSet.new;
	
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

#pragma mark Formatting checking convenience

/// Returns TRUE when the line has no Fountain formatting (like **bold**)
-(bool)noFormatting {
	if (_boldRanges.count || _italicRanges.count || _strikeoutRanges.count || _underlinedRanges.count) return NO;
	else return YES;
}

#pragma mark - Identity

- (BOOL)matchesUUID:(NSUUID*)uuid {
	if ([self.uuid.UUIDString.lowercaseString isEqualToString:uuid.UUIDString.lowercaseString]) return true;
	else return false;
}
- (BOOL)matchesUUIDString:(NSString*)uuid {
    if ([self.uuid.UUIDString.lowercaseString isEqualToString:uuid]) return true;
    else return false;
}
- (NSString*)uuidString {
    return self.uuid.UUIDString;
}

#pragma mark - Ranges

/// Returns the line position in document
-(NSInteger)position {
	if (_representedLine == nil) return _position;
	else return _representedLine.position;
}

- (bool)rangeInStringRange:(NSRange)range {
	if (range.location + range.length <= self.string.length) return YES;
	else return NO;
}

/// Returns ranges with content ONLY (useful for reconstructing the string with no Fountain stylization)
- (NSIndexSet*)contentRanges
{
	NSMutableIndexSet *contentRanges = NSMutableIndexSet.indexSet;
	[contentRanges addIndexesInRange:NSMakeRange(0, self.string.length)];
	
	NSIndexSet *formattingRanges = self.formattingRanges;
	[contentRanges removeIndexes:formattingRanges];
	
	return contentRanges;
}

/// Returns content ranges, including notes
- (NSIndexSet*)contentRangesWithNotes {
	// Returns content ranges WITH notes included
	NSMutableIndexSet *contentRanges = [NSMutableIndexSet indexSet];
	[contentRanges addIndexesInRange:NSMakeRange(0, self.string.length)];
	
	NSIndexSet *formattingRanges = [self formattingRangesWithGlobalRange:NO includeNotes:NO];
	[contentRanges removeIndexes:formattingRanges];
	
	return contentRanges;
}

/// Maps formatting characters into an index set, INCLUDING notes, scene numbers etc. to convert it to another style of formatting
- (NSIndexSet*)formattingRanges {
	return [self formattingRangesWithGlobalRange:NO includeNotes:YES];
}

- (NSUInteger)numberOfPrecedingFormattingCharacters {
    if (self.string.length == 0) return 0;
    
    LineType type = self.type;
    unichar c = [self.string characterAtIndex:0];
    
    // Check if this is a shot
    if (self.string.length > 1) {
        unichar c2 = [self.string characterAtIndex:1];
        if (type == shot && c == '!' && c2 == '!') return 2;
    }
    
    // Other types
    if ((self.type == character && c == '@') ||
        (self.type == heading && c == '.') ||
        (self.type == action && c == '!') ||
        (self.type == lyrics && c == '~') ||
        (self.type == synopse && c == '=') ||
        (self.type == centered && c == '>') ||
        (self.type == transitionLine && c == '>')) {
        return 1;
    }
    // Section
    else if (self.type == section) {
        return self.sectionDepth;
    }
    
    return 0;
}

/// Maps formatting characters into an index set, INCLUDING notes, scene numbers etc.
/// You can use global range flag to return ranges relative to the *whole* document.
/// Notes are included in formatting ranges by default.
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes
{
	NSMutableIndexSet *indices = NSMutableIndexSet.new;
	NSInteger offset = 0;
	
	if (globalRange) offset = self.position;
	
	// Add any ranges that are used to force elements. First handle the elements which don't work without markup characters.
    NSInteger precedingCharacters = self.numberOfPrecedingFormattingCharacters;
    if (precedingCharacters > 0) {
        [indices addIndexesInRange:NSMakeRange(0 + offset, precedingCharacters)];
	}
	
	// Catch dual dialogue force symbol
	if (self.type == dualDialogueCharacter && self.string.length > 0 && [self.string characterAtIndex:self.string.length - 1] == '^') {
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
		[indices addIndexesInRange:(NSRange){ self.sceneNumberRange.location + offset, self.sceneNumberRange.length }];
		// Also remove the surrounding #'s
		[indices addIndex:self.sceneNumberRange.location + offset - 1];
		[indices addIndex:self.sceneNumberRange.location + self.sceneNumberRange.length + offset];
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
		[indices addIndexesInRange:NSMakeRange(range.location, STRIKEOUT_PATTERN.length +offset)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - STRIKEOUT_PATTERN.length +offset, STRIKEOUT_PATTERN.length)];
	}];
			
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
- (BOOL)hasExtension {
	/// Returns  `TRUE` if the character cue has an extension
	if (!self.isAnyCharacter) return false;
	
	NSInteger parenthesisLoc = [self.string rangeOfString:@"("].location;
	if (parenthesisLoc == NSNotFound) return false;
	else return true;
}


#pragma mark - Helper methods

- (NSString*)trimmed {
	return [self.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

/// Joins a line into this line. Copies all stylization and offsets the formatting ranges.
- (void)joinWithLine:(Line *)line
{
	if (!line) return;
	
	NSString *string = line.string;
	
	// Remove symbols for forcing elements
	if (line.numberOfPrecedingFormattingCharacters > 0 && string.length > 0) {
		string = [string substringFromIndex:line.numberOfPrecedingFormattingCharacters];
	}
	
	NSInteger offset = self.string.length + 1 - line.numberOfPrecedingFormattingCharacters;
	if (line.changed) self.changed = YES;
	
	// Join strings
	self.string = [self.string stringByAppendingString:[NSString stringWithFormat:@"\n%@", string]];
	
	// Offset and copy formatting ranges
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
	[line.escapeRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.escapeRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.noteRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	
	// Offset and copy revised ranges
	for (NSString* key in line.revisedRanges.allKeys) {
		if (!self.revisedRanges) self.revisedRanges = NSMutableDictionary.dictionary;
		if (!self.revisedRanges[key]) self.revisedRanges[key] = NSMutableIndexSet.indexSet;
		
		[line.revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			[self.revisedRanges[key] addIndexesInRange:(NSRange){ offset + range.location, range.length }];
		}];
	}
}

- (NSString*)characterName
{
	// This removes any extensions from character name, ie. (V.O.), (CONT'D) etc.
	// We'll allow the method to run for lines under 4 characters, even if not parsed as character cues
	// (update in 2022: why do we do this, past me?)
	if ((self.type != character && self.type != dualDialogueCharacter) && self.string.length > 3) return nil;
	
	// Strip formatting (such as symbols for forcing element types)
	NSString *name = self.stripFormatting;
	if (name.length == 0) return @"";
		
	// Find and remove suffix
	NSRange suffixRange = [name rangeOfString:@"("];
	if (suffixRange.location != NSNotFound && suffixRange.location > 0) name = [name substringWithRange:(NSRange){0, suffixRange.location}];
	
	// Remove dual dialogue character if needed
	if (self.type == dualDialogueCharacter && [name characterAtIndex:name.length-1] == '^') {
		name = [name substringToIndex:name.length - 1];
	}
	
	return [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSString*)titlePageKey {
    NSInteger i = [self.string rangeOfString:@":"].location;
    if (i == NSNotFound || i == 0) return @"";
    
    return [self.string substringToIndex:i].lowercaseString;
}
- (NSString*)titlePageValue {
    NSInteger i = [self.string rangeOfString:@":"].location;
    if (i == NSNotFound) return self.string;
    
    return [[self.string substringFromIndex:i+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

/// Returns `true` for lines which should effectively be considered as empty when parsing.
- (bool)effectivelyEmpty {
    if (self.type == empty || self.length == 0 || self.opensOrClosesOmission || self.type == section || self.type == synopse) return true;
    else return false;
}

- (bool)opensOrClosesOmission {
    NSString *trimmed = [self.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if ([trimmed isEqualToString:@"*/"] || [trimmed isEqualToString:@"/*"]) return true;
    return false;
}

#pragma mark - JSON serialization

-(NSDictionary*)forSerialization {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
		@"string": (self.string.length) ? self.string.copy : @"",
		@"sceneNumber": (self.sceneNumber) ? self.sceneNumber.copy : @"",
		@"position": @(self.position),
		@"range": @{ @"location": @(self.range.location), @"length": @(self.range.length) },
		@"sectionDepth": @(self.sectionDepth),
		@"textRange": @{ @"location": @(self.textRange.location), @"length": @(self.textRange.length) },
		@"typeAsString": self.typeAsString,
		@"omitted": @(self.omitted),
		@"marker": (self.marker.length) ? self.marker : @"",
		@"markerDescription": (self.markerDescription.length) ? self.markerDescription : @"",
		@"uuid": (self.uuid) ? self.uuid.UUIDString : @""
	}];
    
    if (self.type == synopse) {
        json[@"color"] = (self.color != nil) ? self.color : @"";
        json[@"stringForDisplay"] = self.stringForDisplay;
    }
    
    return json;
}

/// Returns a dictionary of ranges for plugins
-(NSDictionary*)ranges {
	return @{
		@"notes": [self indexSetAsArray:self.noteRanges],
		@"omitted": [self indexSetAsArray:self.omittedRanges],
		@"bold": [self indexSetAsArray:self.boldRanges],
		@"italic": [self indexSetAsArray:self.italicRanges],
		@"underlined": [self indexSetAsArray:self.underlinedRanges],
		@"revisions": @{
			@"blue": (self.revisedRanges[@"blue"]) ? [self indexSetAsArray:self.revisedRanges[@"blue"]] : @[],
			@"orange": (self.revisedRanges[@"orange"]) ? [self indexSetAsArray:self.revisedRanges[@"orange"]] : @[],
			@"purple": (self.revisedRanges[@"purple"]) ? [self indexSetAsArray:self.revisedRanges[@"purple"]] : @[],
			@"green": (self.revisedRanges[@"green"]) ? [self indexSetAsArray:self.revisedRanges[@"green"]] : @[]
		}
	};
}

-(NSArray*)indexSetAsArray:(NSIndexSet*)set {
	NSMutableArray *array = NSMutableArray.array;
	[set enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > 0) {
			[array addObject:@[ @(range.location), @(range.length) ]];
		}
	}];
	
	return array;
}

#pragma mark - Custom data

- (NSDictionary*)setCustomData:(NSString*)key value:(id)value {
	if (!_customDataDictionary) _customDataDictionary = NSMutableDictionary.new;
	
	if (!value)	return _customDataDictionary[key];
	else _customDataDictionary[key] = value;
	return nil;
}
- (id)getCustomData:(NSString*)key {
	if (!_customDataDictionary) _customDataDictionary = NSMutableDictionary.new;
	return _customDataDictionary[key];
}


#pragma mark - Debugging

-(NSString *)description
{
	return [NSString stringWithFormat:@"Line: %@  (%@ at %lu) %@", self.string, self.typeAsString, self.position, (self.nextElementIsDualDialogue) ? @"Next is dual" : @"" ];
}
@end
