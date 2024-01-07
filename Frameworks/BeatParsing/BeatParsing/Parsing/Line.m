//
//  Line.m
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  (most) parts copyright © 2019-2021 Lauri-Matti Parppei / Lauri-Matti Parppei. All Rights reserved.

/**
 
# Line Object
 
 Each parsed line is represented by a `Line` object, which holds the string, formatting ranges and other metadata. 
 
 */

#import "Line.h"
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

static NSString* BeatFormattingKeyNone = @"BeatNoFormatting";
static NSString* BeatFormattingKeyItalic = @"BeatItalic";
static NSString* BeatFormattingKeyBold = @"BeatBold";
static NSString* BeatFormattingKeyBoldItalic = @"BeatBoldItalic";
static NSString* BeatFormattingKeyUnderline = @"BeatUnderline";

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

#pragma mark - Shorthands

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


#pragma mark - Type

/// Used by plugin API to create constants for matching line types to enumerated integer values
+ (NSDictionary*)typeDictionary
{
    NSMutableDictionary *types = NSMutableDictionary.dictionary;
    
    NSInteger max = typeCount;
    for (NSInteger i = 0; i < max; i++) {
        LineType type = i;
        NSString *typeName = [Line typeName:type];
        
        [types setValue:@(i) forKey:typeName];
    }
    
    return types;
}

+ (NSString*)typeName:(LineType)type {
    switch (type) {
        case empty:
            return @"empty";
        case section:
            return @"section";
        case synopse:
            return @"synopsis";
        case titlePageTitle:
            return @"titlePageTitle";
        case titlePageAuthor:
            return @"titlePageAuthor";
        case titlePageCredit:
            return @"titlePageCredit";
        case titlePageSource:
            return @"titlePageSource";
        case titlePageContact:
            return @"titlePageContact";
        case titlePageDraftDate:
            return @"titlePageDraftDate";
        case titlePageUnknown:
            return @"titlePageUnknown";
        case heading:
            return @"heading";
        case action:
            return @"action";
        case character:
            return @"character";
        case parenthetical:
            return @"parenthetical";
        case dialogue:
            return @"dialogue";
        case dualDialogueCharacter:
            return @"dualDialogueCharacter";
        case dualDialogueParenthetical:
            return @"dualDialogueParenthetical";
        case dualDialogue:
            return @"dualDialogue";
        case transitionLine:
            return @"transition";
        case lyrics:
            return @"lyrics";
        case pageBreak:
            return @"pageBreak";
        case centered:
            return @"centered";
        case more:
            return @"more";
        case dualDialogueMore:
            return @"dualDialogueMore";
        case shot:
            return @"shot";
        case typeCount:
            return @"";
    }
}

- (NSString*)typeName {
    return [Line typeName:self.type];
}

/// Returns line type as string
+ (NSString*)typeAsString:(LineType)type {
    switch (type) {
        case empty:
            return @"Empty";
        case section:
            return @"Section";
        case synopse:
            return @"Synopse";
        case titlePageTitle:
            return @"Title Page Title";
        case titlePageAuthor:
            return @"Title Page Author";
        case titlePageCredit:
            return @"Title Page Credit";
        case titlePageSource:
            return @"Title Page Source";
        case titlePageContact:
            return @"Title Page Contact";
        case titlePageDraftDate:
            return @"Title Page Draft Date";
        case titlePageUnknown:
            return @"Title Page Unknown";
        case heading:
            return @"Heading";
        case action:
            return @"Action";
        case character:
            return @"Character";
        case parenthetical:
            return @"Parenthetical";
        case dialogue:
            return @"Dialogue";
        case dualDialogueCharacter:
            return @"DD Character";
        case dualDialogueParenthetical:
            return @"DD Parenthetical";
        case dualDialogue:
            return @"DD Dialogue";
        case transitionLine:
            return @"Transition";
        case lyrics:
            return @"Lyrics";
        case pageBreak:
            return @"Page Break";
        case centered:
            return @"Centered";
        case shot:
            return @"Shot";
        case more:
            return @"More";
        case dualDialogueMore:
            return @"DD More";
        case typeCount:
            return @"";
    }
}

/// Retuns current line type as string
- (NSString*)typeAsString
{
    return [Line typeAsString:self.type];
}

