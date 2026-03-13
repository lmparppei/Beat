//
//  ContinousFountainParser.m
//  Beat
//
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//  Parts copyright © 2019-2023 Lauri-Matti Parppei. All rights reserved.

//  Relased under GPL

/*
 
 This code was originally based on Hendrik Noeller's work.
 It is heavily modified for Beat, and not a lot of Hendrik's original code remains.
 
 Parsing happens SEPARATELY from the text view. Once something is changed in the text view,
 we send the changed range here. On iOS, you have to use text storage delegate, and on macOS,
 you can do that in shouldChangeText: - note that those happen at a different stage of editing.
 
 This means that the text view and parser CAN GO OUT OF SYNC. Be EXTREMELY careful with this.
 I've messed it up now and then. My dream would be creating a Beat text container protocol which
 could then be used on NSTextContainer, or just on normal NSAttributedString. The text container
 would register its own changes and provide lines to the parser, eliminating the chance of ever
 going out of sync with the editor.
 
 For now, the current system isn't broken so why fix it.
 
 This is a sprawling, 3800-line class, but I've tried explaining and dividing it with markers.
 A lot of stuff could/should be moved to the line class, I guess, but that's starting to look
 just as bad, he he.
 
 Dread lightly, dear friend.
 
  
 */

#import "ContinuousFountainParser.h"
#import "Line.h"
#import "NSString+CharacterControl.h"
#import "NSMutableIndexSet+Lowest.h"
#import "NSIndexSet+Subset.h"
#import "OutlineScene.h"

#import <BeatParsing/BeatParsing-Swift.h>
#import <BeatParsing/ContinuousFountainParser+Preprocessing.h>
#import <BeatParsing/ContinuousFountainParser+Outline.h>
#import <BeatParsing/ContinuousFountainParser+Lookup.h>
#import <BeatParsing/ContinuousFountainParser+Macros.h>
#import <BeatParsing/ContinuousFountainParser+TitlePage.h>
#import <BeatParsing/ContinuousFountainParser+ParsingRules.h>
#import <BeatParsing/ContinuousFountainParser+LineIdentifiers.h>
#import "ContinuousFountainParser+Notes.h"

#import <BeatParsing/NSArray+BinarySearch.h>
#import <BeatParsing/NSString+CharacterControl.h>

#import "ParsingRule.h"

#define NEW_OUTLINE YES

#pragma mark - Parser

@interface ContinuousFountainParser()

/// An index for the last fetched line result when asking for lines in range
@property (nonatomic) NSUInteger lastLineIndex;
/// The range which was edited most recently.
@property (nonatomic) NSRange editedRange;
/// This is set `true` when we're not parsing the text for the editor but rather for exporting etc.
@property (nonatomic) bool nonContinuous;
/// A private reference to all parsing rules. If you make a copy of the rule array, you can insert your own rules at runtime.
@property (nonatomic) NSArray<ParsingRule*>* parsingRules;

@end


@implementation ContinuousFountainParser

#pragma mark - Initializers

/// Extracts the title page from given string
+ (NSArray*)titlePageForString:(NSString*)string
{
    NSArray <NSString*>*rawLines = [string componentsSeparatedByString:@"\n"];
    
    if (rawLines.count == 0) return @[];
    else if (![rawLines.firstObject containsString:@":"]) return @[];
    
    NSMutableString *text = NSMutableString.new;
    
    for (NSString *l in rawLines) {
        // Break at empty line
        [text appendFormat:@"%@\n", l];
        if ([l isEqualToString:@""]) break;
    }
    [text appendString:@"\n"];
    
    ContinuousFountainParser *parser = [ContinuousFountainParser.alloc initWithString:text];
    [parser updateMacros]; // Resolve macros
    return parser.titlePage;
}

