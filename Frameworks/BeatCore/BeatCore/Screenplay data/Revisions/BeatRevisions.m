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
 
 __Update 2023/11:__ I've started a very slow conversion to use generation numbers rather than colors, but it requires a very deep rewrite.
 
 */

#import <BeatParsing/BeatParsing.h>
#import "BeatUserDefaults.h"
#import "BeatRevisions.h"
#import "BeatLocalization.h"
#import "BeatAttributes.h"
#import <BeatCore/BeatEditorFormatting.h>

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
	//#import "Beat_iOS-Swift.h"

	#define BXChangeDone UIDocumentChangeDone
#endif

@implementation BeatRevisionGeneration
+ (instancetype)withColor:(NSString*)color marker:(NSString*)marker {
    return [BeatRevisionGeneration.alloc initWithColor:color marker:marker];
}

- (instancetype)initWithColor:(NSString*)color marker:(NSString*)marker
{
    self = [super init];
    if (self) {
        self.color = color;
        self.marker = marker;
    }
    return self;
}
@end

@implementation BeatRevisions

+ (void)initialize {
    [super initialize];
    [BeatAttributes registerAttribute:BeatRevisions.attributeKey];
}


#pragma mark - Class convenenience methods

/// Returns the default color, which is FIRST generation
+ (NSString*)defaultRevisionColor { return DEFAULT_COLOR; }

/// Returns all the colors, in generation order
+ (NSArray<NSString*>*)revisionColors { return REVISION_ORDER; }

/// Returns the modern revisions.
+ (NSArray<BeatRevisionGeneration*>*)revisionGenerations
{
    static NSArray* generations;
    
    if (generations == nil) {
        generations = @[
            [BeatRevisionGeneration withColor:@"blue" marker:@"*"],
            [BeatRevisionGeneration withColor:@"orange" marker:@"**"],
            [BeatRevisionGeneration withColor:@"purple" marker:@"+"],
            [BeatRevisionGeneration withColor:@"green" marker:@"++"]
        ];
    }
    
    return generations;
}

/// Convenience method for getting the relevant generation
+ (BeatRevisionGeneration*)generationForColor:(NSString*)color
{
    for (BeatRevisionGeneration* gen in BeatRevisions.revisionGenerations) {
        if ([gen.color isEqualToString:color]) return gen;
    }
    return nil;
}

/// Returns the generation symbols for screenplay rendering
+ (NSDictionary<NSString*, NSString*>*)revisionMarkers {
	return REVISION_MARKERS;
}

