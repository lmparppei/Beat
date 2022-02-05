//
//  BeatColorMenuItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatColorMenuItem.h"

@implementation BeatColorMenuItem

-(id)copyWithZone:(NSZone *)zone {
	BeatColorMenuItem * copy = [super copyWithZone:zone];
	copy.colorKey = self.colorKey;
	return copy;
}

-(id)copy {
	BeatColorMenuItem *copy = [super copy];
	copy.colorKey = self.colorKey;
	return copy;
}

@end