/// Returns line type for string
+ (LineType)typeFromName:(NSString *)name
{
    if ([name isEqualToString:@"empty"]) {
        return empty;
    } else if ([name isEqualToString:@"section"]) {
        return section;
    } else if ([name isEqualToString:@"synopsis"]) {
        return synopse;
    } else if ([name isEqualToString:@"titlePageTitle"]) {
        return titlePageTitle;
    } else if ([name isEqualToString:@"titlePageAuthor"]) {
        return titlePageAuthor;
    } else if ([name isEqualToString:@"titlePageCredit"]) {
        return titlePageCredit;
    } else if ([name isEqualToString:@"titlePageSource"]) {
        return titlePageSource;
    } else if ([name isEqualToString:@"titlePageContact"]) {
        return titlePageContact;
    } else if ([name isEqualToString:@"titlePageDraftDate"]) {
        return titlePageDraftDate;
    } else if ([name isEqualToString:@"titlePageUnknown"]) {
        return titlePageUnknown;
    } else if ([name isEqualToString:@"heading"]) {
        return heading;
    } else if ([name isEqualToString:@"action"]) {
        return action;
    } else if ([name isEqualToString:@"character"]) {
        return character;
    } else if ([name isEqualToString:@"parenthetical"]) {
        return parenthetical;
    } else if ([name isEqualToString:@"dialogue"]) {
        return dialogue;
    } else if ([name isEqualToString:@"dualDialogueCharacter"]) {
        return dualDialogueCharacter;
    } else if ([name isEqualToString:@"dualDialogueParenthetical"]) {
        return dualDialogueParenthetical;
    } else if ([name isEqualToString:@"dualDialogue"]) {
        return dualDialogue;
    } else if ([name isEqualToString:@"transition"]) {
        return transitionLine;
    } else if ([name isEqualToString:@"lyrics"]) {
        return lyrics;
    } else if ([name isEqualToString:@"pageBreak"]) {
        return pageBreak;
    } else if ([name isEqualToString:@"centered"]) {
        return centered;
    } else if ([name isEqualToString:@"shot"]) {
        return shot;
    } else if ([name isEqualToString:@"more"]) {
        return more;
    } else if ([name isEqualToString:@"dualDialogueMore"]) {
        return dualDialogueMore;
    } else {
        return typeCount;
    }
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
    newLine.representedLine = self; // For live pagination, refers to the line in PARSER
    newLine.uuid = self.uuid;
    newLine.position = self.position;
    
    newLine.changed = self.changed;
    
    newLine.beginsTitlePageBlock = self.beginsTitlePageBlock;
    newLine.endsTitlePageBlock = self.endsTitlePageBlock;
    
    //newLine.numberOfPrecedingFormattingCharacters = self.numberOfPrecedingFormattingCharacters;
    newLine.unsafeForPageBreak = self.unsafeForPageBreak;
    
    newLine.resolvedMacros = self.resolvedMacros.mutableCopy;
    
    newLine.revisionColor = self.revisionColor.copy; // This is the HIGHEST revision color on the line
    if (self.revisedRanges) newLine.revisedRanges = self.revisedRanges.mutableCopy; // This is a dictionary of revision color names and their respective ranges
    
    if (self.italicRanges.count) newLine.italicRanges = self.italicRanges.mutableCopy;
    if (self.boldRanges.count) newLine.boldRanges = self.boldRanges.mutableCopy;
    if (self.boldItalicRanges.count) newLine.boldItalicRanges = self.boldItalicRanges.mutableCopy;
    if (self.noteRanges.count) newLine.noteRanges = self.noteRanges.mutableCopy;
    if (self.omittedRanges.count) newLine.omittedRanges = self.omittedRanges.mutableCopy;
    if (self.underlinedRanges.count) newLine.underlinedRanges = self.underlinedRanges.mutableCopy;
    if (self.sceneNumberRange.length) newLine.sceneNumberRange = self.sceneNumberRange;
    if (self.strikeoutRanges.count) newLine.strikeoutRanges = self.strikeoutRanges.mutableCopy;
    if (self.removalSuggestionRanges.count) newLine.removalSuggestionRanges = self.removalSuggestionRanges.mutableCopy;
    if (self.escapeRanges.count) newLine.escapeRanges = self.escapeRanges.mutableCopy;
    if (self.macroRanges) newLine.macroRanges = self.macroRanges.mutableCopy;
    
    if (self.sceneNumber) newLine.sceneNumber = [NSString stringWithString:self.sceneNumber];
    if (self.color) newLine.color = [NSString stringWithString:self.color];
    
    newLine.nextElementIsDualDialogue = self.nextElementIsDualDialogue;
    
    return newLine;
}

#pragma mark - Delegate methods

/// Returns the index of this line in the parser.
/// @warning VERY slow, this should be fixed to conform with the new, circular search methods.
- (NSUInteger)index {
    if (!self.parser) return NSNotFound;
    return [self.parser.lines indexOfObject:self];
}


#pragma mark - String methods

