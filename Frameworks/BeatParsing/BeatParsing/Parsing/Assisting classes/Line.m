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

- (Line*)initWithString:(NSString*)string type:(LineType)type position:(NSInteger)position parser:(id<LineDelegate>)parser
{
    self = [super init];
    if (self) {
        if (string == nil) string = @"";
        
        _string = string;
        _type = type;
        _position = position;
        _formattedAs = -1;
        _parser = parser;
        
        _formattedRanges = NSMutableDictionary.new;
         
        _currentVersion = 0;
        
        _uuid = NSUUID.UUID;
        
        _originalString = string;
        
        // Here we also need to catch possible alternatives
        // [self readAlternativesAndCleanString];
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
        _formattedRanges = NSMutableDictionary.new;
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
    NSMutableDictionary* ranges = NSMutableDictionary.new;
    for (NSValue* key in self.formattedRanges.allKeys) {
        NSMutableIndexSet* indices = ((NSMutableIndexSet*)self.formattedRanges[key]).mutableCopy;
        ranges[key] = indices;
    }
    
    newLine.formattedRanges = ranges;
    
    /*
    newLine.italicRanges = self.italicRanges.mutableCopy;
    newLine.boldRanges = self.boldRanges.mutableCopy;
    newLine.boldItalicRanges = self.boldItalicRanges.mutableCopy;
    newLine.noteRanges = self.noteRanges.mutableCopy;
    newLine.omittedRanges = self.omittedRanges.mutableCopy;
    newLine.underlinedRanges = self.underlinedRanges.mutableCopy;
    newLine.sceneNumberRange = self.sceneNumberRange;
    newLine.removalSuggestionRanges = self.removalSuggestionRanges.mutableCopy;
    newLine.escapeRanges = self.escapeRanges.mutableCopy;
    newLine.macroRanges = self.macroRanges.mutableCopy;
    */
     
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

/*
/// Reads possible line alternatives in the line `** ALTERNATIVES: ... *` and cleans that text up as well. This is unnecessarily complex and won't work, beacuse we need to keep editor and text in sync, so the user KNOWS what they are saving.
- (void)readAlternativesAndCleanString
{
    NSRange rangeOfVersionData = [self.string rangeOfString:@"\/** ALTERNATIVES: "];
    if (rangeOfVersionData.location == NSNotFound) return;
    
    // Remove the alternative data
    self.string = [self.string substringToIndex:rangeOfVersionData.location];
        
    // Get the alternative data
    NSString* versionData = [self.string substringFromIndex:NSMaxRange(rangeOfVersionData)];
    // Remove the * at the end
    NSInteger lastStar = [versionData locationOfLastOccurenceOf:'*'];
    if (lastStar < versionData.length && [versionData characterAtIndex:lastStar+1] == '/') {
        versionData = [versionData substringToIndex:lastStar];
    }
    
    NSData* d = [versionData dataUsingEncoding:NSUTF8StringEncoding];
    NSError* e;
    NSDictionary* versionDict = [NSJSONSerialization JSONObjectWithData:d options:0 error:&e];
    
    if (e != nil) {
        NSLog(@"!!! Error reading version data: %@", e);
        return;
    }
    
    self.currentVersion = ((NSNumber*)versionDict[@"current"]).intValue;
    
    NSArray<NSDictionary*>* alternatives = versionDict[@"versions"];
    NSMutableArray<NSDictionary*>* versions = NSMutableArray.new;
    
    for (NSDictionary* alt in alternatives) {
        NSString* text = alt[@"text"];
        NSDictionary* jsonRevisions = alt[@"revisions"];
        
        NSMutableDictionary<NSNumber*,NSMutableIndexSet*>* revisions = NSMutableDictionary.new;
        
        for (NSString* key in jsonRevisions.allKeys) {
            // These arrays contain ranges as two-number arrays: [loc, len]
            NSArray<NSArray*>* values = jsonRevisions[key];
            NSMutableIndexSet* indices = NSMutableIndexSet.new;
            NSInteger generation = key.integerValue;
            
            for (NSArray<NSNumber*>* value in values) {
                if (value.count < 2) continue;
                NSNumber* loc = value[0];
                NSNumber* len = value[1];
                
                NSRange range = NSMakeRange(loc.intValue, len.intValue);
                [indices addIndexesInRange:range];
            }
            
            revisions[@(generation)] = indices;
        }
        
        [versions addObject:@{
            @"text": text,
            @"revisions": revisions
        }];
    }
    
    self.versions = versions;
}
*/

/// Returns line versions ready to be serialized to JSON.
- (NSArray*)versionsForSerialization
{
    NSMutableArray* versions = [NSMutableArray.alloc initWithCapacity:self.versions.count];
    
    for (NSDictionary* v in self.versions.copy) {
        NSMutableDictionary<NSString*,id>* version = v.mutableCopy;
        
        NSDictionary* originalRanges = (NSDictionary*)version[@"revisions"];
        NSMutableDictionary<NSString*, NSArray<NSArray<NSNumber*>*>*>* revisedRanges = [NSMutableDictionary.alloc initWithCapacity:originalRanges.count];
        
        for (NSNumber* key in originalRanges.allKeys) {
            NSIndexSet* indices = originalRanges[key];
            NSMutableArray<NSArray<NSNumber*>*>* ranges = NSMutableArray.new;
            
            [indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
                [ranges addObject:@[@(range.location), @(range.length)]];
            }];
                        
            revisedRanges[key.stringValue] = ranges; // The key has to be explicitly a string for JSON serialization to work
        }
        
        version[@"revisions"] = revisedRanges;
        
        [versions addObject:version];
    }
    
    return versions;
}

/// Converts revi

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
        
        for (InlineFormatting* formatting in InlineFormatting.rangesToFormat) {
            NSMutableIndexSet* indices = [Line rangesInChars:charArray ofLength:length inLine:self between:formatting.open and:formatting.close startLength:formatting.openLength endLength:formatting.closeLength excludingIndices:nil];
            [self setRanges:indices forFormatting:formatting.formatType];
        }
        
        // This method is called after a line has been split in two, so we'll need to parse any leftover note ranges. Not sure if this actually works or not.
        self.noteRanges = [Line rangesInChars:charArray
                                     ofLength:length
                                       inLine:self
                                      between:NOTE_OPEN_CHAR
                                          and:NOTE_CLOSE_CHAR
                                   withLength:2];
    }
    @catch (NSException* e) {
        NSLog(@"Error when trying to reset formatting: %@", e);
        return;
    }
}


