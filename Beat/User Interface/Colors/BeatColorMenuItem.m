//
//  BeatColorMenuItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatColorMenuItem.h"
#import <BeatCore/BeatLocalization.h>

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

-(instancetype)initWithColor:(NSString*)colorKey
{
	self = [super init];

	self.colorKey = colorKey;
	
	NSString* colorString = [NSString stringWithFormat:@"color.%@", self.colorKey];
	self.image = [NSImage imageNamed:colorString];
	self.title = NSLocalizedString(colorString, nil);
	
	return self;
}

- (void)awakeFromNib {
	// Set text and image based on color name
}

@end
