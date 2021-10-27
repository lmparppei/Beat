//
//  Theme.m
//  Writer / Beat
//
//  Created by Hendrik Noeller on 04.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "Theme.h"

@implementation Theme

-(instancetype)init {
	self = [super init];
	
	// This list maps class properties to plist values.
	// Old, convoluted scheme which should be replaced at some point.
	_propertyToValue = @{
		@"backgroundColor": @"Background",
		@"marginColor": @"Margin",
		@"selectionColor": @"Selection",
		@"textColor": @"Text",
		@"commentColor": @"Comment",
		@"invisibleTextColor": @"InvisibleText",
		@"caretColor": @"Caret",
		@"pageNumberColor": @"PageNumber",
		@"synopsisTextColor": @"SynopsisText",
		@"sectionTextColor": @"SectionText",
		@"outlineBackground": @"OutlineBackground",
		@"outlineHighlight": @"OutlineHighlight",
		@"highlightColor": @"Highlight",
		@"genderWomanColor": @"Woman",
		@"genderManColor": @"Man",
		@"genderOtherColor": @"Other",
		@"genderUnspecifiedColor": @"Unspecified"
	};
	
	return self;
}

- (NSDictionary*)themeAsDictionary {
	return [self themeAsDictionaryWithName:self.name];
}
- (NSDictionary*)themeAsDictionaryWithName:(NSString*)name
{
	NSMutableDictionary *light = [NSMutableDictionary dictionary];
	NSMutableDictionary *dark = [NSMutableDictionary dictionary];
	
	for (NSString *property in _propertyToValue.allKeys) {
		if ([self valueForKey:property]) {
			NSArray *values = [(DynamicColor*)[self valueForKey:property] valuesAsRGB];
			
			NSString *key = _propertyToValue[property];
			light[key] = values[0];
			dark[key] = values[1];
		}
	}
	
	return @{ @"Name": name, @"Light": light, @"Dark": dark };
}

-(id)copy {
	Theme *theme = [[Theme alloc] init];
	
	for (NSString *key in _propertyToValue.allKeys) {
		DynamicColor *color = [(DynamicColor*)[self valueForKey:key] copy];
		[theme setValue:color forKey:key];
	}
	
	return theme;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	Theme *theme = [[self.class allocWithZone:zone] init];
	
	for (NSString *key in _propertyToValue.allKeys) {
		DynamicColor *color = [(DynamicColor*)[self valueForKey:key] copy];
		[theme setValue:color forKey:key];
	}
	
	return theme;
}


@end