/// Rertusn the attribute key used in `NSAttributedString` created by `Line` class
+ (NSString*)attributeKey {
	return REVISION_ATTR;
}
/// Returns a dictionary with "color/generation" -> generation level, ie. "blue" : 0
+ (NSDictionary*)revisionLevels {
    NSMutableDictionary* levels = NSMutableDictionary.new;
    NSArray* colors = BeatRevisions.revisionColors;
    for (NSInteger i=0; i<colors.count; i++) {
        levels[colors[i]] = @(i);
    }
    return levels;
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

+ (void)bakeRevisionsIntoLines:(NSArray *)lines text:(NSAttributedString *)string range:(NSRange)range {
	//
}

/// Bakes the revised ranges from editor into corresponding lines in the parser.
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string
{
	[self bakeRevisionsIntoLines:lines text:string includeRevisions:[self revisionColors]];
}
/// Bakes the revised ranges from editor into corresponding lines in the parser. When needed, you can specify which revisions to include.
+ (void)bakeRevisionsIntoLines:(NSArray*)lines text:(NSAttributedString*)string includeRevisions:(nonnull NSArray *)includedRevisions
{
	// This is a new implementation of the old code, which enumerates line ranges instead of the whole attributed string and then iterating over lines.
	// Slower with short documents, 90 times faster on longer ones.
	for (Line* line in lines) { 
		line.revisedRanges = NSMutableDictionary.new;
		if (line.textRange.length == 0) continue;
		
		// Don't go out of range
		NSRange textRange = line.textRange;
		
		if (NSMaxRange(textRange) > string.length) {
			textRange.length = string.length - NSMaxRange(textRange);
			if (textRange.length <= 0) continue;
		}
		
		@try { @autoreleasepool {
			[string enumerateAttribute:BeatRevisions.attributeKey inRange:textRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
				// Don't go out of range
				if (range.length == 0 || range.location == NSNotFound || NSMaxRange(range) > string.length) return;
				
				BeatRevisionItem *revision = value;
				if (![includedRevisions containsObject:revision.colorName] || revision.type == RevisionNone) return; // Skip if the color is not included
				
				line.changed = YES;
				NSString *revisionColor = revision.colorName;
				if (revisionColor.length == 0) revisionColor = BeatRevisions.defaultRevisionColor;
				
				if (line.revisionColor.length) {
					// The line already has a revision color, apply the higher one
					NSInteger currentRevision = [REVISION_ORDER indexOfObject:line.revisionColor];
					NSInteger thisRevision = [REVISION_ORDER indexOfObject:revisionColor];
					
					if (thisRevision != NSNotFound && thisRevision > currentRevision) line.revisionColor = revisionColor;
				}
				else {
					line.revisionColor = revisionColor;
				}
				
				// Create addition & removal ranges if needed
				if (!line.removalSuggestionRanges) line.removalSuggestionRanges = NSMutableIndexSet.new;
				
				// Create local range
				NSRange localRange = [line globalRangeToLocal:range];
				
				// Save the revised indices based on the local range
				if (revision.type == RevisionRemovalSuggestion) [line.removalSuggestionRanges addIndexesInRange:localRange];
				else if (revision.type == RevisionAddition) {
					// Add revision sets if needed
					if (!line.revisedRanges) line.revisedRanges = NSMutableDictionary.new;
					if (!line.revisedRanges[revisionColor]) line.revisedRanges[revisionColor] = NSMutableIndexSet.new;
					
					[line.revisedRanges[revisionColor] addIndexesInRange:localRange];
				}
			}];
		} }
		@catch (NSException *e) {
			NSLog(@"Bake attributes: Line out of range  (%lu/%lu) -  %@", textRange.location, textRange.length, line);
		}
	}
}

/// Bakes the revised ranges from editor into corresponding lines in the parser.
+ (void)bakeRevisionsIntoLines:(NSArray*)lines revisions:(NSDictionary*)revisions string:(NSString*)string
{
	NSAttributedString *attrStr = [self attrStringWithRevisions:revisions string:string];
	[self bakeRevisionsIntoLines:lines text:attrStr];
}


#pragma mark Attributed string

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


#pragma mark JSON data for saved files

/// Returns lines that have been changed, but not added to
+ (NSMutableDictionary*)changedLinesForSaving:(NSArray*)lines {
    NSMutableDictionary *changedLines = NSMutableDictionary.new;
        
    for (NSInteger i=0; i < lines.count; i++) {
        Line *line = lines[i];
        
        if (line.changed) {
            NSString *revisionColor = line.revisionColor;
            if (revisionColor.length == 0) revisionColor = BeatRevisions.defaultRevisionColor;
            [changedLines setValue:revisionColor forKey:[NSString stringWithFormat:@"%lu", i]];
        }
    }
    
    return changedLines;
}