- (NSString*)stringForDisplay {
    if (!self.omitted) {
        return [self.stripFormatting stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    } else {
        Line *line = self.clone;
        [line.omittedRanges removeAllIndexes];
        return [line.stripFormatting stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
}

/// @warning Legacy method. Use `line.stripFormatting`
- (NSString*)textContent {
    return self.stripFormatting;
}

/// Returns the last character as `unichar`
- (unichar)lastCharacter {
    if (_string.length > 0) {
        return [_string characterAtIndex:self.length - 1];
    } else {
        // Return error value
        return 0;
    }
}

/// Returns `true` if the stored original content is equal to current string
- (bool)matchesOriginal {
    return [self.string isEqualToString:self.originalString];
}

#pragma mark - Strip formatting

/// Strip any Fountain formatting from the line
/// // Strip any Fountain formatting from the line
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
- (NSString*)stripNotes {
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
- (NSString*)stripSceneNumber {
    NSString *result = [self.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", self.sceneNumber] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, self.string.length)];
    return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

#pragma mark - Element booleans

- (bool)canBeSplitParagraph
{
    return (self.type == action || self.type == lyrics || self.type == centered);
}

/// Returns TRUE for scene, section and synopsis elements
- (bool)isOutlineElement
{
    return (self.type == heading || self.type == section);
}

/// Returns TRUE for any title page element
- (bool)isTitlePage
{
    return (self.type == titlePageTitle ||
            self.type == titlePageCredit ||
            self.type == titlePageAuthor ||
            self.type == titlePageDraftDate ||
            self.type == titlePageContact ||
            self.type == titlePageSource ||
            self.type == titlePageUnknown);
}

/// Checks if the line is completely non-printing __in the eyes of parsing__.
- (bool)isInvisible
{
    return (self.omitted || self.type == section || self.type == synopse || self.isTitlePage);
}

/// Returns TRUE if the line type is forced
- (bool)forced {
    return (self.numberOfPrecedingFormattingCharacters > 0);
}


#pragma mark Dialogue

/// Returns `true` for ANY SORT OF dialogue element, including dual dialogue
- (bool)isAnySortOfDialogue
{
    return (self.isDialogue || self.isDualDialogue);
}

/// Returns `true` for any dialogue element, including character cue
- (bool)isDialogue
{
    return (self.type == character || self.type == parenthetical || self.type == dialogue || self.type == more);
}

/// Returns `true` for dialogue block elements, excluding character cues
- (bool)isDialogueElement
{
    // Is SUB-DIALOGUE element
    return (self.type == parenthetical || self.type == dialogue);
}

/// Returns `true` for any dual dialogue element, including character cue
- (bool)isDualDialogue {
    return (self.type == dualDialogue || self.type == dualDialogueCharacter || self.type == dualDialogueParenthetical || self.type == dualDialogueMore);
}

/// Returns `true` for dual dialogue block elements, excluding character cues
- (bool)isDualDialogueElement {
    return (self.type == dualDialogueParenthetical || self.type == dualDialogue || self.type == dualDialogueMore);
}

/// Returns `true` for ANY character cue (single or dual)
- (bool)isAnyCharacter {
    return (self.type == character || self.type == dualDialogueCharacter);
}

/// Returns `true` for ANY parenthetical line (single or dual)
- (bool)isAnyParenthetical {
    return (self.type == parenthetical || self.type == dualDialogueParenthetical);
}

/// Returns `true` for ANY dialogue line (single or dual)
- (bool)isAnyDialogue
{
    return (self.type == dialogue || self.type == dualDialogue);
}


#pragma mark Omissions & notes
// What a silly mess. TODO: Please fix this.

/// Returns `true` for ACTUALLY omitted lines, so not only for effectively omitted. This is a silly thing for legacy compatibility.
- (bool)isOmitted
{
    return (self.omittedRanges.count >= self.string.length);
}

/// Returns `true` if the line is omitted, kind of. This is a silly mess because of historical reasons.
/// @warning This also includes lines that have 0 length or are completely a note, meaning the method will return YES for empty and/or note lines too.
- (bool)omitted
{
    return (self.omittedRanges.count + self.noteRanges.count >= self.string.length);
}

/**
 Returns true for a line which is a note. Should be used only in conjuction with .omited to check that, yeah, it's omited but it's a note:
 `if (line.omited && !line.note) { ... }`
 
 Checked using trimmed length, to make lines like `  [[note]]` be notes.
 */
- (bool)note
{
    return (self.noteRanges.count >= self.trimmed.length && self.noteRanges.count && self.string.length >= 2);
}

/// Returns `true` if the note is able to succesfully terminate a multi-line note block (contains `]]`)
- (bool)canTerminateNoteBlock {
    return [self canTerminateNoteBlockWithActualIndex:nil];
}
- (bool)canTerminateNoteBlockWithActualIndex:(NSInteger*)position
{
    if (self.length > 30000) return false;
    else if (![self.string containsString:@"]]"]) return false;
    
    unichar chrs[self.string.length];
    [self.string getCharacters:chrs];
    
    for (NSInteger i=0; i<self.length - 1; i++) {
        unichar c1 = chrs[i];
        unichar c2 = chrs[i+1];
        
        if (c1 == ']' && c2 == ']') {
            if (position != nil) *position = i;
            return true;
        }
        else if (c1 == '[' && c2 == '[') return false;
    }
    
    return false;
}

/// Returns `true` if the line can begin a note block
- (bool)canBeginNoteBlock
{
    return [self canBeginNoteBlockWithActualIndex:nil];
}

/// Returns `true` if the lien can begin a note block
/// @param index Pointer to the index where the potential note block begins.
- (bool)canBeginNoteBlockWithActualIndex:(NSInteger*)index
{
    if (self.length > 30000) return false;
    
    unichar chrs[self.string.length];
    [self.string getCharacters:chrs];
    
    for (NSInteger i=self.length - 1; i > 0; i--) {
        unichar c1 = chrs[i];
        unichar c2 = chrs[i-1];
        
        if (c1 == '[' && c2 == '[') {
            if (index != nil) *index = i - 1;
            return true;
        }
        else if (c1 == ']' && c2 == ']') return false;
    }
    
    return false;
}

- (NSArray*)noteContents
{
    return [self noteContentsWithRanges:false];
}

- (NSMutableDictionary<NSValue*, NSString*>*)noteContentsAndRanges
{
    return [self noteContentsWithRanges:true];
}

- (NSArray*)contentAndRangeForLastNoteWithPrefix:(NSString*)string
{
    string = string.lowercaseString;

    NSDictionary* notes = self.noteContentsAndRanges;
    NSRange noteRange = NSMakeRange(0, 0);
    NSString* noteContent = nil;
    
    // Iterate through notes and only accept the last one.
    for (NSValue* r in notes.allKeys) {
        NSRange range = r.rangeValue;
        NSString* noteString = notes[r];
        NSInteger location = [noteString.lowercaseString rangeOfString:string].location;
        
        // Only accept notes which are later than the one already saved, and which begin with the given string
        if (range.location < noteRange.location || location != 0 ) continue;
        
        // Check the last character, which can be either ' ' or ':'. If it's note, carry on.
        if (noteString.length > string.length) {
            unichar followingChr = [noteString characterAtIndex:string.length];
            if (followingChr != ' ' && followingChr != ':') continue;
        }
        
        noteRange = range;
        noteContent = noteString;
    }
    
    if (noteContent != nil) {
        // For notes with a prefix, we need to check that the note isn't bleeding out.
        if (NSMaxRange(noteRange) == self.length && self.noteOut) return nil;
        else return @[ [NSValue valueWithRange:noteRange], noteContent ];
    } else {
        return nil;
    }
}

- (id)noteContentsWithRanges:(bool)withRanges {
    __block NSMutableDictionary<NSValue*, NSString*>* rangesAndStrings = NSMutableDictionary.new;
    __block NSMutableArray* strings = NSMutableArray.new;
    
    NSArray* notes = [self noteData];
    for (BeatNoteData* note in notes) {
        if (withRanges) rangesAndStrings[[NSValue valueWithRange:note.range]] = note.content;
        else [strings addObject:note.content];
    }
    
    if (withRanges) return rangesAndStrings;
    else return strings;
}

- (NSArray*)notes
{
    return self.noteData;
}

- (NSArray*)notesAsJSON
{
    NSMutableArray* notes = NSMutableArray.new;
    for (BeatNoteData* note in self.noteData) {
        [notes addObject:note.json];
    }
    return notes;
}


#pragma mark Centered

/// Returns TRUE if the line is *actually* centered.
- (bool)centered {
	if (self.string.length < 2) return NO;
    return ([self.string characterAtIndex:0] == '>' && [self.string characterAtIndex:self.string.length - 1] == '<');
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

#pragma mark - Story beats

- (NSArray<Storybeat *> *)beats
{
    _beatRanges = NSMutableIndexSet.new;
    NSMutableSet* beats = NSMutableSet.new;
    
    for (BeatNoteData* note in self.noteData) {
        if (note.type != NoteTypeBeat) continue;
        [self.beatRanges addIndexesInRange:note.range];
        
        // This is an empty note, ignore
        NSInteger i = [note.content rangeOfString:@" "].location;
        if (i == NSNotFound) continue;
        
        NSString* beatContents = [note.content substringFromIndex:i];
        NSArray* singleBeats = [beatContents componentsSeparatedByString:@","];
        
        for (NSString* b in singleBeats) {
            Storybeat* beat = [Storybeat line:self scene:nil string:b.uppercaseString range:note.range];
            [beats addObject:beat];
        }
    }
    
    return beats.allObjects;
}
- (NSMutableIndexSet *)beatRanges
{
    if (_beatRanges == nil) [self beats];
    return _beatRanges;
}

- (bool)hasBeat {
	if ([self.string.lowercaseString containsString:@"[[beat "] ||
		[self.string.lowercaseString containsString:@"[[beat:"] ||
        [self.string.lowercaseString containsString:@"[[storyline"])
		return YES;
	else
		return NO;
}
- (bool)hasBeatForStoryline:(NSString*)storyline {
	for (Storybeat *beat in self.beats) {
		if ([beat.storyline.lowercaseString isEqualToString:storyline.lowercaseString]) return YES;
	}
	return NO;
}

- (NSArray<NSString*>*)storylines
{
	NSMutableArray *storylines = NSMutableArray.array;
	for (Storybeat *beat in self.beats) {
		[storylines addObject:beat.storyline];
	}
	return storylines;
}

- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline
{
	for (Storybeat *beat in self.beats) {
		if ([beat.storyline.lowercaseString isEqualToString:storyline.lowercaseString]) return beat;
	}
	return nil;
}
 
- (NSRange)firstBeatRange {
	__block NSRange beatRange = NSMakeRange(NSNotFound, 0);
	
	[self.beatRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		// Find first range
		if (range.length > 0) {
			beatRange = range;
			*stop = YES;
		}
	}];
	
	return beatRange;
}


#pragma mark - Formatting & attribution

/// Parse and apply Fountain stylization inside the string contained by this line.
- (void)resetFormatting {
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

/// Converts an FDX-style attributed string back to Fountain
- (NSString*)attributedStringToFountain:(NSAttributedString*)attrStr
{
	// NOTE! This only works with the FDX attributed string
	NSMutableString *result = NSMutableString.string;
	
	__block NSInteger pos = 0;
	
	[attrStr enumerateAttributesInRange:(NSRange){0, attrStr.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSString *string = [attrStr attributedSubstringFromRange:range].string;
				
		NSMutableString *open = [NSMutableString stringWithString:@""];
		NSMutableString *close = [NSMutableString stringWithString:@""];
		NSMutableString *openClose = [NSMutableString stringWithString:@""];
		
		NSSet *styles = attrs[@"Style"];
		
		if ([styles containsObject:BOLD_STYLE]) [openClose appendString:BOLD_PATTERN];
		if ([styles containsObject:ITALIC_STYLE]) [openClose appendString:ITALIC_PATTERN];
		if ([styles containsObject:UNDERLINE_STYLE]) [openClose appendString:UNDERLINE_PATTERN];
        if ([styles containsObject:NOTE_STYLE]) {
            [open appendString:[NSString stringWithFormat:@"%s", NOTE_OPEN_CHAR]];
            [close appendString:[NSString stringWithFormat:@"%s", NOTE_CLOSE_CHAR]];
        }
        				
		[result appendString:open];
		[result appendString:openClose];
		[result appendString:string];
		[result appendString:openClose];
		[result appendString:close];

		pos += open.length + openClose.length + string.length + openClose.length + close.length;
	}];
	
	return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

/// Creates and stores a string with style attributes. Please don't use in editor, only for static parsing.
/// - note N.B. This is NOT a Cocoa-compatible attributed string. The attributes are used to create a string for screenplay rendering or FDX export.
- (NSAttributedString*)attrString
{
	if (_attrString == nil) {
		NSAttributedString *string = [self attributedStringForFDX];
		NSMutableAttributedString *result = NSMutableAttributedString.new;
		
		[self.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			[result appendAttributedString:[string attributedSubstringFromRange:range]];
		}];
		
		_attrString = result;
	}
	
	return _attrString;
}

- (NSAttributedString*)attributedStringForFDX
{
    return [self attributedString];
}

/// Returns a string with style attributes.
/// - note N.B. Does NOT return a Cocoa-compatible attributed string. The attributes are used to create a string for screenplay rendering or FDX export.
- (NSAttributedString*)attributedString
{
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:(self.string) ? self.string : @""];
		
	// Make (forced) character names uppercase
	if (self.type == character || self.type == dualDialogueCharacter) {
		NSString *name = [self.string substringWithRange:self.characterNameRange].uppercaseString;
		if (name) [string replaceCharactersInRange:self.characterNameRange withString:name];
	}
    
	// Add font stylization
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > ITALIC_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addStyleAttr:ITALIC_STYLE toString:string range:range];
		}
	}];

	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > BOLD_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addStyleAttr:BOLD_STYLE toString:string range:range];
		}
	}];
    
	[self.boldItalicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > ITALIC_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addStyleAttr:BOLDITALIC_STYLE toString:string range:range];
		}
	}];
	
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > UNDERLINE_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addStyleAttr:UNDERLINE_STYLE toString:string range:range];
		}
	}];
		
	[self.omittedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > OMIT_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addStyleAttr:OMIT_STYLE toString:string range:range];
		}
	}];
	
	[self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > NOTE_PATTERN.length * 2) {
			if ([self rangeInStringRange:range]) [self addStyleAttr:NOTE_STYLE toString:string range:range];
		}
	}];

	[self.escapeRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if ([self rangeInStringRange:range]) [self addStyleAttr:OMIT_STYLE toString:string range:range];
	}];
		
	[self.removalSuggestionRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if ([self rangeInStringRange:range]) [self addStyleAttr:@"RemovalSuggestion" toString:string range:range];
	}];
        
    // Add macro attributes
    if (self.macroRanges.count > 0) {
        for (NSValue* r in self.macros.allKeys) {
            NSString* resolvedMacro = self.resolvedMacros[r];
            
            NSRange range = r.rangeValue;
            [string addAttribute:@"Macro" value:(resolvedMacro) ? resolvedMacro : @"" range:range];
        }
    }
    
	if (self.revisedRanges.count) {
		for (NSString *key in _revisedRanges.allKeys) {
			[_revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
                if ([self rangeInStringRange:range]) {
                    [string addAttribute:@"Revision" value:key range:range];
                }
			}];
		}
	}
    
	// Loop through tags and apply
	for (NSDictionary *tag in self.tags) {
		NSString* tagValue = tag[@"tag"];
		if (!tagValue) continue;
		
		NSRange range = [(NSValue*)tag[@"range"] rangeValue];
		[string addAttribute:@"BeatTag" value:tagValue range:range];
	}
	
	return string;
}

