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

#import <BeatCore/BeatCore-Swift.h>
#import <BeatParsing/BeatParsing.h>
#import "BeatUserDefaults.h"
#import "BeatRevisions.h"
#import "BeatLocalization.h"
#import "BeatAttributes.h"
#import <BeatCore/BeatEditorFormatting.h>

#define REVISION_ATTR @"Revision"
#define LEGACY_REVISIONS @[@"blue", @"orange", @"purple", @"green"]

#if !TARGET_OS_IOS
    #import <Cocoa/Cocoa.h>
    #define BXChangeDone NSChangeDone
#else
    #import <UIKit/UIKit.h>
    #define BXChangeDone UIDocumentChangeDone
#endif

@implementation BeatRevisionGeneration
+ (instancetype)withLevel:(NSInteger)level color:(NSString*)color marker:(NSString*)marker {
    return [BeatRevisionGeneration.alloc initWithLevel:level color:color marker:marker];
}

- (instancetype)initWithLevel:(NSInteger)level color:(NSString*)color marker:(NSString*)marker
{
    self = [super init];
    if (self) {
        self.level = level;
        self.color = color;
        self.marker = marker;
    }
    return self;
}
@end

@interface BeatRevisions ()
@property (nonatomic) bool queuedChanges;
@property (nonatomic) NSRange queuedRange;
@property (nonatomic) NSInteger queuedDelta;
@end

@implementation BeatRevisions

+ (void)initialize {
    [super initialize];
    [BeatAttributes registerAttribute:BeatRevisions.attributeKey];
}


#pragma mark - Class convenenience methods

+ (NSArray<NSString*>*)legacyRevisions { return LEGACY_REVISIONS; }

/// Returns the modern revisions.
+ (NSArray<BeatRevisionGeneration*>*)revisionGenerations
{
    static NSArray* generations;
    
    if (generations == nil) {
        generations = @[
            [BeatRevisionGeneration withLevel:0 color:@"blue" marker:@"*"],
            [BeatRevisionGeneration withLevel:1 color:@"pink" marker:@"**"],
            [BeatRevisionGeneration withLevel:2 color:@"yellow" marker:@"+"],
            [BeatRevisionGeneration withLevel:3 color:@"green" marker:@"++"],
            [BeatRevisionGeneration withLevel:4 color:@"goldenrod" marker:@"@"],
            [BeatRevisionGeneration withLevel:5 color:@"buff" marker:@"@@"],
            [BeatRevisionGeneration withLevel:6 color:@"rose" marker:@"#"],
            [BeatRevisionGeneration withLevel:7 color:@"cherry" marker:@"##"],
        ];
    }
    
    return generations;
}

/// A shorthand for returning the marker by generation.
/// - note: If the generation level is beyond existing generations, we'll return an empty string.
+ (NSString*)markerForGeneration:(NSInteger)generation
{
    NSArray<BeatRevisionGeneration*>* generations = BeatRevisions.revisionGenerations;
    if (generation < generations.count) return generations[generation].marker;
    else return @"";
}

+ (NSIndexSet*)everyRevisionIndex
{
    return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, BeatRevisions.revisionGenerations.count)];
}

/// Convenience method for getting the relevant generation
+ (BeatRevisionGeneration*)generationForColor:(NSString*)color
{
    for (BeatRevisionGeneration* gen in BeatRevisions.revisionGenerations) {
        if ([gen.color isEqualToString:color]) return gen;
    }
    return nil;
}

/// Rertusn the attribute key used in `NSAttributedString` created by `Line` class
+ (NSString*)attributeKey {
	return REVISION_ATTR;
}

+ (void)bakeRevisionsIntoLines:(NSArray<Line*>*)lines text:(NSAttributedString *)string range:(NSRange)range {
    //
}

