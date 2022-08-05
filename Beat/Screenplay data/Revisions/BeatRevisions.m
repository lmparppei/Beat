//
//  BeatRevisions.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

/**
 
 This class manages the convoluted revisioning system.
 Note that there are only FOUR generations (for now), and they are distinguished by their COLOR and not GENERATION NUMBER.
 The number is basically their index in the array.
 
 */

#import "BeatRevisions.h"
#import "Line.h"
#import "BeatLocalization.h"
#import "BeatUserDefaults.h"

#define REVISION_ATTR @"Revision"
#define DEFAULT_COLOR @"blue"
#define REVISION_ORDER @[@"blue", @"orange", @"purple", @"green"]

#define REVISION_MARKERS @{ @"blue": @"*", @"orange": @"**", @"purple": @"+", @"green": @"++" }

#if !TARGET_OS_IOS
    #import <Cocoa/Cocoa.h>
	//#import "Beat-Swift.h"

	#define BXChangeDone NSChangeDone
#else
    #import <UIKit/UIKit.h>
	#import "Beat_iOS-Swift.h"

	#define BXChangeDone UIDocumentChangeDone
#endif

@implementation BeatRevisions

/// Returns the default color, which is FIRST generation
+ (NSString*)defaultRevisionColor {
	return DEFAULT_COLOR;
}

/// Returns all the colors, in generation order
+ (NSArray*)revisionColors {
	return REVISION_ORDER;
}
/// Returns the generation symbols for screenplay rendering
+ (NSDictionary*)revisionMarkers {
	return REVISION_MARKERS;
}
/// Rertusn the attribute key used in `NSAttributedString` created by `Line` class
+ (NSString*)attributeKey {
	return REVISION_ATTR;
}
/// Checks if the given generation is newer than the other one. This is done because generations are separated by their COLOR and not their generation.
+ (bool)isNewer:(NSString*)currentColor than:(NSString*)oldColor {
	NSArray * colors = BeatRevisions.revisionColors;
	NSInteger currentIdx = [colors indexOfObject:currentColor];
	NSInteger oldIdx = [colors indexOfObject:oldColor];
	
	if (currentIdx > oldIdx) return YES;
	else if (oldIdx == NSNotFound) return YES;
	else return NO;
}
/// Bakes the revised ranges from editor into corresponding lines in the parser.
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string parser:(ContinuousFountainParser*)parser
{
	[self bakeRevisionsIntoLines:lines text:string parser:parser includeRevisions:[self revisionColors]];
}
/// Bakes the revised ranges from editor into corresponding lines in the parser. When needed, you can specify which revisions to include.
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string parser:(ContinuousFountainParser*)parser includeRevisions:(nonnull NSArray *)includedRevisions
{
	[string enumerateAttribute:@"Revision" inRange:(NSRange){0,string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		if (range.length < 1 || range.location == NSNotFound || range.location + range.length > string.length) return;
		
		BeatRevisionItem *item = value;
		if (![includedRevisions containsObject:item.colorName]) return; // Skip if the color is not included
		
		if (item.type != RevisionNone) {
			NSArray *linesInRange = [parser linesInRange:range];
			for (Line* line in linesInRange) {
				line.changed = YES;
				
				// Set revision color
				NSString *revisionColor = item.colorName;
				if (!revisionColor.length) revisionColor = DEFAULT_COLOR;
				
				if (line.revisionColor.length) {
					// The line already has a revision color, apply the higher one
					NSInteger currentRevision = [REVISION_ORDER indexOfObject:line.revisionColor];
					NSInteger thisRevision = [REVISION_ORDER indexOfObject:revisionColor];
					
					if (thisRevision != NSNotFound && thisRevision > currentRevision) line.revisionColor = revisionColor;
				}
				else line.revisionColor = revisionColor;
				
				// Create addition & removal ranges if needed
				//if (!line.additionRanges) line.additionRanges = NSMutableIndexSet.indexSet;
				if (!line.removalSuggestionRanges) line.removalSuggestionRanges = NSMutableIndexSet.indexSet;
				
				// Create local range
				NSRange localRange = [line globalRangeToLocal:range];
				if (item.type == RevisionRemovalSuggestion) [line.removalSuggestionRanges addIndexesInRange:localRange];
				else if (item.type == RevisionAddition) {
					// Add revision sets if needed
					if (!line.revisedRanges) line.revisedRanges = NSMutableDictionary.new;
					if (!line.revisedRanges[revisionColor]) line.revisedRanges[revisionColor] = NSMutableIndexSet.new;
					
					[line.revisedRanges[revisionColor] addIndexesInRange:localRange];
				}
			}
		}
	}];
}

