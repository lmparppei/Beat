//
//  FDXInterface.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 07.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//
//  Greatly copied from: https://github.com/vilcans/screenplain/blob/master/screenplain/export/fdx.py

/*
 
 Being modified for Beat to support FDX tagging.
 
 We should maybe connect the actual parser parsing the document, instead of parsing the contents again.
 This way the tagging data could be read straight from the baked line elements instead of playing around
 with strange offsetting etc.
 
 */


#import <BeatParsing/BeatParsing.h>
#import "FDXInterface.h"

@implementation FDXInterface

+ (NSString*)fdxFromString:(NSString*)string tags:(NSArray*)tags
{
	ContinuousFountainParser* parser = [[ContinuousFountainParser alloc] initWithString:string];
	if ([parser.lines count] == 0) {
		return @"";
	}
	NSMutableString* result = [@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
							   @"<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"1\">\n"
							   @"\n"
							   @"  <Content>\n" mutableCopy];
	
	bool inDualDialogue = NO;
	for (int i = 0; i < [parser.lines count]; i++) {
		inDualDialogue = [self appendLineAtIndex:i fromLines:parser.lines toString:result inDualDialogue:inDualDialogue tags:tags];
	}
	
	[result appendString:@"  </Content>\n"];
	
	Line* firstLine = parser.lines[0];
	if (firstLine.type == titlePageTitle ||
		firstLine.type == titlePageAuthor ||
		firstLine.type == titlePageCredit ||
		firstLine.type == titlePageSource ||
		firstLine.type == titlePageDraftDate ||
		firstLine.type == titlePageContact) {
		[self appendTitlePageFromLines:parser.lines toString:result];
	}
	
	[result appendString:@"</FinalDraft>\n"];
	
	return result;
}
+ (NSString*)fdxFromString:(NSString*)string
{
	return [self fdxFromString:string tags:nil];
}

