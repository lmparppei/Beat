//
//  BeatReviewItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatColors.h"
#import "BeatRevisionItem.h"
#import "BeatRevisions.h"

#if !TARGET_OS_IOS
    #import <Cocoa/Cocoa.h>
#else
    #import <UIKit/UIKit.h>
#endif

@interface BeatRevisionItem ()
@property (nonatomic, weak) BeatColor *color;
@property (nonatomic, weak) BeatColor *backgroundColor;
@end

@implementation BeatRevisionItem

-(instancetype)initWithType:(RevisionType)type color:(NSString*)color {
	self = [super init];
	if (self) {
		_type = type;
		
		if (color.length) _colorName = color;
		else _colorName = BeatRevisions.defaultRevisionColor;
	}
	return self;
}

/// An experimental way to do this for now
-(instancetype)initWithType:(RevisionType)type generation:(BeatRevisionGeneration*)generation
{
    self = [super init];
    if (self) {
        _type = type;
        
        if (generation.color.length) _colorName = generation.color;
        else _colorName = BeatRevisions.defaultRevisionColor;
        
        _generation = generation;
    }
    return self;
}

+ (BeatRevisionItem*)type:(RevisionType)type color:(NSString*)color
{
	return [[BeatRevisionItem alloc] initWithType:type color:color];
}

+ (BeatRevisionItem*)type:(RevisionType)type
{
	return [[BeatRevisionItem alloc] initWithType:type color:@""];
}

/// Returns the key for saving
- (NSString*)key {
	if (self.type == RevisionRemovalSuggestion) return @"RemovalSuggestion";
	else if (self.type == RevisionAddition) return @"Addition";
	return @"";
}

- (BeatColor*)color {
	if (_color) return _color;
	if (self.colorName.length) _color = [BeatColors color:self.colorName];
	if (!_color) _color = [BeatColors color:BeatRevisions.defaultRevisionColor];
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

#pragma mark - Debug
- (NSString*)description { return [NSString stringWithFormat:@"Revision: %@ (%@)", self.key, self.colorName]; }

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
