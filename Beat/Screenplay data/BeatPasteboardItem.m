//
//  BeatPasteboardItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import "BeatPasteboardItem.h"
#define UTI @"com.kapitanFI.beat.copiedString"

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

+(NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
	return @[UTI];
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
	return @[UTI];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
	if(![type isEqualToString:UTI]) return nil;
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	BeatPasteboardItem *item = [[self.class allocWithZone:zone] init];
	item->_attrString = [_attrString copyWithZone:zone];
	return item;
}

/**
 If it's a long string with no line breaks, let's do some basic sanitization.
 // This won't be perfect, but a good starting point. The method adds e
 */
+ (NSString*)sanitizeString:(NSString*)string {
	// Convert line breaks and separate lines into an array
	string = [string stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
	
	if ([string rangeOfString:@"\n"].location == NSNotFound) return string;
	
	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	
	NSMutableString *result = NSMutableString.new;
	NSString* previousLine;
	
	LineType lastType = empty;
	
	for (NSString* line in lines) {
		if (lastType == heading && line.length > 0) [result appendString:@"\n"];
		
		if ([line.uppercaseString rangeOfString:@"INT."].location == 0 || [line.uppercaseString rangeOfString:@"EXT."].location == 0) {
			// Add extra line break for headings if needed
			if (previousLine.length > 0) [result appendFormat:@"\n%@", line.uppercaseString];
			lastType = heading;
		}
		else if (line.onlyUppercaseUntilParenthesis) {
			// Add extra line break for character cues
			if (previousLine.length > 0) [result appendFormat:@"\n%@", line];
			lastType = character;
		}
		else {
			[result appendFormat:@"%@", line];
			lastType = (line.length > 0) ? action : empty;
		}
	
		if (line != lines.lastObject) {
			[result appendString:@"\n"];
		} else {
			
		}
		
		previousLine = line;
	}
	
	return result;

}

@end