/// N.B. Does NOT return a Cocoa-compatible attributed string. The attributes are used to create a string for FDX/HTML conversion.
- (void)addStyleAttr:(NSString*)name toString:(NSMutableAttributedString*)string range:(NSRange)range
{
    if (name == nil) NSLog(@"WARNING: Null value passed to attributes");
    
	// We are going out of range. Abort.
	if (range.location + range.length > string.length || range.length < 1 || range.location == NSNotFound) return;
	
	// Make a copy and enumerate attributes.
	// Add style to the corresponding range while retaining the existing attributes, if applicable.
	[string.copy enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        NSMutableSet* style;
        if (attrs[@"Style"] != nil) {
            // We need to make a copy of the set, otherwise we'll add to the same set of attributes as earlier, causing issues with overlapping attributes.
            style = ((NSMutableSet*)attrs[@"Style"]).mutableCopy;
            [style addObject:name];
        } else {
            style = [NSMutableSet.alloc initWithArray:@[name]];
        }
        
		[string addAttribute:@"Style" value:style range:range];
	}];
}

- (NSAttributedString*)attributedStringWithMacros
{
    NSMutableAttributedString* string = [NSMutableAttributedString.alloc initWithString:self.string];
    // Add macro attributes
    for (NSValue* r in self.macros) {
        NSRange range = r.rangeValue;
        NSString* resolvedMacro = self.resolvedMacros[r];
        
        [string addAttribute:@"Macro" value:(resolvedMacro) ? resolvedMacro : @"" range:range];
    }
    return string;
}

