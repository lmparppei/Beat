//
//  SceneFiltering.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.12.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

/*
 
 This is the filter used to match scenes in the outline to a set of filters. The code is still WIP and the structure should allow adding new filters more easily, but this is what we got for now.
 
 First set the correct pointers:
 [filter setScript:(NSMutableArray*)lines scenes:(NSMutableArray*)scenes];
 
 Then set the filters:
 [filter byText:@"text to search"];
 [filter byCharacter:@"CHARACTER NAME"];
 [filter byScenes:(NSMutableArray*)prefilteredScenes];
 
 [filter addColor:@"color name"];
 [filter removeColor:@"color name"];
 
 [filter reset];
 
 Test a scene against the filters:
 if ([filter match:scene]) ...
 
 Test if any filters are active:
 if ([filter activeFilters]) ...
 
 Test if specific filters are on:
 if ([filter filterText]) ...
 if ([filter filterColor]) ...
 if ([filter filterCharacter]) ...
 
 */

#import "SceneFiltering.h"
#import "OutlineScene.h"
#import "FountainAnalysis.h"

@implementation SceneFiltering

- (SceneFiltering*)init
{
    self = [super init];
    if (self) {
		_text = @"";
		_colors = [NSMutableArray array];
		_filteredScenes = [NSMutableArray array];
		_analysis = [[FountainAnalysis alloc] init];
    }
    return self;
}

- (void)reset {
	_text = @"";
	[_scenes removeAllObjects];
	[_colors removeAllObjects];
}

- (bool)activeFilters {
	if ([_text length] || [_character length] || [_colors count]) return YES;
	return NO;
}
- (bool)filterText {
	if ([_text length]) return YES; else return NO;
}
- (bool)filterColor {
	if ([_colors count]) return YES; else return NO;
}
- (bool)filterCharacter {
	if ([_scenes count] > 0 && [_character length] > 0) return YES; else return NO;
}

- (void)byText:(NSString*)string {
	_text = string;
}
- (void)byColor:(NSString*)color {
	[self addColorFilter:color];
}
- (void)byScenes:(NSMutableArray *)scenes {
	_scenes = [NSMutableArray arrayWithArray:scenes];
}
- (void)byCharacter:(NSString*)character {
	_character = [NSString stringWithString:character];
	[_filteredScenes removeAllObjects];
		
	[self.analysis setupScript:_lines scenes:_scenes];
	_filteredScenes = [self.analysis scenesWithCharacter:_character onlyDialogue:NO];
}

- (void)resetScenes {
	_character = @"";
	[_filteredScenes removeAllObjects];
}

// This updates the lines + scenes pointers if we need them later
- (void)setScript:(NSMutableArray *)lines scenes:(NSMutableArray *)scenes {
	_lines = lines;
	_scenes = scenes;
}

- (bool)match:(OutlineScene*)scene {
	bool matchSearch = NO;
	bool matchCharacter = NO;
	bool matchColor = NO;

	// NOTE: the prefiltered scene array has to be updated EVERY TIME the outline is reloaded
	if ([self filterCharacter]) {
		if ([_filteredScenes indexOfObject:scene] == NSNotFound) {
			matchCharacter = NO;
		} else {
			matchCharacter = YES;
		}
	}
		
	if ([scene.string rangeOfString:_text options:NSCaseInsensitiveSearch].location != NSNotFound) {
		matchSearch = YES;
	}

	if ([_colors indexOfObject:[scene.color lowercaseString]] != NSNotFound) matchColor = YES;
	
	// ONLY text
	if (![self filterColor] && ![self filterCharacter] && [self filterText]) {
		if (matchSearch) return YES;
	}
	// ONLY color
	else if (![self filterCharacter] && ![self filterText]) {
		if (matchColor) return YES;
	}
	// ONLY character
	else if (![self filterColor] && ![self filterText] && [self filterCharacter]) {
		if (matchCharacter) return YES;
	}
	// Color + text search
	else if ([self filterColor] && [self filterText] && ![self filterCharacter]) {
		if (matchSearch && matchColor) return YES;
	}
	// Color + character
	else if ([self filterColor] && [self filterCharacter] && ![self filterText]) {
		if (matchColor && matchCharacter) return YES;
	}
	// Character + text search
	else if ([self filterText] && [self filterCharacter]) {
		if (matchSearch && matchCharacter) return YES;
	}

	return NO;
}

- (void)addColorFilter:(NSString*)color {
	NSInteger index = [_colors indexOfObject:color];
	if (index == NSNotFound) {
		[_colors addObject:color];
	}
}
- (void)removeColorFilter:(NSString*)color {
	NSInteger index = [_colors indexOfObject:color];
	if (index != NSNotFound) {
		[_colors removeObjectAtIndex:index];
	}
}

// Debugging
- (NSString*)listFilters {
	NSString* list = @"";
	if ([self filterCharacter]) list = [list stringByAppendingString:@"character, "];
	if ([self filterColor]) list = [list stringByAppendingString:@"color, "];
	if ([self filterText]) list = [list stringByAppendingString:@"text"];
	return list;
}

@end
