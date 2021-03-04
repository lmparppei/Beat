//
//  TagDefinition.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
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

@end