/// Bakes the revised ranges from editor into corresponding lines in the parser.
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string parser:(ContinuousFountainParser*)parser
{
	NSAttributedString *attrStr = [self attrStringWithRevisions:revisions string:string];
	[self bakeRevisionsIntoLines:parser.lines text:attrStr parser:parser];
}

/// Writes the given revisions into a plain text string, and returns an attributed string
+ (NSAttributedString*)attrStringWithRevisions:(NSDictionary*)revisions string:(NSString*)string {
	NSMutableAttributedString *attrStr = [NSMutableAttributedString.alloc initWithString:(string) ? string : @""];
	
	for (NSString *key in revisions.allKeys) {
		NSArray *items = revisions[key];
		
		for (NSArray *item in items) {
			NSString *color;
			NSInteger loc = [(NSNumber*)item[0] integerValue];
			NSInteger len = [(NSNumber*)item[1] integerValue];
			
			// Load color if available
			if (item.count > 2) color = item[2];
			
			// Ensure the revision is in range, find lines in range and bake revisions
			if (len > 0 && loc + len <= string.length) {
				RevisionType type;
				NSRange range = (NSRange){loc, len};
				
				if ([key isEqualToString:@"Addition"]) type = RevisionAddition;
				else if ([key isEqualToString:@"Removal"] || [key isEqualToString:@"RemovalSuggestion"]) type = RevisionRemovalSuggestion;
				else type = RevisionNone;
				
				BeatRevisionItem *revision = [BeatRevisionItem type:type color:color];
				
				if (revision.type != RevisionNone) {
					[attrStr addAttribute:REVISION_ATTR value:revision range:range];
				}
			}
		}
	}
	
	return attrStr;
}

/// Returns lines that have been changed, but not added to
+ (NSMutableDictionary*)changedLinesForSaving:(NSArray*)lines {
	NSMutableDictionary *changedLines = NSMutableDictionary.new;
		
	for (NSInteger i=0; i < lines.count; i++) {
		Line *line = lines[i];
		
		if (line.changed) {
			NSString *revisionColor = line.revisionColor;
			if (revisionColor.length == 0) revisionColor = BeatRevisions.defaultRevisionColor;
			[changedLines setValue:line.revisionColor forKey:[NSString stringWithFormat:@"%lu", i]];
		}
	}
	
	return changedLines;
}

/// Returns the revised ranges to be saved into data block of the Fountain file
+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string {
	NSMutableAttributedString *str = string.mutableCopy;
	
	NSDictionary *ranges = @{
		@"Addition": [NSMutableArray array],
		@"Removed": [NSMutableArray array],
		@"RemovalSuggestion": [NSMutableArray array]
	};
	
	// Find all line breaks and remove the revision attributes
	NSRange searchRange = NSMakeRange(0,1);
	NSRange foundRange;
	
	while (searchRange.location < string.length) {
		searchRange.length = string.length-searchRange.location;
		foundRange = [string.string rangeOfString:@"\n" options:0 range:searchRange];
		
		if (foundRange.location != NSNotFound) {
			[str setAttributes:nil range:foundRange]; // Remove attributes from line berak
			searchRange.location = foundRange.location+foundRange.length; // Continue the search
		} else {
			// Done
			break;
		}
	}
	
	// Enumerate through revisions and save them.
	[str enumerateAttribute:@"Revision" inRange:(NSRange){0,string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *item = value;
		
		if (item.type != RevisionNone) {
			NSMutableArray *values = ranges[item.key];
			
			NSArray *lastItem = values.lastObject;
			NSInteger lastLoc = [(NSNumber*)lastItem[0] integerValue];
			NSInteger lastLen = [(NSNumber*)lastItem[1] integerValue];
			NSString *lastColor = lastItem[2];
			
			if (lastLoc + lastLen == range.location && [lastColor isEqualToString:item.colorName]) {
				// This is a continuation of the last range
				values[values.count-1] = @[@(lastLoc), @(lastLen + range.length), item.colorName];
			} else {
				// This is a new range
				[values addObject:@[@(range.location), @(range.length), item.colorName]];
			}
		}
	}];
	
	return ranges;
}

#pragma mark - Editor methods