/// Returns the revised ranges to be saved into data block of the Fountain file
+ (NSDictionary*)rangesForSaving:(NSAttributedString*)string {
    NSMutableAttributedString *str = string.mutableCopy;
    
    NSDictionary *ranges = @{
        @"Addition": NSMutableArray.new,
        @"Removed": NSMutableArray.new,
        @"RemovalSuggestion": NSMutableArray.new
    };
    
    // Enumerate through revisions and save them.
    [str enumerateAttribute:BeatRevisions.attributeKey inRange:(NSRange){0,string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
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


#pragma mark - Instance methods

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate {
    self = [super init];
    if (self) {
        self.delegate = delegate;
        [self setup];
    }
    return self;
}


/// Adds  revision attributes from the delegate
- (void)loadRevisions {
    NSDictionary* revisions = [_delegate.documentSettings get:DocSettingRevisions];
    if (revisions == nil) return;
    
    [self loadRevisionsFromDictionary:revisions];
}

/// Adds given revision attributes using a `BeatEditorDelegate`
- (void)loadRevisionsFromDictionary:(NSDictionary*)revisions {
    id d;
    if (_delegate != nil) d = _delegate;
    else if (_revisionDelegate != nil) d = _revisionDelegate;

    for (NSString *key in revisions.allKeys) {
        NSArray *items = revisions[key];
        
        for (NSArray *item in items) {
            NSString *color;
            NSInteger loc = [(NSNumber*)item[0] integerValue];
            NSInteger len = [(NSNumber*)item[1] integerValue];
            
            // Load color if available
            if (item.count > 2) color = item[2];
            
            // Ensure the revision is in range, find lines in range and bake revisions
            if (len > 0 && loc + len <= _delegate.text.length) {
                RevisionType type;
                NSRange range = (NSRange){loc, len};
                
                if ([key isEqualToString:@"Addition"]) type = RevisionAddition;
                else if ([key isEqualToString:@"Removal"] || [key isEqualToString:@"RemovalSuggestion"]) type = RevisionRemovalSuggestion;
                else type = RevisionNone;
                
                BeatRevisionItem *revision = [BeatRevisionItem type:type color:color];
                
                if (revision.type != RevisionNone) {
                    [d addAttribute:BeatRevisions.attributeKey value:revision range:range];
                }
            }
        }
    }
    
}


#pragma mark - Editor methods

#pragma mark Setup the class & load revisions

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
				if (revisionItem) [_delegate.textStorage addAttribute:REVISION_ATTR value:revisionItem range:range];
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
		
	// Set the mode in editor
	bool revisionMode = [_delegate.documentSettings getBool:DocSettingRevisionMode];
	if (revisionMode) { self.delegate.revisionMode = YES; }
}

/// Combines single, orphaned revision attributes to longer ranges
- (void)fixRevisionAttributesInRange:(NSRange)fullRange
{
    NSTextStorage *textStorage = self.delegate.textStorage;
    
    __block NSRange currentRange = NSMakeRange(NSNotFound, 0);
    __block BeatRevisionItem* previousRevision;
    
    [textStorage beginEditing];
    
    NSAttributedString* text = textStorage.copy;
    [text enumerateAttribute:BeatRevisions.attributeKey inRange:fullRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        BeatRevisionItem* revision = value;
        
        bool revisionsMatch = [revision.colorName isEqualToString:previousRevision.colorName] && revision.type == previousRevision.type;
                
        if ((!revisionsMatch || range.location != NSMaxRange(currentRange)) && previousRevision != nil) {
            // Revision generation changed or the range is not continuous, so let's add the attribute
            [textStorage addAttribute:BeatRevisions.attributeKey value:previousRevision range:currentRange];
            previousRevision = nil;
        }
        
        if (revision == nil) return;
        
        if (previousRevision == nil) {
            currentRange = range;
            previousRevision = revision;
        } else {
            currentRange.length += range.length;
        }
    }];
    
    // Add the last revision
    if (previousRevision != nil && currentRange.length > 0) {
        [textStorage addAttribute:BeatRevisions.attributeKey value:previousRevision range:currentRange];
    }
    
    [textStorage endEditing];
}


#pragma mark Register changes

/// This is for registering changes via `NSTextStorage` delegate method `didProcessEditing`.
- (void)registerChangesWithLocation:(NSInteger)location length:(NSInteger)length delta:(NSInteger)delta {
    if (delta < 0 && length == 0) {
        // This is a removal.
        // In the near future, we'll add a removal marker here.
        if (delta > 0) location -= labs(delta);
        else location -= 1;
        length = 1;
    }
    
    if (location < 0) return;
    
    [self registerChangesInRange:NSMakeRange(location, length)];
    
    // Fix the attributes on this line to avoid zillions of extra attributes
    Line* editedLine = [self.delegate.parser lineAtPosition:location];
    [self fixRevisionAttributesInRange:editedLine.textRange];
}

/// When in revision mode, this method automatically adds revision markers to given range. Should only invoked when editing has happened.
- (void)registerChangesInRange:(NSRange)range {
    // Avoid going out of range
    if (NSMaxRange(range) > self.delegate.text.length) return;
    
	NSString * change = [self.delegate.text substringWithRange:range];

	// Check if this was just a line break
	if (range.length < 2) {
		Line * line = [_delegate.parser lineAtPosition:range.location];
		
		if ([change isEqualToString:@"\n"]) {
			// This was a line break. If it was at the end of a line, reduce that line from the range.
			if (NSMaxRange(range) == NSMaxRange(line.range)) return;
		}
	}
	
	[_delegate.textStorage removeAttribute:BeatRevisions.attributeKey range:range];
	[_delegate.textStorage addAttribute:BeatRevisions.attributeKey value:[BeatRevisionItem type:RevisionAddition color:_delegate.revisionColor] range:range];
}


#pragma mark Conversions

- (void)removeRevisionGenerations:(NSArray<BeatRevisionGeneration*>*)generations
{
    //
}

/// Converts a revision generation to another.
/// @param original The generation to convert
/// @param newGen Target generation. Passing a `nil` parameter will remove the original generation.
- (void)convertRevisionGeneration:(BeatRevisionGeneration*)original to:(BeatRevisionGeneration* _Nullable)newGen {
    [self convertRevisionGeneration:original to:newGen range:NSMakeRange(0, self.delegate.text.length)];
}
/// Converts a revision generation to another.
/// @param original The generation to convert
/// @param newGen Target generation. Passing a `nil` parameter will remove the original generation.
/// @param convertedRange The range in which the conversion happens
- (void)convertRevisionGeneration:(BeatRevisionGeneration*)original to:(BeatRevisionGeneration* _Nullable)newGen range:(NSRange)convertedRange
{
    NSAttributedString* text = self.delegate.getAttributedText;

    // Store old revisions for undoing
    NSDictionary* oldRevisions = [BeatRevisions rangesForSaving:text];
    
    [text enumerateAttribute:BeatRevisions.attributeKey inRange:convertedRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {

        BeatRevisionItem* revision = (BeatRevisionItem*)value;
        if (revision == nil || revision.type == RevisionNone || ![revision.colorName isEqualToString:original.color]) return;
        
        if (newGen != nil) {
            // convert to another generation
            BeatRevisionItem* newRevision = [BeatRevisionItem type:revision.type color:newGen.color];
            if (newRevision) [self.delegate.textStorage addAttribute:BeatRevisions.attributeKey value:newRevision range:range];
        } else {
            [self.delegate.textStorage removeAttribute:BeatRevisions.attributeKey range:range];
        }
    }];
    
    // Update foreground colors in revised range if needed
    if (self.delegate.showRevisedTextColor) {
        [self.delegate.formatting refreshRevisionTextColorsInRange:convertedRange];
    }
    
    [self.delegate.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
        [self.delegate.documentSettings set:DocSettingRevisions as:oldRevisions];
        [self setup];
    }];
}

