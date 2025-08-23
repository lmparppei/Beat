//
//  Line.m
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  (most) parts copyright © 2019-2024 Lauri-Matti Parppei / Lauri-Matti Parppei. All Rights reserved.

/**
 
# Line Object
 
 Each parsed line is represented by a `Line` object, which holds the string, formatting ranges and other metadata.
 
 What you are about to see are the horrors of object-oriented programming. Lines should be structs and assisting objects, but I've tasked them to do a lot more, which is NOT wise. This is because they are often handled outside the parser, which adds to complexity, mostly when rendering to an exported document.  We need to split lines, reset inline formatting, turn them into attributed strings and back to Founain etc. and it didn't make sense to do this using the parser at the time. I'm regretting my life choices now.
 
 I've split some of the duties of this object to categories to make the pain a little more bearable.
 
 */

#import "Line.h"
#import <BeatParsing/Line+Type.h>
#import <BeatParsing/Line+ConvenienceTypeChecks.h>
#import <BeatParsing/Line+AttributedStrings.h>
#import <BeatParsing/Line+Notes.h>
#import <BeatParsing/Line+SplitAndJoin.h>
#import <BeatParsing/Line+RangeLookup.h>

#import "BeatExportSettings.h"
#import "NSString+CharacterControl.h"
#import "NSString+EMOEmoji.h"
#import <BeatParsing/BeatParsing-Swift.h>

@interface Line()
@property (nonatomic) NSUInteger oldHash;
@property (nonatomic) NSString* cachedString;

@property (nonatomic) NSDictionary* beatRangesAndContents;
@end

@implementation Line
 
#pragma mark - Shorthand initializers

+ (Line*)withString:(NSString*)string type:(LineType)type parser:(id<LineDelegate>)parser {
    return [[Line alloc] initWithString:string type:type position:0 parser:parser];
}
+ (Line*)withString:(NSString*)string type:(LineType)type {
    return [[Line alloc] initWithString:string type:type];
}

/// Use this ONLY for creating temporary lines while paginating
+ (Line*)withString:(NSString*)string type:(LineType)type pageSplit:(bool)pageSplit {
    return [[Line alloc] initWithString:string type:type pageSplit:YES];
}

+ (NSArray*)markupCharacters {
    return @[@".", @"@", @"~", @"!"];
}

#pragma mark - Initialization

- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSInteger)position parser:(id<LineDelegate>)parser {
    self = [super init];
    if (self) {
        if (string == nil) string = @"";
        
        _string = string;
        _type = type;
        _position = position;
        _formattedAs = -1;
        _parser = parser;
        
        _boldRanges = NSMutableIndexSet.indexSet;
        _italicRanges = NSMutableIndexSet.indexSet;
        _underlinedRanges = NSMutableIndexSet.indexSet;
        _boldItalicRanges = NSMutableIndexSet.indexSet;
        _strikeoutRanges = NSMutableIndexSet.indexSet;
        _noteRanges = NSMutableIndexSet.indexSet;
        _omittedRanges = NSMutableIndexSet.indexSet;
        _escapeRanges = NSMutableIndexSet.indexSet;
        _removalSuggestionRanges = NSMutableIndexSet.indexSet;
        
        _currentVersion = 0;
        
        _uuid = NSUUID.UUID;
        
        _originalString = string;
    }
    return self;
}

- (Line*)initWithString:(NSString*)string position:(NSInteger)position
{
    return [[Line alloc] initWithString:string type:0 position:position parser:nil];
}
- (Line*)initWithString:(NSString*)string position:(NSInteger)position parser:(id<LineDelegate>)parser
{
    return [[Line alloc] initWithString:string type:0 position:position parser:parser];
}
- (Line*)initWithString:(NSString *)string type:(LineType)type position:(NSInteger)position {
    return [[Line alloc] initWithString:string type:type position:position parser:nil];
}

/// Init a line for non-continuous parsing
- (Line*)initWithString:(NSString *)string type:(LineType)type {
    return [[Line alloc] initWithString:string type:type position:-1 parser:nil];
}

/// Use this ONLY for creating temporary lines while paginating.
- (Line*)initWithString:(NSString *)string type:(LineType)type pageSplit:(bool)pageSplit {
    self = [super init];
    if (self) {
        _string = string;
        _type = type;
        _unsafeForPageBreak = YES;
        _formattedAs = -1;
        _uuid = NSUUID.UUID;
        _nextElementIsDualDialogue = false;
        
        _beginsNewParagraph = false;
        
        if (pageSplit) [self resetFormatting];
    }
    return self;
}



#pragma mark - Thread-safe getters