/// Bakes the revised ranges from editor into corresponding lines in the parser.
+ (void)bakeRevisionsIntoLines:(NSArray<Line*>*)lines text:(NSAttributedString*)string
{
    NSIndexSet* allRevisions = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.revisionGenerations.count)];
	[self bakeRevisionsIntoLines:lines text:string includeRevisions:allRevisions];
}
/// Bakes the revised ranges from editor into corresponding lines in the parser. When needed, you can specify which revisions to include.
+ (void)bakeRevisionsIntoLines:(NSArray<Line*>*)lines text:(NSAttributedString*)string includeRevisions:(nonnull NSIndexSet*)includedRevisions
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
				if (![includedRevisions containsIndex:revision.generationLevel] || revision.type == RevisionNone) return; // Skip if the color is not included
				
				line.changed = YES;
				
				if (revision.generationLevel > line.revisionGeneration) {
                    line.revisionGeneration = revision.generationLevel;
				}
				
				// Create addition & removal ranges if needed
				if (!line.removalSuggestionRanges) line.removalSuggestionRanges = NSMutableIndexSet.new;
				
				// Create local range
				NSRange localRange = [line globalRangeToLocal:range];
				
				// Save revised indices based on the local range
                if (revision.type == RevisionRemovalSuggestion) {
                    [line.removalSuggestionRanges addIndexesInRange:localRange];
                } else if (revision.type == RevisionAddition) {
                    NSNumber* level = @(revision.generationLevel);

					// Add revision sets if needed
					if (!line.revisedRanges) line.revisedRanges = NSMutableDictionary.new;
					if (!line.revisedRanges[level]) line.revisedRanges[level] = NSMutableIndexSet.new;
					
					[line.revisedRanges[level] addIndexesInRange:localRange];
				}
			}];
		} }
		@catch (NSException *e) {
			NSLog(@"Bake attributes: Line out of range  (%lu/%lu) -  %@", textRange.location, textRange.length, line);
		}
	}
}

/// Bakes the revised ranges from editor into corresponding lines in the parser.
+ (void)bakeRevisionsIntoLines:(NSArray<Line*>*)lines revisions:(NSDictionary*)revisions string:(NSString*)string
{
    NSAttributedString *attrStr = [self attrStringWithRevisions:revisions string:string];
    [self bakeRevisionsIntoLines:lines text:attrStr];
}

/// Returns a JSON array created from revision data baked in lines.
+ (NSDictionary<NSString*,NSArray*>*)serializeFromBakedLines:(NSArray<Line*>*)lines
{
    NSDictionary<NSString*,NSMutableArray*>* ranges = @{
        @"Addition": NSMutableArray.new,
        @"Removed": NSMutableArray.new,
        @"RemovalSuggestion": NSMutableArray.new
    };

    for (Line* line in lines) {
        if (line.revisedRanges.count == 0) continue;
        
        NSMutableArray* revisions = NSMutableArray.new;
        
        NSArray* sortedKeys = [line.revisedRanges.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return ((NSNumber*)obj1).integerValue < ((NSNumber*)obj2).integerValue;
        }];
        
        for (NSNumber* gen in sortedKeys) {
            NSIndexSet* indices = line.revisedRanges[gen];
            [indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
                [revisions addObject:@[
                    @(range.location),
                    @(range.length),
                    gen
                ]];
            }];
        }
        
        [ranges[@"Addition"] addObjectsFromArray:revisions];
    }
    
    return ranges;
}

#pragma mark Attributed string

/// Writes the given revisions into a plain text string, and returns an attributed string
+ (NSAttributedString*)attrStringWithRevisions:(NSDictionary*)revisions string:(NSString*)string {
    NSMutableAttributedString *attrStr = [NSMutableAttributedString.alloc initWithString:(string) ? string : @""];
    [BeatRevisions loadRevisionsFromDictionary:revisions toAttributedString:attrStr];
    return attrStr;
}

#pragma mark JSON data for saved files

