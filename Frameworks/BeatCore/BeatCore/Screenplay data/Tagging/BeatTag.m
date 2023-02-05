//
//  BeatTag.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 BeatTag is added as an ATTRIBUTE for the string.
 It is rendered according to its ITEM.
 
 */

#import "BeatTag.h"

@implementation BeatTag

+ (BeatTag*)withDefinition:(TagDefinition *)def {
	return [[BeatTag alloc] initWithDefinition:def];
}

- (instancetype)initWithDefinition:(TagDefinition*)def {
	self = [super init];
	
	if (self) {
		self.type = def.type;
		self.defId = def.defId;
		self.tagId = [BeatTagging newId];
		self.definition = def;
	}
	
	return self;
}

- (NSString*)key {
	return [BeatTagging keyFor:self.type];
}
- (NSString*)typeAsString {
	return [BeatTagging keyFor:self.type];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	BeatTag *tag = [[self.class allocWithZone:zone] init];
	tag->_type = self.type;
	tag->_defId = [self.defId copyWithZone:zone];
	tag->_tagId = [self.tagId copyWithZone:zone];
	tag->_definition = [self.definition copyWithZone:zone];
	
	return tag;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
	[coder encodeInteger:self.type forKey:@"type"];
	[coder encodeObject:self.defId forKey:@"defId"];
	[coder encodeObject:self.tagId forKey:@"tagId"];
	[coder encodeObject:self.definition forKey:@"definition"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	self = [super init];
	if (self) {
		_type = [coder decodeIntegerForKey:@"type"];
		_defId = [coder decodeObjectForKey:@"defId"];
		_tagId = [coder decodeObjectForKey:@"tagId"];
		_definition = [coder decodeObjectForKey:@"definition"];
	}
	
	return self;
}

@end
