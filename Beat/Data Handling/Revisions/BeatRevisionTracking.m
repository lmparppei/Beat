//
//  BeatRevisionTracking.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This is used in Preview and Export to bake attributed ranges into the screenplay.
 
 */

#import "BeatRevisionTracking.h"
#import "Line.h"
#import "BeatLocalization.h"
#import "BeatUserDefaults.h"

#define REVISION_ATTR @"Revision"
#define DEFAULT_COLOR @"blue"
#define REVISION_ORDER @[@"blue", @"orange", @"purple", @"green"]

#define REVISION_MARKERS @{ @"blue": @"*", @"orange": @"**", @"purple": @"+", @"green": @"++" }

#if !TARGET_OS_IOS
    #import <Cocoa/Cocoa.h>
#else
    #import <UIKit/UIKit.h>
#endif

@implementation BeatRevisionTracking

+ (NSString*)defaultRevisionColor {
	return DEFAULT_COLOR;
}

+ (NSArray*)revisionColors {
	return REVISION_ORDER;
}
+ (NSDictionary*)revisionMarkers {
	return REVISION_MARKERS;
}
+ (NSString*)revisionAttribute {
	return REVISION_ATTR;
}

+ (bool)isNewer:(NSString*)currentColor than:(NSString*)oldColor {
	NSArray * colors = BeatRevisionTracking.revisionColors;
	NSInteger currentIdx = [colors indexOfObject:currentColor];
	NSInteger oldIdx = [colors indexOfObject:oldColor];
	
	if (currentIdx > oldIdx) return YES;
	else if (oldIdx == NSNotFound) return YES;
	else return NO;
}
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string parser:(ContinuousFountainParser*)parser
{
	[self bakeRevisionsIntoLines:lines text:string parser:parser includeRevisions:[self revisionColors]];
}

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

+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string parser:(ContinuousFountainParser*)parser
{
	
	NSAttributedString *attrStr = [self attrStringWithRevisions:revisions string:string];
	[self bakeRevisionsIntoLines:parser.lines text:attrStr parser:parser];
	
	/*
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
						
						// Set revision color
						line.revisionColor = revision.colorName;
						if (!line.revisionColor.length) line.revisionColor = DEFAULT_COLOR;
						
						if (!line.removalRanges) line.removalRanges = [NSMutableIndexSet indexSet];
						
						NSRange localRange = [line globalRangeToLocal:range];
						if (revision.type == RevisionRemoval) [line.removalRanges addIndexesInRange:localRange];
						else if (revision.type == RevisionAddition) [line.additionRanges addIndexesInRange:localRange];
					}
				}
			}
		}
	}
	 */
}

+ (NSAttributedString*)attrStringWithRevisions:(NSDictionary*)revisions string:(NSString*)string {
	NSMutableAttributedString *attrStr = [NSMutableAttributedString.alloc initWithString:string];
	
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

+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string {
	NSMutableAttributedString *str = string.mutableCopy;
	
	NSDictionary *ranges = @{
		@"Addition": [NSMutableArray array],
		@"Removed": [NSMutableArray array],
		@"RemovalSuggestion": [NSMutableArray array],
		@"Comment": [NSMutableArray array]
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

- (void)loadRevisionMarkers {

	// Load changed indices
	NSDictionary *changedIndices = [self.delegate.documentSettings get:DocSettingChangedIndices];
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

- (void)setupRevisions {
	// This loads revisions from the file
	_delegate.revisionColor = [_delegate.documentSettings getString:DocSettingRevisionColor];
	if (![_delegate.revisionColor isKindOfClass:NSString.class] || !_delegate.revisionColor) _delegate.revisionColor = BeatRevisionTracking.defaultRevisionColor;
	
	// First load all changed indices
	// [self loadRevisionMarkers];
	
	// Second, get revised ranges from document settings and iterate through them
	NSDictionary *revisions = [_delegate.documentSettings get:DocSettingRevisions];
	
	for (NSString *key in revisions.allKeys) {
		NSArray *items = revisions[key];
		
		for (NSArray *item in items) {
			NSString *color;
			NSInteger loc = [(NSNumber*)item[0] integerValue];
			NSInteger len = [(NSNumber*)item[1] integerValue];
			
			// Load color if available
			if (item.count > 2) color = item[2];
			if (color.length == 0) color = BeatRevisionTracking.defaultRevisionColor;
			
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
						if ([BeatRevisionTracking isNewer:revisionItem.colorName than:l.revisionColor]) {
							l.revisionColor = color;
						}
					} else {
						l.revisionColor = color;
					}
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

#if TARGET_OS_IOS


#else

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
	[_delegate updateChangeCount:NSChangeDone];
	[_delegate updatePreview];
	
	// Create an undo step

	[_delegate.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
		[attrStr enumerateAttribute:BeatRevisionTracking.revisionAttribute inRange:NSMakeRange(0, attrStr.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
			if (range.length == 0) return;
			BeatRevisionItem *revision = value;
			
			if (revision) {
				NSRange attrRange = NSMakeRange(originalRange.location + range.location, range.length);
				[self.delegate.textView.textStorage addAttribute:BeatRevisionTracking.revisionAttribute value:revision range:attrRange];
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
	
	[_delegate.textView.attributedString enumerateAttribute:BeatRevisionTracking.revisionAttribute inRange:NSMakeRange(0, _delegate.text.length) options:NSAttributedStringEnumerationReverse usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
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