/// Length of the string
-(NSInteger)length {
    @synchronized (self.string) {
        return self.string.length;
    }
}

/// Range for the full line (incl. line break)
-(NSRange)range
{
    @synchronized (self) {
        return NSMakeRange(self.position, self.length + 1);
    }
}

/// Range for text content only (excl. line break)
-(NSRange)textRange
{
    @synchronized (self) {
        return NSMakeRange(self.position, self.length);
    }
}

/// Returns the line position in document
-(NSInteger)position
{
    if (_representedLine == nil) {
        @synchronized (self) {
            return _position;
        }
    } else {
        return _representedLine.position;
    }
}


#pragma mark - Cloning

/* This should be implemented as NSCopying */

-(id)copy {
    return [self clone];
}

- (Line*)clone {
    Line* newLine = [Line withString:self.string type:self.type];
    newLine.representedLine = self;
    newLine.uuid = self.uuid;
    newLine.position = self.position;
    
    newLine.changed = self.changed;
    
    newLine.beginsTitlePageBlock = self.beginsTitlePageBlock;
    newLine.endsTitlePageBlock = self.endsTitlePageBlock;
    
    newLine.unsafeForPageBreak = self.unsafeForPageBreak;
    
    newLine.resolvedMacros = self.resolvedMacros.mutableCopy;
    
    if (self.revisedRanges.count > 0) newLine.revisedRanges = self.revisedRanges.mutableCopy;
    
    // Not sure why these are guarded.
    newLine.italicRanges = self.italicRanges.mutableCopy;
    newLine.boldRanges = self.boldRanges.mutableCopy;
    newLine.boldItalicRanges = self.boldItalicRanges.mutableCopy;
    newLine.noteRanges = self.noteRanges.mutableCopy;
    newLine.omittedRanges = self.omittedRanges.mutableCopy;
    newLine.underlinedRanges = self.underlinedRanges.mutableCopy;
    newLine.sceneNumberRange = self.sceneNumberRange;
    newLine.strikeoutRanges = self.strikeoutRanges.mutableCopy;
    newLine.removalSuggestionRanges = self.removalSuggestionRanges.mutableCopy;
    newLine.escapeRanges = self.escapeRanges.mutableCopy;
    newLine.macroRanges = self.macroRanges.mutableCopy;
    
    newLine.sceneNumber = self.sceneNumber.copy;
    newLine.color = self.color.copy;
    
    newLine.versions = self.versions.mutableCopy;
    newLine.currentVersion = self.currentVersion;
    
    newLine.noteData = self.noteData;
    
    newLine.nextElementIsDualDialogue = self.nextElementIsDualDialogue;
    
    return newLine;
}

#pragma mark - Delegate methods

/// Returns the index of this line in the parser. Don't use this for every line.
- (NSUInteger)index
{
    if (!self.parser) return NSNotFound;
    return [self.parser indexOfLine:self];
}


#pragma mark - String methods

