//
//  BeatPasteboardItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.9.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatPasteboardItem.h"

@implementation BeatPasteboardItem
 
- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.attrString forKey:@"attrString"];
	[coder encodeObject:self.attrString.string forKey:@"string"];
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
	// I am using the bundleID as a type
	return @[[[NSBundle mainBundle] bundleIdentifier]];
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
	// I am using the bundleID as a type
	return @[[[NSBundle mainBundle] bundleIdentifier]];
}


- (id)pasteboardPropertyListForType:(NSString *)type {
	// I am using the bundleID as a type
	if(![type isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]) {
		return nil;
	}
	
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	BeatPasteboardItem *item = [[self class] allocWithZone:zone];
	item->_attrString = [_attrString copyWithZone:zone];
	return item;
}

@end