- (ContinuousFountainParser*)initStaticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings
{
    return [self initWithString:string delegate:nil settings:settings nonContinuous:YES];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate nonContinuous:(bool)nonContinuous
{
    return [self initWithString:string delegate:delegate settings:nil nonContinuous:nonContinuous];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate
{
    return [self initWithString:string delegate:delegate settings:nil];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate settings:(BeatDocumentSettings*)settings
{
    return [self initWithString:string delegate:delegate settings:settings nonContinuous:NO];
}
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate settings:(BeatDocumentSettings*)settings nonContinuous:(bool)nonContinuous
{
    self = [super init];
    
    if (self) {
        _lines = NSMutableArray.array;
        _outline = NSMutableArray.array;
        _changedIndices = NSMutableIndexSet.indexSet;
        _titlePage = NSMutableArray.array;
        
        _delegate = delegate;
        _nonContinuous = nonContinuous;
        _staticDocumentSettings = settings;
        
        previousLineIndex = NSNotFound;
        previousSceneIndex = NSNotFound;
        
        // Inform that this parser is STATIC and not continuous (wtf, why is this done using dual values?)
        if (_nonContinuous) _staticParser = YES;
        else _staticParser = NO;
        
        // Store a local reference to parsing rules
        _parsingRules = ContinuousFountainParser.rules;
        
        [self parseText:string];
        [self updateMacros];
    }
    
    return self;
}

- (ContinuousFountainParser*)initWithString:(NSString*)string
{
    return [self initWithString:string delegate:nil];
}

/// Returns the actual rule for given type
- (ParsingRule*)ruleForType:(LineType)type
{
    static NSDictionary<NSNumber*, ParsingRule*>* rules;
    if (rules == nil) {
        NSMutableDictionary* ruleDict = [NSMutableDictionary.alloc initWithCapacity:self.parsingRules.count];
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            for (ParsingRule* rule in self.parsingRules) {
                ruleDict[@(rule.resultingType)] = rule;
            }
            
            rules = ruleDict;
        });
    }
    
    return rules[@(type)];
}

#pragma mark - Document setting getter

/// Returns either document settings OR static document settings. Note that if static document settings are provided, they are preferred.
/// TODO: Perhaps the parser should hold the document settings and read them when originally parsing the document? This would be much more sensible.
- (BeatDocumentSettings*)documentSettings
{
    if (self.staticDocumentSettings != nil) return self.staticDocumentSettings;
    else return self.delegate.documentSettings;
}


#pragma mark - Saved file processing

/// Returns the RAW text when saving a screenplay.
- (NSString*)screenplayForSaving
{
    NSArray *lines = self.safeLines.copy;
    NSMutableString *content = NSMutableString.string;
    
    Line *previousLine;
    for (Line* line in lines) {
        if (!line) continue;
        
        NSString* string = line.string;
        /*
        // This won't work, because we need to keep editor + parser in sync. Alternatives need to be stored to settings.
        if (line.versions.count > 0) {
            // Update current version
            [line storeVersion];
            //We need to have methods for serializing index sets
            NSDictionary* versionDict = @{
                @"current": @(line.currentVersion),
                @"versions": line.versionsForSerialization
            };
            NSData* versionData = [NSJSONSerialization dataWithJSONObject:versionDict options:0 error:nil];
            NSString* versionString = [NSString stringWithFormat:@"\/** ALTERNATIVES: %@ *\/", [NSString.alloc initWithData:versionData encoding:NSUTF8StringEncoding]];
            
            string = [string stringByAppendingString:versionString];
        }*/
    
        // Append to full content
        [content appendString:string];
        
        // Add a line break until we reach the end
        if (line != self.lines.lastObject) [content appendString:@"\n"];
        
        previousLine = line;
    }
    
    return content;
}

/// Returns the whole document as single string
- (NSString*)rawText
{
    NSMutableString *string = NSMutableString.string;
    for (Line* line in self.lines) {
        if (line != self.lines.lastObject) [string appendFormat:@"%@\n", line.string];
        else [string appendFormat:@"%@", line.string];
    }
    return string;
}


#pragma mark - Parsing

#pragma mark Bulk parsing

- (void)parseText:(NSString*)text
{
    if (text == nil) text = @"";
    
    // Replace MS Word/Windows line breaks with macOS ones
    text = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    
    // Split the text by line breaks
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    _lines = [NSMutableArray arrayWithCapacity:lines.count];
    _firstTime = true;
    
    NSUInteger position = 0; // To track at which position every line begins
    
    Line *previousLine;
    
    for (NSString *rawLine in lines) {
        @autoreleasepool {
            NSInteger index = _lines.count;
            Line* line = [[Line alloc] initWithString:rawLine position:position parser:self];
            [self.lines addObject:line];
            
            // Initial parsing
            [self parseTypeAndFormattingForLine:line atIndex:index];
            
            // Quick fix for mistaking an ALL CAPS action for a character cue. This only works in linear, static parsing.
            if (previousLine.type == character && (line.string.length < 1 || line.type == empty)) {
                previousLine.type = [self parseLineTypeFor:line atIndex:index - 1];
                if (previousLine.type == character) previousLine.type = action;
            }
            
            position += rawLine.length + 1; // +1 for newline character
            previousLine = line;
        }
    }
    
    // Reset outline changes
    [self updateOutline];
    self.outlineChanges = OutlineChanges.new;
    
    // Reset changes (to force the editor to reformat each line)
    [self.changedIndices addIndexesInRange:NSMakeRange(0,self.lines.count)];
    
    // Set identifiers (if applicable)
    [self setIdentifiersForOutlineElements:[self.documentSettings get:DocSettingHeadingUUIDs]];
    
    _firstTime = false;
}

// This sets EVERY INDICE as changed.
- (void)resetParsing {
    NSInteger index = 0;
    while (index < self.lines.count) {
        [self.changedIndices addIndex:index];
        index++;
    }
}


#pragma mark - Continuous Parsing

/**
 
 Following code is terrible. I tried refactoring this mess, but the system is pretty confusing and intricate.
 I'll just leave it as it is.
 
 Flow:
 parseChangeInRange ->
 parseAddition/parseRemoval methods write changedIndices
 -> correctParsesInLines processes changedIndices
 
 */

- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string {
    if (range.location == NSNotFound) return;
    
    _lastEditedLine = nil;
    _editedRange = range;
    
    @synchronized (_lines) {
        NSMutableIndexSet *changedIndices = [self processLineChanges:range withString:string];
        [self correctParsesInLines:changedIndices];
    }
}

- (NSMutableIndexSet*)processLineChanges:(NSRange)range withString:(NSString*)string {
    NSMutableIndexSet *changedIndices = NSMutableIndexSet.new;
    
    if (range.length == 0) {
        // Addition
        [changedIndices addIndexes:[self parseAddition:string atPosition:range.location]];
    } else if (string.length == 0) {
        // Removal
        [changedIndices addIndexes:[self parseRemovalAt:range]];
    } else {
        // Replacement
        [changedIndices addIndexes:[self parseRemovalAt:range]];
        [changedIndices addIndexes:[self parseAddition:string atPosition:range.location]];
    }
    
    return changedIndices;
}

#pragma mark Parsing additions

/// This is a convoluted mess.
/// I've replaced the old unichar-based code with this monstrosity to avoid weird quirks with multi-byte characters, and to preserve some metadata when inserting line breaks at the beginning of a line.
- (NSIndexSet*)parseAddition:(NSString*)string atPosition:(NSUInteger)position
{
    NSMutableIndexSet *changedIndices = NSMutableIndexSet.new;
    
    // Get the line where into which we are adding characters
    NSUInteger lineIndex = [self lineIndexAtPosition:position];
    Line* line = self.lines[lineIndex];
    
    [changedIndices addIndex:lineIndex];
    
    NSUInteger indexInLine = position - line.position;
    
    // Cut the string in half
    NSString* tail = [line.string substringFromIndex:indexInLine];
    line.string = [line.string substringToIndex:indexInLine];
    
    NSInteger currentRange = -1;
    
    for (NSInteger i=0; i<string.length; i++) {
        if (currentRange < 0) currentRange = i;
        
        unichar chr = [string characterAtIndex:i];
        
        if (chr == '\n') {
            NSString* addedString = [string substringWithRange:NSMakeRange(currentRange, i - currentRange)];
            line.string = [line.string stringByAppendingString:addedString];
            
            if (lineIndex < self.lines.count - 1) {
                Line* nextLine = self.lines[lineIndex+1];
                NSInteger delta = ABS(NSMaxRange(line.range) - nextLine.position);
                [self decrementLinePositionsFromIndex:lineIndex+1 amount:delta];
            }
            
            [self addLineWithString:@"" atPosition:NSMaxRange(line.range) lineIndex:lineIndex+1];
            
            // Increment current line index and reset inspected range
            lineIndex++;
            currentRange = -1;
            
            // Set current line
            line = self.lines[lineIndex];
        }
    }
    
    // Get the remaining string (if applicable)
    NSString* remainder = (currentRange >= 0) ? [string substringFromIndex:currentRange] : @"";
    line.string = [line.string stringByAppendingString:remainder];
    line.string = [line.string stringByAppendingString:tail];
    
    [self adjustLinePositionsFrom:lineIndex];
    
    //[self report];
    [changedIndices addIndexesInRange:NSMakeRange(changedIndices.firstIndex + 1, lineIndex - changedIndices.firstIndex)];
    
    return changedIndices;
}


#pragma mark Parsing removals

- (NSIndexSet*)parseRemovalAt:(NSRange)range
{
    NSMutableIndexSet *changedIndices = NSMutableIndexSet.new;
    
    // Note: First and last index can be the same, if we are parsing on the same line
    NSInteger firstIndex = [self lineIndexAtPosition:range.location];
    NSInteger lastIndex = [self lineIndexAtPosition:NSMaxRange(range)];
    
    Line* firstLine = self.lines[firstIndex];
    Line* lastLine = self.lines[lastIndex];
    
    bool originalLineWasEmpty = (firstLine.string.length == 0);
    bool lastLineWasEmpty = (lastLine.string.length == 0 || lastLine.type == empty);
    
    bool omitOut = false;
    bool omitIn = false;
    
    NSInteger i = firstIndex;
    while (i < self.lines.count && range.length > 0) {
        Line* line = self.lines[i];
        
        // Store a flag if last handled line previously terminated an omission
        omitOut = line.omitOut;
        omitIn = line.omitIn;
        
        NSRange intersection = NSIntersectionRange(line.range, range);
        NSRange localRange = NSMakeRange(intersection.location - line.position, intersection.length);
        
        if (range.length <= 0) {
            break;
        }
        else if (intersection.length == line.range.length) {
            // The range covers this whole line, remove it altogether.
            [self removeLineAtIndex:i];
            range.length -= line.range.length; // Subtract from full range
        } else {
            // This line is partly covered by the range
            line.string = [line.string stringByRemovingRange:localRange];
            [self decrementLinePositionsFromIndex:i+1 amount:localRange.length];
            range.length -= localRange.length; // Subtract from full range
            
            // Move on to next line (even if we only wanted to remove one character)
            i++;
        }
    }
    
    // Join the two lines if the original line didn't get removed in the process
    if (firstIndex != lastIndex && firstLine == self.lines[firstIndex] &&
        self.lines.count > firstIndex + 1 && self.lines[firstIndex+1] == lastLine) {
        firstLine.string = [firstLine.string stringByAppendingString:lastLine.string];
        [self removeLineAtIndex:firstIndex+1];
        
        NSInteger diff = NSMaxRange(firstLine.range) - lastLine.position;
        [self incrementLinePositionsFromIndex:firstIndex+1 amount:diff];
    }
    
    //[self report];
    
    // Add necessary indices
    [changedIndices addIndex:firstIndex];
    
    // If the line terminated or bleeded out an omit, check surrounding indices, too.
    // Also removing a line break can cause some elements change their type.
    if ((omitOut || lastLineWasEmpty) && firstIndex < self.lines.count+1) [changedIndices addIndex:firstIndex+1];
    if ((omitIn || originalLineWasEmpty) && firstIndex > 0) [changedIndices addIndex:firstIndex-1];
    
    // Make sure we have at least one line left after the operation
    if (self.lines.count == 0) {
        Line* newLine = [Line withString:@"" type:empty];
        newLine.position = 0;
        [self.lines addObject:newLine];
    }
    
    return changedIndices;
}


#pragma mark Add / remove lines

/// Removes a line from the parsed content and decrements positions of other lines
- (void)removeLineAtIndex:(NSInteger)index
{
    if (index < 0 || index >= self.lines.count) return;
    
    Line* line = self.lines[index];
    
    // Check if this line affects the outline
    if (line.isOutlineElement) [self removeOutlineElementForLine:line];
    [self addUpdateToOutlineIfNeededAt:index];
    
    // Remove the line
    [self.lines removeObjectAtIndex:index];
    [self decrementLinePositionsFromIndex:index amount:line.range.length];
    
    // Notify delegate
    [self.delegate lineWasRemoved:line];
    
    // Reset all caches
    [self.uuidTable removeObjectForKey:line.uuidString];
    _lastEditedLine = nil;
    if (line == _prevLineAtLocation) _prevLineAtLocation = nil;
}

/// Adds a new line into the parsed content and increments positions of other lines
- (void)addLineWithString:(NSString*)string atPosition:(NSInteger)position lineIndex:(NSInteger)index
{
    Line *newLine = [Line.alloc initWithString:string position:position parser:self];
    
    [self.lines insertObject:newLine atIndex:index];
    [self incrementLinePositionsFromIndex:index+1 amount:1];
    
    // Reset cached line
    _lastEditedLine = nil;
}


#pragma mark - Correcting parsed content for existing lines

/// Modern way of parsing a line type. We should migrate to this ASAP.
- (LineType)parseLineTypeFor:(Line*)line atIndex:(NSInteger)index
{
    Line *previousLine = (index > 0) ? self.lines[index - 1] : nil;
    Line *nextLine = (index+1 < self.lines.count && index >= 0) ? self.lines[index + 1] : nil;
    
    // Check if this line was forced to become a character cue in editor (by pressing tab)
    if (line.forcedCharacterCue || _delegate.characterInputForLine == line) {
        line.forcedCharacterCue = NO;
        // 94 = ^ (this is here to avoid issues with Turkish alphabet)
        return (line.string.lastNonWhiteSpaceCharacter == 94) ? dualDialogueCharacter : character;
    } else if (line.length == 0 && previousLine.isAnyCharacter) {
        
        //return (previousLine.type == character) ? dialogue : dualDialogue;
    }
    
    if (line.string.length > 0) {
        // Add the first \ as an escape character if needed
        if ([line.string characterAtIndex:0] == '\\')
            [line.escapeRanges addIndex:0];
    }
    
    for (ParsingRule* rule in self.parsingRules) {
        // Ignore disabled types
        if ([self.delegate.disabledTypes containsIndex:(NSInteger)rule.resultingType]) continue;
        
        if ([rule validate:line previousLine:previousLine nextLine:nextLine delegate:self.delegate]) {
            return rule.resultingType;
        }
    }
    
    if ((line.length > 1 && line.string.containsOnlyWhitespace) || line.length > 0) {
        return action;
    } else {
        return empty;
    }
}


/// Ensures that any dialogue on the given line is parsed correctly. Continuous parsing only. A bit confusing to use. Unhelpful documentation.
- (void)ensureDialogueParsingFor:(Line*)line
{
    if (!line.isAnyCharacter) return;
        
    NSInteger i = [self indexOfLine:line];
    if (i == NSNotFound) return;
    
    NSArray *lines = self.lines;
    
    Line *nextLine;
    
    // Get the neighboring lines
    if (i < self.lines.count - 1) nextLine = lines[i + 1];
    
    // Let's not do anything, if we are currently editing these lines.
    if (nextLine != nil && nextLine.string.length == 0 &&
        !NSLocationInRange(_delegate.selectedRange.location, nextLine.range) &&
        !NSLocationInRange(_delegate.selectedRange.location, line.range) &&
        line.numberOfPrecedingFormattingCharacters == 0
        ) {
        line.type = action;
        [self.changedIndices addIndex:i];
        [_delegate applyFormatChanges];
    }
}


/// Intermediate method for `corretParsesInLines` which first finds the indices for line objects and then passes the index set to the main method.
- (void)correctParsesForLines:(NSArray *)lines
{
    NSMutableIndexSet *indices = NSMutableIndexSet.new;
    
    for (Line* line in lines) {
        NSInteger i = [self indexOfLine:line];
        if (i != NSNotFound) [indices addIndex:i];
    }
    
    [self correctParsesInLines:indices];
}

/// Corrects parsing in given line indices
- (void)correctParsesInLines:(NSMutableIndexSet*)lineIndices
{
    while (lineIndices.count > 0) {
        [self correctParseInLine:lineIndices.lowestIndex indicesToDo:lineIndices];
    }
}

/// Fixes dialogue blocks when something is addede below a possible cue
- (void)correctDialogueBlockIfNeededAt:(NSInteger)index
{
    if (index == 0) return;
    Line* line = self.lines[index];
    
    Line* prevLine = self.lines[index-1];
    Line* lineBeforeThat = (index > 1) ? self.lines[index-2] : nil;
    
    for (ParsingRule* rule in self.parsingRules) {
        if ([rule validate:prevLine previousLine:lineBeforeThat nextLine:line delegate:self.delegate]) {
            NSLog(@"Corrected");
            prevLine.type = rule.resultingType;
            [self.changedIndices addIndex:index-1];
            return;
        }
    }
    
    /*
    ParsingRule* characterRule = [self ruleForType:character];
    ParsingRule* dualDialogueCharacterRule = [self ruleForType:dualDialogueCharacter];
    
    // Check if the previous line might be a character cue
    Line* prevLine =  self.lines[index-1];
    Line* lineBeforeThat = (index > 1) ? self.lines[index-2] : nil;
    Line* nextLine = (index < self.lines.count - 1) ? self.lines[index+1] : nil;
    if (prevLine.type == empty) return;
    
    if (line.length > 0 && prevLine.length > 0) {
        bool isCue = false;
        
        for (ParsingRule* rule in @[characterRule, dualDialogueCharacterRule]) {
            if ([rule validate:prevLine
                  previousLine:lineBeforeThat
                      nextLine:nextLine
                      delegate:self.delegate]) {
                prevLine.type = rule.resultingType;
                isCue = true;
            }
        }
        
        if (isCue) {
            [self.changedIndices addIndex:index-1];
        }
    }
     */
}

/// Fixes orphaned cues when line breaks are added to dialogue blocks
- (void)correctOrphanedCueIfNeededAt:(NSInteger)index
{
    Line* line = self.lines[index];
    if (index == 0 || line.type != empty) return;
    
    NSRange selection = (NSThread.isMainThread) ? self.delegate.selectedRange : NSMakeRange(0, 0);
    BOOL emptyLineFound = false;
    
    for (NSInteger i=index-1; i>=0; i--) {
        Line* l = self.lines[i];
        
        if (l.length == 0 || l.type == empty) {
            // Break after two empty lines, no cue to be found
            if (emptyLineFound) break;
            emptyLineFound = true;
            continue;
        } else if (!l.isAnyCharacter) {
            break;
        }
        
        if (selection.location != NSMaxRange(l.textRange) && !NSLocationInRange(selection.location, l.range)) {
            l.type = action;
            [self.changedIndices addIndex:i];
            break;
        }
    }
}

/// Corrects parsing in a single line. Once done, it will be removed from `indices`, but note that new indices might be added in the process.
- (void)correctParseInLine:(NSUInteger)index indicesToDo:(NSMutableIndexSet*)indices
{
    // Do nothing if we went out of range.
    // Note: for code convenience and clarity, some methods can ask to reformat lineIndex-2 etc.,
    // so this check is needed.
    if (index < 0 || index == NSNotFound || index >= self.lines.count) {
        [indices removeIndex:index];
        return;
    }
    
    // Check if this is the last line to be parsed
    bool lastToParse = (indices.count == 1);
    
    Line* currentLine = self.lines[index];
        
    // Remove index as done from array if in array
    if (indices.count) {
        NSUInteger lowestToDo = indices.lowestIndex;
        if (lowestToDo == index) [indices removeIndex:index];
    }
    
    // Save the original line type
    LineType oldType = currentLine.type;
    bool oldOmitOut = currentLine.omitOut;
    
    NSRange oldMarker = currentLine.markerRange;
    NSIndexSet* oldNotes = currentLine.noteRanges.copy;
    
    // We need to look behind before parsing
    if (oldType == empty && currentLine.length > 0) [self correctDialogueBlockIfNeededAt:index];
    
    // Parse correct type
    [self parseTypeAndFormattingForLine:currentLine atIndex:index];
    
    // Update macros when the last line has been updated
    if (lastToParse && self.macrosNeedUpdate) [self updateMacros];
    
    // Add, remove or update outline elements
    if ((oldType == section || oldType == heading) && !currentLine.isOutlineElement) {
        // This line is no longer an outline element
        [self removeOutlineElementForLine:currentLine];
    } else if (currentLine.isOutlineElement && !(oldType == section || oldType == heading)) {
        // This line became outline element
        [self addOutlineElement:currentLine];
    } else {
        // In other case, let's see if we should update the scene
        if ((currentLine.isOutlineElement && (oldType == section || oldType == heading)) ||
            (oldNotes != nil && ![oldNotes isEqualToIndexSet:currentLine.noteRanges]) ||
            !(NSEqualRanges(oldMarker, currentLine.markerRange)) ||
            currentLine.noteRanges.count > 0 ||
            currentLine.type == synopse ||
            currentLine.markerRange.length ||
            currentLine.isOutlineElement ||
            (oldType == synopse && currentLine.type != synopse)
            ) {
            // For any changes to outline elements, we also need to add update the preceding line
            bool didChangeType = (currentLine.type != oldType);
            [self addUpdateToOutlineAtLine:currentLine didChangeType:didChangeType];
        }
        
        // Update all macros
        if (currentLine.macroRanges.count > 0) self.macrosNeedUpdate = true;
    }
        
    // Correct orphaned dialogue if needed
    //[self correctOrphanedDialogueAt:index];
    [self correctOrphanedCueIfNeededAt:index];
        
    // If there is a next element, check if it might need a reparse because of a change in type or omit out
    if (oldType != currentLine.type || oldOmitOut != currentLine.omitOut || lastToParse ||
        currentLine.isDialogueElement || currentLine.isDualDialogueElement || currentLine.type == empty) {
        
        if (index < self.lines.count - 1) {
            Line* nextLine = self.lines[index+1];
            
            bool nextLineAffectedByEmptyLine = [self requiresPrecedingLineToBeEmpty:nextLine.type];
            
            if (currentLine.type != oldType ||
                currentLine.isTitlePage ||					
                nextLine.isTitlePage ||
                
                // Avoid dialogue weirdness
                (currentLine.isAnySortOfDialogue && nextLine.string.length > 0 && !currentLine.isAnySortOfDialogue && currentLine.position != _editedRange.location) ||

                nextLine.isOutlineElement ||
                
                // if the line became empty, it might change type of next line
                (currentLine.type == empty && (nextLineAffectedByEmptyLine || nextLine.length > 0)) ||
                
                // Look for unterminated omits & notes
                nextLine.omitIn != currentLine.omitOut ||
                oldOmitOut != currentLine.omitOut
                )
            {
                [indices addIndex:index+1];
                //[self correctParseInLine:index+1 indicesToDo:indices];
            }
        }
    }

    [self.changedIndices addIndex:index];
}

- (bool)requiresPrecedingLineToBeEmpty:(LineType)type
{
    return (type == heading || type == character || type == dualDialogueCharacter || type == shot);
}


#pragma mark - Incrementing / decrementing line positions

/// Automatically adjusts line positions based on line content. A replacement for the old, clunky `incrementLinePositions` and `decrementLinePositions`.  You still have to make sure that you are parsing correct stuff, though.
/// @note: When calling, start from the line that was changed.
- (void)adjustLinePositionsFrom:(NSInteger)index
{
    if (index >= self.lines.count) return;
    
    Line* line = self.lines[index];
    NSInteger delta = NSMaxRange(line.range);
    index++;
    
    for (;index<self.lines.count; index++) {
        Line* l = self.lines[index];
        l.position = delta;
        
        delta = NSMaxRange(l.range);
    }
}

- (void)incrementLinePositionsFromIndex:(NSUInteger)index amount:(NSUInteger)amount
{
    for (; index < [self.lines count]; index++) {
        Line* line = self.lines[index];
        line.position += amount;
    }
}

- (void)decrementLinePositionsFromIndex:(NSUInteger)index amount:(NSUInteger)amount
{
    for (; index < self.lines.count; index++) {
        Line* line = self.lines[index];
        line.position -= amount;
    }
}


#pragma mark - Parsing Core

/// Parses line type and formatting ranges for current line. This method also takes care of handling possible disabled types.
/// @note Type and formatting are parsed by iterating through character arrays. Using regexes would be much easier, but also about 10 times more costly in CPU time.
- (void)parseTypeAndFormattingForLine:(Line*)line atIndex:(NSUInteger)index
{ @autoreleasepool {
    LineType oldType = line.type;
    line.escapeRanges = NSMutableIndexSet.new;
    
    // Parse current line type
    line.type = [self parseLineTypeFor:line atIndex:index];
    
    // Remember where our boneyard begins
    if (line.isBoneyardSection) self.boneyardAct = line;
    
    // Make sure we didn't receive a disabled type
    if ([self.delegate.disabledTypes containsIndex:(NSUInteger)line.type]) {
        line.type = (line.length > 0) ? action : empty;
    }
    
    // Parse notes
    [self parseNotesFor:line at:index oldType:oldType];
    
    // Parse inline formatting
    [self parseInlineFormattingFor:line atIndex:index];
        
    // Set color for outline elements
    if (line.isOutlineElement || line.type == synopse) line.color = [self colorForHeading:line];
    
    // Parse marker
    line.marker = [self markerForLine:line];
    
    // This could be done in editor formatting code, but whatever.
    line.titleRange = NSMakeRange(0, 0);
    if (line.isTitlePage && [line.string containsString:@":"]) {
        // If the title doesn't begin with \t or space, format it as key name
        if ([line.string characterAtIndex:0] != ' ' && [line.string characterAtIndex:0] != '\t' ) {
            line.titleRange = NSMakeRange(0, [line.string rangeOfString:@":"].location + 1);
        }
    }
} }

- (void)parseInlineFormattingFor:(Line*)line atIndex:(NSInteger)index
{
    NSUInteger length = line.string.length;
    unichar charArray[length];
    [line.string getCharacters:charArray];
    
    // Omits have stars in them, which can be mistaken for formatting characters.
    // We store the omit asterisks into the "excluded" index set to avoid this mixup.
    NSMutableIndexSet* excluded = NSMutableIndexSet.new;
    
    // First, we handle notes and omits, which can bleed over multiple lines.
    // The cryptically named omitOut and noteOut mean that the line bleeds omit/note out on the next line,
    // while omitIn and noteIn tell that are a part of another omitted/note block.
    
    Line* previousLine = (index <= self.lines.count && index > 0) ? self.lines[index-1] : nil;
    
    line.omittedRanges = [Line rangesOfOmitChars:charArray
                                        ofLength:length
                                          inLine:line
                                 lastLineOmitOut:previousLine.omitOut
                                     saveStarsIn:excluded];
    
    // InlineFormatting class provides inline formatting rules. Earlier we did all of these manually, one-by-one, which was more readable, but this saves space and is much more sensible.
    for (InlineFormatting* format in InlineFormatting.rangesToFormat) {
        NSMutableIndexSet* indices = [Line rangesInChars:charArray ofLength:length inLine:line between:format.open and:format.close startLength:format.openLength endLength:format.closeLength excludingIndices:excluded];
        [line setRanges:indices forFormatting:format.formatType];
    }
    
    if (line.type == heading) {
        line.sceneNumberRange = [self sceneNumberForChars:charArray ofLength:length line:line];
        line.resetsSceneNumber = false;
        
        if (line.sceneNumberRange.length == 0) {
            line.sceneNumber = @"";
        } else {
            line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
            NSString* lastSymbol = [line.sceneNumber substringFromIndex:line.sceneNumber.length - 1];
            if ([lastSymbol isEqualToString:@">"] || [lastSymbol isEqualToString:@"＞"]) {
                line.sceneNumber = [line.sceneNumber substringToIndex:line.sceneNumber.length - 1];
                line.resetsSceneNumber = true;
            }
        }
    }
}


- (NSRange)sceneNumberForChars:(unichar*)string ofLength:(NSUInteger)length line:(Line*)line
{
    NSUInteger location = NSNotFound;
    
    for(NSInteger i = length - 1; i >= 0; i--) {
        // Exclude note ranges
        if ([line.noteRanges containsIndex:i]) continue;

        unichar c = string[i];
        if (c == '#') {
            if (location == NSNotFound) location = i;
            else return NSMakeRange(i+1, location-i-1);
        }
    }
    
    return NSMakeRange(0, 0);
}

- (NSString *)markerForLine:(Line*)line
{
    line.markerRange = (NSRange){0, 0};
    line.marker = @"";
    line.markerDescription = @"";
    
    NSString *markerColor = @"";
    NSString *markerContent = @"";
    
    // Get the last marker. If none is found, just return ""
    NSArray* marker = [line contentAndRangeForLastNoteWithPrefix:@"marker"];
    if (marker == nil) return @"";
    
    // The correct way to add a marker is to write [[marker color:Content]], but we'll be gratitious here.
    NSRange range = ((NSNumber*)marker[0]).rangeValue;
    NSString* string = marker[1];
    
    if (![string containsString:@":"] && [string containsString:@" "]) {
        // No colon, let's separate components.
        // First words will always be "marker", so get the second word and see if it's a color
        NSArray<NSString*>* words = [string componentsSeparatedByString:@" "];
        NSInteger descriptionStart = @"marker ".length;
        
        if (words.count > 1) {
            NSString* potentialColor = words[1].lowercaseString;
            if ([self.colors containsObject:potentialColor]) {
                markerColor = potentialColor;
            }
        }
        
        // Get the content after we've checked for potential color for this marker
        markerContent = [string substringFromIndex:descriptionStart + markerColor.length];
    }
    else if ([string containsString:@":"]) {
        NSInteger l = [string rangeOfString:@":"].location;
        markerContent = [string substringFromIndex:l+1];
        
        NSString* left = [string substringToIndex:l];
        NSArray* words = [left componentsSeparatedByString:@" "];
        
        if (words.count > 1) markerColor = words[1];
    }
    
    // Use default as marker color if no applicable color found
    line.marker = (markerColor.length > 0) ? markerColor.lowercaseString : @"default";
    line.markerDescription = [markerContent stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    line.markerRange = range;
        
    return markerColor;
}

/// Finds and sets the color for given outline-level line. Only the last one is used, preceding color notes are ignored.
- (NSString *)colorForHeading:(Line *)line
{
    NSArray *colors = self.colors;
    
    __block NSString* headingColor = @"";
    line.colorRange = NSMakeRange(0, 0);
    
    NSDictionary<NSValue*, NSString*>* noteContents = line.noteContentsAndRanges;
    for (NSNumber* key in noteContents.allKeys) {
        NSRange range = key.rangeValue;
        NSString* content = noteContents[key].lowercaseString;
        
        // We only want the last color on the line, which DOESN'T bleed out.
        // The values come from a dictionary, so we can't be sure, so just skip it if it's an earlier one.
        if (line.colorRange.location > range.location ||
            (NSMaxRange(range) == line.length && line.noteOut) ) continue;
        
        // We can define a color using both [[color red]] or just [[red]], or #ffffff
        if ([content rangeOfString:@"color "].location == 0) {
            // "color red"
            headingColor = [content substringFromIndex:@"color ".length];
            line.colorRange = range;
        } else if ([colors containsObject:content] ||
                 (content.length == 7 && [content characterAtIndex:0] == '#')) {
            // pure "red" or "#ff0000"
            headingColor = content;
            line.colorRange = range;
        }
    }
    
    return headingColor;
}


#pragma mark - Thread-safety for arrays

/**
 
 `safeLines` and `safeOutline` create a copy of the respective array when called from a background thread.
 
 Because Beat now supports plugins with direct access to the parser, we need to be extra careful with our threads.
 Almost any changes to the screenplay in editor will mutate the `.lines` array, so a background process
 calling something that enumerates the array (ie. `linesForScene:`) will cause an immediate crash.
 
 */

- (NSArray*)safeLines
{
    return (NSThread.isMainThread) ? self.lines : self.lines.copy;
}

- (NSArray*)safeOutline
{
    return (NSThread.isMainThread) ? self.outline : self.outline.copy;
}


#pragma mark - Convenience methods

- (NSInteger)numberOfScenes
{
	NSArray *lines = self.safeLines;
	NSInteger scenes = 0;
	
	for (Line *line in lines) {
		if (line.type == heading) scenes++;
	}
	
	return scenes;
}

- (NSArray<OutlineScene*>*)scenes
{
	NSArray *outline = self.safeOutline; // Use thread-safe lines
    NSMutableArray *scenes = NSMutableArray.new;
	
	for (OutlineScene *scene in outline) {
		if (scene.type == heading) [scenes addObject:scene];
	}
	return scenes;
}



#pragma mark - Colors

/// We can't import `BeatColors` here, so let's use generic color names
- (NSArray<NSString*>*)colors
{
    static NSArray* colors;
    if (colors == nil) colors = @[@"red", @"blue", @"green", @"pink", @"magenta", @"gray", @"purple", @"cyan", @"teal", @"yellow", @"orange", @"brown"];
    return colors;
}


#pragma mark - Debugging tools

- (void)report
{
    NSInteger lastPos = 0;
    NSInteger lastLen = 0;
    for (Line* line in self.lines) {
        NSString *error = @"";
        if (lastPos + lastLen != line.position) error = @" 🔴 ERROR";
        
        if (error.length > 0) {
            NSLog(@"   (%lu -> %lu): %@ (%lu) %@ (%lu/%lu)", line.position, line.position + line.string.length + 1, line.string, line.string.length, error, lastPos, lastLen);
        }
        lastLen = line.string.length + 1;
        lastPos = line.position;
    }
}


@end
/*
 
 Thank you, Hendrik Noeller, for making Beat possible.
 Without your massive original work, any of this had never happened.
 
 */