#pragma mark - Formatting range lookup
/*
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
*/


+ (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length inLine:(inout Line*)line between:(char*)startString withLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes
{
    return [Line rangesInChars:string ofLength:length inLine:line between:startString and:startString startLength:delimLength endLength:delimLength excludingIndices:excludes];
}

+ (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length inLine:(inout Line*)line between:(char*)startString and:(char*)endString withLength:(NSInteger)delimLength
{
    return [Line rangesInChars:string ofLength:length inLine:line between:startString and:endString withLength:delimLength excludingIndices:nil];
}


+ (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length inLine:(inout Line*)line between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes
{
    // Let's use the asym method here, just put in our symmetric delimiters.
    return [Line rangesInChars:string ofLength:length inLine:line between:startString and:endString startLength:delimLength endLength:delimLength excludingIndices:excludes];
}

/**
 @note Returns indices between given char delimiters
 */
+ (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length inLine:(inout Line*)line between:(char*)startString and:(char*)endString startLength:(NSUInteger)startLength endLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes
{
    NSMutableIndexSet* indexSet = NSMutableIndexSet.new;
    if (length < startLength + delimLength) return indexSet;
    
    NSRange range = NSMakeRange(-1, 0);
    
    for (NSInteger i=0; i <= length - delimLength; i++) {
        // If this index is contained in the omit character indexes, skip
        if ([excludes containsIndex:i]) continue;
        
        // First check for escape character
        if (i > 0) {
            unichar prevChar = string[i-1];
            if (prevChar == '\\') {
                [line.escapeRanges addIndex:i - 1];
                continue;
            }
        }
        
        if (range.location == -1) {
            // Next, see if we can find the whole start string
            bool found = true;
            for (NSInteger k=0; k<startLength; k++) {
                if (i+k >= length) {
                    break;
                } else if (startString[k] != string[i+k]) {
                    found = false;
                    break;
                }
            }
            
            if (!found) continue;
            
            // Success! We found a matching string
            range.location = i;
            
            // Pass the starting string
            i += startLength-1;
            
        } else {
            // We have found a range, let's see if we find a closing string.
            bool found = true;
            for (NSInteger k=0; k<delimLength; k++) {
                if (endString[k] != string[i+k]) {
                    found = false;
                    break;
                }
            }
            
            if (!found) continue;
            
            // Success, we found a closing string.
            range.length = i + delimLength - range.location;
            [indexSet addIndexesInRange:range];
            
            // Add the current formatting ranges to future excludes
            [excludes addIndexesInRange:(NSRange){ range.location, startLength }];
            [excludes addIndexesInRange:(NSRange){ i, delimLength }];
            
            range.location = -1;
            
            // Move past the ending string
            i += delimLength - 1;
        }
    }
    
    return indexSet;
}

+ (NSMutableIndexSet*)rangesOfOmitChars:(unichar*)string ofLength:(NSUInteger)length inLine:(Line*)line lastLineOmitOut:(bool)lastLineOut saveStarsIn:(NSMutableIndexSet*)stars
{
    line.omitIn = lastLineOut;
    
    NSMutableIndexSet* indexSet = NSMutableIndexSet.new;
    NSRange range = (line.omitIn) ? NSMakeRange(0, 0) : NSMakeRange(NSNotFound, 0);
    
    for (NSUInteger i=0; i < length-1; i++) {
        if (i+1 > length) break;
        unichar c1 = string[i];
        unichar c2 = string[i+1];
        
        if (c1 == '/' && c2 == '*' && range.location == NSNotFound) {
            [stars addIndex:i+1];
            range.location = i;
            
        } else if (c1 == '*' && c2 == '/') {
            if (range.location == NSNotFound) continue;
            
            [stars addIndex:i];
            
            range.length = i - range.location + OMIT_PATTERN_LENGTH;
            [indexSet addIndexesInRange:range];
            
            range = NSMakeRange(NSNotFound, 0);
        }
    }
    
    if (range.location != NSNotFound) {
        line.omitOut = true;
        [indexSet addIndexesInRange:NSMakeRange(range.location, line.length - range.location)];
    } else {
        line.omitOut = false;
    }
    
    return indexSet;
}
 

#pragma mark - Formatting shorthands

/*
 
 This is very convoluted, but what can I say. These are shorthand getters for formatted ranges, which are stored in a single mutable dictionary. This makes the system much more scalable, so instead of applying tons of unnecessary hard-coded range names, we can use an enum value, but unfortunately those hard-coded names are already scattered around the app, so ... yeah, this is what we end up. At least from now on, it's much easier to maintain the ranges or add new ones.
 
 Any newer methods should be using this system from now on.
 
 */

- (NSMutableIndexSet*)boldRanges { return [self formattedRange:FormattingRangeBold]; }
- (void)setBoldRanges:(NSMutableIndexSet *)boldRanges { [self setRanges:boldRanges forFormatting:FormattingRangeBold]; }

- (NSMutableIndexSet*)italicRanges { return [self formattedRange:FormattingRangeItalic]; }
- (void)setItalicRanges:(NSMutableIndexSet *)italicRanges { [self setRanges:italicRanges forFormatting:FormattingRangeItalic]; }

- (NSMutableIndexSet*)underlinedRanges { return [self formattedRange:FormattingRangeUnderlined]; }
- (void)setUnderlinedRanges:(NSMutableIndexSet *)underlinedRanges { [self setRanges:underlinedRanges forFormatting:FormattingRangeUnderlined]; }

- (NSMutableIndexSet*)macroRanges { return [self formattedRange:FormattingRangeMacro]; }
- (void)setMacroRanges:(NSMutableIndexSet *)macroRanges { [self setRanges:macroRanges forFormatting:FormattingRangeMacro]; }

- (NSMutableIndexSet*)highlightRanges { return [self formattedRange:FormattingRangeHighlight]; }
- (void)setHighlightRanges:(NSMutableIndexSet *)highlightRanges { [self setRanges:highlightRanges forFormatting:FormattingRangeHighlight]; }

- (NSMutableIndexSet *)omittedRanges { return [self formattedRange:FormattingRangeOmission]; }
- (void)setOmittedRanges:(NSMutableIndexSet *)omittedRanges { [self setRanges:omittedRanges forFormatting:FormattingRangeOmission]; }

- (NSMutableIndexSet *)noteRanges { return [self formattedRange:FormattingRangeNote]; }
- (void)setNoteRanges:(NSMutableIndexSet *)noteRanges { [self setRanges:noteRanges forFormatting:FormattingRangeNote]; }

- (NSMutableIndexSet *)removalSuggestionRanges { return [self formattedRange:FormattingRangeRemovalSuggestion]; }
- (void)setRemovalSuggestionRanges:(NSMutableIndexSet *)removalSuggestionRanges { _formattedRanges[@(FormattingRangeRemovalSuggestion)] = removalSuggestionRanges; }

- (NSMutableIndexSet *)escapeRanges { return [self formattedRange:FormattingRangeEscape]; }
- (void)setEscapeRanges:(NSMutableIndexSet *)escapeRanges { [self setRanges:escapeRanges forFormatting:FormattingRangeEscape]; }

/// Returns the index set for given formatted range type. Never returns a `nil` value.
- (NSMutableIndexSet*)formattedRange:(FormattedRange)type
{
    if (_formattedRanges[@(type)] == nil) _formattedRanges[@(type)] = NSMutableIndexSet.new;
    return _formattedRanges[@(type)];
}

/// Set ranges for a formatting type. Ensures that you won't save a `nil` value.
- (void)setRanges:(NSMutableIndexSet*)indices forFormatting:(FormattedRange)formatting
{
    self.formattedRanges[@(formatting)] = (indices != nil) ? indices : NSMutableIndexSet.new;
}

/// It's much more sensible to calculate this on the fly than store it every time.
- (NSMutableIndexSet*)boldItalicRanges
{
    NSMutableIndexSet* boldItalicRanges = [self.italicRanges indexesIntersectingIndexSet:self.boldRanges].mutableCopy;
    return boldItalicRanges;
}


#pragma mark Formatting checking convenience

/// Returns TRUE when the line has no inline formatting (like **bold**)
-(bool)noFormatting
{
    return !(self.boldRanges.count || self.italicRanges.count || self.highlightRanges.count || self.underlinedRanges.count);
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
        @"notes": self.noteRanges.arrayRepresentation,
        @"omitted": self.omittedRanges.arrayRepresentation,
        @"bold": self.boldRanges.arrayRepresentation,
        @"italic": self.italicRanges.arrayRepresentation,
        @"underlined": self.underlinedRanges.arrayRepresentation,
        @"highlighted": self.highlightRanges.arrayRepresentation,
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


#pragma mark - Image

- (NSString*)image
{
    /*
     
     Resolve image from macro. The bundle or whatever has to be available via export settings to support pagination. Maybe the whole line should 
     
     */
    return nil;
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
