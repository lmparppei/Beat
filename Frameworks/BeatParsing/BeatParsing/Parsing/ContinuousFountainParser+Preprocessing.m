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

- (NSArray*)preprocessForPrinting
{
    return [self preprocessForPrintingWithLines:self.safeLines exportSettings:nil screenplayData:nil];
}

- (NSArray*)preprocessForPrintingWithExportSettings:(BeatExportSettings*)exportSettings
{
    return [self preprocessForPrintingWithLines:self.safeLines exportSettings:exportSettings screenplayData:nil];
}

- (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines exportSettings:(BeatExportSettings*)settings screenplayData:(BeatScreenplay**)screenplay
{
    if (!lines) lines = self.safeLines;
    return [ContinuousFountainParser preprocessForPrintingWithLines:lines documentSettings:self.documentSettings exportSettings:settings screenplay:screenplay];
}

+ (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines documentSettings:(BeatDocumentSettings*)documentSettings
{
    return [ContinuousFountainParser preprocessForPrintingWithLines:lines documentSettings:documentSettings exportSettings:nil screenplay:nil];
}
+ (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines documentSettings:(BeatDocumentSettings*)documentSettings exportSettings:(BeatExportSettings*)exportSettings screenplay:(BeatScreenplay**)screenplay
{
    // The array for printable elements
    NSMutableArray *elements = NSMutableArray.new;
    
    // Create a copy of parsed lines
    NSMutableArray *linesForPrinting = NSMutableArray.array;
    Line *precedingLine;
    BeatMacroParser* macros = BeatMacroParser.new;
    
    
    for (Line* line in lines) {
        [linesForPrinting addObject:line.clone];
                
        Line *l = linesForPrinting.lastObject;
        
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
        if (l.macroRanges.count == l.length && l.resolvedMacros.count == 0) {
            [linesForPrinting removeLastObject];
            l.type = empty;
            precedingLine = l;
            continue;
        }
        
        // Skip notes
        if (l.note && !exportSettings.printNotes) continue;
        
        // Reset dual dialogue
        else if (l.type == character) l.nextElementIsDualDialogue = false;
        
        else if (l.type == action || l.type == lyrics || l.type == centered) {
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
    
    // Get scene number offset from the delegate/document settings
    NSInteger sceneNumber = 1;
    if ([documentSettings getInt:DocSettingSceneNumberStart] > 1) {
        sceneNumber = [documentSettings getInt:DocSettingSceneNumberStart];
        if (sceneNumber < 1) sceneNumber = 1;
    }
    
    //
    Line *previousLine;
    for (Line *line in linesForPrinting) {
        // Fix a weird bug for first line
        if (line.type == empty && line.string.length && !line.string.containsOnlyWhitespace) line.type = action;
        
        // Check if we should spare some non-printing objects or not.
        if ((line.isInvisible || line.effectivelyEmpty) && !([exportSettings.additionalTypes containsIndex:line.type] || (line.note && exportSettings.printNotes))) {
            
            // Lines which are *effectively* empty have to be remembered.
            if (line.effectivelyEmpty) previousLine = line;

            continue;
        }
        
        // Add scene numbers
        if (line.type == heading) {
            if (line.sceneNumberRange.length > 0) {
                line.sceneNumber = [line.string substringWithRange:line.sceneNumberRange];
            }
            else if (!line.sceneNumber) {
                line.sceneNumber = [NSString stringWithFormat:@"%lu", sceneNumber];
                sceneNumber += 1;
            }
        } else {
            line.sceneNumber = @"";
        }
        
        // Eliminate faux empty lines with only single space. To force whitespace you have to use two spaces.
        if ([line.string isEqualToString:@" "]) {
            line.type = empty;
            continue;
        }
                 
        // Remove misinterpreted dialogue
        if (line.isAnyDialogue && line.string.length == 0) {
            line.type = empty;
            previousLine = line;
            continue;
        }
                    
        // If this is a dual dialogue character cue, we'll need to search for the previous one
        // and make it aware of being a part of a dual dialogue block.
        if (line.type == dualDialogueCharacter) {
            NSInteger i = elements.count - 1;
            while (i >= 0) {
                Line *precedingLine = [elements objectAtIndex:i];
                                
                if (precedingLine.type == character) {
                    precedingLine.nextElementIsDualDialogue = YES;
                    break;
                }
                
                // Break the loop if this is not a dialogue element OR it's another dual dialogue element.
                if (!(precedingLine.isDialogueElement || precedingLine.isDualDialogueElement)) break;

                i--;
            }
        }
        
        [elements addObject:line];
        
        previousLine = line;
    }
    
    return elements;
}


@end
