//
//  LivePagination.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LivePagination.h"
#import "FNElement.h"
#import "FNPaginator.h"

@implementation LivePagination

- (instancetype)init {
	self = [super init];
	
	_font = [NSFont fontWithName:@"Courier" size:12];
	_lineHeight = _font.pointSize;
	
	return self;
}

/*
 
 If the fixed constants in FNPaginator are changed, these should too!!!
 (mostly oneInchBuffer)
 
 */

- (NSArray*)paginate:(NSArray*) lines {
	@autoreleasepool {
		
		NSMutableArray *result = [NSMutableArray array];
		
		CGFloat position = 0;
		CGFloat blockHeight = 0;
		NSInteger maxElements = [lines count];
		
		NSInteger oneInchBuffer = 72;
		NSInteger maxPageHeight = _paperSize.height - round(oneInchBuffer * 1.30);
		
		// Look for title page ...
		bool titlePage = NO;
		bool emptyLine = NO;
		
		NSInteger index = -1;
		NSInteger startIndex = 0;
		NSInteger pages = 1;
		
		for (Line* line in lines) {
			index++;
			
			if (line.type == titlePageTitle || line.type == titlePageAuthor || line.type == titlePageCredit || line.type == titlePageSource || line.type == titlePageContact || line.type == titlePageUnknown || line.type == titlePageDraftDate) titlePage = YES;
			
			// We need 2 empty lines after title page section
			if (line.type == empty && titlePage) {
				if (!emptyLine) emptyLine = YES;
				else {
					startIndex = index + 1;
					break;
				}
			}
			
			// Break after 20 lines
			if (index > 20) break;
		}
		
		// First page starts after title page data
		[result addObject:[self makePageBreakFor:lines[startIndex] at:0.0]];
		
		Line * previousLine;
		
		for (NSInteger i = startIndex; i < maxElements; i++) {
			Line* line = lines[i];
			
			if (line.type == synopse ||
				line.type == section ||
				line.omited ||
				line.type == titlePageTitle ||
				line.type == titlePageAuthor ||
				line.type == titlePageCredit ||
				line.type == titlePageSource ||
				line.type == titlePageContact ||
				line.type == titlePageUnknown ||
				line.type == titlePageDraftDate) {
				
				continue;
			}
			NSString *type;
			
			if (line.type == action) type = @"Action";
			else if (line.type == empty) type = @"Action";
			else if (line.type == character) type = @"Character";
			else if (line.type == parenthetical) type = @"Parenthetical";
			else if (line.type == dialogue) type = @"Dialogue";
			else if (line.type == heading) type = @"Scene Heading";
			else if (line.type == transitionLine) type = @"Transition";
			else type = @"General";
			
			// Page break
			if (line.type == pageBreak) {
				// Add y position to array
				[result addObject:[self makePageBreakFor:line at:blockHeight - maxPageHeight]];

				pages++;
				
				position = 0;
				blockHeight = 0;
						
				previousLine = line;
				continue;
			}
			
			CGFloat spaceBefore = 0;
			if (position > 0) {
				if (line.type == heading) spaceBefore = _lineHeight * 2.5;
				else if (line.type == dialogue || line.type == parenthetical) spaceBefore = 0;
				else spaceBefore = _lineHeight * 1.1;
			}
			

			blockHeight = [FNPaginator heightForString:line.string font:_font maxWidth:[FNPaginator widthForElementType:type]  lineHeight:_lineHeight] + spaceBefore;
									
			// The page will break here
			if (position + blockHeight >= maxPageHeight) {
				pages++;
				
				// Page headings are moved to the next page in case of a page break, so push in the previous element
				if (line.type == heading || line.type == character) {
					[result addObject:[self makePageBreakFor:previousLine at:-1.0]];
					NSLog(@"- - - heading %@ // %f // %lu", line.string, position, maxPageHeight);
					position = 0;
				}
				else if (line.type == dialogue) {
					CGFloat overflow = position + blockHeight - maxPageHeight;
					if (overflow > _lineHeight) {
						[result addObject:[self makePageBreakFor:line at:position + blockHeight - maxPageHeight]];
						position = _lineHeight; // For character cue on next page
					} else {
						if (previousLine.type == parenthetical) {
							NSInteger index = [lines indexOfObject:line];
							[result addObject:[self makePageBreakFor:[lines objectAtIndex:index-2] at:0]];
							position = 0;
						} else {
							[result addObject:[self makePageBreakFor:previousLine at: 0]];
							position = 0;
						}
						
					}
				}
				else if (line.type == parenthetical) {
					NSInteger index = [lines indexOfObject:line];
					[result addObject:[self makePageBreakFor:[lines objectAtIndex:index-2] at:0]];
					position = 0;
				}
				else {
					
					// Add line element to the page break array
					NSLog(@"- - - break %@ // %f // %lu", line.string, position, maxPageHeight);
					[result addObject:[self makePageBreakFor:line at:position + blockHeight - maxPageHeight]];
					
					//NSLog(@"---- cut at: %@", line.string);
					position = 0;
				}
				
				blockHeight = 0;
			}
			
			previousLine = line;
			position += blockHeight;
		}
		NSLog(@"pages: %lu", pages);
		
		return result;
	}
}
- (NSDictionary*)makePageBreakFor:(Line*)line at:(CGFloat)yPosition {
	return @{ @"line": line, @"position": [NSNumber numberWithFloat:yPosition] };

}

@end