- (void)downgradeFromRevisionIndex:(NSInteger)genIndex
{
    NSArray* generations = BeatRevisions.revisionGenerations;
    if (genIndex >= generations.count) return;
    
    for (NSInteger i=0; i<generations.count; i++) {
        BeatRevisionGeneration* gen = generations[i];
        
        BeatRevisionGeneration* newGen = nil;
        if (i >= genIndex && i > 0) newGen = generations[i-genIndex];
        
        [self convertRevisionGeneration:gen to:newGen];
    }
}


#pragma mark Convenience methods

/// Move to next revision marker
- (void)nextRevision
{
    [self nextRevisionOfGeneration:nil];
}
- (void)nextRevisionOfGeneration:(NSString*)generation
{
	NSRange effectiveRange;
	NSRange selectedRange = _delegate.selectedRange;
	if (selectedRange.location == _delegate.text.length && selectedRange.location > 0) selectedRange.location -= 1;
	
	// Find out if we are inside or at the beginning of a revision right now
	NSUInteger searchLocation = selectedRange.location;
	
	BeatRevisionItem *revision = [_delegate.textStorage attribute:BeatRevisions.attributeKey atIndex:selectedRange.location effectiveRange:&effectiveRange];
	NSString *revisionColor = revision.colorName;
	if (revision) {
		searchLocation = NSMaxRange(effectiveRange);
		revisionColor = revision.colorName;
	}
	
	__block NSRange revisionRange = NSMakeRange(NSNotFound, 0);
	__block NSRange previousRange = NSMakeRange(searchLocation, 0);
	
	[_delegate.textStorage enumerateAttribute:BeatRevisions.attributeKey
                                      inRange:NSMakeRange(searchLocation, _delegate.text.length - searchLocation)
                                      options:0
                                   usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *revision = value;
		if (revision.type == RevisionNone) return;
		
        bool correctGeneration = true;
        if (generation != nil && ![revision.colorName.lowercaseString isEqualToString:generation.lowercaseString]) correctGeneration = false;
        
		if ((range.location != NSMaxRange(previousRange) || ![revisionColor isEqualToString:revision.colorName]) && correctGeneration) {
                *stop = YES;
                revisionRange = range;
		}
		
		previousRange = range;
	}];
	
	if (revisionRange.location != NSNotFound) {
		[self.delegate scrollToRange:NSMakeRange(revisionRange.location, 0)];
	}
}

