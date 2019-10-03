//
//  FountainReport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FountainReport.h"
#import "NSString+Whitespace.h"

@implementation FountainReport

- (id)init
{
	if ((self = [super init]) == nil) { return nil; }

	// Fuck dictionaries
	_characters = [[NSMutableArray alloc] init];
	_lines = [[NSMutableArray alloc] init];
	
	_characterLines = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (NSString*) createReport:(NSMutableArray*)lines {
	// Reset everything
	[_characterLines removeAllObjects];
	
	NSInteger interiorScenes = 0;
	NSInteger exteriorScenes = 0;
	NSInteger otherScenes = 0;
	
	NSInteger lineIndex = -1;
	
	for (Line* line in lines) {
		lineIndex += 1;
		
		if (line.type == character) {
			// Because we are sending the lines array from the continuous parser, we need to double check certain things
			
			// We won't proceed if there is no next line. I mean, come on.
			if (lineIndex + 1 < [lines count]) {
				Line* nextLine = [lines objectAtIndex:lineIndex+1];
				
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
				interiorScenes += 1;
				exteriorScenes += 1;
				continue;
			}
			else if ([string rangeOfString:interior].location != NSNotFound || [string rangeOfString:interiorShort].location != NSNotFound) {
				interiorScenes += 1;
			}
			else if ([string rangeOfString:exterior].location != NSNotFound || [string rangeOfString:exteriorShort].location != NSNotFound) {
					exteriorScenes += 1;
			} else {
				otherScenes += 1;
			}
		}
	}
	
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
	[json appendFormat:@"scenes:{ interior: %lu, exterior: %lu, other: %lu }", interiorScenes, exteriorScenes, otherScenes];
	
	// JSON END
	[json appendString:@"}"];
	
	return json;
}

@end