+ (bool)appendLineAtIndex:(NSUInteger)index fromLines:(NSArray*)lines toString:(NSMutableString*)result inDualDialogue:(bool)inDualDialogue tags:(NSArray*)tags
{
    Line* line = lines[index];
    NSString* paragraphType = [self typeAsFDXString:line.type];
    if (paragraphType.length == 0) {
        //Ignore if no type is known
        return inDualDialogue;
    }
    
    
    
    //If no double dialogue is currently in action, and a dialogue should be printed, check if it is followed by double dialogue so both can be wrapped in a double dialogue
    if (!inDualDialogue && line.type == character) {
        for (NSUInteger i = index + 1; i < [lines count]; i++) {
            Line* futureLine = lines[i];
            if (futureLine.type == parenthetical ||
                futureLine.type == dialogue ||
                futureLine.type == empty) {
                continue;
            }
            if (futureLine.type == dualDialogueCharacter) {
                inDualDialogue = YES;
            }
            break;
        }
        if (inDualDialogue) {
            [result appendString:@"    <Paragraph>\n"];
            [result appendString:@"      <DualDialogue>\n"];
        }
    }
    
    
    
    //Append Open Paragraph Tag
    if (line.type == centered) {
        [result appendFormat:@"    <Paragraph Alignment=\"Center\" Type=\"%@\">\n", paragraphType];
    } else {
		// Add scene number if it's a heading
		if (line.type == heading) {
			// Strip possible scene number
			if (line.sceneNumber) line.string = [line.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", line.sceneNumber] withString:@""];
			[result appendFormat:@"    <Paragraph Number=\"%@\" Type=\"%@\">\n", line.sceneNumber, paragraphType];
		} else {
			[result appendFormat:@"    <Paragraph Type=\"%@\">\n", paragraphType];
		}
    }
    
    //Append content
    [self appendLineContents:line toString:result tags:tags];
    
    //Apend close paragraph
    [result appendString:@"    </Paragraph>\n"];
    
    //If a double dialogue is currently in action, check wether it needs to be closed after this
    if (inDualDialogue) {
        if (index < [lines count] - 1) {
            //If the following line doesn't have anything to do with dialogue, end double dialogue
            Line* nextLine = lines[index+1];
            if (nextLine.type != empty &&
                nextLine.type != character &&
                nextLine.type != parenthetical &&
                nextLine.type != dialogue &&
                nextLine.type != dualDialogueCharacter &&
                nextLine.type != dualDialogueParenthetical &
                nextLine.type != dualDialogue) {
                inDualDialogue = NO;
                [result appendString:@"      </DualDialogue>\n"];
                [result appendString:@"    </Paragraph>\n"];
            }
        } else {
            //If the line is the last line, it's also time to close the dual dialogue tag
            inDualDialogue = NO;
            [result appendString:@"      </DualDialogue>\n"];
            [result appendString:@"    </Paragraph>\n"];
        }
    }
    
    return inDualDialogue;
}

#define BOLD_PATTERN_LENGTH 2
#define ITALIC_UNDERLINE_PATTERN_LENGTH 1

+ (void)appendLineContents:(Line*)line toString:(NSMutableString*)result tags:(NSArray*)tags
{
    //Remove all formatting symbols from the line and the ranges
    NSMutableString* string = [line.string mutableCopy];
    
    NSMutableIndexSet* boldRanges = [line.boldRanges mutableCopy];
    NSMutableIndexSet* italicRanges = [line.italicRanges mutableCopy];
    NSMutableIndexSet* underlinedRanges = [line.underlinedRanges mutableCopy];
    int __block removedChars = 0;
    
    NSMutableIndexSet* currentRanges = [boldRanges mutableCopy];
    
    [currentRanges enumerateRangesWithOptions:0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        NSRange beginSymbolRange = NSMakeRange(range.location - removedChars, BOLD_PATTERN_LENGTH);
        NSRange endSymbolRange = NSMakeRange(range.location + range.length - 2*BOLD_PATTERN_LENGTH - removedChars, BOLD_PATTERN_LENGTH); //after deleting begin symboL!
        
        [string replaceCharactersInRange:beginSymbolRange withString:@""];
        [string replaceCharactersInRange:endSymbolRange withString:@""];
        
        [boldRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                             by:-beginSymbolRange.length];
        [boldRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                             by:-endSymbolRange.length];
        [italicRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                               by:-beginSymbolRange.length];
        [italicRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                               by:-endSymbolRange.length];
        [underlinedRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                                   by:-beginSymbolRange.length];
        [underlinedRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                                   by:-endSymbolRange.length];
        
        removedChars += BOLD_PATTERN_LENGTH*2;
    }];
    removedChars = 0;
    
    currentRanges = [italicRanges mutableCopy];
    
    [currentRanges enumerateRangesWithOptions:0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        NSRange beginSymbolRange = NSMakeRange(range.location - removedChars, ITALIC_UNDERLINE_PATTERN_LENGTH);
        NSRange endSymbolRange = NSMakeRange(range.location + range.length - 2*ITALIC_UNDERLINE_PATTERN_LENGTH - removedChars, ITALIC_UNDERLINE_PATTERN_LENGTH);
        
        [string replaceCharactersInRange:beginSymbolRange withString:@""];
        [string replaceCharactersInRange:endSymbolRange withString:@""];
        
        [boldRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                             by:-beginSymbolRange.length];
        [boldRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                             by:-endSymbolRange.length];
        [italicRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                               by:-beginSymbolRange.length];
        [italicRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                               by:-endSymbolRange.length];
        [underlinedRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                                   by:-beginSymbolRange.length];
        [underlinedRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                                   by:-endSymbolRange.length];
        
        removedChars += ITALIC_UNDERLINE_PATTERN_LENGTH*2;
    }];
    removedChars = 0;
    
    currentRanges = [underlinedRanges mutableCopy];
    
    [currentRanges enumerateRangesWithOptions:0 usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        NSRange beginSymbolRange = NSMakeRange(range.location - removedChars, ITALIC_UNDERLINE_PATTERN_LENGTH);
        NSRange endSymbolRange = NSMakeRange(range.location + range.length - 2*ITALIC_UNDERLINE_PATTERN_LENGTH - removedChars, ITALIC_UNDERLINE_PATTERN_LENGTH);
        
        [string replaceCharactersInRange:beginSymbolRange withString:@""];
        [string replaceCharactersInRange:endSymbolRange withString:@""];
        
        [boldRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                             by:-beginSymbolRange.length];
        [boldRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                             by:-endSymbolRange.length];
        [italicRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                               by:-beginSymbolRange.length];
        [italicRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                               by:-endSymbolRange.length];
        [underlinedRanges shiftIndexesStartingAtIndex:beginSymbolRange.location+beginSymbolRange.length
                                                   by:-beginSymbolRange.length];
        [underlinedRanges shiftIndexesStartingAtIndex:endSymbolRange.location+endSymbolRange.length
                                                   by:-endSymbolRange.length];
        
        removedChars += ITALIC_UNDERLINE_PATTERN_LENGTH*2;

    }];
    
    //Remove the > < from centered text
    if (line.type == centered) {
        [string replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
        [string replaceCharactersInRange:NSMakeRange(string.length - 1, 1) withString:@""];
        [boldRanges shiftIndexesStartingAtIndex:1 by:-1];
        [italicRanges shiftIndexesStartingAtIndex:1 by:-1];
        [underlinedRanges shiftIndexesStartingAtIndex:1 by:-1];
    }
    
    //Remove the " ^" from double dialogue character
    if (line.type == dualDialogueCharacter) {
        [string replaceCharactersInRange:NSMakeRange(string.length - 1, 1) withString:@""];
        while ([string characterAtIndex:string.length - 1] == ' ') {
            [string replaceCharactersInRange:NSMakeRange(string.length - 1, 1) withString:@""];
        }
    }
    
    NSUInteger length = string.length;
    NSUInteger appendFromIndex = line.numberOfPrecedingFormattingCharacters;
    
    bool lastBold = [boldRanges containsIndex:appendFromIndex];
    bool lastItalic = [italicRanges containsIndex:appendFromIndex];
    bool lastUnderlined = [underlinedRanges containsIndex:appendFromIndex];
    
    if (length == 0) {
        return;
    } else if (length == 1) {
        [self appendText:string  bold:lastBold italic:lastItalic underlined:lastUnderlined toString:result];
        return;
    }
    
    for (NSUInteger i = 1+appendFromIndex; i < length; i++) {
        bool bold = [boldRanges containsIndex:i];
        bool italic = [italicRanges containsIndex:i];
        bool underlined = [underlinedRanges containsIndex:i];
        if (bold != lastBold || italic != lastItalic || underlined != lastUnderlined) {
            NSRange appendRange = NSMakeRange(appendFromIndex, i-appendFromIndex);
            
            if (length > 0 && appendRange.location + appendRange.length <= length) {
                [self appendText:[string substringWithRange:appendRange] bold:lastBold italic:lastItalic underlined:lastUnderlined toString:result];
            }
            
            appendFromIndex = i;
            lastBold = bold;
            lastItalic = italic;
            lastUnderlined = underlined;
        }
    }
    //append last range
    NSRange appendRange = NSMakeRange(appendFromIndex, length-appendFromIndex);
    [self appendText:[string substringWithRange:appendRange] bold:lastBold italic:lastItalic underlined:lastUnderlined toString:result];
    
}