/// Returns the revised ranges to be saved into data block of the Fountain file
+ (NSDictionary<NSString*,NSArray*>*)rangesForSaving:(NSAttributedString*)string
{
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
            // Get the range array for given revision type
            NSMutableArray *values = ranges[item.key];
            NSArray *lastItem = values.lastObject;
            
            NSRange lastRange = NSMakeRange(NSNotFound, 0);
            NSInteger lastGeneration = NSNotFound;
            
            // Each range item should have three items: location, length and generation level.
            // We'll convert the previous NSNumber values into real integers.
            if (lastItem.count == 3)  {
                lastRange.location = [(NSNumber*)lastItem[0] integerValue];
                lastRange.length = [(NSNumber*)lastItem[1] integerValue];
                lastGeneration = [(NSNumber*)lastItem[2] integerValue];
            }
            
            // Check if we should continue the last range (to avoid a lot of consecutive attributes with the same revision level)
            if (NSMaxRange(lastRange) == range.location && lastGeneration == item.generationLevel) {
                // This is a continuation of the last range
                values[values.count-1] = @[@(lastRange.location), @(lastRange.length + range.length), @(item.generationLevel)];
            } else {
                // This is a new range
                [values addObject:@[@(range.location), @(range.length), @(item.generationLevel)]];
            }
        }
    }];
    
    // Let's not save an empty dict if there are no values.
    bool empty = true;
    for (NSString* key in ranges.allKeys) {
        NSArray* values = ranges[key];
        if (values.count > 0) {
            empty = false;
            break;
        }
    }
    
    return empty ? @{} : ranges;
}

/// Returns serialized ranges for current document. You can use these values either for saving to document settings or in plugins etc.
- (NSDictionary<NSString*,NSArray*>*)serializedRanges
{
    return [BeatRevisions rangesForSaving:self.delegate.attributedString];
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
    
    [BeatRevisions loadRevisionsFromDictionary:revisions toAttributedString:self.delegate.textStorage];
}

/// Adds given revision attributes using a `BeatEditorDelegate`.
/// - note: This is a duplicate of `attrStringWithRevisions:`. Please combine these at some point.
+ (void)loadRevisionsFromDictionary:(NSDictionary*)revisions toAttributedString:(inout NSMutableAttributedString*)attrStr
{
    for (NSString *key in revisions.allKeys) {
        NSArray *items = revisions[key];
        
        for (NSArray *item in items) {
            NSInteger loc = [(NSNumber*)item[0] integerValue];
            NSInteger len = [(NSNumber*)item[1] integerValue];
            NSInteger generation = 0;
            
            // Load generation if available (in some rare legacy cases this could be missing)
            if (item.count > 2) {
                id levelItem = item[2];
                
                // Convert from legacy revisions if needed
                if ([levelItem isKindOfClass:NSString.class]) generation = [LEGACY_REVISIONS indexOfObject:levelItem];
                else if ([levelItem isKindOfClass:NSNumber.class]) generation = [(NSNumber*)levelItem integerValue];
            }
            
            // Ensure the revision is in range, find lines in range and bake revisions
            if (len > 0 && loc + len <= attrStr.string.length) {
                RevisionType type;
                NSRange range = (NSRange){loc, len};
                
                if ([key isEqualToString:@"Addition"]) type = RevisionAddition;
                else if ([key isEqualToString:@"Removal"] || [key isEqualToString:@"RemovalSuggestion"]) type = RevisionRemovalSuggestion;
                else type = RevisionNone;
                
                BeatRevisionItem *revision = [BeatRevisionItem type:type generation:generation];
                
                if (revision.type != RevisionNone) {
                    [attrStr addAttribute:BeatRevisions.attributeKey value:revision range:range];
                }
            }
        }
    }
}

/// This method takes in a JSON range object from a line and applies it to given line
- (void)loadLocalRevision:(NSDictionary*)revision line:(Line*)line
{
    [self.delegate removeAttribute:BeatRevisions.attributeKey range:line.textRange];
    
    for (NSNumber* gen in revision.allKeys) {
        NSIndexSet* indices = revision[gen];
        [indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
            BeatRevisionItem* revision = [BeatRevisionItem type:RevisionAddition generation:gen.integerValue];
            NSRange globalRange = NSMakeRange(line.position + range.location, range.length);
            [self.delegate addAttribute:BeatRevisions.attributeKey value:revision range:globalRange];
        }];
    }
}


#pragma mark - Editor methods

#pragma mark Setup the class & load revisions