/// Returns an attributed string without formatting markup
- (NSAttributedString*)attributedStringForOutputWith:(BeatExportSettings*)settings
{
    // First create a standard attributed string with the style attributes in place
    NSMutableAttributedString* attrStr = self.attributedString.mutableCopy;
    
    // Set up an index set for each index we want to include.
    NSMutableIndexSet* includedRanges = NSMutableIndexSet.new;
    // If we're printing notes, let's include those in the ranges
    if (settings.printNotes) [includedRanges addIndexes:self.noteRanges];
    
    // Create actual content ranges
    NSMutableIndexSet* contentRanges = [self contentRangesIncluding:includedRanges].mutableCopy;
    
    // Enumerate visible ranges and build up the resulting string
    NSMutableAttributedString* result = NSMutableAttributedString.new;
    [contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length == 0) return;
        
        NSAttributedString* content = [attrStr attributedSubstringFromRange:range];
        [result appendAttributedString:content];
        
        // To ensure we can map the resulting attributed string *back* to the editor ranges, we'll mark the ranges they represent. This is an experimental part of the possible upcoming more WYSIWYG-like experience.
        NSRange editorRange = NSMakeRange(range.location, range.length);
        [result addAttribute:@"BeatEditorRange" value:[NSValue valueWithRange:editorRange] range:NSMakeRange(result.length-range.length, range.length)];
    }];
    
    // Replace macro ranges. All macros should be resolved by now.
    [result.copy enumerateAttribute:@"Macro" inRange:NSMakeRange(0,result.length) options:NSAttributedStringEnumerationReverse usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        if (value == nil) return;
        NSDictionary* attrs = [result attributesAtIndex:range.location effectiveRange:nil];
        NSAttributedString* resolved = [NSAttributedString.alloc initWithString:value attributes:attrs];
        [result replaceCharactersInRange:range withAttributedString:resolved];
    }];
        
    return result;
}


#pragma mark - Splitting

