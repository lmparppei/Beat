//
//  TagDefinition.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "TagDefinition.h"
#import "BeatTagging.h"

@implementation TagDefinition

- (instancetype)initWithName:(NSString*)name type:(BeatTagType)type identifier:(NSString*)defId
{
	self = [super init];
	
	if (self) {
		_type = type;
		_name = name;
		_defId = defId;
	}
	
	return self;
}

- (bool)hasId:(NSString*)tagId {
	if ([self.defId isEqualToString:tagId]) return YES;
	else return NO;
}

- (NSString*)typeAsString {
	return [BeatTagging keyFor:self.type];
}

#pragma mark - Copy & encode

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	TagDefinition *newDef = [[self.class allocWithZone:zone] init];
	newDef->_defId = [self.defId copyWithZone:zone];
	newDef->_type = self.type;
	newDef->_name = [self.name copyWithZone:zone];
	
	return newDef;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
	[coder encodeObject:self.name forKey:@"name"];
	[coder encodeObject:self.defId forKey:@"defId"];
	[coder encodeInteger:self.type forKey:@"type"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	self = [super init];
	if (self) {
		_type = [coder decodeIntegerForKey:@"type"];
		_name = [coder decodeObjectForKey:@"name"];
		_defId = [coder decodeObjectForKey:@"defId"];
	}
	return self;
}

- (NSDictionary*)serialized {
	return @{
		@"type": [BeatTagging keyFor:self.type],
		@"name": (self.name) ? self.name : @"",
		@"id": (self.defId) ? self.defId : @""
	};
}

@end
