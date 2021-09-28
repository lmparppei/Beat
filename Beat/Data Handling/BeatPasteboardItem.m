//
//  BeatPasteboardItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.9.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

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

@end