/**

 Splits a line at a given PRINTING index, meaning that the index was calculated from
 the actually printing string, with all formatting removed. That's why we'll first create an attributed string,
 and then format it back to Fountain.
 
 The whole practice is silly, because we could actually just put attributed strings into the paginated
 result — with revisions et al. I don't know why I'm just thinking about this now. Well, Beat is not
 the result of clever thinking and design, but trial and error. Fuck you, past me, for leaving all
 this to me.
 
 We could actually send attributed strings to the PAGINATOR and make it easier to calculate the ----
 it's 22.47 in the evening, I have to work tomorrow and I'm sitting alone in my kitchen. It's not
 a problem for present me.
 
 See you in the future.
 
 __Update in 2023-12-28__: The pagination _sort of_ works like this nowadays, but because we are
 still rendering Fountain to something else, we still need to split and format the lines.
 This should still be fixed at some point. Maybe create line element which already has a preprocessed
 attributed string for output.
 
 */
- (NSArray<Line*>*)splitAndFormatToFountainAt:(NSInteger)index {
	NSAttributedString *string = [self attributedStringForFDX];
	NSMutableAttributedString *attrStr = NSMutableAttributedString.new;
	
	[self.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > 0) [attrStr appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
	
	NSAttributedString *first  = [NSMutableAttributedString.alloc initWithString:@""];
	NSAttributedString *second = [NSMutableAttributedString.alloc initWithString:@""];
	
	// Safeguard index (this could happen to numerous reasons, extra spaces etc.)
	if (index > attrStr.length) index = attrStr.length;
	
	// Put strings into the split strings
	first = [attrStr attributedSubstringFromRange:(NSRange){ 0, index }];
	if (index <= attrStr.length) second = [attrStr attributedSubstringFromRange:(NSRange){ index, attrStr.length - index }];
	
	// Remove whitespace from the beginning if needed
    while (second.string.length > 0) {
        if ([second.string characterAtIndex:0] == ' ') {
            second = [second attributedSubstringFromRange:NSMakeRange(1, second.length - 1)];
            // The index also shifts
            index += 1;
        } else {
            break;
        }
    }
	
	Line *retain = [Line withString:[self attributedStringToFountain:first] type:self.type pageSplit:YES];
	Line *split = [Line withString:[self attributedStringToFountain:second] type:self.type pageSplit:YES];
	
	if (self.changed) {
		retain.changed = YES;
		split.changed = YES;
	}
        
    // Set flags
    
    retain.beginsNewParagraph = self.beginsNewParagraph;
    retain.paragraphIn = self.paragraphIn;
    retain.paragraphOut = true;

    split.paragraphIn = true;
    split.beginsNewParagraph = true;

    // Set identity
    
	retain.uuid = self.uuid;
	retain.position = self.position;
	
	split.uuid = self.uuid;
	split.position = self.position + retain.string.length;
	
	// Now we'll have to go through some extra trouble to keep the revised ranges intact.
	if (self.revisedRanges.count) {
		NSRange firstRange = NSMakeRange(0, index);
		NSRange secondRange = NSMakeRange(index, split.string.length);
		split.revisedRanges = NSMutableDictionary.new;
		retain.revisedRanges = NSMutableDictionary.new;
		
		for (NSString *key in self.revisedRanges.allKeys) {
			retain.revisedRanges[key] = NSMutableIndexSet.indexSet;
			split.revisedRanges[key] = NSMutableIndexSet.indexSet;
			
			// Iterate through revised ranges, calculate intersections and add to their respective line items
			[self.revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
				NSRange firstIntersct = NSIntersectionRange(range, firstRange);
				NSRange secondIntersct = NSIntersectionRange(range, secondRange);
				
				if (firstIntersct.length > 0) {
					[retain.revisedRanges[key] addIndexesInRange:firstIntersct];
				}
				if (secondIntersct.length > 0) {
					// Substract offset from the split range to get it back to zero
					NSRange actualRange = NSMakeRange(secondIntersct.location - index, secondIntersct.length);
					[split.revisedRanges[key] addIndexesInRange:actualRange];
				}
			}];
		}
	}
    
    // Let's also split our resolved macros
    if (self.resolvedMacros.count) {
        retain.resolvedMacros = NSMutableDictionary.new;
        split.resolvedMacros = NSMutableDictionary.new;
        
        for (NSValue* r in self.resolvedMacros.allKeys) {
            NSRange range = r.rangeValue;
            if (range.length == 0) continue;
            
            if (NSMaxRange(range) < index) {
                NSValue* rKey = [NSValue valueWithRange:range];
                retain.resolvedMacros[rKey] = self.resolvedMacros[r];
            } else {
                NSRange newRange = NSMakeRange(range.location - index, range.length);
                NSValue* rKey = [NSValue valueWithRange:newRange];
                split.resolvedMacros[rKey] = self.resolvedMacros[r];
            }
        }
    }
	
	return @[ retain, split ];
}


#pragma mark - Formatting helpers

/// What is this? Seems like a more sensible attributed string idea.
- (NSAttributedString*)formattingAttributes
{
    NSMutableAttributedString* attrStr = [NSMutableAttributedString.alloc initWithString:self.string];
    
    [self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [attrStr addAttribute:BeatFormattingKeyItalic value:@YES range:range];
    }];
    [self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [attrStr addAttribute:BeatFormattingKeyBold value:@YES range:range];
    }];
    [self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [attrStr addAttribute:BeatFormattingKeyUnderline value:@YES range:range];
    }];
    
    return attrStr;
}

#pragma mark Formatting range lookup

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

