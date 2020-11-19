//
//  BeatComparison.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 You who will emerge from the flood
 In which we have gone under
 Remember
 When you speak of our failings
 The dark time too
 Which you have escaped.
 
 
 
 This is a class for comparing two Fountain files against each other, using Google's
 diff-match-patch framework.
 
 The system is a bit convoluted, so let me elaborate. This class also provides the
 UI functions, which then sends the script to PrintView, which THEN calls this class
 again to set comparison markers (line.changed = YES) and prints out the HTML file.
 
 Comparison can be run outside the UI too:
 BeatComparison *comparison = [[BeatComparison alloc] init];
 [comparison compare:parser.lines with:oldScript];
 
 It's multiple systems built on top of each other in a messy way, but it works for now.
 Hopefully I don't need to touch it again.
 
 Note that the PrintView (of Writer legacy) has to be retained in memory as it
 works asynchronously.
 
 */

//#import <DiffMatchPatch/DiffMatchPatch.h>
#import "DiffMatchPatch.h"
#import "BeatComparison.h"

#import "ContinousFountainParser.h"
#import "Line.h"

@implementation BeatComparison

- (NSArray*)diffReportFrom:(NSString*)newScript with:(NSString*)oldScript {
	DiffMatchPatch *diff = [[DiffMatchPatch alloc] init];
		
	// Get edited lines
	NSArray *lines = [diff diff_linesToCharsForFirstString:oldScript andSecondString:newScript];
	NSMutableArray *diffs = [diff diff_mainOfOldString:lines[0] andNewString:lines[1] checkLines:YES];
	
	// Operate the diff report
	[diff diff_chars:diffs toLines:lines[2]];
	[diff diff_cleanupSemantic:diffs];
	
	return diffs;
}

- (NSDictionary*)changeListFrom:(NSString*)oldScript to:(NSString*)newScript {
	
	NSArray *diffs = [self diffReportFrom:newScript with:oldScript];
	
	NSInteger additions = 0;
	NSInteger removals = 0;
	NSInteger equal = 0;
	
	for (Diff *d in diffs) {
		if (d.operation == DIFF_DELETE) removals += d.text.length;
		if (d.operation == DIFF_EQUAL) equal += d.text.length;
		else if (d.operation == DIFF_INSERT) additions += d.text.length;
	}
	
	NSDictionary *changes = @{
		@"unchanged": [NSNumber numberWithInteger:equal],
		@"removed": [NSNumber numberWithInteger:removals],
		@"added": [NSNumber numberWithInteger:additions]
	};
	
	return changes;
}

- (void)compare:(NSArray*)script with:(NSString*)oldScript {
	
	NSMutableString *newScript = [NSMutableString string];
	for (Line *line in script) {
		[newScript appendString:line.string];
		[newScript appendString:@"\n"];
	}
	
	NSArray *diffs = [self diffReportFrom:newScript with:oldScript];
	
	// Go through the changed indices and calculate their positions
	// NB: We are running diff-match-patch in line mode, so basically the line indices for inserts should do.
	NSInteger index = 0;
	NSMutableIndexSet *changedIndices = [NSMutableIndexSet indexSet];
	
	NSMutableArray *changedRanges = [NSMutableArray array];
	
	for (Diff *d in diffs) {
		if (d.operation == DIFF_EQUAL) {
			index += d.text.length;
		}
		else if (d.operation == DIFF_INSERT) {
			// This is a new line
			[changedIndices addIndex:index];
			NSRange changedRange = NSMakeRange(index, d.text.length);
			[changedRanges addObject:[NSNumber valueWithRange:changedRange]];
			
			index += d.text.length;
		} else {
			// ... and ignore deletions.
		}
		
	}
	
	// Go through the parsed lines and look if they are contained within changed ranges
	for (Line *l in script) {
		if (l.type == empty || l.isTitlePage) { l.changed = NO; continue; }
		
		bool changed = NO;
		
		NSRange lineRange = NSMakeRange(l.position, l.string.length);
		for (NSNumber *range in changedRanges) {
			if (NSIntersectionRange(range.rangeValue, lineRange).length > 0) {
				changed = YES;
			}
		}
		
		// Mark the line as changed
		if (changed) l.changed = YES;
	}
}

@end