- (NSString*)stringForDisplay
{
    // Wow. This is pretty hacky. If the line is not omitted, we'll return the normal stripped and trimmed string, but otherwise we'll create a clone and remove the omissions.
    if (!self.omitted) {
        return [self.stripFormatting stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    } else {
        Line *line = self.clone;
        [line.omittedRanges removeAllIndexes];
        return [line.stripFormatting stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
}

/// @warning Legacy method for plugin compatibility. Use `line.stripFormatting`.
- (NSString*)textContent { return self.stripFormatting; }

/// Returns the last character as `unichar`
- (unichar)lastCharacter
{
    if (_string.length > 0) return [_string characterAtIndex:self.length - 1];
    else return 0; // 0 is error in this case
}

/// Returns `true` if the stored original content is equal to current string. Original is stored when the object is first initialized.
- (bool)matchesOriginal
{
    return [self.string isEqualToString:self.originalString];
}

/// Returns the metadata for an alternative version of this line
/// - warning: This method **DOES NOT** replace anything, but instead returns the text and possible revisions of the line. You will need to handle the actual replacement yourself in editor.
- (NSDictionary*)switchVersion:(NSInteger)amount
{
    NSInteger i = self.currentVersion + amount;
    if (i < 0 || i == NSNotFound || i >= self.versions.count) return nil;
    
    // First, store the previous version
    [self storeVersion];
    
    // Then inform the editor that it should switch to this version
    self.currentVersion = i;
    return self.versions[i];
}

/// Stores the current version of this line
/// - note: You need to have baked the revisions in the text for this to work correctly
- (void)storeVersion
{
    if (self.versions == nil) self.versions = NSMutableArray.new;

    self.versions[self.currentVersion] = @{
        @"text": self.string,
        @"revisions": (self.revisedRanges != nil) ? self.revisedRanges : @{}
    };
}

/// Adds a new version of this text.
/// - note: You need to have baked the revisions in the text for this to work correctly
- (void)addVersion
{
    [self storeVersion];
    [self.versions addObject:@{
        @"text": self.string,
        @"revisions": (self.revisedRanges != nil) ? self.revisedRanges : @{}
    }];
    self.currentVersion = self.versions.count - 1;
}


#pragma mark - Strip formatting

/// Strip any Fountain formatting from the line
- (NSString*)stripFormatting
{
    return [self stripFormattingWithSettings:nil];
}

- (NSString*)stripFormattingWithSettings:(BeatExportSettings*)settings
{
    NSMutableIndexSet *contentRanges = self.contentRanges.mutableCopy;
    if (settings.printNotes) [contentRanges addIndexes:self.noteRanges];

    __block NSMutableString *content = NSMutableString.string;
    NSDictionary* macros = self.resolvedMacros;
    
    [contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        // Let's make sure we don't have bad data here (can happen in some multithreaded instances)
        if (NSMaxRange(range) > self.string.length) {
            range.length = self.string.length - NSMaxRange(range);
            if (range.length <= 0) return;
        }
        
        NSMutableString *strippedContent = NSMutableString.new;

        // We need to replace macros. This is a more efficient way than using attributed strings.
        for (NSValue *macroRange in macros) {
            NSRange replacementRange = macroRange.rangeValue;
            NSString *macroValue = macros[macroRange];
            
            // Check if the replacement range intersects with the current range
            NSRange intersectionRange = NSIntersectionRange(range, replacementRange);
            
            if (intersectionRange.length > 0) {
                // There is an intersection, so replace the intersecting part with the replacement string
                if (intersectionRange.location > range.location) {
                    NSRange prefixRange = NSMakeRange(range.location, intersectionRange.location - range.location);
                    [strippedContent appendString:[self.string substringWithRange:prefixRange]];
                }
                
                [strippedContent appendString:macroValue];
                
                // Update the range for the next iteration
                NSInteger remainder = NSMaxRange(range) - NSMaxRange(intersectionRange);
                range.location = NSMaxRange(intersectionRange);
                range.length = remainder;
            }
        }
        
        // Append any remaining content after replacements
        if (range.location < NSMaxRange(range)) {
            NSRange remainingRange = NSMakeRange(range.location, NSMaxRange(range) - range.location);
            [strippedContent appendString:[self.string substringWithRange:remainingRange]];
        }
        
        [content appendString:strippedContent];
    }];
    
    return content;
}

/// Returns a string with notes removed
- (NSString*)stripNotes
{
    __block NSMutableString *string = [NSMutableString stringWithString:self.string];
    __block NSUInteger offset = 0;
    
    [self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.location - offset + range.length > string.length) {
            range = NSMakeRange(range.location, string.length - range.location - offset);
        }
        
        @try {
            [string replaceCharactersInRange:NSMakeRange(range.location - offset, range.length) withString:@""];
        }
        @catch (NSException* exception) {
            NSLog(@"cleaning out of range: %@ / (%lu, %lu) / offset %lu", self.string, range.location, range.length, offset);
        }
        @finally {
            offset += range.length;
        }
    }];
    
    return string;
}

