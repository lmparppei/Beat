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
#import <BeatParsing/NSArray+BinarySearch.h>
#import "ContinuousFountainParser+Notes.h"
#import <BeatParsing/NSString+CharacterControl.h>
#import "ParsingRule.h"

#define NEW_OUTLINE YES

#pragma mark - Parser

@interface ContinuousFountainParser()

/// An index for the last fetched line result when asking for lines in range
@property (nonatomic) NSUInteger lastLineIndex;
/// The range which was edited most recently.
@property (nonatomic) NSRange editedRange;

// Title page parsing
@property (nonatomic) NSString *openTitlePageKey;
@property (nonatomic) NSString *previousTitlePageKey;

// Static parser flag
@property (nonatomic) bool nonContinuous;

// Cached line set for UUID creation
@property (nonatomic) NSArray* cachedLines;

@property (nonatomic) NSArray<ParsingRule*>* parsingRules;

@end

@implementation ContinuousFountainParser

static NSDictionary* patterns;


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
        
        // Inform that this parser is STATIC and not continuous (wtf, why is this done using dual values?)
        if (_nonContinuous) _staticParser = YES;
        else _staticParser = NO;
        
        // Parsing rules for the future.
        _parsingRules = @[
            [ParsingRule type:heading options:(PreviousIsEmpty) previousTypes:nil beginsWith:@[@".", @"．"] endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:@[@"."]],
            [ParsingRule type:shot options:(PreviousIsEmpty) previousTypes:nil beginsWith:@[@"!!", @"！！"] endsWith:nil],
            [ParsingRule type:action options:0 previousTypes:nil beginsWith:@[@"!", @"！"] endsWith:nil],
            [ParsingRule type:lyrics options:0 previousTypes:nil beginsWith:@[@"~", @"～"] endsWith:nil],
            [ParsingRule type:dualDialogueCharacter options:(PreviousIsEmpty | AllowsLeadingWhitespace) previousTypes:nil beginsWith:@[@"@", @"＠"] endsWith:@[@"^"]],
            [ParsingRule type:character options:(PreviousIsEmpty | AllowsLeadingWhitespace) previousTypes:nil beginsWith:@[@"@", @"＠"] endsWith:nil],
            
            [ParsingRule type:section options:(PreviousIsEmpty) previousTypes:nil beginsWith:@[@"#", @"＃"] endsWith:nil],
            [ParsingRule type:synopse options:0 previousTypes:nil beginsWith:@[@"="] endsWith:nil],
            
            [ParsingRule type:heading options:(PreviousIsEmpty) previousTypes:nil beginsWith:@[@"int", @"ext", @"i/e", @"i./e", @"e/i", @"e./i"] endsWith:nil requiredAfterPrefix:@[@" ", @"."] excludedAfterPrefix:nil],
            [ParsingRule type:centered options:(AllowsLeadingWhitespace) previousTypes:nil beginsWith:@[@">"] endsWith:@[@"<"]],
            [ParsingRule type:transitionLine options:0 previousTypes:nil beginsWith:@[@">"] endsWith:nil],
            [ParsingRule type:transitionLine options:(PreviousIsEmpty | AllCapsUntilParentheses) previousTypes:nil beginsWith:nil endsWith:@[@"TO:"]],
            
            // Dual dialogue
            [ParsingRule type:dualDialogueCharacter options:(PreviousIsEmpty | AllCapsUntilParentheses | AllowsLeadingWhitespace) previousTypes:nil beginsWith:nil endsWith:@[@"^"] requiredAfterPrefix:nil excludedAfterPrefix:nil],
            [ParsingRule type:dualDialogueParenthetical options:(AllowsLeadingWhitespace | PreviousIsNotEmpty)  previousTypes:@[@(dualDialogueCharacter), @(dualDialogue)] beginsWith:@[@"("] endsWith:nil requiredAfterPrefix:nil excludedAfterPrefix:nil],
            [ParsingRule type:dualDialogue options:(AllowsLeadingWhitespace | PreviousIsNotEmpty) minimumLength:1 previousTypes:@[@(dualDialogueCharacter), @(dualDialogue), @(dualDialogueParenthetical)]],
            
            // Dialogue
            [ParsingRule type:character options:(PreviousIsEmpty | AllCapsUntilParentheses | AllowsLeadingWhitespace) minimumLength:2 minimumLengthAtInput:3 previousTypes:nil],
            [ParsingRule type:parenthetical options:(AllowsLeadingWhitespace | PreviousIsNotEmpty) previousTypes:@[@(character), @(dialogue), @(parenthetical)] beginsWith:@[@"("] endsWith:nil],
            [ParsingRule type:dialogue options:(AllowsLeadingWhitespace | RequiresTwoEmptyLines | PreviousIsNotEmpty) minimumLength:0 previousTypes:@[@(character), @(dialogue), @(parenthetical)]],
            
            [ParsingRule type:titlePageTitle options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"title:"] endsWith:nil ],
            [ParsingRule type:titlePageCredit options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"credit:"] endsWith:nil],
            [ParsingRule type:titlePageAuthor options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"author:", @"authors:"] endsWith:nil],
            [ParsingRule type:titlePageSource options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"source:"] endsWith:nil],
            [ParsingRule type:titlePageContact options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"contact:"] endsWith:nil],
            [ParsingRule type:titlePageDraftDate options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:@[@"draft date:"] endsWith:nil],
            [ParsingRule type:titlePageUnknown options:(AllowsLeadingWhitespace | BelongsToTitlePage) previousTypes:nil beginsWith:nil endsWith:nil],
                         
            [ParsingRule type:empty exactMatches:@[@"", @" "]],
        ];
        
        [self parseText:string];
        [self updateMacros];
    }
    
    return self;
}
- (ContinuousFountainParser*)initWithString:(NSString*)string
{
    return [self initWithString:string delegate:nil];
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
    text = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]; // Replace MS Word/Windows line breaks with macOS ones
    
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
            [self.lines addObject:line]; //Add to lines array
            
            [self parseTypeAndFormattingForLine:line atIndex:index];
            
            // Quick fix for mistaking an ALL CAPS action for a character cue
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
    /*
    NSMutableIndexSet* changedIndices = NSMutableIndexSet.new;
    
    // Get the line where we are adding characters
    NSUInteger lineIndex = [self lineIndexAtPosition:position];
    Line* currentLine = self.lines[lineIndex];
    
    [changedIndices addIndex:lineIndex];
    
    NSUInteger indexInLine = position - currentLine.position;
    
    // Split the current line at insertion point
    NSString* firstHalf = [currentLine.string substringToIndex:indexInLine];
    NSString* secondHalf = [currentLine.string substringFromIndex:indexInLine];
    
    // Split the added string into components by newline
    NSArray* components = [string componentsSeparatedByString:@"\n"];
    
    if (components.count == 1) {
        // No line breaks in the added string, just insert the string
        currentLine.string = [NSString stringWithFormat:@"%@%@%@", firstHalf, string, secondHalf];
    } else {
        // Multiple components with line breaks
        
        // Keep the original line intact with its metadata
        if (indexInLine == 0) {
            // When inserting at the beginning of a line
            
            // First, add all new lines except the last one
            NSInteger insertionIndex = lineIndex;
            for (NSUInteger i = 0; i < components.count - 1; i++) {
                [self addLineWithString:components[i] atPosition:currentLine.position lineIndex:insertionIndex];
                [changedIndices addIndex:insertionIndex];
                insertionIndex++;
            }
            
            // Append the last component to the original line with secondHalf
            currentLine.string = [components.lastObject stringByAppendingString:secondHalf];
            lineIndex = insertionIndex; // Update lineIndex to the original line's new position
        } else {
            // When inserting in the middle or at the end of a line
            // Firs update the current line with firstHalf + first component
            currentLine.string = [firstHalf stringByAppendingString:components[0]];
            
            // Now insert new lines for in-the-middle components
            NSInteger insertionIndex = lineIndex + 1;
            for (NSUInteger i = 1; i < components.count; i++) {
                NSString* lineContent = (i == components.count - 1)
                ? [components[i] stringByAppendingString:secondHalf] // Last component gets secondHalf
                : components[i];                                      // Middle components as-is
                
                [self addLineWithString:lineContent
                             atPosition:NSMaxRange(self.lines[insertionIndex-1].range)
                              lineIndex:insertionIndex];
                [changedIndices addIndex:insertionIndex];
                insertionIndex++;
            }
            
            // Update lineIndex to point to the last inserted line
            lineIndex = insertionIndex - 1;
        }
    }
    
    // Adjust positions of all subsequent lines
    [self adjustLinePositionsFrom:changedIndices.firstIndex];
    
    return changedIndices;
     */
    
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
    
    // Reset cached line
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

