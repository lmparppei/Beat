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
 
 ... that day has come long since. It's still a horribly convoluted system.
 
 */

#import "BeatPreview.h"
#import "Line.h"
#import "ContinousFountainParser.h"
#import "OutlineScene.h"
#import "BeatHTMLScript.h"
#import "BeatComparison.h"

@implementation BeatPreview

+ (NSString*) createQuickLook:(NSString*)rawScript {
	return [self createNewPreview:rawScript of:nil scene:nil sceneNumbers:YES type:BeatQuickLookPreview];
}
+ (NSString*) createNewPreview:(NSString*)rawScript {
	return [self createNewPreview:rawScript of:nil scene:nil];
}
+ (NSString*) createNewPreview:(NSString*)rawScript of:(NSDocument*)document scene:(NSString*)scene {
	return [self createNewPreview:rawScript of:document scene:scene sceneNumbers:YES type:BeatPrintPreview];
}
+ (NSString*) createNewPreview:(NSString*)rawScript of:(NSDocument*)document scene:(NSString*)scene sceneNumbers:(bool)sceneNumbers {
	return [self createNewPreview:rawScript of:document scene:scene sceneNumbers:sceneNumbers type:BeatPrintPreview];
}
+ (NSString*) createNewPreview:(NSString*)rawScript of:(NSDocument*)document scene:(NSString*)scene sceneNumbers:(bool)sceneNumbers type:(BeatPreviewType)previewType {
	
	ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:rawScript];
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
	
	if (previewType == BeatQuickLookPreview) {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script quickLook:YES];
		return html.html;
	}
	else if (previewType == BeatComparisonPreview) {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initForComparisonWithScript:script];
		return html.html;
	} else {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script document:document scene:scene];
		return html.html;
	}
}

+ (NSString*) preprocessSceneNumbers:(NSArray*)lines
{
	// This is horrible shit and should be fixed ASAP
	
	NSString *sceneNumberPattern = @".*(\\#([0-9A-Za-z\\.\\)-]+)\\#)";
	NSPredicate *testSceneNumber = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", sceneNumberPattern];
	NSMutableString *fullText = [NSMutableString stringWithString:@""];
	
	NSUInteger sceneCount = 1; // Track scene amount
		
	for (Line *line in lines) {
		//NSString *cleanedLine = [line.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		// Can't clean it, because we could fuck it up otherwise
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

/*
 
 Sä näytät tosi hienolta, Zaia
 kun poltat savukkeen ja katot valokuvia
 sä olet itse niissä
 ja koko huone (myöskin mä)
 on siin kans
 
 */

@end
