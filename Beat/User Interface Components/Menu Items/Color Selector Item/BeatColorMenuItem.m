//
//  BeatColorMenuItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatColorMenuItem.h"
#import <BeatCore/BeatLocalization.h>
#import <BeatCore/BeatColors.h>

@implementation BeatColorMenuItem

-(id)copyWithZone:(NSZone *)zone
{
	BeatColorMenuItem * copy = [super copyWithZone:zone];
	copy.colorKey = self.colorKey;
	return copy;
}

-(id)copy
{
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

-(instancetype)initWithCustomColor:(NSString*)colorName
{
	self = [super init];
	
	self.colorKey = colorName;
	self.custom = true;
	
	self.title = NSLocalizedString(@"color.custom", nil);
	
	if (@available(macOS 11.0, *)) {
		self.image = [NSImage imageWithSystemSymbolName:@"paintpalette.fill" accessibilityDescription:@""];
		NSColor* customColor = [BeatColors color:colorName];
		if (customColor != nil) {
			self.attributedTitle = [NSAttributedString.alloc initWithString:self.title attributes:@{
				NSForegroundColorAttributeName: customColor
			}];
		}
	} else {
		self.image = [NSImage imageNamed:@"paintpalette.fill"];
	}
	
	return self;
}

- (void)updateCustomColor:(NSString*)colorName
{
	self.colorKey = colorName;
	
	NSColor* customColor = [BeatColors color:colorName];
	if (customColor != nil) {
		self.attributedTitle = [NSAttributedString.alloc initWithString:self.title attributes:@{
			NSForegroundColorAttributeName: customColor
		}];
	}
}

- (void)awakeFromNib {
	// Set text and image based on color name
}

@end