#define BOLD_STYLE @"Bold"
#define ITALIC_STYLE @"Italic"
#define UNDERLINE_STYLE @"Underline"

+ (void)appendText:(NSString*)string bold:(bool)bold italic:(bool)italic underlined:(bool)underlined toString:(NSMutableString*)result //In python: _write_text_element
{
    NSMutableString* styleString = [[NSMutableString alloc] init];
    if (bold) {
        [styleString appendString:BOLD_STYLE];
    }
    if (italic) {
        if (bold) {
            [styleString appendString:@"+"];
        }
        [styleString appendString:ITALIC_STYLE];
    }
    if (underlined) {
        if (bold || italic) {
            [styleString appendString:@"+"];
        }
        [styleString appendString:UNDERLINE_STYLE];
    }

    NSMutableString* escapedString = [string mutableCopy];
    [self escapeString:escapedString];
    
    if (!bold && !italic && !underlined) {
        [result appendFormat:@"      <Text>%@</Text>\n", escapedString];
    } else {
        [result appendFormat:@"      <Text Style=\"%@\">%@</Text>\n", styleString, escapedString];
    }
}

+ (void)escapeString:(NSMutableString*)string
{
    [string replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"'"  withString:@"&#x27;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
}

+ (NSString*)typeAsFDXString:(LineType)type
{
    switch (type) {
        case empty:
            return @"";
        case section:
            return @"";
        case synopse:
            return @"";
        case titlePageTitle:
            return @"";
        case titlePageAuthor:
            return @"";
        case titlePageCredit:
            return @"";
        case titlePageSource:
            return @"";
        case titlePageContact:
            return @"";
        case titlePageDraftDate:
            return @"";
        case titlePageUnknown:
            return @"";
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
            return @"";
        case centered:
            return @"Action";
		case more:
			return @"More";
		case dualDialogueMore:
			return @"More";
		case shot:
			return @"Action";
		case typeCount:
			return @"";
    }
}

#define LINES_PER_PAGE 46
#define LINES_BEFORE_CENTER 18
#define LINES_BEFORE_CREDIT 2
#define LINES_BEFORE_AUTHOR 1
#define LINES_BEFORE_SOURCE 2

+ (void)appendTitlePageFromLines:(NSArray*)lines toString:(NSMutableString*)result
{
    NSMutableString* title = [[self stringByRemovingKey:@"title:" fromString:[self firstStringForLineType:titlePageTitle fromLines:lines]] mutableCopy];
    NSMutableString* credit = [[self stringByRemovingKey:@"credit:" fromString:[self firstStringForLineType:titlePageCredit fromLines:lines]] mutableCopy];
    NSMutableString* author = [[self stringByRemovingKey:@"author:" fromString:[self firstStringForLineType:titlePageAuthor fromLines:lines]] mutableCopy];
    NSMutableString* source = [[self stringByRemovingKey:@"source:" fromString:[self firstStringForLineType:titlePageSource fromLines:lines]] mutableCopy];
    NSMutableString* draftDate = [[self stringByRemovingKey:@"draft date:" fromString:[self firstStringForLineType:titlePageDraftDate fromLines:lines]] mutableCopy];
    NSMutableString* contact = [[self stringByRemovingKey:@"contact:" fromString:[self firstStringForLineType:titlePageContact fromLines:lines]] mutableCopy];
    
    [self escapeString:title];
    [self escapeString:credit];
    [self escapeString:author];
    [self escapeString:source];
    [self escapeString:draftDate];
    [self escapeString:contact];
    
    [result appendString:@"  <TitlePage>\n"];
    [result appendString:@"    <Content>\n"];
    
    NSUInteger lineCount = 0;
    
    for (int i = 0; i < LINES_BEFORE_CENTER; i++) {
        [self appendTitlePageLineWithString:@"" center:NO toString:result];
        lineCount++;
    }
    
    if (title) {
        [self appendTitlePageLineWithString:title center:YES toString:result];
        lineCount++;
    }
    
    if (credit) {
        for (int i = 0; i < LINES_BEFORE_CREDIT; i++) {
            [self appendTitlePageLineWithString:@"" center:YES toString:result];
            lineCount++;
        }
        [self appendTitlePageLineWithString:credit center:YES toString:result];
    }
    
    if (author) {
        for (int i = 0; i < LINES_BEFORE_AUTHOR; i++) {
            [self appendTitlePageLineWithString:@"" center:YES toString:result];
            lineCount++;
        }
        [self appendTitlePageLineWithString:author center:YES toString:result];
    }
    
    if (source) {
        for (int i = 0; i < LINES_BEFORE_SOURCE; i++) {
            [self appendTitlePageLineWithString:@"" center:YES toString:result];
            lineCount++;
        }
        [self appendTitlePageLineWithString:source center:YES toString:result];
    }
    
    while (lineCount < LINES_PER_PAGE - 2) {
        [self appendTitlePageLineWithString:@"" center:NO toString:result];
        lineCount++;
    }
    
    if (draftDate) {
        [self appendTitlePageLineWithString:draftDate center:NO toString:result];
    }
    
    if (contact) {
        [self appendTitlePageLineWithString:contact center:NO toString:result];
    }
    
    [result appendString:@"    </Content>\n"];
    [result appendString:@"  </TitlePage>\n"];
}

+ (void)appendTitlePageLineWithString:(NSString*)string center:(bool)center toString:(NSMutableString*)result
{
    if (center) {
        [result appendString:@"      <Paragraph Alignment=\"Center\">\n"];
    } else {
        [result appendString:@"      <Paragraph>\n"];
    }
    
    [result appendFormat:@"        <Text>%@</Text>\n", string];
    
    [result appendString:@"      </Paragraph>\n"];
}

+ (NSString*)firstStringForLineType:(LineType)type fromLines:(NSArray*)lines
{
    for (Line* line in lines) {
        if (line.type == type) {
            return line.string;
        }
    }
    return nil;
}

+ (NSString*)stringByRemovingKey:(NSString*)key fromString:(NSString*)string
{
    if (string) {
        if ([[[string substringToIndex:key.length] lowercaseString] isEqualToString:key]) {
            string = [string stringByReplacingCharactersInRange:NSMakeRange(0, key.length) withString:@""];
        }
        while (string.length > 0 && [string characterAtIndex:0] == ' ') {
            string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
        }
    }
    return string;
}

@end
