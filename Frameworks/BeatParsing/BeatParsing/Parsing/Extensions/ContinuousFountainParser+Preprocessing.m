//
//  ContinuousFountainParser+Preprocessing.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 4.1.2024.
//
/**
 
 This category handles the line preprocessing before the document is allowed to be printed.
 
 */

#import "ContinuousFountainParser+Preprocessing.h"
#import <BeatParsing/BeatParsing-Swift.h>
#import <BeatParsing/BeatScreenplay.h>
#import <BeatParsing/BeatExportSettings.h>


#pragma mark - Preprocessing

@implementation ContinuousFountainParser (Preprocessing)

- (NSArray<Line*>*)preprocessForPrinting
{
    return [self preprocessForPrintingWithLines:self.safeLines exportSettings:nil screenplayData:nil];
}

- (NSArray<Line*>*)preprocessForPrintingWithExportSettings:(BeatExportSettings*)exportSettings
{
    return [self preprocessForPrintingWithLines:self.safeLines exportSettings:exportSettings screenplayData:nil];
}

- (NSArray<Line*>*)preprocessForPrintingWithLines:(NSArray*)lines exportSettings:(BeatExportSettings*)settings screenplayData:(BeatScreenplay**)screenplay
{
    if (!lines) lines = self.safeLines;
    return [ContinuousFountainParser preprocessForPrintingWithLines:lines documentSettings:self.documentSettings exportSettings:settings screenplay:screenplay];
}

+ (NSArray<Line*>*)preprocessForPrintingWithLines:(NSArray*)lines documentSettings:(BeatDocumentSettings*)documentSettings
{
    return [ContinuousFountainParser preprocessForPrintingWithLines:lines documentSettings:documentSettings exportSettings:nil screenplay:nil];
}