/// Setup the class: Loads revisions from the current document (via delegate) and adds them into the editor string.
/// @warning Might break iOS compatibility if not handled with care.
- (void)setup
{
	_delegate.revisionLevel = [_delegate.documentSettings getInt:DocSettingRevisionLevel];

    // Convert legacy revision level to current system if needed
    if ([_delegate.documentSettings getString:DocSettingRevisionColor].length > 0) {
        NSString* color = [_delegate.documentSettings getString:DocSettingRevisionColor];
        NSInteger level = [LEGACY_REVISIONS indexOfObject:color];
        if (level != NSNotFound) _delegate.revisionLevel = level;
        
        [_delegate.documentSettings remove:DocSettingRevisionColor];
    }
    
	// Get revised ranges from document settings and iterate through them
	NSDictionary *revisions = [_delegate.documentSettings get:DocSettingRevisions];
	
    [BeatRevisions loadRevisionsFromDictionary:revisions toAttributedString:_delegate.textStorage];
			
	// Set the mode in editor
	bool revisionMode = [_delegate.documentSettings getBool:DocSettingRevisionMode];
	if (revisionMode) { self.delegate.revisionMode = YES; }
}

/// Combines single, orphaned revision attributes to longer ranges
- (void)fixRevisionAttributesInRange:(NSRange)fullRange
{
    NSTextStorage *textStorage = self.delegate.textStorage;
    
    // Clamp the range if needed
    if (NSMaxRange(fullRange) > textStorage.length) {
        fullRange.length = textStorage.length - NSMaxRange(fullRange);
        if (fullRange.length <= 0) return;
    }
    
    __block NSRange currentRange = NSMakeRange(NSNotFound, 0);
    __block BeatRevisionItem* previousRevision;
    
    [textStorage beginEditing];
    
    NSAttributedString* text = textStorage.copy;
    [text enumerateAttribute:BeatRevisions.attributeKey inRange:fullRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        BeatRevisionItem* revision = value;
        
        bool revisionsMatch = (revision.generationLevel == previousRevision.generationLevel) && revision.type == previousRevision.type;
        
        if ((!revisionsMatch || range.location != NSMaxRange(currentRange)) && previousRevision != nil) {
            // Revision generation changed or the range is not continuous, so let's add the attribute
            [textStorage addAttribute:BeatRevisions.attributeKey value:previousRevision range:currentRange];
            previousRevision = nil;
        }

        // No revision, continut
        if (revision == nil) return;
        
        if (previousRevision == nil) {
            currentRange = range;
            previousRevision = revision;
        } else {
            currentRange.length += range.length;
        }
    }];
    
    // Add the last revision. First make sure we won't go out of range.
    if (NSMaxRange(currentRange) > textStorage.length) {
        currentRange.length = textStorage.length - currentRange.location;
        if (currentRange.length < 0) currentRange.length = 0;
    }
    
    // Add range
    if (currentRange.location != NSNotFound && previousRevision != nil && currentRange.length > 0 && NSMaxRange(currentRange) <= textStorage.length) {
        [textStorage addAttribute:BeatRevisions.attributeKey value:previousRevision range:currentRange];
    }
    
    [textStorage endEditing];
}


#pragma mark Register changes

/// Because Apple changed something in macOS Sonoma, we need to queue changes when characters are edited AND then apply those changes if needed. Oh my fucking god.
- (void)queueRegisteringChangesInRange:(NSRange)range delta:(NSInteger)delta
{
    _queuedChanges = true;
    _queuedRange = range;
    _queuedDelta = delta;
}

/// Call when you reliably known that the text has changed AND you've successfully registered the changes.
- (void)applyQueuedChanges
{
    if (!_queuedChanges) return;
    
    [self registerChangesInRange:_queuedRange delta:_queuedDelta];
    _queuedChanges = false;
}

/// This is for registering changes via `NSTextStorage` delegate method `didProcessEditing`.
- (void)registerChangesInRange:(NSRange)range delta:(NSInteger)delta
{
    if (delta < 0 && range.length == 0) {
        // This is a removal.
        // In the near future, we'll add a removal marker here.
        if (delta > 0) range.location -= labs(delta);
        else range.location -= 1;
        range.length = 1;
    }
    
    if (range.location < 0) return;
    
    [self registerChangesInRange:NSMakeRange(range.location, range.length)];
    
    // Fix the attributes on this line to avoid zillions of extra attributes
    Line* editedLine = [self.delegate.parser lineAtPosition:range.location];
    [self fixRevisionAttributesInRange:editedLine.textRange];
}