/// Returns TRUE when the line has no Fountain formatting (like **bold**)
-(bool)noFormatting {
	if (_boldRanges.count || _italicRanges.count || _strikeoutRanges.count || _underlinedRanges.count) return NO;
	else return YES;
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

#pragma mark - Ranges

/// Converts a global (document-wide) range into local range inside the line
-(NSRange)globalRangeToLocal:(NSRange)range
{
    // Insert a range and get a LOCAL range in the line
    NSRange lineRange = (NSRange){ self.position, self.string.length };
    NSRange intersection = NSIntersectionRange(range, lineRange);
    
    return (NSRange){ intersection.location - self.position, intersection.length };
}

/// Converts a global (document-wide) range into local range inside this line
-(NSRange)globalRangeFromLocal:(NSRange)range
{
    return NSMakeRange(range.location + self.position, range.length);
}

- (bool)rangeInStringRange:(NSRange)range {
	if (range.location + range.length <= self.string.length) return YES;
	else return NO;
}

/// Returns ranges with content ONLY (useful for reconstructing the string with no Fountain stylization)
- (NSIndexSet*)contentRanges
{
    return [self contentRangesIncluding:nil];
}
/// Returns ranges with content ONLY (useful for reconstructing the string with no Fountain stylization), with given extra ranges included.
- (NSIndexSet*)contentRangesIncluding:(NSIndexSet*)includedRanges
{
    NSMutableIndexSet *contentRanges = NSMutableIndexSet.indexSet;
    [contentRanges addIndexesInRange:NSMakeRange(0, self.string.length)];
    
    // Get formatting ranges.
    // We can provide ranges that are excluded from formatting ranges and included in the resulting string.
    NSMutableIndexSet *formattingRanges = self.formattingRanges.mutableCopy;
    [formattingRanges removeIndexes:includedRanges];
    
    // Remove formatting indices from content indices.
    [contentRanges removeIndexes:formattingRanges];
    
    return contentRanges;
}

/// Returns content ranges, including notes
- (NSIndexSet*)contentRangesWithNotes {
	// Returns content ranges WITH notes included
	NSMutableIndexSet *contentRanges = [NSMutableIndexSet indexSet];
	[contentRanges addIndexesInRange:NSMakeRange(0, self.string.length)];
	
	NSIndexSet *formattingRanges = [self formattingRangesWithGlobalRange:NO includeNotes:NO];
	[contentRanges removeIndexes:formattingRanges];
	
	return contentRanges;
}

- (NSUInteger)numberOfPrecedingFormattingCharacters
{
    if (self.string.length < 1) return 0;
    
    LineType type = self.type;
    unichar c = [self.string characterAtIndex:0];
    
    // Check if this is a shot
    if (self.string.length > 1 && c == '!') {
        unichar c2 = [self.string characterAtIndex:1];
        if (type == shot && c2 == '!') return 2;
    }
    
    // Other types
    if ((self.type == character && c == '@') ||
        (self.type == heading && c == '.') ||
        (self.type == action && c == '!') ||
        (self.type == lyrics && c == '~') ||
        (self.type == synopse && c == '=') ||
        (self.type == centered && c == '>') ||
        (self.type == transitionLine && c == '>')) {
        return 1;
    }
    // Section
    else if (self.type == section) {
        return self.sectionDepth;
    }
    
    return 0;
}

/// Maps formatting characters into an index set, INCLUDING notes, scene numbers etc. to convert it to another style of formatting
- (NSIndexSet*)formattingRanges {
    return [self formattingRangesWithGlobalRange:NO includeNotes:YES];
}

/// Maps formatting characters into an index set, INCLUDING notes, scene numbers etc.
/// You can use global range flag to return ranges relative to the *whole* document.
/// Notes are included in formatting ranges by default.
- (NSIndexSet*)formattingRangesWithGlobalRange:(bool)globalRange includeNotes:(bool)includeNotes
{
	NSMutableIndexSet *indices = NSMutableIndexSet.new;
	NSInteger offset = 0;
	
	if (globalRange) offset = self.position;
	
	// Add any ranges that are used to force elements. First handle the elements which don't work without markup characters.
    NSInteger precedingCharacters = self.numberOfPrecedingFormattingCharacters;
    if (precedingCharacters > 0) {
        [indices addIndexesInRange:NSMakeRange(0 + offset, precedingCharacters)];
	}
	
	// Catch dual dialogue force symbol
	if (self.type == dualDialogueCharacter && self.string.length > 0 && [self.string characterAtIndex:self.string.length - 1] == '^') {
		[indices addIndex:self.string.length - 1 +offset];
	}
	
	// Add ranges for > and < (if needed)
	if (self.type == centered && self.string.length >= 2) {
		if ([self.string characterAtIndex:0] == '>' && [self.string characterAtIndex:self.string.length - 1] == '<') {
			[indices addIndex:0+offset];
			[indices addIndex:self.string.length - 1+offset];
		}
	}
    
    // Title page keys will be included in formatting ranges
    if (self.isTitlePage && self.beginsTitlePageBlock && self.titlePageKey.length) {
        NSInteger i = self.titlePageKey.length+1;
        [indices addIndexesInRange:NSMakeRange(0, i)];
        
        // Also add following spaces to formatting ranges
        while (i < self.length) {
            unichar c = [self.string characterAtIndex:i];
            
            if (c == ' ') [indices addIndex:i];
            else break;
            
            i++;
        }
    }
	
	// Escape ranges
	[indices addIndexes:[[NSIndexSet alloc] initWithIndexSet:self.escapeRanges]];
	
	// Scene number range
	if (self.sceneNumberRange.length) {
		[indices addIndexesInRange:(NSRange){ self.sceneNumberRange.location + offset, self.sceneNumberRange.length }];
		// Also remove the surrounding #'s
		[indices addIndex:self.sceneNumberRange.location + offset - 1];
		[indices addIndex:self.sceneNumberRange.location + self.sceneNumberRange.length + offset];
	}
	
	// Stylization ranges
	[self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location +offset, BOLD_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - BOLD_PATTERN.length +offset, BOLD_PATTERN.length)];
	}];
	[self.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location +offset, ITALIC_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - ITALIC_PATTERN.length +offset, ITALIC_PATTERN.length)];
	}];
	[self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location +offset, UNDERLINE_PATTERN.length)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - UNDERLINE_PATTERN.length +offset, UNDERLINE_PATTERN.length)];
	}];
    /*
	[self.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[indices addIndexesInRange:NSMakeRange(range.location, STRIKEOUT_PATTERN.length +offset)];
		[indices addIndexesInRange:NSMakeRange(range.location + range.length - STRIKEOUT_PATTERN.length +offset, STRIKEOUT_PATTERN.length)];
	}];
     */
			
	// Add note ranges
	if (includeNotes) [indices addIndexes:self.noteRanges];
	[indices addIndexes:self.omittedRanges];
	
	return indices;
}