/// Setup the class: Loads revisions from the current document (via delegate) and adds them into the editor string.
/// @warning Might break iOS compatibility if not handled with care.
- (void)setup {
	// This loads revisions from the file
	_delegate.revisionColor = [_delegate.documentSettings getString:DocSettingRevisionColor];
	if (![_delegate.revisionColor isKindOfClass:NSString.class] || !_delegate.revisionColor) _delegate.revisionColor = BeatRevisions.defaultRevisionColor;
	
	// Get revised ranges from document settings and iterate through them
	NSDictionary *revisions = [_delegate.documentSettings get:DocSettingRevisions];
	
	for (NSString *key in revisions.allKeys) {
		NSArray *items = revisions[key];
		
		for (NSArray *item in items) {
			NSString *color;
			NSInteger loc = [(NSNumber*)item[0] integerValue];
			NSInteger len = [(NSNumber*)item[1] integerValue];
			
			// Load color if available
			if (item.count > 2) color = item[2];
			if (color.length == 0) color = BeatRevisions.defaultRevisionColor;
			
			// Ensure the revision is in range and then paint it
			if (len > 0 && loc + len <= _delegate.text.length) {
				// Check revision type
				RevisionType type;
				NSRange range = (NSRange){loc, len};
				
				if ([key isEqualToString:@"Addition"]) type = RevisionAddition;
				else if ([key isEqualToString:@"Removal"] || [key isEqualToString:@"RemovalSuggestion"]) type = RevisionRemovalSuggestion;
				else type = RevisionNone;
				
				// Create the revision item
				BeatRevisionItem *revisionItem = [BeatRevisionItem type:type color:color];
				if (revisionItem) [_delegate.textView.textStorage addAttribute:REVISION_ATTR value:revisionItem range:range];
				
				// Also, find out the line and set their revision color.
				// This is mostly done for compatibility with lines saved using earlier than 1.931.
				NSArray *linesInRange = [self.delegate.parser linesInRange:range];
				for (Line* l in linesInRange) {
					if (l.type == empty) continue;
					
					l.changed = YES;
					
					if (l.revisionColor.length) {
						if ([BeatRevisions isNewer:revisionItem.colorName than:l.revisionColor]) {
							l.revisionColor = color;
						}
					} else {
						l.revisionColor = color;
					}
				}
			}
		}
	}
	
	// Load changed indices (legacy support + handles REMOVALS rather than additions)
	NSDictionary *changedIndices = [self.delegate.documentSettings get:DocSettingChangedIndices];
	
	// Check for correct class
	if ([changedIndices isKindOfClass:NSDictionary.class]) {
		for (NSString* val in changedIndices.allKeys) {
			NSString *revisionColor = changedIndices[val];
			if (revisionColor) {
				@try {
					Line *l = self.delegate.parser.lines[val.integerValue];
					l.changed = YES;
					l.revisionColor = revisionColor;
				}
				@catch (NSException *e) {
					NSLog(@"ERROR: Changed index outside of range");
				}
			}
		}
	}
		
	bool revisionMode = [_delegate.documentSettings getBool:DocSettingRevisionMode];
	if (revisionMode) {
		self.delegate.revisionMode = YES;
		[self.delegate updateQuickSettings];
	}
}


/// Move to next revision marker
- (void)nextRevision {
    NSString *string;
#if TARGET_OS_IOS
    string = _delegate.textView.text;
#else
    string = _delegate.textView.string;
#endif
    
	NSRange selectedRange = _delegate.selectedRange;
	
	// Find out if we are inside or at the beginning of a revision right now
	NSUInteger searchLocation = selectedRange.location;
	
	NSRange effectiveRange;
	BeatRevisionItem *revision = [_delegate.textView.textStorage attribute:@"Revision" atIndex:selectedRange.location effectiveRange:&effectiveRange];
	if (revision) searchLocation = NSMaxRange(effectiveRange);
	
	__block NSRange revisionRange = NSMakeRange(NSNotFound, 0);
	[_delegate.textView.textStorage enumerateAttribute:@"Revision"
											   inRange:NSMakeRange(searchLocation, string.length - searchLocation)
											   options:0
											usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *revision = value;
		if (revision.type != RevisionNone) {
			*stop = YES;
			revisionRange = range;
		}
	}];
	
	if (revisionRange.location != NSNotFound) {
		[self.delegate scrollToRange:NSMakeRange(revisionRange.location, 0)];
	}
}

/// Move to previous revision marker
- (void)previousRevision {
	NSRange selectedRange = _delegate.selectedRange;
	
	// Find out if we are inside or at the beginning of a revision right now
	NSUInteger searchLocation = selectedRange.location;
	
	NSRange effectiveRange;
	BeatRevisionItem *revision = [_delegate.textView.textStorage attribute:@"Revision" atIndex:selectedRange.location effectiveRange:&effectiveRange];
	if (revision) {
		//NSLog(@"Revision: %@  // %@", revision.colorName, [_delegate.textView.string substringWithRange:effectiveRange]);
		searchLocation = effectiveRange.location;
	}
	
	__block NSRange revisionRange = NSMakeRange(NSNotFound, 0);
	
	[_delegate.textView.textStorage enumerateAttribute:@"Revision"
											   inRange:NSMakeRange(0, searchLocation - 1)
											   options:NSAttributedStringEnumerationReverse
											usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *revision = value;
		if (revision.type != RevisionNone) {
			*stop = YES;
			revisionRange = range;
		}
	}];
	
	if (revisionRange.location != NSNotFound) {
		[self.delegate scrollToRange:NSMakeRange(revisionRange.location, 0)];
	}
}