/// When in revision mode, this method automatically adds revision markers to given range. Should only invoked when editing has happened.
- (void)registerChangesInRange:(NSRange)range
{
    // Avoid going out of range
    if (NSMaxRange(range) > self.delegate.text.length) return;    

	NSString * change = [self.delegate.text substringWithRange:range];

	// Check if this was just a line break
	if (range.length < 2) {
		Line * line = [_delegate.parser lineAtPosition:range.location];
		
        // This was a line break. If it was at the end of a line, reduce that line from the range.
        if ([change isEqualToString:@"\n"] && NSMaxRange(range) == NSMaxRange(line.range)) return;
	}
    
    BeatRevisionItem* revision = [BeatRevisionItem type:RevisionAddition generation:_delegate.revisionLevel];
    
	[_delegate.textStorage removeAttribute:BeatRevisions.attributeKey range:range];
	[_delegate.textStorage addAttribute:BeatRevisions.attributeKey value:revision range:range];
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
        if (revision == nil || revision.type == RevisionNone || revision.generationLevel != original.level) return;
        
        if (newGen != nil) {
            // convert to another generation
            BeatRevisionItem* newRevision = [BeatRevisionItem type:revision.type generation:newGen.level];
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
        if (i >= genIndex) newGen = generations[i-genIndex];
                
        [self convertRevisionGeneration:gen to:newGen];
    }
}


#pragma mark Convenience methods

- (NSDictionary*)revisedRanges
{
    NSDictionary *revisions = [BeatRevisions rangesForSaving:self.delegate.getAttributedText];
    return revisions;
}


