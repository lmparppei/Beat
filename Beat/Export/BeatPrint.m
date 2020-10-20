//
//  BeatPrint.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 This class creates a HTML print from a document.
 Created to avoid using having to embed the diff-match-patch framework into the quicklook plugin.
 
 What we should do here is to parse the previous file too, then run scene number preprocessing on it (lol) 
 
 */


#import "BeatPrint.h"
#import "BeatPreview.h"
#import "Line.h"
#import "ContinousFountainParser.h"
#import "OutlineScene.h"
#import "BeatHTMLScript.h"
#import "BeatComparison.h"

@implementation BeatPrint

+ (NSString*) createPrint:(NSString*)rawText document:(Document*)document compareWith:(NSString*)oldScript {
	// Should we show scene numbers?
	bool sceneNumbering = document.printSceneNumbers;
	
	// Parse the input again
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:rawText];
	NSMutableDictionary *script = [NSMutableDictionary dictionaryWithDictionary:@{
		@"script": [NSMutableArray array],
		@"title page": [NSMutableArray array]
	}];
	NSMutableArray *elements = [NSMutableArray array];

	// See if we want to compare it with something
	// BeatComparison marks the Line objects as changed
	if (oldScript) {
		BeatComparison *comparison = [[BeatComparison alloc] init];
		[comparison compare:parser.lines with:oldScript];
	}
	
	Line *previousLine;
	
	NSInteger sceneNumber = 1;
	
	for (Line *line in parser.lines) {
		// Skip over certain elements
		if (line.type == synopse || line.type == section || line.omited || [line isTitlePage]) {
			if (line.type == empty) previousLine = line;
			continue;
		}
		
		if (line.type == heading && sceneNumbering) {
			// If scene numbering is ON, let's strip forced numbers and set correct numbers to the line objects
			if (line.sceneNumberRange.length > 0) {
				line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
				line.string = line.stripSceneNumber;
			} else {
				line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
				line.string = line.stripSceneNumber;
				sceneNumber += 1;
			}
		}
		
		// This is a paragraph with a line break,
		// so append the line to the previous one
		
		// NOTE: This should be changed so that there is a possibility of having no-margin elements
		// Just needs some parser-level work.
		// Later me: no idea what that person was going on about? Care to elaborate?
		
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

- (NSString*) preprocessSceneNumbersFor:(NSArray*)lines
{
	// This is horrible shit and should be fixed ASAP
	NSString *sceneNumberPattern = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPattern];
	NSMutableString *fullText = [NSMutableString stringWithString:@""];
	
	NSUInteger sceneCount = 1; // Track scene amount
		
	// Make a copy of the array if this is called in a background thread
	for (Line *line in lines) {
		//NSString *cleanedLine = [line.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		NSString *cleanedLine = [NSString stringWithString:line.string];
		
		// If the heading already has a forced number, skip it
		if (line.type == heading && ![testSceneNumber evaluateWithObject: cleanedLine]) {
			// Check if the scene heading is omited
			if (![line omited]) {
				[fullText appendFormat:@"%@ #%lu#\n", cleanedLine, sceneCount];
				sceneCount++;
			} else {
				// We will still append the heading into the raw text … this is a dirty fix
				// to keep indexing of scenes intact
				[fullText appendFormat:@"%@\n", cleanedLine];
			}
		} else {
			[fullText appendFormat:@"%@\n", cleanedLine];
		}
		
		// Add a line break after the scene heading if it doesn't have one
		// If the user relies on this feature, it breaks the file's compatibility with other Fountain editors, but they have no one else to blame than themselves I guess. And my friendliness and hospitality allowing them to break the syntax.
		if (line.type == heading && line != [lines lastObject]) {
			NSInteger lineIndex = [lines indexOfObject:line];
			if ([(Line*)[lines objectAtIndex:lineIndex + 1] type] != empty) {
				[fullText appendFormat:@"\n"];
			}
		}
	}
	
	return fullText;
}

@end