/// Move to previous revision marker
- (void)previousRevision
{
    [self previousRevisionOfGeneration:nil];
}

- (void)previousRevisionOfGeneration:(NSString*)generation
{
	NSRange effectiveRange;
	NSRange selectedRange = _delegate.selectedRange;
	if (selectedRange.location == _delegate.text.length && selectedRange.location > 0) selectedRange.location -= 1;
	
	// Find out if we are inside or at the beginning of a revision right now
	NSUInteger searchLocation = selectedRange.location;
	
	[_delegate.textStorage fixAttributesInRange:NSMakeRange(0, _delegate.textStorage.string.length)];
	BeatRevisionItem *revision = [_delegate.textStorage attribute:BeatRevisions.attributeKey atIndex:selectedRange.location effectiveRange:&effectiveRange];
	NSString *revisionColor = nil;
	
	if (revision) {
		revisionColor = revision.colorName;
		searchLocation = effectiveRange.location;
	}
		
	__block NSRange revisionRange = NSMakeRange(NSNotFound, 0);
	__block NSRange previousRange = NSMakeRange(searchLocation, 0);
	
	[_delegate.textStorage enumerateAttribute:BeatRevisions.attributeKey
                                      inRange:NSMakeRange(0, searchLocation)
                                      options:NSAttributedStringEnumerationReverse
                                   usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *revision = value;
		if (revision.type == RevisionNone) return;
        
        bool correctGeneration = true;
        if (generation != nil && ![revision.colorName isEqualToString:generation]) correctGeneration = false;
        
		if ((NSMaxRange(range) != previousRange.location || ![revisionColor isEqualToString:revision.colorName]) && correctGeneration) {
			*stop = YES;
			revisionRange = range;
		}
		
		previousRange = range;
	}];
	
	if (revisionRange.location != NSNotFound) {
		[self.delegate scrollToRange:NSMakeRange(revisionRange.location, 0)];
	}
}



#pragma mark - Revisions

/// Jumps to next revision
- (IBAction)nextRevision:(id)sender
{
	[self nextRevision];
}
/// Jumps to previous revision
- (IBAction)previousRevision:(id)sender
{
	[self previousRevision];
}

- (IBAction)previousRevisionOfCurrentGeneration:(id)sender
{
    [self previousRevisionOfGeneration:self.delegate.revisionColor];
}

- (IBAction)nextRevisionOfCurrentGeneration:(id)sender
{
    [self nextRevisionOfGeneration:self.delegate.revisionColor];
}


