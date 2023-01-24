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
#import "BeatEditorFormatting.h"
#import "BeatMeasure.h"

@interface BeatLayoutManager()
@property (nonatomic) NSMutableParagraphStyle* _Nullable markerStyle;
@property (nonatomic) NSMutableParagraphStyle* _Nullable sceneNumberStyle;
@end

@implementation BeatLayoutManager

@dynamic delegate;

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
	if (_markerStyle == nil) {
		_markerStyle = NSMutableParagraphStyle.new;
		_markerStyle.minimumLineHeight = BeatEditorFormatting.editorLineHeight;
	}
	
	if (!self.textView) {
		NSLog(@"WARNING: No text view set for BeatLayoutManager.");
		[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
		return;
	}
	
	// Replace some glyphs
	//Line* line = [self.delegate.editorDelegate.parser lineAtPosition:];
	
	[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
		
	[self drawSceneNumberForGlyphRange:glyphsToShow];
	[self drawRevisionMarkers:glyphsToShow];
}

- (void)drawSceneNumberForGlyphRange:(NSRange)glyphRange {
	// Scene number drawing is off, return
	if (!self.textView.editorDelegate.showSceneNumberLabels) return;
	
	// Create the style if needed
	if (_sceneNumberStyle == nil) {
		_sceneNumberStyle = NSMutableParagraphStyle.new;
		_sceneNumberStyle.minimumLineHeight = BeatEditorFormatting.editorLineHeight;
	}
	
	NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
	
	[self.textStorage enumerateAttribute:@"representedLine" inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		Line* line = (Line*)value;
		if (line == nil || line.type != heading) return;
		
		NSRange headingRange = NSMakeRange(line.position, 1);
		if (self.textView.editorDelegate.hideFountainMarkup) {
			if (line.length > 1) headingRange.location += 1;
			else headingRange = line.range;
		}
		
		NSRange lineRange = [self glyphRangeForCharacterRange:headingRange actualCharacterRange:nil];
		NSRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:self.textContainers.firstObject];
		
		// Calculate rect for the marker position
		NSRect rect = NSMakeRect(self.textView.textContainerInset.width,
								 self.textView.textContainerInset.height + boundingRect.origin.y,
								 7.5 * line.sceneNumber.length,
								 boundingRect.size.height + 1.0);
		
		NSColor* color;
		if (line.color.length > 0) color = [BeatColors color:line.color];
		if (color == nil) color = ThemeManager.sharedManager.textColor.effectiveColor;
		
		NSString *sceneNumber = line.sceneNumber;
		[sceneNumber drawAtPoint:rect.origin withAttributes:@{
			NSFontAttributeName: self.textView.editorDelegate.courier,
			NSForegroundColorAttributeName: color,
			NSParagraphStyleAttributeName: self.sceneNumberStyle
		}];
	}];
}


-(void)drawRevisionMarkers:(NSRange)glyphRange {
	/*
	 
	 This works in a peculiar way:
	 We'll store the NSRect of each marker range into a set using NSNumber, so there will
	 never be two overlapping rects. Those rects are put in a dictionary entry under the
	 revision color.
	 
	 After all glyphs have been iterated, we'll draw the marker strings and draw a rect
	 under them - and voilà: latest revision markers block out the earlier ones.
	 
	 It's a bit convoluted scheme, but works surprisingly well and efficiently.
	 
	 2022/12: Thanks, past me, for this completely useless documentation.
	 
	*/
	
	
	NSTextStorage* textStorage = self.textStorage;
	NSTextContainer* textContainer = self.textContainers.firstObject;
	NSSize offset = textContainer.textView.textContainerInset;
	
	NSMutableDictionary<NSString*, NSMutableSet<NSValue*>*> *revisions = NSMutableDictionary.new;
	for (NSString *string in BeatRevisions.revisionColors) revisions[string] = NSMutableSet.new;
	
	while (glyphRange.length > 0) {
		// Get character range for the range we're displaying
		NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL], attributeCharRange, attributeGlyphRange;
		
		// Get revision attributes at this range
		BeatRevisionItem *revision = [textStorage attribute:BeatRevisions.attributeKey
													atIndex:charRange.location longestEffectiveRange:&attributeCharRange
													inRange:charRange];
		// Get actual glyphs
		attributeGlyphRange = [self glyphRangeForCharacterRange:attributeCharRange actualCharacterRange:NULL];
		// Get intersection range between the glyphs being displayed and the actual attribute range
		attributeGlyphRange = NSIntersectionRange(attributeGlyphRange, glyphRange);
				
		// Check if there actually was a revision attribute
		if ((revision.type == RevisionAddition || revision.type == RevisionCharacterRemoved) && revision != nil && revision.colorName != nil) {
			// Get bounding rect for the range
			NSRect boundingRect = [self boundingRectForGlyphRange:attributeGlyphRange
												  inTextContainer:textContainer];
			
			// Calculate rect for the marker position
			NSRect rect = NSMakeRect(offset.width + _textView.documentWidth - 22,
									offset.height + boundingRect.origin.y,
									 22,
									 boundingRect.size.height + 1.0);
			
			// Add the marker to dictionary:
			// dict["colorName"][] -> rect
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
			NSUInteger lineCount = round(rect.size.height / BeatEditorFormatting.editorLineHeight);
			
			// Create markers by line count
			for (NSUInteger i=0; i<lineCount; i++) {
				[markerStr appendFormat:@"%@\n", marker];
			}

			// Draw a background rect under the marker to block out earlier markers
			[bgColor setFill];
			NSRectFill(rect);
			
			// Draw string
			[markerStr drawAtPoint:rect.origin withAttributes:@{
				NSFontAttributeName: self.textView.editorDelegate.courier,
				NSForegroundColorAttributeName: ThemeManager.sharedManager.textColor.effectiveColor,
				NSParagraphStyleAttributeName: _markerStyle
			}];
		}];
		
		[NSGraphicsContext restoreGraphicsState];
	}
}

-(void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
	[super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
		
	/*
	NSRange charRange = [self characterRangeForGlyphRange:glyphsToShow actualGlyphRange:NULL];
	
	NSArray *lines = [self.delegate.editorDelegate.parser linesInRange:charRange];
	
	for (Line *l in lines) {
		if (l.markerRange.length > 0) {
			NSRange markerRange = NSMakeRange(l.position + l.markerRange.location, l.markerRange.length);
			NSRange glyphRange = [self glyphRangeForCharacterRange:markerRange actualCharacterRange:nil];
			NSArray * rects = [self rectsForGlyphRange:glyphRange];
			
			for (NSValue* v in rects) {
				NSRect r = v.rectValue;
				r.origin.x += self.textView.textContainerInset.width;
				r.origin.y += self.textView.textContainerInset.height;

				NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:r xRadius:3 yRadius:3];
				
				NSColor * color = [BeatColors color:l.marker];
				//if (NSLocationInRange(self.textView.selectedRange.location, l.range)) color = [color colorWithAlphaComponent:.1];
				color = [color colorWithAlphaComponent:.1];
				
				if (color != nil) {
					[color setFill];
					[path fill];
				}
			}
		}
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
