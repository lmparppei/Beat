//
//  BeatReviewItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatRevisionItem.h"
#import "BeatColors.h"

#if !TARGET_OS_IOS
    #import <Cocoa/Cocoa.h>
#else
    #import <UIKit/UIKit.h>
#endif

@interface BeatRevisionItem ()
//@property (weak) ThemeManager *themeManager;
@property (nonatomic, weak) BeatColor *color;
@property (nonatomic, weak) BeatColor *backgroundColor;
@end

@implementation BeatRevisionItem

-(instancetype)initWithType:(RevisionType)type color:(NSString*)color {
	self = [super init];
	if (self) {
		//_themeManager = [ThemeManager sharedManager];
		_type = type;
		
		if (color.length) _colorName = color;
		else _colorName = BeatRevisionItem.availableColors.firstObject;
	}
	return self;
}

+ (NSArray<NSString*>*)availableColors {
	return @[@"blue", @"green", @"purple", @"orange"];
}
+ (BeatRevisionItem*)type:(RevisionType)type color:(NSString*)color
{
	return [[BeatRevisionItem alloc] initWithType:type color:color];
}

+ (BeatRevisionItem*)type:(RevisionType)type
{
	return [[BeatRevisionItem alloc] initWithType:type color:@""];
}

- (NSString*)key {
	if (self.type == RevisionRemovalSuggestion) return @"RemovalSuggestion";
	else if (self.type == RevisionAddition) return @"Addition";
	return @"";
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@", self.key];
}

- (BeatColor*)color {
	if (_color) return _color;
	if (self.colorName.length) _color = [BeatColors color:self.colorName];
	if (!_color) _color = [BeatColors color:[BeatRevisionItem availableColors].firstObject];
	return _color;
}

- (BeatColor*)backgroundColor {
	if (_backgroundColor) return _backgroundColor;
	_backgroundColor = [self.color colorWithAlphaComponent:0.09];
	return _backgroundColor;
}

#pragma mark - Encoding and Copying

-(void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeInteger:self.type forKey:@"type"];
	[coder encodeObject:self.colorName forKey:@"colorName"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	self = [super init];

	if (self) {
		_type = [coder decodeIntForKey:@"type"];
		_colorName = [coder decodeObjectForKey:@"colorName"];
	}
	
	return self;

}


-(id)copyWithZone:(NSZone *)zone {
	BeatRevisionItem *newItem = [[[self class] alloc] initWithType:(RevisionType)self.type color:(NSString*)[self.colorName copyWithZone:zone]];
	return newItem;
}



@end
/*
 
 16.3.
 16. maaliskuuta
 istun paperipinkan päällä ja katson kadulle:
 paljon kevättä
 istun paperipinkan päällä ja silloin
 aivan kuin filmiltä nään hänen silmillään...
 
 16.3
 täytyy mennä ulos postiin
 hän on sileänaama, poikanen vielä
 lunastaa tulleen paketin
 jonka sisältö muuttaa
 K A I K E N
 hän viettää
 15 seuraava vuottansa matkalla...
 
 alas
 postin
 portaita
 auringossa
 
 */
