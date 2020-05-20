//
//  BeatPreview.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//
/*
 
 This acts as a bridge between FNScript and Beat.
 Should be replaced / rewritten ASAP.
 
 */

#import "BeatPreview.h"
#import "FNScript.h"
#import "FNElement.h"
#import "Line.h"
#import "ContinousFountainParser.h"
#import "OutlineScene.h"

@implementation BeatPreview

+ (FNScript*) createPreview:(NSString*)rawText {
	// Continuous parser is much faster than the normal Fountain parser
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:rawText];
	//FNScript *script = [[FNScript alloc] initWithString:rawString];
	
	FNScript *script = [[FNScript alloc] init];
	script.elements = [NSArray array];
	
	for (Line *line in parser.lines) {
		// Skip over certain elements
		if (line.type == synopse || line.type == section || line.omited || [line isTitlePage]) continue;
	
		FNElement *element = [line fountainElement];
		if (element) script.elements = [script.elements arrayByAddingObject:element];
		
		// If this is dual dialogue character cue, we need to search for the previous one too
		if (element.isDualDialogue) {
			bool previousCharacterFound = NO;
			NSInteger i = script.elements.count - 2; // Go for previous element
			while (i > 0) {
				FNElement *previousElement = [script.elements objectAtIndex:i];
				if ([previousElement.elementType isEqualToString:@"Character"]) {
					previousElement.isDualDialogue = YES;
					previousCharacterFound = YES;
					break;
				}
				i--;
			}
			
			// If there was no previous character, just reset
			if (!previousCharacterFound) {
				element.isDualDialogue = NO;
			}
		}
	}
	
	// Set title page data
	script.titlePage = parser.titlePage;
	
	return script;
}

@end