/// Handles an array of lines and preprocesses them for pagination/rendering module according to document settings. Macros are applied, effectively empty lines are stripped away, forced page numbers and paragraph break rules are applied and so on.
+ (NSArray<Line*>*)preprocessForPrintingWithLines:(NSArray*)lines documentSettings:(BeatDocumentSettings*)documentSettings exportSettings:(BeatExportSettings*)exportSettings screenplay:(BeatScreenplay**)screenplay
{
    // Create a copy of parsed lines
    NSMutableArray<Line*>* preprocessedLines = NSMutableArray.array;
    Line *precedingLine;
    BeatMacroParser* macros = BeatMacroParser.new;
        
    NSString* queuedPageNumber = nil;
    
    NSInteger lineNumber = 1;
    NSInteger dialogueNumber = 1;
    
    // First we'll skip non-printable lines and resolve macros.
    for (Line* line in lines) {
        // Store the original line number in editor
        line.lineNumber = lineNumber;
        lineNumber++;
        
        // Stop at boneyard
        if (line.isBoneyardSection) break;
        
        // Eliminate faux empty lines with only single space. To force whitespace you have to use two spaces.
        // This shouldn't happen, but better safe than sorry.
        if ([line.string isEqualToString:@" "] && line.type != empty) line.type = empty;

        bool printable = !line.effectivelyEmpty || ([exportSettings.additionalTypes containsIndex:line.type] || (line.note && exportSettings.printNotes));
        
        // Let's use a clone of the line
        [preprocessedLines addObject:line.clone];
        Line *l = preprocessedLines.lastObject;
        
        if (queuedPageNumber != nil && printable) {
            l.forcedPageNumber = queuedPageNumber;
            queuedPageNumber = nil;
        }
                
        // Reset macro panel at top-level sections
        if (l.type == section && l.sectionDepth == 1) {
            [macros resetPanel];
        }
        
        // Preprocess macros
        if (l.macroRanges.count > 0) {
            NSArray<NSValue*>* macroKeys = [l.macros.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSValue*  _Nonnull obj1, NSValue*  _Nonnull obj2) {
                return (obj1.rangeValue.location > obj2.rangeValue.location);
            }];
            
            l.resolvedMacros = NSMutableDictionary.new;
            for (NSValue* range in macroKeys) {
                NSString* macro = l.macros[range];
                id value = [macros parseMacro:macro];
                
                if (value != nil) l.resolvedMacros[range] = [NSString stringWithFormat:@"%@", value];
            }
        }
         
        // Skip line if it's a macro and has no results
        if (l.macroRanges.count > 0 && l.macroRanges.count == l.length && l.resolvedMacros.count == 0) {
            [preprocessedLines removeLastObject];
            l.type = empty;
            precedingLine = l;
            continue;
        }
        
        if (l.note && !exportSettings.printNotes) {
            // Skip notes when not needed
            queuedPageNumber = l.forcedPageNumber;
            continue;
        } else if (l.type == character) {
            // Reset dual dialogue
            l.nextElementIsDualDialogue = false;
        } else if (l.type == action || l.type == lyrics || l.type == centered) {
            l.beginsNewParagraph = true;
            
            // BUT in some cases, they don't.
            if (!precedingLine.effectivelyEmpty && precedingLine.type == l.type) {
                l.beginsNewParagraph = false;
            }
        } else {
            l.beginsNewParagraph = true;
        }
        
        precedingLine = l;
    }
    
    // Let's see if a page number remains in queue. We'll apply that to the last preprocessed line.
    if (queuedPageNumber != nil) {
        preprocessedLines.lastObject.forcedPageNumber = queuedPageNumber;
    }
    
    // Get scene number offset from the delegate/document settings
    NSInteger sceneNumber = 1;
    if ([documentSettings getInt:DocSettingSceneNumberStart] > 1) {
        sceneNumber = [documentSettings getInt:DocSettingSceneNumberStart];
        if (sceneNumber < 1) sceneNumber = 1;
    }
    
    // Array for the final printable elements
    NSMutableArray<Line*>* linesToPrint = [NSMutableArray.alloc initWithCapacity:preprocessedLines.count];
    queuedPageNumber = nil;

    // Previously handled line, not necessarily previously added line.
    Line *previousLine;
    
    // Next, we'll go through the cleaned lines and do some extra checks.
    for (Line *line in preprocessedLines) {
        // Fix a weird bug for first line
        if (line.type == empty && line.string.length && !line.string.containsOnlyWhitespace) line.type = action;
        
        // Check for forced page numbers
        if (queuedPageNumber != nil) line.forcedPageNumber = queuedPageNumber;
        queuedPageNumber = line.forcedPageNumber;
                
        BOOL shouldProcessLine = true;
                
        // Check if we should spare some non-printing objects or not.
        if (line.isNonPrinting &&
            !([exportSettings.additionalTypes containsIndex:line.type] || (line.note && exportSettings.printNotes))) {
            // The previous line has to inherit the page number IF it's not a line break
            Line* previousPrintedLine = linesToPrint.lastObject;
            if (previousPrintedLine != nil && previousPrintedLine.type != pageBreak && queuedPageNumber != nil) {
                previousPrintedLine.forcedPageNumber = queuedPageNumber;
                queuedPageNumber = nil;
            }
            
            // Lines which are *effectively* empty have to be remembered.
            if (line.effectivelyEmpty) previousLine = line;
            shouldProcessLine = false;
        } else if (line.isAnyDialogue && line.string.length == 0) {
            // Remove misinterpreted dialogue
            line.type = empty;
            previousLine = line;
            shouldProcessLine = false;
        }
         
        // This line didn't pass the tests
        if (!shouldProcessLine) continue;

        // Add scene numbers
        if (line.type == heading) {
            if (line.sceneNumberRange.length > 0) {
                line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
                
                // We need to do some extra trickery for heading elements when they have macros, because the user might have used a macro for the scene number.
                // NB: If we were dealing with pure Fountain, we could just preprocess the text as string and replace macros before parsing the text back to Fountain.
                // However, this is not possible, because we have all sorts of metadata, so there are certain tricks we have to pull here. Not cool, I know.
                if (line.macroRanges.count > 0) {
                    NSAttributedString* aStr = line.attributedStringWithResolvedMacros;
                    Line* ln = [Line withString:aStr.string type:line.type];
                    [ln parseSceneNumber];
                    if (ln.sceneNumber.length > 0) line.sceneNumber = ln.sceneNumber;
                }
            } else if (!line.sceneNumber) {
                line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
                sceneNumber += 1;
            }
        } else {
            line.sceneNumber = @"";
        }
        
        // If this is a dual dialogue character cue, we'll need to search for the previous one
        // and make it aware of being a part of a dual dialogue block.
        if (line.type == dualDialogueCharacter) {
            [self findAndSetDualDialogueSiblingIn:linesToPrint];
        }

        // We can safely nil the queued page number here
        queuedPageNumber = nil;
        
        if (line.isAnyDialogue) {
            line.dialogueNumber = dialogueNumber;
            dialogueNumber += 1;
        }
        
        // This line safely passed processing to be printed
        [linesToPrint addObject:line];
        previousLine = line;
    }

    return linesToPrint;
}

+ (void)findAndSetDualDialogueSiblingIn:(NSArray*)lines
{
    NSInteger i = lines.count - 1;
    while (i >= 0) {
        Line *precedingLine = lines[i];
        
        if (precedingLine.type == character) {
            precedingLine.nextElementIsDualDialogue = YES;
            break;
        }
        
        // Break the loop if this is not a dialogue element OR it's another dual dialogue element.
        if (!(precedingLine.isDialogueElement || precedingLine.isDualDialogueElement)) break;
        
        i--;
    }
}


@end
