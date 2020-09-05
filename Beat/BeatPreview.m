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
#import "Line.h"
#import "ContinousFountainParser.h"
#import "OutlineScene.h"
#import "BeatHTMLScript.h"

@implementation BeatPreview

+ (NSString*) createPrint:(NSString*)rawText document:(NSDocument*)document {
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:rawText];
	NSMutableDictionary *script = [NSMutableDictionary dictionaryWithDictionary:@{
		@"script": [NSMutableArray array],
		@"title page": [NSMutableArray array]
	}];
	NSMutableArray *elements = [NSMutableArray array];

	Line *previousLine;
	
	for (Line *line in parser.lines) {
		// Skip over certain elements
		if (line.type == synopse || line.type == section || line.omited || [line isTitlePage]) {
			if (line.type == empty) previousLine = line;
			continue;
		}
	
		// This is a paragraph with a line break,
		// so append the line to the previous one
		
		// NOTE: This should be changed so that there is a possibility of having no-margin elements
		// Just needs some parser-level work.
		
		if (line.type == action && line.isSplitParagraph && [parser.lines indexOfObject:line] > 0) {
			Line *previousLine = [elements objectAtIndex:elements.count - 1];

			previousLine.string = [previousLine.string stringByAppendingFormat:@"\n%@", line.cleanedString];
			continue;
		}
		
		if (line.type == dialogue && line.string.length < 1) {
			line.type = empty;
			previousLine = line;
			continue;
		}

		[elements addObject:line];
				
		// If this is dual dialogue character cue,
		// we need to search for the previous one too, just in cae
		if (line.isDualDialogueElement) {
			bool previousCharacterFound = NO;
			NSInteger i = elements.count - 2; // Go for previous element
			while (i > 0) {
				Line *previousLine = [elements objectAtIndex:i];
				
				if (!(previousLine.isDialogueElement || previousLine.isDualDialogueElement)) break;
				
				if (previousLine.type == character ) {
					previousLine.nextElementIsDualDialogue = YES;
					previousCharacterFound = YES;
					break;
				}
				i--;
			}
		}
		
		previousLine = line;
	}
	
	// Set script data
	[script setValue:parser.titlePage forKey:@"title page"];
	[script setValue:elements forKey:@"script"];

	BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script document:document print:YES];
	return html.html;
}

+ (NSString*) createQuickLook:(NSString*)rawText {
	return [self createNewPreview:rawText of:nil scene:nil quickLook:YES];
}
+ (NSString*) createNewPreview:(NSString*)rawText {
	return [self createNewPreview:rawText of:nil scene:nil];
}
+ (NSString*) createNewPreview:(NSString*)rawText of:(NSDocument*)document scene:(NSString*)scene {
	return [self createNewPreview:rawText of:document scene:scene quickLook:NO];
}
+ (NSString*) createNewPreview:(NSString*)rawText of:(NSDocument*)document scene:(NSString*)scene quickLook:(bool)quickLook {
	// Continuous parser is much faster than the normal Fountain parser
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:rawText];
	NSMutableDictionary *script = [NSMutableDictionary dictionaryWithDictionary:@{
		@"script": [NSMutableArray array],
		@"title page": [NSMutableArray array]
	}];
	NSMutableArray *elements = [NSMutableArray array];
	
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
			Line *previousLine = [elements objectAtIndex:elements.count - 1];

			previousLine.string = [previousLine.string stringByAppendingFormat:@"\n%@", line.cleanedString];
			continue;
		}
		
		if (line.type == dialogue && line.string.length < 1) {
			line.type = empty;
			previousLine = line;
			continue;
		}

		[elements addObject:line];
				
		// If this is dual dialogue character cue,
		// we need to search for the previous one too
		if (line.isDualDialogueElement) {
			bool previousCharacterFound = NO;
			NSInteger i = elements.count - 2; // Go for previous element
			while (i > 0) {
				Line *previousLine = [elements objectAtIndex:i];
				
				if (!(previousLine.isDialogueElement || previousLine.isDualDialogueElement)) break;
				
				if (previousLine.type == character ) {
					previousLine.nextElementIsDualDialogue = YES;
					previousCharacterFound = YES;
					break;
				}
				i--;
			}
		}
		
		previousLine = line;
	}
	
	// Set script data
	[script setValue:parser.titlePage forKey:@"title page"];
	[script setValue:elements forKey:@"script"];
	
	if (quickLook) {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script quickLook:YES];
		return html.html;
	} else {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script document:document scene:scene];
		return html.html;
	}
}

/*
 
 Sä näytät tosi hienolta, Zaia
 kun poltat savukkeen ja katot valokuvia
 sä olet itse niissä
 ja koko huone (myöskin mä)
 on siin kans
 
 */

@end
