//
//  FountainReport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/09/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This module creates an analysis of the Fountain script. It's a bit convoluted.
 The gender analysis relies on an external dictionary, ie. { "character": "gender" }
 
 Usage:
 FountainAnalysis *analysis = [[FountainAnalysis init] alloc];
 [analysis setupScript:lines scenes:scenes];
 [analysis setupScript:lines scenes:scenes genders:genders];
 
 (lines: NSArray with Line objects, scenes: NSArray with OutlineScene objects, genders: NSDictionary { name: gender })
 
 // Get JSON string for everything
 NSString *json = [analysis getJSON];
 
 // Get scenes with lines for a certain character
 NSMutableArray *scenes = [analysis scenesWithCharacter:@"Name" onlyDialogue:YES];
 
 
 */

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatPagination2/BeatPagination2.h>
#import "FountainAnalysis.h"

// lol
#define LATER @[@"LATER", @"MYÖHEMMIN", @"SPÄTER", @"SENARE", @"PLUS TARD", @"ENSUITE", @"LUEGO", @"SENERE", @"SEINERE", @"SEINNA", @"BERANDUAGO", @"DESPRÉS", @"PÄRAST", @"HILJEM", @"TAGANTJÄRELE", @"SEURAAVAKSI", @"PÄRASTPOOLE", @"VĒLĀK", @"VĖLIAU", @"PÓŹNIEJ"]

@interface FountainAnalysis ()

@property NSMutableArray * characters;
@property NSArray * lines;
@property NSArray * scenes;
@property NSDictionary * genders;
@property NSMutableDictionary * TOD;
@property NSMutableDictionary<NSString *, NSNumber *>* characterLines;

@property NSInteger interiorScenes;
@property NSInteger exteriorScenes;
@property NSInteger otherScenes;
@property NSInteger words;
@property NSInteger glyphs;

@property NSArray* avgLength;
@property NSArray* longestLength;

@end

@implementation FountainAnalysis

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate
{
	if ((self = [super init]) == nil) { return nil; }
	_delegate = delegate;
	
	_characterLines = [NSMutableDictionary dictionary];
	_TOD = [NSMutableDictionary dictionary];
		
	_lines = self.delegate.parser.lines.copy;
	_scenes = self.delegate.parser.scenes.copy;
	_genders = self.delegate.characterGenders;
	
	return self;
}