/// Generic method for adding a revisino marker, no matter the type
- (void)markerAction:(RevisionType)type
{
	[self markerAction:type range:_delegate.selectedRange];
	[_delegate attributedString]; // Save attributed text to cache
}

- (void)markerAction:(RevisionType)type range:(NSRange)range
{
	// Content can't be marked as revised when locked, and only allow this for editor view
    if (_delegate.contentLocked || range.location == NSNotFound) return;
	else if (type == RevisionRemovalSuggestion && range.length == 0) return;

    // Store the original attributes
    NSAttributedString* originalAttrs = [self.delegate.attributedString attributedSubstringFromRange:range];
    
	// Run the actual action
	if (type == RevisionRemovalSuggestion) [self markRangeForRemoval:range];
	else if (type == RevisionAddition) [self markRangeAsAddition:range];
	else [self clearReviewMarkers:range];
	
	[_delegate setSelectedRange:(NSRange){range.location + range.length, 0}];
	[_delegate updateChangeCount:BXChangeDone];
    [_delegate invalidatePreviewAt:range.location];
	
    /*
	[_delegate.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
        [self.delegate renderBackgroundForRange:originalRange];
	}];
	*/
    
    // Create an undo step
#if TARGET_OS_OSX
    // I don't know why, but we shouldn't invoke undo manager on iOS
    [[_delegate.undoManager prepareWithInvocationTarget:self] restoreRevisionsInRange:range from:originalAttrs];
#endif
    
	// Refresh backgrounds
	[_delegate renderBackgroundForRange:range];
}

- (void)restoreRevisionsInRange:(NSRange)range from:(NSAttributedString*)string
{
    [string enumerateAttribute:BeatRevisions.attributeKey inRange:(NSRange){0,string.length} options:0 usingBlock:^(id  _Nullable value, NSRange localRange, BOOL * _Nonnull stop) {
        NSRange globalRange = NSMakeRange(range.location + localRange.location, localRange.length);
        
        BeatRevisionItem* revision = (BeatRevisionItem*)value;
        if (revision == nil) {
            [self.delegate.textStorage removeAttribute:BeatRevisions.attributeKey range:globalRange];
        } else {
            [self.delegate.textStorage addAttribute:BeatRevisions.attributeKey value:revision range:globalRange];
        }
    }];
    
    [_delegate renderBackgroundForRange:range];
}

- (void)markRangeAsAddition:(NSRange)range {
	BeatRevisionItem *revision = [BeatRevisionItem type:RevisionAddition color:_delegate.revisionColor];
	if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
        
    [_delegate refreshTextView];
}
- (void)markRangeForRemoval:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionRemovalSuggestion];
	if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
    [_delegate refreshTextView];
}
- (void)clearReviewMarkers:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionNone];
	if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
    [_delegate refreshTextView];
}

- (void)addRevision:(NSRange)range color:(NSString *)color
{
    if (NSMaxRange(range) > self.delegate.text.length) return;
    
    BeatRevisionItem* revision = [BeatRevisionItem type:RevisionAddition color:color];
    if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
}
- (void)removeRevision:(NSRange)range
{
    [_delegate.textStorage removeAttribute:REVISION_ATTR range:range];
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
	
	[_delegate.attributedString enumerateAttribute:BeatRevisions.attributeKey inRange:NSMakeRange(0, _delegate.text.length) options:NSAttributedStringEnumerationReverse usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *revision = value;
		
		if (revision.type == RevisionRemovalSuggestion && range.length > 0) {
			[self markerAction:RevisionNone range:range];
			[self.delegate replaceRange:range withString:@""];
		}
	}];
	
	// Then clear all attributes
	[self markerAction:RevisionNone range:NSMakeRange(0, _delegate.text.length)];
    [_delegate refreshTextView];
}

#else

- (void)commitRevisions {
    NSLog(@"Implement commit revisions for iOS");
}

#endif

@end
/*
 
 let the right one in
 let the old dreams die
 
 */
