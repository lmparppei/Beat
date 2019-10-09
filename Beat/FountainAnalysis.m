//
//  FountainReport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FountainAnalysis.h"
#import "NSString+Whitespace.h"

@implementation FountainAnalysis

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
	_characterLines = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void) setupScript:(NSMutableArray*)lines scenes:(NSMutableArray*)scenes {
	_lines = lines;
	_scenes = scenes;
}

- (void) createReport {
	// Reset everything
	[_characterLines removeAllObjects];
	
	_interiorScenes = 0;
	_exteriorScenes = 0;
	_otherScenes = 0;
	
	NSInteger lineIndex = -1;
	
	for (Line* line in _lines) {
		lineIndex += 1;
		
		if (line.type == character) {
			// Because we are sending the lines array from the continuous parser, we need to double check certain things
			
			// We won't proceed if there is no next line. I mean, come on.
			if (lineIndex + 1 < [_lines count]) {
				Line* nextLine = [_lines objectAtIndex:lineIndex+1];
				
				// This is not a character cue if the next line is empty
				if ([nextLine.string length] < 1 || [nextLine.string containsOnlyWhitespace]) continue;
				
				NSString *character = line.string;
			
				// Remove any (V.O.), (CONT'D), (O.S.) etc. stuff from the cue
				if ([character rangeOfString:@"("].location != NSNotFound) {
					NSRange infoRange = [character rangeOfString:@"("];
					NSRange characterRange = NSMakeRange(0, infoRange.location);
					
					character = [NSString stringWithString:[character substringWithRange:characterRange]];
				}
				
				// Trim any useless whitespace
				character = [NSString stringWithString:[character stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
				
				// Check if the character has been already found
				// Thank you, Venk & Tom Jefferys at stackoverflow
				NSNumber *value = [_characterLines objectForKey:character];
				
				if (!value) {
					// Add new value
					_characterLines[character] = [NSNumber numberWithInt:1];
				} else {
					// Append old value
					NSNumber *newValue = [NSNumber numberWithInt:[value intValue] + 1];
					_characterLines[character] = newValue;
				}
			}
		}
		
		if (line.type == heading) {
			// Count int/ext. Following stuff is shady as hell. Here's a Charles Bukowski quote to ease the pain:
			
			// Sometimes you climb out of bed in the morning and you think,
			// I'm not going to make it, but you laugh inside
			// — remembering all the times you've felt that way.
			
			NSString *interior = @"INT.";
			NSString *interiorShort = @"I.";
			NSString *exterior = @"EXT.";
			NSString *exteriorShort = @"E.";
			
			NSString *both = @"INT./EXT.";
			NSString *bothShort = @"I./E.";
			
			NSString *string = [line.string uppercaseString];
			
			if ([string rangeOfString:both].location != NSNotFound || [string rangeOfString:bothShort].location != NSNotFound) {
				_interiorScenes += 1;
				_exteriorScenes += 1;
				continue;
			}
			else if ([string rangeOfString:interior].location != NSNotFound || [string rangeOfString:interiorShort].location != NSNotFound) {
				_interiorScenes += 1;
			}
			else if ([string rangeOfString:exterior].location != NSNotFound || [string rangeOfString:exteriorShort].location != NSNotFound) {
				_exteriorScenes += 1;
			} else {
				_otherScenes += 1;
			}
		}
	}
}

- (NSString*)getJSON {
	if (![_lines count] || ![_scenes count]) {
		NSLog(@"You forgot to setup the analyzer by [FountainAnalysis setupScript:...])");
		return nil;
	}
	[self createReport];
	return [self createJSON];
}

- (NSString*)createJSON {
	// JSON BEGIN
	NSMutableString * json = [NSMutableString stringWithString:@"{"];
	
	// JSON characters --------------------------------------------------------
	[json appendString:@"characters:{"];
	NSInteger characterIndex = 0;
	for (NSString *character in _characterLines) {
		// Oh well, let's comply to JSON standards and add the comma ONLY between new objects and not at the end
		if (characterIndex > 0) [json appendString:@","];
		
		// Get value and append character to JSON
		NSNumber *value = _characterLines[character];
		[json appendFormat:@"\"%@\": %lu", character, [value unsignedIntegerValue]];
		characterIndex += 1;
	}
	[json appendString:@"},"];
	
	// JSON scenes --------------------------------------------------------
	[json appendFormat:@"scenes:{ interior: %lu, exterior: %lu, other: %lu }", _interiorScenes, _exteriorScenes, _otherScenes];
	
	// JSON END
	[json appendString:@"}"];
	
	return json;
}

- (NSMutableArray*)scenesWithCharacter:(NSString *)characterName onlyDialogue:(bool)onlyDialogue  {
	// Let's assume we have the scenes / lines property set
	if (![_scenes count] || ![_lines count]) return nil;
	
	// We'll use a simple trick here.
	// First remove all extra whitespace from the character and then add one space at the beginning.
	// Later on, we'll do the exact same thing for lines in the scene, so we'll have a pretty reliable way of telling if that exact character string is present in the scene. Not waterproof, but splash resistant.
	
	characterName = [characterName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	NSString* actionCharacter = [NSString stringWithFormat:@" %@", characterName];
	
	NSMutableArray* filteredScenes = [[NSMutableArray alloc] init];
	
	for (OutlineScene* scene in _scenes) {
		// Don't go through synopses and sections
		if (scene.type == synopse || scene.type == section) continue;
		
		NSInteger index = [self.lines indexOfObject:scene.line];
		if (index + 1 >= [self.lines count]) break; // Heading was the last line
		
		// Loop through lines array until we encounter a scene heading
		for (NSInteger i = index + 1; i < [self.lines count]; i++) {
			Line* line = [self.lines objectAtIndex:i];
			
			// Break on next scene
			if (line.type == heading) break;

			bool found = NO;
			NSString* string = line.string;
			
			// The character is talking in the scene
			if (line.type == character) {
				if ([string isEqualToString:characterName]) found = YES;
			}
			
			// The character is at least MENTIONED within the action
			if (line.type == action && !onlyDialogue) {
				string = [NSString stringWithFormat:@" %@", string]; // See above
				if ([string rangeOfString:actionCharacter options:NSCaseInsensitiveSearch].location != NSNotFound) found = YES;
			}
			
			if (found && ![filteredScenes containsObject:scene]) {
				[filteredScenes addObject:scene];
				break; // Look no further
			}
		}
	}
	
	return filteredScenes;
}

@end
