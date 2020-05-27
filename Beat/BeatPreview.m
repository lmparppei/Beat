//
//  BeatPreview.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//
/*
 
 This acts as a bridge between FNScript and Beat.
 One day we'll have a native system to convert a Beat script into HTML
 and this intermediate class is useless. Hopefully.
 
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
	
	Line *previousLine;
	
	for (Line *line in parser.lines) {
		// Skip over certain elements
		if (line.type == synopse || line.type == section || line.omited || [line isTitlePage]) {
			if (line.type == empty) previousLine = line;
			continue;
		}
	
		// This is a paragraph with a line break,
		// so append the line to the previous one
		if (line.type == action && line.isSplitParagraph && [parser.lines indexOfObject:line] > 0) {
			FNElement *previousElement = [script.elements objectAtIndex:script.elements.count - 1];

			previousElement.elementText = [previousElement.elementText stringByAppendingFormat:@"\n%@", line.cleanedString];
			continue;
		}
		
		if (line.type == dialogue && line.string.length < 1) {
			line.type = empty;
			previousLine = line;
			continue;
		}
		
		FNElement *element = [line fountainElement];
		if (element) {
			script.elements = [script.elements arrayByAddingObject:element];
		}
		
		// If this is dual dialogue character cue,
		// we need to search for the previous one too
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
		previousLine = line;
	}
	
	// Set title page data
	script.titlePage = parser.titlePage;
	
	return script;
}

/*
 
 Sä näytät tosi hienolta, Zaia
 kun poltat savukkeen ja katot valokuvia
 sä olet itse niissä
 ja koko huone (myöskin mä)
 on siin kans
 
 */

@end