/// Move to next revision marker
- (void)nextRevision
{
    [self nextRevisionOfGeneration:NSNotFound];
}
- (void)nextRevisionOfGeneration:(NSInteger)level
{
	NSRange effectiveRange;
	NSRange selectedRange = _delegate.selectedRange;
	if (selectedRange.location == _delegate.text.length && selectedRange.location > 0) selectedRange.location -= 1;
	
	// Find out if we are inside or at the beginning of a revision right now
	NSUInteger searchLocation = selectedRange.location;
	
	BeatRevisionItem *revision = [_delegate.textStorage attribute:BeatRevisions.attributeKey atIndex:selectedRange.location effectiveRange:&effectiveRange];
	
	if (revision) searchLocation = NSMaxRange(effectiveRange);
	
	__block NSRange revisionRange = NSMakeRange(NSNotFound, 0);
	__block NSRange previousRange = NSMakeRange(searchLocation, 0);
	
	[_delegate.textStorage enumerateAttribute:BeatRevisions.attributeKey
                                      inRange:NSMakeRange(searchLocation, _delegate.text.length - searchLocation)
                                      options:0
                                   usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem *revision = value;
		if (revision.type == RevisionNone) return;
		
        bool correctGeneration = true;
        if (level != NSNotFound && revision.generationLevel != level) correctGeneration = false;
        
		if ((range.location != NSMaxRange(previousRange) || level != revision.generationLevel) && correctGeneration) {
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
    [self previousRevisionOfGeneration:NSNotFound];
}

/// Set level as `NSNotFound` if you don't want to look for any specific revision level
- (void)previousRevisionOfGeneration:(NSInteger)level
{
	NSRange effectiveRange;
	NSRange selectedRange = _delegate.selectedRange;
	if (selectedRange.location == _delegate.text.length && selectedRange.location > 0) selectedRange.location -= 1;
	
	// Find out if we are inside or at the beginning of a revision right now
	NSUInteger searchLocation = selectedRange.location;
	
	[_delegate.textStorage fixAttributesInRange:NSMakeRange(0, _delegate.textStorage.string.length)];
	BeatRevisionItem *revision = [_delegate.textStorage attribute:BeatRevisions.attributeKey atIndex:selectedRange.location effectiveRange:&effectiveRange];
	
    if (revision) searchLocation = effectiveRange.location;
		
	__block NSRange revisionRange = NSMakeRange(NSNotFound, 0);
	__block NSRange previousRange = NSMakeRange(searchLocation, 0);
	
	[_delegate.textStorage enumerateAttribute:BeatRevisions.attributeKey
                                      inRange:NSMakeRange(0, searchLocation)
                                      options:NSAttributedStringEnumerationReverse
                                   usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        BeatRevisionItem *revision = value;
        if (revision.type == RevisionNone) return;
        
        bool correctGeneration = true;
        if (level != NSNotFound && revision.generationLevel != level) correctGeneration = false;
        
		if ((NSMaxRange(range) != previousRange.location || revision.generationLevel != level) && correctGeneration) {
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
    [self previousRevisionOfGeneration:self.delegate.revisionLevel];
}

- (IBAction)nextRevisionOfCurrentGeneration:(id)sender
{
    [self nextRevisionOfGeneration:self.delegate.revisionLevel];
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
#if TARGET_OS_OSX
    NSAttributedString* originalAttrs = [self.delegate.attributedString attributedSubstringFromRange:range];
#endif
    
    // Run the actual action
    if (type == RevisionRemovalSuggestion) [self markRangeForRemoval:range];
    else if (type == RevisionAddition) [self markRangeAsAddition:range];
    else [self clearReviewMarkers:range];
    
    [_delegate setSelectedRange:(NSRange){range.location + range.length, 0}];
    [_delegate updateChangeCount:BXChangeDone];
    [_delegate invalidatePreviewAt:range.location];
        
    // Create an undo step
#if TARGET_OS_OSX
    // I don't know why, but we shouldn't invoke undo manager on iOS
    [[_delegate.undoManager prepareWithInvocationTarget:self] restoreRevisionsInRange:range from:originalAttrs];
#endif
    
    // Refresh backgrounds
    [_delegate.formatting refreshBackgroundForRange:range];
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
    
    [_delegate.formatting refreshBackgroundForRange:range];
}

- (void)markRangeAsAddition:(NSRange)range
{
	BeatRevisionItem *revision = [BeatRevisionItem type:RevisionAddition generation:_delegate.revisionLevel];
	if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
        
    [_delegate refreshTextView];
}
- (void)markRangeForRemoval:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionRemovalSuggestion generation:_delegate.revisionLevel];
	if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
    [_delegate refreshTextView];
}
- (void)clearReviewMarkers:(NSRange)range {
	BeatRevisionItem* revision = [BeatRevisionItem type:RevisionNone generation:_delegate.revisionLevel];
	if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
    [_delegate refreshTextView];
}

- (void)addRevision:(NSRange)range generation:(NSInteger)generation
{
    if (NSMaxRange(range) > self.delegate.text.length) return;
    
    BeatRevisionItem* revision = [BeatRevisionItem type:RevisionAddition generation:generation];
    if (revision) [_delegate.textStorage addAttribute:REVISION_ATTR value:revision range:range];
}

- (void)addRevisions:(NSIndexSet*)indices generation:(NSInteger)generation
{
    [self.delegate.textStorage beginEditing];
    [indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [self addRevision:range generation:generation];
    }];
    [self.delegate.textStorage endEditing];
}

/// - warning: This is a LEGACY METHOD which adds a revision based on the old, color-name-based system. __Do NOT USE THIS.__
- (void)addRevision:(NSRange)range color:(NSString*)color
{
    NSLog(@"⚠️ addRevision:color: is deprecated. Use addRevision:generation: instead.");
    NSInteger level = [LEGACY_REVISIONS indexOfObject:color];
    if (level != NSNotFound) [self addRevision:range generation:level];
}

- (void)removeRevision:(NSRange)range
{
    [_delegate.textStorage removeAttribute:REVISION_ATTR range:range];
}

#if !TARGET_OS_IOS

/// An experimental method which removes any text suggested to be removed and clears all revisions.
- (void)commitRevisions
{
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
            [self.delegate.textActions replaceRange:range withString:@""];
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
