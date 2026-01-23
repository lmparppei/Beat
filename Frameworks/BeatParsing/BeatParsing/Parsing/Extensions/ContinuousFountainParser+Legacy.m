//
//  ContinuousFountainParser+Legacy.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 19.1.2026.
//

#import "ContinuousFountainParser+Legacy.h"
#import <BeatParsing/ContinuousFountainParser+TitlePage.h>

/**
 A collection of legacy methods which will reside here for testing purposes.
 */
@implementation ContinuousFountainParser (Legacy)

/// Parses the line type for given line. It *has* to know its line index.
/// @warning __This method is no longer in use.__ Use ONLY for testing purposes.
- (LineType)parseLineTypeFor:(Line*)line atIndex:(NSUInteger)index
{ @synchronized (self) {
    NSLog(@"🆘 DEPRECATED: Do not use parseLineTypeFor: unless it's for testing.");
    
    Line *previousLine = (index > 0) ? self.lines[index - 1] : nil;
    Line *nextLine = (line != self.lines.lastObject && index+1 < self.lines.count) ? self.lines[index+1] : nil;
    
    NSString *trimmedString = (line.string.length > 0) ? [line.string stringByTrimmingTrailingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] : @"";
    
    // Check for everything that is considered as empty
    bool previousIsEmpty = (previousLine.effectivelyEmpty || index == 0);
        
    // Check if this line was forced to become a character cue in editor (by pressing tab)
    if (line.forcedCharacterCue || self.delegate.characterInputForLine == line) {
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
        [self.changedIndices addIndex:index-1];
        
        if (firstChar == '(' || [firstSymbol isEqualToString:@"（"]) {
            return (previousLine.isDialogue) ? parenthetical : dualDialogueParenthetical;
        } else {
            return dialogue;
        }
    }
    
    // Action is the default
    return action;
} }

/// Notifies character cue that it has a dual dialogue sibling. Used in static parsing, I guess? (2026 edit: I think this is obsolete.)
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

@end
