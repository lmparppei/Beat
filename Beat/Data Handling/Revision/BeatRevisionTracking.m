//
//  BeatRevisionTracking.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

/*
 
 This is used in Preview and Export to bake attributed ranges into the screenplay.
 
 */

#import "BeatRevisionTracking.h"
#import "BeatRevisionItem.h"
#import "Line.h"
#import <Cocoa/Cocoa.h>

@implementation BeatRevisionTracking
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string parser:(ContinuousFountainParser*)parser
{
	[string enumerateAttribute:@"Revision" inRange:(NSRange){0,string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		if (range.length < 1 || range.location == NSNotFound || range.location + range.length > string.length) return;
		
		BeatRevisionItem *item = value;
		
		if (item.type != RevisionNone) {
			NSArray *linesInRange = [parser linesInRange:range];
			for (Line* line in linesInRange) {
				line.changed = YES;
				if (!line.removalRanges) line.removalRanges = [NSMutableIndexSet indexSet];
				
				NSRange localRange = [line globalRangeToLocal:range];
				if (item.type == RevisionRemoval) [line.removalRanges addIndexesInRange:localRange];
				else if (item.type == RevisionAddition) [line.additionRanges addIndexesInRange:localRange];
			}
		}
	}];
}
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string parser:(ContinuousFountainParser*)parser
{
	if (revisions.count && !string.length) NSLog(@"NOTE: No string available for baking the revisions.");

	for (NSString *key in revisions.allKeys) {
		NSArray *items = revisions[key];
		for (NSArray *item in items) {
			NSString *color;
			NSInteger loc = [(NSNumber*)item[0] integerValue];
			NSInteger len = [(NSNumber*)item[1] integerValue];
			
			// Load color if available
			if (item.count > 2) {
				color = item[2];
			}
			
			// Ensure the revision is in range, find lines in range and bake revisions
			if (len > 0 && loc + len <= string.length) {
				RevisionType type;
				NSRange range = (NSRange){loc, len};
				
				if ([key isEqualToString:@"Addition"]) type = RevisionAddition;
				else if ([key isEqualToString:@"Removal"]) type = RevisionRemoval;
				else type = RevisionNone;
				
				BeatRevisionItem *revision = [BeatRevisionItem type:type color:color];
				//if (revisionItem) [self.textView.textStorage addAttribute:revisionAttribute value:revisionItem range:range];
				
				if (revision.type != RevisionNone) {
					NSArray *linesInRange = [parser linesInRange:range];
					for (Line* line in linesInRange) {
						line.changed = YES;
						if (!line.removalRanges) line.removalRanges = [NSMutableIndexSet indexSet];
						
						NSRange localRange = [line globalRangeToLocal:range];
						if (revision.type == RevisionRemoval) [line.removalRanges addIndexesInRange:localRange];
						else if (revision.type == RevisionAddition) [line.additionRanges addIndexesInRange:localRange];
					}
				}
			}
		}
	}
}

+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string {
	NSDictionary *ranges = @{
		@"Addition": [NSMutableArray array],
		@"Removal": [NSMutableArray array],
		@"Comment": [NSMutableArray array]
	};
	
	[string enumerateAttribute:@"Revision" inRange:(NSRange){0,string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *item = value;
		if (item.type != RevisionNone) {
			NSMutableArray *values = ranges[item.key];
			[values addObject:@[@(range.location), @(range.length), item.colorName]];
		}
	}];
	
	return ranges;
}

@end