/// Parse faulty and orphaned dialogue (this can happen, because... well, there are *reasons*)
- (void)correctOrphanedDialogueAt:(NSUInteger)index {
    if (index == 0) return;
    
    Line *prevLine = self.lines[index - 1]; // Get previous line
    NSRange selection = (NSThread.isMainThread) ? self.delegate.selectedRange : NSMakeRange(0, 0); // Get selection
    
    // If previous line is NOT EMPTY, has content and the selection is not at the preceding position, go through preceding lines
    if (prevLine.type != empty && prevLine.length == 0 && selection.location != prevLine.position - 1) {
        NSInteger i = index - 1;
        
        while (i >= 0) {
            Line *l = self.lines[i];
            
            if (l.length > 0 && l != self.delegate.characterInputForLine && l.numberOfPrecedingFormattingCharacters == 0) {
                // Not a forced character cue, not the preceding line to selection
                if (l.type == character && selection.location != NSMaxRange(l.textRange) && !NSLocationInRange(selection.location, l.range)) {
                    l.type = action;
                    [self.changedIndices addIndex:i];
                }
                break;
            } else if (l.type != empty && l.length == 0) {
                l.type = empty;
                [self.changedIndices addIndex:i];
            }
            
            i -= 1;
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
    [self correctOrphanedDialogueAt:index];
        
    //If there is a next element, check if it might need a reparse because of a change in type or omit out
    if (oldType != currentLine.type || oldOmitOut != currentLine.omitOut || lastToParse ||
        currentLine.isDialogueElement || currentLine.isDualDialogueElement || currentLine.type == empty) {
        
        if (index < self.lines.count - 1) {
            Line* nextLine = self.lines[index+1];
            
            bool nextLineAffectedByEmptyLine = [self requiresPrecedingLineToBeEmpty:nextLine.type];
            
            if (currentLine.type != oldType ||
                currentLine.isTitlePage ||					// if line is a title page, parse next line too
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
    line.type = [self parseLineTypeFor:line atIndex:index];
    
    // In the future we'll replace the previous function with rule-based parsing. This already works, but needs support for FORCED TYPES.
    //LineType test = [self ruleBasedParsingFor:line atIndex:index];
    //if (line.type != test) NSLog(@"⚠️ wrong type:  rule-based %@ / parsed %@) - %@", [Line typeName:test], [Line typeName:line.type], line);
    
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
    
    line.omittedRanges = [self rangesOfOmitChars:charArray
                                        ofLength:length
                                          inLine:line
                                 lastLineOmitOut:previousLine.omitOut
                                     saveStarsIn:excluded];
    
    line.boldRanges = [self rangesInChars:charArray
                                 ofLength:length
                                  between:BOLD_CHAR
                                      and:BOLD_CHAR
                               withLength:BOLD_PATTERN_LENGTH
                         excludingIndices:excluded
                                     line:line];
    
    line.italicRanges = [self rangesInChars:charArray
                                   ofLength:length
                                    between:ITALIC_CHAR
                                        and:ITALIC_CHAR
                                 withLength:ITALIC_PATTERN_LENGTH
                           excludingIndices:excluded
                                       line:line];
    
    line.underlinedRanges = [self rangesInChars:charArray
                                       ofLength:length
                                        between:UNDERLINE_CHAR
                                            and:UNDERLINE_CHAR
                                     withLength:UNDERLINE_PATTERN_LENGTH
                               excludingIndices:nil
                                           line:line];
    
    line.macroRanges = [self rangesInChars:charArray
                                  ofLength:length
                                   between:MACRO_OPEN_CHAR
                                       and:MACRO_CLOSE_CHAR
                                withLength:2
                          excludingIndices:nil
                                      line:line];
    
    // Intersecting indices between bold & italic are boldItalic
    if (line.boldRanges.count > 0 && line.italicRanges.count > 0) {
        line.boldItalicRanges = [line.italicRanges indexesIntersectingIndexSet:line.boldRanges].mutableCopy;
    } else {
        line.boldItalicRanges = NSMutableIndexSet.new;
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

/// Modern way of parsing a line type. We should migrate to this ASAP.
- (LineType)ruleBasedParsingFor:(Line*)line atIndex:(NSInteger)index
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
        if ([rule validate:line previousLine:previousLine nextLine:nextLine delegate:self.delegate]) {
            return rule.resultingType;
        }
    }
    
    if (line.length == 0) return empty;
    return action;
}


/// Parses the line type for given line. It *has* to know its line index.
/// TODO: This bunch of spaghetti should be refactored and split into smaller functions.
- (LineType)parseLineTypeFor:(Line*)line atIndex:(NSUInteger)index
{ @synchronized (self) {
    Line *previousLine = (index > 0) ? self.lines[index - 1] : nil;
    Line *nextLine = (line != self.lines.lastObject && index+1 < self.lines.count) ? self.lines[index+1] : nil;
    
    NSString *trimmedString = (line.string.length > 0) ? [line.string stringByTrimmingTrailingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] : @"";
    
    // Check for everything that is considered as empty
    bool previousIsEmpty = (previousLine.effectivelyEmpty || index == 0);
        
    // Check if this line was forced to become a character cue in editor (by pressing tab)    
    if (line.forcedCharacterCue || _delegate.characterInputForLine == line) {
        line.forcedCharacterCue = NO;
        // 94 = ^ (this is here to avoid issues with Turkish alphabet)
        if (line.string.lastNonWhiteSpaceCharacter == 94) return dualDialogueCharacter;
        else return character;
    }
    
    // Handle empty lines first
    if (line.length == 0) {
        if (previousLine.isDialogue || previousLine.isDualDialogue) {
            // If preceding line is formatted as dialogue BUT it's empty, we'll just return empty.
            if (previousLine.string.length == 0) return empty;
            
            // If preceded by a character cue, always return dialogue
            if (previousLine.type == character) return dialogue;
            else if (previousLine.type == dualDialogueCharacter) return dualDialogue;
            
            NSInteger selection = (NSThread.isMainThread) ? self.delegate.selectedRange.location : 0;
            
            // If it's any other dialogue line and we're editing it, return dialogue
            if ((previousLine.isAnyDialogue || previousLine.isAnyParenthetical)
                && previousLine.length > 0
                && (nextLine.length == 0 || nextLine == nil)
                && NSLocationInRange(selection, line.range)) {
                return (previousLine.isDialogue) ? dialogue : dualDialogue;
            }
        }
        
        return empty;
    }
    
    // Check forced elements
    
    // Find last and first character. Excuse the upcoming mess.
    // Some elements ignore the leading whitespace, but NOT action, section and synopsis.
    unichar actualFirstChar = [line.string characterAtIndex:0];
    NSInteger firstCharIndex = line.string.indexOfFirstNonWhiteSpaceCharacter;
    if (firstCharIndex == NSNotFound || actualFirstChar == '!' || actualFirstChar == '=' || actualFirstChar == '#') firstCharIndex = 0;
    NSInteger lastCharIndex = line.string.indexOfLastNonWhiteSpaceCharacter;
    if (lastCharIndex == NSNotFound) lastCharIndex = line.string.length - 1;
    
    unichar firstChar = [line.string characterAtIndex:firstCharIndex];
    unichar lastChar = [line.string characterAtIndex:lastCharIndex];
    
    // Support for full width punctuation. Let's not waste energy by substringing the line unless we actually need to.
    bool fullWidthPunctuation = (firstChar >= 0xFF01 && firstChar <= 0xFF60);
    NSString* firstSymbol = (fullWidthPunctuation) ? [line.string substringToIndex:1] : nil;
    
    // Also, lets add the first \ as an escape character
    if (firstChar == '\\') [line.escapeRanges addIndex:firstCharIndex];
    
    // Forced whitespace
    bool containsOnlyWhitespace = line.string.containsOnlyWhitespace; // Save to use again later
    bool twoSpaces = (firstChar == ' ' && lastChar == ' ' && line.length > 1); // Contains at least two spaces
    
    if (containsOnlyWhitespace && !twoSpaces) return empty;
        
    // Check forced types
    if ([trimmedString isEqualToString:@"==="]) {
        return pageBreak;
    } else if (firstCharIndex == 0 && (firstChar == '!' || [firstSymbol isEqualToString:@"！"]) ) {
        // Action or shot
        if (line.length > 1) {
            unichar secondChar = [line.string characterAtIndex:1];
            NSString* secondSymbol = [line.string substringWithRange:NSMakeRange(1, 1)];
            if (secondChar == '!'  || [secondSymbol isEqualToString:@"！"]) return shot;
        }
        return action;
    } else if (firstChar == '.' && previousIsEmpty) {
        // '.' forces a heading, but we'll check that it isn't followed by another dot.
        if (line.length == 1 || (line.length > 1 && [line.string characterAtIndex:1] != '.')) {
            return heading;
        }
    }
    // ... and then the rest.
    else if ((firstChar == '@' || [firstSymbol isEqualToString:@"＠"]) && line.string.lastNonWhiteSpaceCharacter == 94 && previousIsEmpty) return dualDialogueCharacter;
    else if (firstChar == '@' || [firstSymbol isEqualToString:@"＠"]) return character;
    else if (firstChar == '>' && lastChar == '<') return centered;
    else if (firstChar == '>') return transitionLine;
    else if (firstChar == '~' || [firstSymbol isEqualToString:@"～"]) return lyrics;
    else if (firstChar == '='|| [firstSymbol isEqualToString:@"＝"]) return synopse;
    else if (firstChar == '#' || [firstSymbol isEqualToString:@"＃"]) return section;
    else if ((firstChar == '.' || [firstSymbol isEqualToString:@"．"]) && previousIsEmpty) return heading;
    
    // Title page
    if ((previousLine == nil || previousLine.isTitlePage) && !(line.string.containsOnlyUppercase && previousLine == nil)) {
        LineType titlePageType = [self parseTitlePageLineTypeFor:line previousLine:previousLine lineIndex:index];
        if (titlePageType != NSNotFound) return titlePageType;
    }
    
    // Dual dialogue
    if (lastChar == 94 && line.noteRanges.firstIndex != 0 && previousIsEmpty) {
        // A character line ending in ^ is a dual dialogue character
        // (94 = ^, we'll compare the numerical value to avoid mistaking Turkish alphabet character Ş as ^)
        NSString* cue = [line.string substringToIndex:line.length - 1];
        if (cue.length > 0 && cue.onlyUppercaseUntilParenthesis) {
            // Note the previous character cue that it's followed by dual dialogue
            [self makeCharacterAwareOfItsDualSiblingFrom:index];
            return dualDialogueCharacter;
        }
    }
    else if (previousIsEmpty && line.string.length >= 3 && line != self.delegate.characterInputForLine) {
        
        // Check for transitions first
        if (line.visibleContentIsUppercase && previousIsEmpty) {
            NSString* transition = [line.string substringFromIndex:line.length - 3];
            if ([transition isEqualToString:@"TO:"] || [transition isEqualToString:@"IN:"]) return transitionLine;
        }

        // Handle items which require an empty line before them (and we're not forcing character input)
        NSString* firstChars = [line.string substringToIndex:3].lowercaseString;
        
        // Heading
        if ([firstChars isEqualToString:@"int"] ||
            [firstChars isEqualToString:@"ext"] ||
            [firstChars isEqualToString:@"est"] ||
            [firstChars isEqualToString:@"i/e"] ||
            [firstChars isEqualToString:@"e/i"]) {
            
            // If it's just under 4 characters, return heading
            if (line.length < 4) return heading;
            
            // To avoid words like "international" from becoming headings, the extension HAS to end with either dot, space or slash
            unichar nextChar = [line.string characterAtIndex:3];
            if (nextChar == '.' || nextChar == ' ' || nextChar == '/') return heading;
        }
        
        // Character
        if (line.string.onlyUppercaseUntilParenthesis && !containsOnlyWhitespace && line.noteRanges.firstIndex != 0) {
            // It is possible that this IS NOT A CHARACTER but an all-caps action line
            if (index + 2 < self.lines.count) {
                Line* twoLinesOver = (Line*)self.lines[index+2];
                
                NSRange selection = self.delegate.selectedRange;
                
                // Next line is empty, line after that isn't - and we're not on that particular line
                bool nextLinesAreEmpty = (nextLine.length == 0 && twoLinesOver.length == 0);
                //bool selectionOnNextLine = (nextLine.length == 0 && NSLocationInRange(selection.location, nextLine.range));
                bool selectionOnCurrentLine = NSLocationInRange(selection.location, line.range);
                
                if (!selectionOnCurrentLine && nextLinesAreEmpty) {
                    return action;
                }
            }
            
            return character;
        }
    }
    else if ((previousLine.isDialogue || previousLine.isDualDialogue) && previousLine.length > 0) {
        // If the line begins with open parenthesis, it's a parenthetical line
        if (firstChar == '(') return (previousLine.isDialogue) ? parenthetical : dualDialogueParenthetical;
        // Otherwise it's just dialogue
        return (previousLine.isDialogue) ? dialogue : dualDialogue;
    }
    
    // If the previous line is UPPERCASE, isn't a forced element, and is preceded by an empty line, and this line isn't empty, it can be a character cue.
    // Basically we'll make any all-caps lines with < 3 characters character cues and/or make all-caps actions character cues when
    // the text is changed to have some dialogue follow it.
    // We're doing this only after everything else has failed.
    else if (previousLine.type == action
        && !previousIsEmpty
        && line.length > 0
        && !previousLine.forced
        && previousLine.string.onlyUppercaseUntilParenthesis
        && [self previousLine:previousLine].type == empty) {
        
        // Welcome to UTF-8 hell in ObjC. 94 = ^, we'll use the unichar numerical value to avoid mistaking Turkish alphabet letter 'Ş' as '^'.
        if (previousLine.string.lastNonWhiteSpaceCharacter == 94) previousLine.type = dualDialogueCharacter;
        else previousLine.type = character;
        
        // Note that the previous line got changed
        [_changedIndices addIndex:index-1];
        
        if (firstChar == '(' || [firstSymbol isEqualToString:@"（"]) {
            return (previousLine.isDialogue) ? parenthetical : dualDialogueParenthetical;
        } else {
            return dialogue;
        }
    }
    
    // Action is the default
    return action;
} }

/// I don't understand any of this.
- (LineType)parseTitlePageLineTypeFor:(Line*)line previousLine:(Line*)previousLine lineIndex:(NSInteger)index
{
    NSString *key = line.titlePageKey;
    
    if (key.length > 0) {
        // This is a keyed title page line (Title: Something)
        NSString* value = line.titlePageValue;
        if (value == nil) value = @"";
        
        // Store title page data
        NSMutableDictionary *titlePageData = @{ key: [NSMutableArray arrayWithObject:value] }.mutableCopy;
        [_titlePage addObject:titlePageData];
        
        // Set this key as open (in case there are additional title page lines)
        _openTitlePageKey = key;
        
        if ([key isEqualToString:@"title"]) {
            return titlePageTitle;
        } else if ([key isEqualToString:@"author"] || [key isEqualToString:@"authors"]) {
            return titlePageAuthor;
        } else if ([key isEqualToString:@"credit"]) {
            return titlePageCredit;
        } else if ([key isEqualToString:@"source"]) {
            return titlePageSource;
        } else if ([key isEqualToString:@"contact"]) {
            return titlePageContact;
        } else if ([key isEqualToString:@"contacts"]) {
            return titlePageContact;
        } else if ([key isEqualToString:@"contact info"]) {
            return titlePageContact;
        } else if ([key isEqualToString:@"draft date"]) {
            return titlePageDraftDate;
        } else {
            return titlePageUnknown;
        }
    } else if (previousLine.isTitlePage) {
        // This is a non-keyed title page line and part of a title page block
        NSString *key = @"";
        NSInteger i = index - 1;
        while (i >= 0) {
            Line *pl = self.lines[i];
            if (pl.titlePageKey.length > 0) {
                key = pl.titlePageKey;
                break;
            }
            i -= 1;
        }
        if (key.length > 0) {
            NSMutableDictionary* dict = _titlePage.lastObject;
            [(NSMutableArray*)dict[key] addObject:line.string];
        }
        
        return previousLine.type;
    }
    
    return NSNotFound;
}

/// Notifies character cue that it has a dual dialogue sibling. Used in static parsing, I guess?
- (void)makeCharacterAwareOfItsDualSiblingFrom:(NSInteger)index
{
    NSInteger i = index - 1;
    while (i >= 0) {
        Line *prevLine = [self.lines objectAtIndex:i];
        
        if (prevLine.type == character) {
            prevLine.nextElementIsDualDialogue = YES;
            break;
        } else if (!prevLine.isDialogueElement && !prevLine.isDualDialogueElement && prevLine.type != empty) {
            // If we encounter something else than a line of dialogue or an empty line, break the loop.
            break;
        }
        
        i--;
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
        if ([content containsString:@"color "]) {
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



#pragma mark - Title page

/// Returns the title page lines as string
- (NSString*)titlePageAsString
{
    NSMutableString *string = NSMutableString.new;
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        [string appendFormat:@"%@\n", line.string];
    }
    return string;
}

/// Returns just the title page lines
- (NSArray<Line*>*)titlePageLines
{
    NSMutableArray *lines = NSMutableArray.new;
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        [lines addObject:line];
    }
    
    return lines;
}

/// Re-parser the title page and returns a weird array structure: `[ { "key": "value }, { "key": "value }, { "key": "value } ]`.
/// This is because we want to maintain the order of the keys, and though ObjC dictionaries sometimes stay in the correct order, things don't work like that in Swift.
- (NSArray<NSDictionary<NSString*,NSArray<Line*>*>*>*)parseTitlePage
{
    [self.titlePage removeAllObjects];
    
    // Store the latest key
    NSString *key = @"";
    BeatMacroParser* titlePageMacros = BeatMacroParser.new;
    
    // Iterate through lines and break when we encounter a non- title page line
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        
        [self resolveMacrosOn:line parser:titlePageMacros];
        
        // Reset flags
        line.beginsTitlePageBlock = false;
        line.endsTitlePageBlock = false;
        
        // Determine if the line is empty
        bool empty = false;
        
        // See if there is a key present on the line ("Title: ..." -> "Title")
        if (line.titlePageKey.length > 0) {
            key = line.titlePageKey.lowercaseString;
            if ([key isEqualToString:@"author"]) key = @"authors";
            
            line.beginsTitlePageBlock = true;
            
            NSMutableDictionary* titlePageValue = [NSMutableDictionary dictionaryWithDictionary:@{ key: NSMutableArray.new }];
            [self.titlePage addObject:titlePageValue];
            
            // Add the line into the items of the current line, IF IT'S NOT EMPTY
            NSString* trimmed = [line.string substringFromIndex:line.titlePageKey.length+1].trim;
            if (trimmed.length == 0) empty = true;
        }
        
        // Find the correct item in an array of dictionaries
        // [ { "title": [Line] } , { ... }, ... ]
        NSMutableArray *items = [self titlePageArrayForKey:key];
        if (items == nil) continue;
        
        // Add the line if it's not empty
        if (!empty) [items addObject:line];
    }
    
    // After we've gathered all the elements, lets iterate them once more to determine where blocks end.
    for (NSDictionary<NSString*,NSArray<Line*>*>* element in self.titlePage) {
        NSArray<Line*>* lines = element.allValues.firstObject;
        Line* firstLine = lines.firstObject;
        Line* lastLine = lines.lastObject;
        
        // I've seen a weird issue with NSStrings being inserted here. No idea how and why, but… yeah. This is an emergency fix.
        if ([firstLine isKindOfClass:Line.class])
            firstLine.beginsTitlePageBlock = true;
        if ([lastLine isKindOfClass:Line.class])
            lastLine.endsTitlePageBlock = true;
    }
    
    return self.titlePage;
}

/// Returns the lines for given title page key. For example,`Title` would return something like `["My Film"]`.
- (NSMutableArray<Line*>*)titlePageArrayForKey:(NSString*)key
{
    for (NSMutableDictionary* d in self.titlePage) {
        if ([d.allKeys.firstObject isEqualToString:key]) return d[d.allKeys.firstObject];
    }
    return nil;
}


#pragma mark - Finding character ranges

- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString withLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes line:(Line*)line
{
    // Let's use the asym method here, just put in our symmetric delimiters.
    return [self asymRangesInChars:string ofLength:length between:startString and:endString startLength:delimLength endLength:delimLength excludingIndices:excludes line:line];
}

/**
 @note This is a confusing method name, but only because it is based on the old rangesInChars method. However, it's basically the same code, but I've put in the ability to seek ranges between two delimiters that are **not** the same, and can have asymmetrical length.  The original method now just calls this using the symmetrical delimiters.
 */
- (NSMutableIndexSet*)asymRangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(char*)startString and:(char*)endString startLength:(NSUInteger)startLength endLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes line:(Line*)line
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

- (NSMutableIndexSet*)rangesOfOmitChars:(unichar*)string ofLength:(NSUInteger)length inLine:(Line*)line lastLineOmitOut:(bool)lastLineOut saveStarsIn:(NSMutableIndexSet*)stars
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


#pragma mark - Thread-safety for arrays

/**
 
 `safeLines` and `safeOutline` create a copy of the respective array when called from a background thread.
 
 Because Beat now supports plugins with direct access to the parser, we need to be extra careful with our threads.
 Almost any changes to the screenplay in editor will mutate the `.lines` array, so a background process
 calling something that enumerates the array (ie. `linesForScene:`) will cause an immediate crash.
 
 */

- (NSArray*)safeLines
{
	if (NSThread.isMainThread) return self.lines;
	else return self.lines.copy;
}
- (NSArray*)safeOutline
{
	if (NSThread.isMainThread) return self.outline;
	else return self.outline.copy;
}

/// Returns a map with the UUID as key to identify actual line objects.
/// TODO: Maybe convert this into a map table?
- (NSMapTable<NSUUID*, Line*>*)uuidsToLines
{
    @synchronized (self.lines) {
        // Return the cached version when possible -- or when we are not in the main thread.

        if ([self.cachedLines isEqualToArray:self.lines]) {
            return _uuidsToLines;
        }

        NSArray* lines = self.lines.copy;
        
        // Store the current state of lines
        self.cachedLines = lines;

        // Create UUID map with strong UUID references to weak line objects.
        NSMapTable<NSUUID*, Line*>* uuidTable = [NSMapTable.alloc initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:lines.count];

        // Create UUID array. This method is usually used by background methods, so we'll need to create a copy of the line array.
        // NSMutableDictionary* uuids = [NSMutableDictionary.alloc initWithCapacity:lines.count];
        
        for (Line* line in lines) {
            if (line == nil) continue;
            // uuids[line.uuid] = line;
            [uuidTable setObject:line forKey:line.uuid.copy];
        }
        
        _uuidsToLines = uuidTable;
        return _uuidsToLines;
    }
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


#pragma mark - Line identifiers (UUIDs)

/// Returns every line UUID as an arrayg
- (NSArray<NSUUID*>*)lineIdentifiers:(NSArray<Line*>*)lines
{
	if (lines == nil) lines = self.lines;
	
	NSMutableArray *uuids = NSMutableArray.new;
	for (Line *line in lines) {
		[uuids addObject:line.uuid];
	}
	return uuids;
}

/// Sets the given UUIDs to each line at the same index. Note that you can provide either an array of `NSString`s or __REAL__ `NSUUID`s.
- (void)setIdentifiers:(NSArray*)uuids
{
	for (NSInteger i = 0; i < uuids.count; i++) {
		id item = uuids[i];
        // We can have either strings or real UUIDs in the array. Make sure we're using the correct type.
        NSUUID *uuid = ([item isKindOfClass:NSString.class]) ? [NSUUID.alloc initWithUUIDString:item] : item;
				
		if (i < self.lines.count && uuid != nil) {
			Line *line = self.lines[i];
			line.uuid = uuid;
		}
	}
}

/// Sets the given UUIDs to each outline element at the same index
- (void)setIdentifiersForOutlineElements:(NSArray<NSDictionary<NSString*, NSString*>*>*)uuids
{
    for (NSInteger i=0; i<self.outline.count; i++) {
        if (i >= uuids.count) break;
        
        OutlineScene* scene = self.outline[i];
        NSDictionary* item = uuids[i];
        
        NSString* uuidString = item[@"uuid"];
        NSString* string = item[@"string"];
        
        if ([scene.string.lowercaseString isEqualToString:string.lowercaseString]) {
            NSUUID* uuid = [NSUUID.alloc initWithUUIDString:uuidString];
            scene.line.uuid = uuid;
        }
    }
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
