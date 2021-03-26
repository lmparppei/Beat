//
//  BeatReviewItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatRevisionItem.h"
#import "BeatColors.h"
//#import "ThemeManager.h"
#import <Cocoa/Cocoa.h>

@interface BeatRevisionItem ()
//@property (weak) ThemeManager *themeManager;
@property (nonatomic, weak) NSColor *color;
@property (nonatomic, weak) NSColor *backgroundColor;
@end

@implementation BeatRevisionItem

-(instancetype)initWithType:(RevisionType)type text:(NSString*)text color:(NSString*)color {
	self = [super init];
	if (self) {
		//_themeManager = [ThemeManager sharedManager];
		_type = type;
		_text = text;
		
		if (color) _colorName = color;
		else _colorName = @"";
	}
	return self;
}

+ (NSArray<NSString*>*)availableColors {
	return @[@"blue", @"green", @"purple", @"orange"];
}
+ (BeatRevisionItem*)type:(RevisionType)type color:(NSString*)color
{
	return [[BeatRevisionItem alloc] initWithType:type text:@"" color:color];
}

+ (BeatRevisionItem*)type:(RevisionType)type
{
	return [[BeatRevisionItem alloc] initWithType:type text:@"" color:@""];
}

- (NSString*)key {
	if (self.type == RevisionRemoval) return @"Removal";
	else if (self.type == RevisionAddition) return @"Addition";
	else if (self.type == RevisionComment) return @"Comment";
	return @"";
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@", self.key];
}

- (NSColor*)color {
	if (_color) return _color;
	if (self.colorName.length) _color = [BeatColors color:self.colorName];
	if (!_color) _color = [BeatColors color:@"cyan"];
	return _color;
}

- (NSColor*)backgroundColor {
	if (_backgroundColor) return _backgroundColor;
	_backgroundColor = [[self color] colorWithAlphaComponent:0.2];
	return _backgroundColor;
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
 jonka sisältö muutta
 K A I K E N
 hän viettää
 15 seuraava vuottansa matkalla
 
 alas postin portaita
 auringossa...
 
 */