#pragma mark - Actions

/// Generic method for adding a revisino marker, no matter the type
- (void)markerAction:(RevisionType)type {
	[self markerAction:type range:_delegate.selectedRange];
}
- (void)markerAction:(RevisionType)type range:(NSRange)range {
	// Content can't be marked as revised when locked, and only allow this for editor view
	if (_delegate.contentLocked) return;
	if (range.location == NSNotFound) return;
	
	if (type == RevisionRemovalSuggestion && range.length == 0) return;

	// Save old attributes in selected range
	// CONSIDER MOVING THIS+UNDO STEP TO THE ACTUAL METHODS
	__block NSAttributedString *attrStr = [_delegate.textView.textStorage attributedSubstringFromRange:range];
	__block NSRange originalRange = range;
	
	// Run the actual action
	if (type == RevisionRemovalSuggestion) [self markRangeForRemoval:range];
	else if (type == RevisionAddition) [self markRangeAsAddition:range];
	else [self clearReviewMarkers:range];
	
	[_delegate.textView setSelectedRange:(NSRange){range.location + range.length, 0}];
	[_delegate updateChangeCount:BXChangeDone];
	[_delegate updatePreview];
	
	// Create an undo step

	[_delegate.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
		[attrStr enumerateAttribute:BeatRevisions.attributeKey inRange:NSMakeRange(0, attrStr.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
			if (range.length == 0) return;
			BeatRevisionItem *revision = value;
			
			if (revision) {
				NSRange attrRange = NSMakeRange(originalRange.location + range.location, range.length);
				[self.delegate.textView.textStorage addAttribute:BeatRevisions.attributeKey value:revision range:attrRange];
			}
		}];

		[self.delegate renderBackgroundForRange:originalRange];
	}];
		
	// Refresh backgrounds
	[_delegate renderBackgroundForRange:range];
}

- (void)markRangeAsAddition:(NSRange)range {
	BeatRevisionItem *revision = [BeatRevisionItem type:RevisionAddition color:_delegate.revisionColor];
	if (revision) [_delegate.textView.textStorage addAttribute:REVISION_ATTR value:revision range:range];
}
- (void)markRangeForRemoval:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionRemovalSuggestion];
	if (revision) [_delegate.textView.textStorage addAttribute:REVISION_ATTR value:revision range:range];
}
- (void)clearReviewMarkers:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionNone];
	if (revision) [_delegate.textView.textStorage addAttribute:REVISION_ATTR value:revision range:range];
}

#if !TARGET_OS_IOS

/// An experimental method which removes any text suggested to be removed and clears all revisions.
- (void)commitRevisions {
	NSAlert *alert = NSAlert.new;
	alert.showsSuppressionButton = YES;
	
	bool dontAsk = [BeatUserDefaults.sharedDefaults isSuppressed:@"commitRevisions"];
	
	if (!dontAsk) {
		alert.messageText = [BeatLocalization localizeString:@"#revisions.commitPrompt.title#"];
		alert.informativeText = [BeatLocalization localizeString:@"#revisions.commitPrompt.text#"];
		
		[alert addButtonWithTitle:[BeatLocalization localizeString:@"#general.OK#"]];
		[alert addButtonWithTitle:[BeatLocalization localizeString:@"#general.cancel#"]];
		alert.buttons[1].keyEquivalent = [NSString stringWithFormat:@"%C", 0x1b];
		
		NSModalResponse result = [alert runModal];
		
		if (alert.suppressionButton.state == NSOnState) {
			[BeatUserDefaults.sharedDefaults setSuppressed:@"commitRevisions" value:YES];
		}
		
		if (result != NSAlertFirstButtonReturn) return;
	}
	
	// First find any ranges suggested for removal
	
	[_delegate.textView.attributedString enumerateAttribute:BeatRevisions.attributeKey inRange:NSMakeRange(0, _delegate.text.length) options:NSAttributedStringEnumerationReverse usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *revision = value;
		
		if (revision.type == RevisionRemovalSuggestion && range.length > 0) {
			[self markerAction:RevisionNone range:range];
			[self.delegate replaceRange:range withString:@""];
			
			[self.delegate renderBackgroundForLines];
		}
	}];
	
	// Then clear all attributes
	[self markerAction:RevisionNone range:NSMakeRange(0, _delegate.text.length)];
	for (Line* line in _delegate.lines) [_delegate renderBackgroundForLine:line clearFirst:YES];

}

#endif

@end
/*
 
 let the right one in
 let the old dreams die
 
 */
