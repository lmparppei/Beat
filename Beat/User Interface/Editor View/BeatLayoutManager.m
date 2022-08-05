//
//  BeatLayoutManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatLayoutManager.h"
#import "BeatTextView.h"
#import "BeatRevisions.h"

@implementation BeatLayoutManager

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
	if (!self.textView) {
		NSLog(@"WARNING: No text view set for BeatLayoutManager.");
		[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
		return;
	}
	
	[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
	
	NSTextStorage *textStorage = self.textStorage;
	NSTextContainer *textContainer = self.textContainers[0];
	
	NSRange glyphRange = glyphsToShow;
	
	// Save text container margins
	NSSize offset = self.textContainers.firstObject.textView.textContainerInset;
		
	/*
	 
	 This works in a peculiar way:
	 We'll store the NSRect of each marker range into a set using NSNumber, so there will
	 never be two overlapping rects. Those rects are put in a dictionary entry under the
	 revision color.
	 
	 After all glyphs have been iterated, we'll draw the marker strings and draw a rect
	 under them - and voilà: latest revision markers block out the earlier ones.
	 
	 It's a bit convoluted scheme, but works surprisingly well and efficiently.
	 
	 */
	NSMutableDictionary<NSString*, NSMutableSet<NSValue*>*> *revisions = NSMutableDictionary.new;
	for (NSString *string in BeatRevisions.revisionColors) revisions[string] = NSMutableSet.new;
	
	while (glyphRange.length > 0) {
		NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL], attributeCharRange, attributeGlyphRange;
		
		BeatRevisionItem *revision = [textStorage attribute:@"Revision"
													atIndex:charRange.location longestEffectiveRange:&attributeCharRange
													inRange:charRange];
		attributeGlyphRange = [self glyphRangeForCharacterRange:attributeCharRange actualCharacterRange:NULL];
		attributeGlyphRange = NSIntersectionRange(attributeGlyphRange, glyphRange);
		
		if (revision.type == RevisionAddition || revision.type == RevisionCharacterRemoved) {
			NSRect boundingRect = [self boundingRectForGlyphRange:attributeGlyphRange
												  inTextContainer:textContainer];
			
			// Calculate rect for the marker position
			NSRect rect = NSMakeRect(offset.width + _textView.editorDelegate.documentWidth - 22,
									offset.height + boundingRect.origin.y + 1.0,
									 22,
									 boundingRect.size.height);
			
			// Add the marker to dictionary
			[revisions[revision.colorName] addObject:[NSNumber valueWithRect:rect]];
		}
				
		glyphRange.length = NSMaxRange(glyphRange) - NSMaxRange(attributeGlyphRange);
		glyphRange.location = NSMaxRange(attributeGlyphRange);
	}
	
	for (NSString *color in BeatRevisions.revisionColors) {
		[NSGraphicsContext saveGraphicsState];
		
		NSMutableSet *rects = revisions[color];
		NSString *marker = BeatRevisions.revisionMarkers[color];
		NSColor *bgColor = ThemeManager.sharedManager.backgroundColor.effectiveColor;
		
		[rects enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
			NSRect rect = [(NSValue*)obj rectValue];
			NSMutableString *markerStr = NSMutableString.new;
			NSUInteger lineCount = round(rect.size.height / 22); // line height is 22, based on my scientific reasearch lol
			
			// Create markers by line count
			for (NSUInteger i=0; i<lineCount; i++) [markerStr appendFormat:@"%@\n", marker];

			// Draw a background rect under the marker to block out earlier markers
			[bgColor setFill];
			NSRectFill(rect);
			
			// Draw string
			[markerStr drawAtPoint:rect.origin withAttributes:@{
				NSFontAttributeName: self.textView.editorDelegate.courier,
				NSForegroundColorAttributeName: ThemeManager.sharedManager.textColor.effectiveColor
			}];
		}];
		
		[NSGraphicsContext restoreGraphicsState];
	}
}

-(void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
	[super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
		
	/*
	 
	 // Tuleville sukupolville.
	 // An die Nachgeborenen.
	 // For generations to come.
	 
	NSTextStorage *textStorage = self.textStorage;
	NSRange glyphRange = glyphsToShow;
	
	while (glyphRange.length > 0) {
		[NSGraphicsContext saveGraphicsState];
		
		NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL], attributeCharRange, attributeGlyphRange;
				
		BeatRevisionItem *revision = [textStorage attribute:@"Revision"
									  atIndex:charRange.location longestEffectiveRange:&attributeCharRange
									  inRange:charRange];
		
		attributeGlyphRange = [self glyphRangeForCharacterRange:attributeCharRange actualCharacterRange:NULL];
		attributeGlyphRange = NSIntersectionRange(attributeGlyphRange, glyphRange);
		
		if (revision.type == RevisionAddition || revision.type == RevisionCharacterRemoved) {
			// We have to create an array of ranges to accurately handle backgrounds spanning over multiple lines,
			// because I'd love to avoid the background to fill up the whitespace at line breaks.
			NSMutableArray *ranges = [NSMutableArray arrayWithObject:[NSNumber valueWithRange:attributeGlyphRange]];
			
			NSString *substr = [self.textStorage.string substringWithRange:attributeCharRange];
			NSInteger previousCutOff = -1;
			
			if ([substr containsString:@"\n"]) {
				[ranges removeAllObjects];
				
				for (NSInteger i=0; i<substr.length; i++) {
					if ([substr characterAtIndex:i] == '\n') {
						
						NSRange globalRange = NSMakeRange(charRange.location + previousCutOff + 1, i - previousCutOff - 1);
						if (globalRange.length > 0) {
							NSRange fragmentGlyphRange = [self glyphRangeForCharacterRange:globalRange actualCharacterRange:NULL];
							fragmentGlyphRange = NSIntersectionRange(fragmentGlyphRange, glyphRange);
							
							[ranges addObject:[NSNumber valueWithRange:fragmentGlyphRange]];
						}
						previousCutOff = i;
					}
				}
			}
			
			NSArray *rects;
			if (ranges.count == 1) rects = [self rectsForGlyphRange:attributeGlyphRange];
			else {
				NSMutableArray *fragmentRects = NSMutableArray.array;
				for (NSNumber *range in ranges) {
					NSRange fragmentRange = range.rangeValue;
					NSRange glyphRange = [self glyphRangeForCharacterRange:fragmentRange actualCharacterRange:nil];
					[fragmentRects addObjectsFromArray:[self rectsForGlyphRange:glyphRange]];
				}
				rects = fragmentRects;
			}
			
			[revision.backgroundColor setFill];
			for (NSNumber *val in rects) {
				NSRect rect = val.rectValue;
				rect.origin.x += self.textView.textContainerInset.width;
				rect.origin.y += self.textView.textContainerInset.height;
				NSRectFill(rect);
			}
		}
		
		glyphRange.length = NSMaxRange(glyphRange) - NSMaxRange(attributeGlyphRange);
		glyphRange.location = NSMaxRange(attributeGlyphRange);

		[NSGraphicsContext restoreGraphicsState];
	}
	*/

}



-(NSArray*)rectsForGlyphRange:(NSRange)glyphsToShow {
	NSMutableArray *rects = NSMutableArray.new;
	
	NSTextContainer *tc = self.textContainers.firstObject;
	
	[self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(NSRect rect, NSRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
		
		NSRect lfRect = [self boundingRectForGlyphRange:NSIntersectionRange(glyphsToShow, glyphRange) inTextContainer:tc];
		[rects addObject:[NSNumber valueWithRect:lfRect]];
	}];
	
	return rects;
}

@end
