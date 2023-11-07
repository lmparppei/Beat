//
//  SceneFiltering.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.12.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import "SceneFiltering.h"

@interface SceneFiltering()
@property (nonatomic) NSString* text;
@property (nonatomic) NSString* character;
@property (nonatomic) NSString* storyline;
@property (nonatomic) NSMutableSet* colors;
@property (weak) NSMutableArray* lines; // This is a reference to the parser
@property (nonatomic) NSMutableArray* scenes; // This is a real array of scenes
@property (nonatomic) NSMutableArray* filteredScenes;
@end

@implementation SceneFiltering

- (SceneFiltering*)init
{
    self = [super init];
    if (self) {
		_text = @"";
		_storyline = @"";
		
		_colors = NSMutableSet.new;
		_scenes = NSMutableArray.new;
		_lines = NSMutableArray.new;
    }
    return self;
}

- (void)reset {
	_text = @"";
	_storybeat = @"";
	[_scenes removeAllObjects];
	[_colors removeAllObjects];
}

- (bool)activeFilters {
	return (self.numberOfFilters > 0);
}

- (void)byText:(NSString*)string {
	_text = string;
}

- (void)byStoryline:(NSString*)storyline {
	_storyline = storyline;
}

- (void)byColor:(NSString*)color {
	[self addColorFilter:color];
}

- (void)byScenes:(NSMutableArray *)scenes {
	_scenes = [NSMutableArray arrayWithArray:scenes];
}

- (void)byCharacter:(NSString*)character {
	_character = [NSString stringWithString:character];
}

- (void)addColorFilter:(NSString*)color
{
	[_colors addObject:color];
}

- (void)removeColorFilter:(NSString*)color {
	[_colors removeObject:color];
}

- (void)resetScenes {
	_character = @"";
}

- (NSInteger)numberOfFilters
{
	NSInteger filters = 0;
	if (self.text.length) filters++;
	if (self.storyline.length) filters++;
	if (self.character.length) filters++;
	if (self.colors.count) filters++;
	
	return filters;
}

- (bool)match:(OutlineScene*)scene
{
	NSInteger matches = 0;
	
	if (self.text.length && [scene.string containsString:self.text]) {
		matches++;
	}
	if (self.character.length && [scene.characters containsObject:self.character]) {
		matches++;
	}
	if (self.colors.count > 0 && [self.colors containsObject:scene.color.lowercaseString]) {
		matches++;
	}
	if (self.storyline.count > 0 && [scene.storylines containsObject:self.storyline]) {
		matches++;
	}
	
	if (matches == self.numberOfFilters) return true;
	else return false;
}


/*
 
 jag vill spola tillbaka
 Super 8
 vi måste få ett lyckligare slut
 gör Super 8 -moll
 till Technicolor Gold
 
 */

@end