- (void) createReport {
	// Reset everything
	[_characterLines removeAllObjects];
	
	[self calculateAverageSceneLength];
	
	_interiorScenes = 0;
	_exteriorScenes = 0;
	_otherScenes = 0;
	_words = 0;
	_glyphs = 0;
	
	NSInteger lineIndex = -1;
	
	for (Line* line in _lines) {
		lineIndex += 1;
		
		if (!line.isInvisible && line.string.length) {
			_glyphs += line.stripFormatting.length;
			_words += [[line.stripFormatting componentsSeparatedByString:@" "] count];
		}
		
		if (line.type == character) {
			// Because we are sending the lines array from the continuous parser, we need to double check certain things
			
			// We won't proceed if there is no next line. I mean, come on.
			if (lineIndex + 1 < [_lines count]) {
				Line* nextLine = [_lines objectAtIndex:lineIndex+1];
				
				// This is not a character cue if the next line is empty
				if (nextLine.string.length < 1 || line.string.containsOnlyWhitespace) continue;
				
				// Get character name (strips V.O. etc.)
				NSString *character = line.characterName;
								
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
			// Map the times of day
			NSString *str = line.stripFormatting;
			NSRange todRange = [str rangeOfString:@"- " options:NSBackwardsSearch];
			
			if (todRange.location + 2 < line.string.length) {
				NSString *tod = [str substringFromIndex:todRange.location + 2];
				
				// Replace things like [STORY] and [[COLOR RED]], NIGHT (PRESENT DAY)
				tod = [tod replace:RX(@"\\[(.*)\\]") with:@""];
				tod = [tod replace:RX(@"\\((.*)\\)") with:@""];
				
				// This is PRETTY SHADY. Basically, we have an array with some quick translations of the word 'later'.
				// Then, we'll iterate through them and remove anything that might be indicate the scene happening "later"
				// than the previous one. If there is a god, have mercy on me.
				for (NSString *later in LATER) {
					tod = [tod stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" / %@", later] withString:@""];
					tod = [tod stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" - %@", later] withString:@""];
					tod = [tod stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@", %@", later] withString:@""];
				}
				
				tod = [tod stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
				
				// See if anything is left
				if (tod.length > 1) {
					if (!_TOD[tod]) {
						[_TOD setValue:[NSNumber numberWithInt:1] forKey:tod];
					} else {
						NSInteger i = [(NSNumber*)[_TOD valueForKey:tod] integerValue];
						[_TOD setValue:[NSNumber numberWithInteger:i + 1] forKey:tod];
					}
				}
			}
			
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

- (void)calculateAverageSceneLength {
	CGFloat totalLength = 0;
	CGFloat longest = 0;
	
	BeatPaginationManager* pm = self.delegate.pagination;
	for (OutlineScene* scene in self.scenes) {
		CGFloat length = [pm heightForScene:scene];
		if (length > 0) totalLength += length;
		if (length > longest) longest = length;
	}
	
	CGFloat avg = totalLength / self.scenes.count;
	CGFloat avgPages = floorf(avg);
	CGFloat avgEights = avg - avgPages;
	
	CGFloat lngPages = floorf(longest);
	CGFloat lngEights = longest - lngPages;
		
	_avgLength = @[ @(avgPages), @(avgEights) ];
	_longestLength = @[ @(lngPages), @(lngEights) ];
	
}
	
- (NSString*)getJSON {
	if (!_lines.count) {
		return @"genders:{ }";
	}
	[self createReport];
	return [self createJSON];
}

- (NSString*)createJSON {
	// JSON BEGIN
	NSMutableString * json = [NSMutableString stringWithString:@"{"];
	
	// JSON genders --------------------------------------------
	
	[json appendString:@"genders:{"];
	for (NSString *character in _genders) {
		[json appendFormat:@"\"%@\": '%@',", character, _genders[character]];
	}
	[json appendString:@"},"];
	
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
	[json appendFormat:@"scenes:{ interior: %lu, exterior: %lu, other: %lu },", _interiorScenes, _exteriorScenes, _otherScenes];
	// JSON times of day --------------------------------------------------------
	NSData *tods = [NSJSONSerialization dataWithJSONObject:_TOD options:NSJSONWritingPrettyPrinted error:nil];
	[json appendFormat:@"tods:%@,", [[NSString alloc] initWithData:tods encoding:NSUTF8StringEncoding]];
	// JSON statistics --------------------------------------------------------
	[json appendFormat:@"statistics:{ words: %lu, glyphs: %lu, scenes: %lu, avgLength: { pages: %lu, eights: %f }, longestScene: { pages: %lu, eights: %f } }",
	 _words, _glyphs, _scenes.count,
	 [(NSNumber*)_avgLength[0] integerValue], [(NSNumber*)_avgLength[1] floatValue],
	 [(NSNumber*)_longestLength[0] integerValue], [(NSNumber*)_longestLength[1] floatValue]
	];
	
	// JSON END
	[json appendString:@"}"];
	
	return json;
}

- (NSMutableArray*)scenesWithCharacter:(NSString *)characterName onlyDialogue:(bool)onlyDialogue  {
	// Let's assume we have the scenes / lines property set
	if (!_scenes.count || !_lines.count) return nil;
	
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
		if (index + 1 >= self.lines.count) break; // Heading was the last line
		
		// Loop through lines array until we encounter a scene heading
		for (NSInteger i = index + 1; i < _lines.count; i++) {
			Line* line = self.lines[i];
			
			// Break on next scene
			if (line.type == heading) {
				break;
			}

			bool found = NO;
			NSString* string = line.string;
					
			// The character is talking in the scene
			if (line.type == character) {
				if ([line.characterName isEqualToString:characterName]) found = YES;
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
