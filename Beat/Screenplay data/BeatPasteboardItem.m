//
//  BeatPasteboardItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>
#import "BeatPasteboardItem.h"
#define UTI @"com.kapitanFI.beat.pasteboardItem"


@implementation BeatPasteboardItem

+ (BOOL)supportsSecureCoding { return YES; }

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard
{
	if ([type isEqualToString:UTI]) return NSPasteboardReadingAsData;
	return NSPasteboardReadingAsString;
}

- (id)initWithAttrString:(NSAttributedString*)string
{
	// Because of security reasons, macOS 10.14+ requires us to conform to secure coding. This is a very crappy implementation of that.
	// We'll strip out any custom Beat attributes and then encode values to another dictionary.
	
	self = [super init];
	
	if (self) {
		NSMutableAttributedString* attrStr = string.mutableCopy;
		
		NSMutableDictionary<NSString*, NSMutableArray*>* ranges = NSMutableDictionary.new;
		
		[attrStr.copy enumerateAttributesInRange:attrStr.range options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull values, NSRange range, BOOL * _Nonnull stop) {
			for (NSAttributedStringKey key in BeatAttributes.shared.keys) {
				if (values[key] == nil) continue;
				
				id value = values[key];
				
				if (ranges[key] == nil) ranges[key] = NSMutableArray.new;
				
				NSString* className = [value className];
				[ranges[key] addObject:@[className, value, [NSValue valueWithRange:range]]];
				
				[attrStr removeAttribute:key range:range];
			}
		}];
		
		_attrString = attrStr.copy;
		_attrRanges = ranges;
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	
	if (self) {
		// Because of security reasons, macOS 10.14+ requires us to conform to secure coding. This is a very crappy implementation of that.
		// Custom Beat attributes have been stripped away, so we need to add them back ……… and hope that the decoding goes well.
		
		NSAttributedString *attrStr =
			[coder decodeObjectOfClass:NSAttributedString.class forKey:@"attrString"];

		/// Basic support for core classes and custom ones.
		/// To support anything to be copy-pasted via text attributes, you have to register it via `BeatAttributes` and implement `NSSecureCoding` for the class.
		NSMutableSet *containerClasses = [NSMutableSet setWithObjects:
			[NSDictionary class], [NSArray class], [NSString class], [NSData class], [NSValue class], nil];
		[containerClasses addObjectsFromArray:BeatAttributes.shared.classes.allObjects];
		
		NSDictionary<NSString *, NSArray *> *ranges =
			[coder decodeObjectOfClasses:containerClasses forKey:@"attrRanges"];

		/// This will be our final string
		NSMutableAttributedString *result = attrStr.mutableCopy;
		
		for (NSString *key in ranges) {
			for (NSArray *entry in ranges[key]) {
				NSString *className = entry[0];
				id value = entry[1];
				NSRange range = [entry[2] rangeValue];
				
				NSError *error = nil;
			
				if (value) {
					[result addAttribute:key value:value range:range];
				} else {
					NSLog(@"Failed to decode custom attribute %@: %@", className, error);
				}
			}
		}

		_attrString = result;
	}
	
	return self;
}


- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:_attrString forKey:@"attrString"];
	[coder encodeObject:_attrRanges forKey:@"attrRanges"];
}

-(id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type
{
	if ([type isEqualToString:UTI]) {
		NSError *error = nil;
		NSLog(@" --> %@", propertyList);
		id obj = [NSKeyedUnarchiver unarchivedObjectOfClass:BeatPasteboardItem.class
												   fromData:propertyList
													  error:&error];
		
		if (error) {
			NSLog(@"ERROR %@", error);
		}
		
		return obj;
	} else if ([type isEqualToString:NSPasteboardTypeString] || [type isEqualToString:@"public.utf8-plain-text"]) {
		// propertyList here is an NSString, not NSData
		NSString *string = [propertyList isKindOfClass:[NSString class]] ? propertyList : nil;
		if (string != nil) {
			NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:string];
			return [[BeatPasteboardItem alloc] initWithAttrString:attrStr];
		}
	}
	
	return nil;
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
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self
										 requiringSecureCoding:true
														 error:&error];
	if (!data) NSLog(@"Archive failed: %@", error);
	return data;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	BeatPasteboardItem *item = [[self.class allocWithZone:zone] init];
	item->_attrString = [_attrString copyWithZone:zone];
	
	return item;
}

/**
 If it's a long string with no line breaks, let's do some basic sanitization.
 This won't be perfect, but a good starting point. We'll detect scene headings and character cues.
 @note (This causes problems for some reason and __IS NOT USED__.
 */
+ (NSString*)sanitizeString:(NSString*)string
{
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