/// Returns a string with the scene number stripped
- (NSString*)stripSceneNumber
{
    NSString *result = [self.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", self.sceneNumber] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, self.string.length)];
    return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

#pragma mark - Section depth

- (NSUInteger)sectionDepth
{
    NSInteger depth = 0;

    for (int c = 0; c < self.string.length; c++) {
        if ([self.string characterAtIndex:c] == '#') depth++;
        else break;
    }
    
    return depth;
}


#pragma mark - Inline formatting

/// Parse and apply Fountain stylization inside the string contained by this line.
- (void)resetFormatting
{
    NSUInteger length = self.string.length;
    // Let's not do this for extremely long lines. I don't know how many symbols a unichar array can hold.
    // I guess there should be a fallback for insanely long strings, but this is a free and open source app, so if your
    // unique artwork requires 300 000 unicode symbols on a single lines, please use some other software.
    if (length > 300000) return;
    
    @try {
        // Store the line as a char array to avoid calling characterAtIndex: at each iteration.
        unichar charArray[length];
        [self.string getCharacters:charArray];
        
        self.boldRanges = [self rangesInChars:charArray
                                     ofLength:length
                                      between:BOLD_CHAR
                                          and:BOLD_CHAR
                                   withLength:2];
        self.italicRanges = [self rangesInChars:charArray
                                     ofLength:length
                                      between:ITALIC_CHAR
                                          and:ITALIC_CHAR
                                   withLength:1];
        
        self.underlinedRanges = [self rangesInChars:charArray
                                           ofLength:length
                                            between:UNDERLINE_CHAR
                                                and:UNDERLINE_CHAR
                                         withLength:1];
        
        self.noteRanges = [self rangesInChars:charArray
                                     ofLength:length
                                      between:NOTE_OPEN_CHAR
                                          and:NOTE_CLOSE_CHAR
                                   withLength:2];
        
        self.macroRanges = [self rangesInChars:charArray
                                      ofLength:length
                                       between:MACRO_OPEN_CHAR
                                           and:MACRO_CLOSE_CHAR
                                    withLength:2];
    }
    @catch (NSException* e) {
        NSLog(@"Error when trying to reset formatting: %@", e);
        return;
    }
}


#pragma mark - Formatting range lookup

/// Returns ranges between given strings. Used to return attributed string formatting to Fountain markup. The same method can be found in the parser, too. Why, I don't know.
- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength
{
    NSMutableIndexSet* indexSet = NSMutableIndexSet.new;
    
    NSInteger lastIndex = length - delimLength; //Last index to look at if we are looking for start
    NSInteger rangeBegin = -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
    
    for (NSInteger i = 0;;i++) {
        if (i > lastIndex) {
            break;
        }
                
        // No range is currently inspected
        if (rangeBegin == -1) {
            bool match = YES;
            for (int j = 0; j < delimLength; j++) {
                // Check for escape character (like \*)
                if (i > 0 && string[j + i - 1] == '\\') {
                    match = NO;
                    break;
                }
            
                if (string[j+i] != startString[j]) {
                    match = NO;
                    break;
                }
            }
            if (match) {
                rangeBegin = i;
                i += delimLength - 1;
            }
        // We have found a range
        } else {
            bool match = YES;
            for (int j = 0; j < delimLength; j++) {
                if (string[j+i] != endString[j]) {
                    match = NO;
                    break;
                }
            }
            if (match) {
                [indexSet addIndexesInRange:NSMakeRange(rangeBegin, i - rangeBegin + delimLength)];
                rangeBegin = -1;
                i += delimLength - 1;
            }
        }
    }
        
    return indexSet;
}


#pragma mark Formatting checking convenience

/// Returns TRUE when the line has no inline formatting (like **bold**)
-(bool)noFormatting
{
    return !(_boldRanges.count || _italicRanges.count || _strikeoutRanges.count || _underlinedRanges.count);
}


#pragma mark - Identity

- (BOOL)matchesUUID:(NSUUID*)uuid
{
    if ([self.uuid.UUIDString.lowercaseString isEqualToString:uuid.UUIDString.lowercaseString]) return true;
    else return false;
}

- (BOOL)matchesUUIDString:(NSString*)uuid
{
    if ([self.uuid.UUIDString.lowercaseString isEqualToString:uuid]) return true;
    else return false;
}

- (NSString*)uuidString
{
    return self.uuid.UUIDString;
}

#pragma mark - Helper methods

- (NSString*)trimmed {
    return [self.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (NSString*)characterName
{
    // This removes any extensions from character name, ie. (V.O.), (CONT'D) etc.
    // We'll allow the method to run for lines under 4 characters, even if not parsed as character cues
    // (update in 2022: why do we do this, past me?)
    if ((self.type != character && self.type != dualDialogueCharacter) && self.string.length > 3) return nil;
    
    // Strip formatting (such as symbols for forcing element types)
    NSString *name = self.stripFormatting;
    if (name.length == 0) return @"";
        
    // Find and remove suffix
    NSRange suffixRange = [name rangeOfString:@"("];
    if (suffixRange.location != NSNotFound && suffixRange.location > 0) name = [name substringWithRange:(NSRange){0, suffixRange.location}];
    
    // Remove dual dialogue character if needed
    if (self.type == dualDialogueCharacter && name.lastNonWhiteSpaceCharacter == '^') {
        name = [name substringToIndex:name.length - 1];
    }
    
    return [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSString*)titlePageKey {
    if (self.string.length == 0) return @"";
    
    NSInteger i = [self.string rangeOfString:@":"].location;
    if (i == NSNotFound || i == 0 || [self.string characterAtIndex:0] == ' ') return @"";
    
    return [self.string substringToIndex:i].lowercaseString;
}
- (NSString*)titlePageValue {
    NSInteger i = [self.string rangeOfString:@":"].location;
    if (i == NSNotFound) return self.string;
    
    return [[self.string substringFromIndex:i+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

/// Returns `true` for lines which should effectively be considered as empty when parsing.
- (bool)effectivelyEmpty {
    if (self.type == empty || self.length == 0 || self.opensOrClosesOmission || self.type == section || self.type == synopse ||
        (self.string.containsOnlyWhitespace && self.string.length == 1)) return true;
    else return false;
}

- (bool)opensOrClosesOmission {
    NSString *trimmed = [self.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if ([trimmed isEqualToString:@"*/"] || [trimmed isEqualToString:@"/*"]) return true;
    return false;
}

#pragma mark - JSON serialization

-(NSDictionary*)forSerialization
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
        @"string": (self.string.length) ? self.string.copy : @"",
        @"sceneNumber": (self.sceneNumber) ? self.sceneNumber.copy : @"",
        @"position": @(self.position),
        @"range": @{ @"location": @(self.range.location), @"length": @(self.range.length) },
        @"sectionDepth": @(self.sectionDepth),
        @"textRange": @{ @"location": @(self.textRange.location), @"length": @(self.textRange.length) },
        @"typeAsString": self.typeAsString,
        @"omitted": @(self.omitted),
        @"marker": (self.marker.length) ? self.marker : @"",
        @"markerDescription": (self.markerDescription.length) ? self.markerDescription : @"",
        @"uuid": (self.uuid) ? self.uuid.UUIDString : @"",
        @"notes": self.notesAsJSON,
        @"ranges": self.ranges
    }];
    
    if (self.type == synopse) {
        json[@"color"] = (self.color != nil) ? self.color : @"";
        json[@"stringForDisplay"] = self.stringForDisplay;
    }
    
    return json;
}

/// Returns a dictionary of ranges for plugins
-(NSDictionary*)ranges
{
    // Preprocess revised ranges for JSON compatibility
    NSMutableDictionary* revisedRanges = NSMutableDictionary.new;
    for (NSNumber* key in self.revisedRanges.allKeys) {
        NSIndexSet* indices = self.revisedRanges[key];
        NSArray* indexArray = [indices arrayRepresentation];
        revisedRanges[[NSString stringWithFormat:@"%lu", key.integerValue]] = indexArray;
    }
    
    return @{
        @"notes": [self.noteRanges arrayRepresentation],
        @"omitted": [self.omittedRanges arrayRepresentation],
        @"bold": [self.boldRanges arrayRepresentation],
        @"italic": [self.italicRanges arrayRepresentation],
        @"underlined": [self.underlinedRanges arrayRepresentation],
        @"revisions": revisedRanges
    };
}

 
#pragma mark - Custom data

- (NSDictionary*)setCustomData:(NSString*)key value:(id)value {
    if (_customDataDictionary == nil) _customDataDictionary = NSMutableDictionary.new;
    
    if (!value) return _customDataDictionary[key];
    else _customDataDictionary[key] = value;
    return nil;
}

- (id)getCustomData:(NSString*)key {
    if (_customDataDictionary == nil) _customDataDictionary = NSMutableDictionary.new;
    return _customDataDictionary[key];
}


#pragma mark - String convenience methods

- (bool)visibleContentIsUppercase
{
    NSString* string = self.stripFormatting;
    return [string containsOnlyUppercase];
}


#pragma mark - Page number convenience method

/// - note You should never, I repeat, NEVER set the underlying forced page number ivar yourself on any line. The only time this is used is when preprocessing __cloned__ lines for printing, because empty (pure note) lines are cleaned up and we need to somehow tell the previous remaining line that it will carry this information onwards.
- (NSString*)forcedPageNumber
{
    if (self.noteRanges.count == 0 && _inheritedForcedPageNumber == nil)
        return nil;
    else if (_inheritedForcedPageNumber != nil)
        return _inheritedForcedPageNumber; // Read the note above
     
    for (NSString* note in self.noteContents) {
        if ([note.lowercaseString rangeOfString:@"page "].location == 0 && note.length > 5) {
            NSString* pageNumber = [note substringFromIndex:5];
            return pageNumber;
        }
    }
    
    return nil;
}

- (void)setForcedPageNumber:(NSString *)forcedPageNumber
{
    _inheritedForcedPageNumber = forcedPageNumber;
}



#pragma mark - Debugging

-(NSString *)description
{
    return [NSString stringWithFormat:@"Line: %@  (%@ at %lu) %@", self.string, self.typeAsString, self.position, (self.nextElementIsDualDialogue) ? @"Next is dual" : @"" ];
}

#pragma mark - Copy

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return [self clone];
}

@end
