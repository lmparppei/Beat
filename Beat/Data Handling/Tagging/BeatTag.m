//
//  BeatTag.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

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

@end
