//
//  BeatPasteboardItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import "BeatPasteboardItem.h"
#define UTI @"com.kapitanFI.beat.pasteboardItem"

@implementation BeatPasteboardItem


- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.attrString forKey:@"attrString"];
}

- (id)initWithAttrString:(NSAttributedString*)string {
	self = [super init];
	
	if (self) {
		_attrString = string;
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];

	if (self) {
		_attrString = [coder decodeObjectForKey:@"attrString"];
	}
	
	return self;
}

-(id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
	return [NSKeyedUnarchiver unarchiveObjectWithData:propertyList];
}

+(NSString*)pasteboardType
{
	return UTI;
}

+(NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
	return @[UTI, @"public.utf8-plain-text", NSPasteboardTypeString];
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
	return @[UTI];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
	if (![type isEqualToString:UTI]) return nil;
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	BeatPasteboardItem *item = [[self.class allocWithZone:zone] init];
	item->_attrString = [_attrString copyWithZone:zone];
	
	return item;
}

/**
 If it's a long string with no line breaks, let's do some basic sanitization.
 This won't be perfect, but a good starting point. We'll detect scene headings and character cues.
 */
+ (NSString*)sanitizeString:(NSString*)string {
	// Convert line breaks and separate lines into an array
	string = [string stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
	string = [string stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
	
	if ([string rangeOfString:@"\n"].location == NSNotFound) return string;
	
	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	
	NSMutableString *result = NSMutableString.new;
	NSString* previousLine;
	
	LineType lastType = empty;
	
	for (NSInteger i=0; i<lines.count; i++) {
		NSString* line = lines[i];
		NSString* lineToAdd = line.copy;
		
		if (lastType == heading && lineToAdd.length > 0) [result appendString:@"\n"];
		
		if ([lineToAdd.uppercaseString rangeOfString:@"INT."].location == 0 || [lineToAdd.uppercaseString rangeOfString:@"EXT."].location == 0) {
			// Add extra line break for headings if needed
			if (previousLine.length > 0) [result appendFormat:@"\n"];
			
			lineToAdd = line.uppercaseString;
			lastType = heading;
		}
		else if (line.onlyUppercaseUntilParenthesis) {
			// Add extra line break for character cues
			if (previousLine.length > 0) [result appendFormat:@"\n"];
			lastType = character;
		}
		else {
			lastType = (line.length > 0) ? action : empty;
		}
	
		[result appendString:lineToAdd];
		
		// Add a line break for everything else except the last line
		if (i < lines.count - 1) [result appendString:@"\n"];
		
		previousLine = lineToAdd;
	}
	
	return result;

}

@end