- (NSRange)characterNameRange
{
	NSInteger parenthesisLoc = [self.string rangeOfString:@"("].location;
	
	if (parenthesisLoc == NSNotFound) {
		return (NSRange){ 0, self.string.length };
	} else {
		return (NSRange){ 0, parenthesisLoc };
	}
}
- (BOOL)hasExtension {
	/// Returns  `TRUE` if the character cue has an extension
	if (!self.isAnyCharacter) return false;
	
	NSInteger parenthesisLoc = [self.string rangeOfString:@"("].location;
	if (parenthesisLoc == NSNotFound) return false;
	else return true;
}

/// Ranges of emojis (o the times we live in)
- (NSArray<NSValue*>*)emojiRanges {
    return self.string.emo_emojiRanges;
}
- (bool)hasEmojis {
    if (self.string == nil) return false;
    return self.string.emo_containsEmoji;
}


#pragma mark - Helper methods

- (NSString*)trimmed {
	return [self.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

/// Joins a line into this line. Copies all stylization and offsets the formatting ranges.
- (void)joinWithLine:(Line *)line
{
	if (!line) return;
	
	NSString *string = line.string;
	
	// Remove symbols for forcing elements
	if (line.numberOfPrecedingFormattingCharacters > 0 && string.length > 0) {
		string = [string substringFromIndex:line.numberOfPrecedingFormattingCharacters];
	}
	
	NSInteger offset = self.string.length + 1 - line.numberOfPrecedingFormattingCharacters;
	if (line.changed) self.changed = YES;
	
	// Join strings
	self.string = [self.string stringByAppendingString:[NSString stringWithFormat:@"\n%@", string]];
	
	// Offset and copy formatting ranges
	[line.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.boldRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.italicRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.underlinedRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.strikeoutRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.escapeRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.escapeRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self.noteRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
	}];
    [line.macroRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [self.macroRanges addIndexesInRange:(NSRange){ offset + range.location, range.length }];
    }];
	
	// Offset and copy revised ranges
	for (NSString* key in line.revisedRanges.allKeys) {
		if (!self.revisedRanges) self.revisedRanges = NSMutableDictionary.dictionary;
		if (!self.revisedRanges[key]) self.revisedRanges[key] = NSMutableIndexSet.indexSet;
		
		[line.revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			[self.revisedRanges[key] addIndexesInRange:(NSRange){ offset + range.location, range.length }];
		}];
	}
    
    // Offset and copy resolved macros
    if (line.macroRanges.count > 0) {
        if (self.resolvedMacros == nil) self.resolvedMacros = NSMutableDictionary.new;
        
        for (NSValue* r in line.resolvedMacros) {
            NSRange range = r.rangeValue;
            NSRange newRange = NSMakeRange(range.location + offset, range.length);
            NSValue* rKey = [NSValue valueWithRange:newRange];
            self.resolvedMacros[rKey] = line.resolvedMacros[r];
        }
    }
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
	if (self.type == dualDialogueCharacter && [name characterAtIndex:name.length-1] == '^') {
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
        @"notes": [self notesAsJSON],
        @"ranges": self.ranges
	}];
    
    if (self.type == synopse) {
        json[@"color"] = (self.color != nil) ? self.color : @"";
        json[@"stringForDisplay"] = self.stringForDisplay;
    }
    
    return json;
}

/// Returns a dictionary of ranges for plugins
-(NSDictionary*)ranges {
	return @{
		@"notes": [self indexSetAsArray:self.noteRanges],
		@"omitted": [self indexSetAsArray:self.omittedRanges],
		@"bold": [self indexSetAsArray:self.boldRanges],
		@"italic": [self indexSetAsArray:self.italicRanges],
		@"underlined": [self indexSetAsArray:self.underlinedRanges],
		@"revisions": @{
			@"blue": (self.revisedRanges[@"blue"]) ? [self indexSetAsArray:self.revisedRanges[@"blue"]] : @[],
			@"orange": (self.revisedRanges[@"orange"]) ? [self indexSetAsArray:self.revisedRanges[@"orange"]] : @[],
			@"purple": (self.revisedRanges[@"purple"]) ? [self indexSetAsArray:self.revisedRanges[@"purple"]] : @[],
			@"green": (self.revisedRanges[@"green"]) ? [self indexSetAsArray:self.revisedRanges[@"green"]] : @[]
		}
	};
}

-(NSArray*)indexSetAsArray:(NSIndexSet*)set {
	NSMutableArray *array = NSMutableArray.array;
	[set enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length > 0) {
			[array addObject:@[ @(range.location), @(range.length) ]];
		}
	}];
	
	return array;
}

#pragma mark - Custom data

- (NSDictionary*)setCustomData:(NSString*)key value:(id)value {
	if (!_customDataDictionary) _customDataDictionary = NSMutableDictionary.new;
	
	if (!value)	return _customDataDictionary[key];
	else _customDataDictionary[key] = value;
	return nil;
}
- (id)getCustomData:(NSString*)key {
	if (!_customDataDictionary) _customDataDictionary = NSMutableDictionary.new;
	return _customDataDictionary[key];
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
