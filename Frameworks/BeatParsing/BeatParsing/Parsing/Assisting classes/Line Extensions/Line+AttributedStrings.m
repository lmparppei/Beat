//
//  Line+AttributedStrings.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import "Line+AttributedStrings.h"
#import <BeatParsing/NSString+CharacterControl.h>
#import <BeatParsing/BeatParsing-Swift.h>

@implementation Line (AttributedStrings)

- (NSString*)attributedStringToFountain:(NSAttributedString *)attrStr
{
    return [Line attributedStringToFountain:attrStr];
}

/// Converts an FDX-style attributed string back to Fountain
+ (NSString*)attributedStringToFountain:(NSAttributedString*)attrStr
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

- (NSAttributedString*)attributedStringForFDX
{
    return self.attributedString;
}

/// Returns a string with style attributes.
/// - note N.B. Does NOT return a Cocoa-compatible attributed string. The attributes are used to create a string for screenplay rendering or FDX export.
- (NSAttributedString*)attributedString
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:(self.string) ? self.string : @""];
        
    // Make non-forced chacter cues uppercase. This should happen automatically, but in some character sets maybe not?
    /*
    if ((self.type == character || self.type == dualDialogueCharacter) && self.numberOfPrecedingFormattingCharacters == 0) {
        NSString *name = [self.string substringWithRange:self.characterNameRange].uppercaseString;
        if (name) [string replaceCharactersInRange:self.characterNameRange withString:name];
    }
     */
    
    // Add font stylization. We iterate through formatting range types (the last enum is a count value) and apply the style names.
    for (NSUInteger i=0; i<(NSUInteger)FormattingRangeCount; i++) {
        FormattedRange formatting = (FormattedRange)i;
        
        NSMutableIndexSet* indices = [self formattedRange:formatting];
        InlineFormatting* f = InlineFormatting.inlineFormats[@(formatting)];
        if (f == nil) continue;

        // Enumerate formatted ranges
        [indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
            // Don't apply any formatting to too short ranges
            if (range.length < f.openLength + f.closeLength) return;
            
            NSString* style = [InlineFormatting styleNameFor:formatting];
            if (style != nil) [string addBeatStyleAttr:style range:range];
            else NSLog(@"WARNING: No style name for %@", @(formatting));
        }];
    }
    
    [self.removalSuggestionRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [string addBeatStyleAttr:@"RemovalSuggestion" range:range];
    }];
        
    // Add macro attributes. We store RESOLVED macro values as ranges, and the actual values are replaced only when rendering to a __printed__ attributed string. (See attributedStringForPrinting)
    if (self.macroRanges.count > 0) {
        for (NSValue* r in self.macros.allKeys) {
            NSString* resolvedMacro = self.resolvedMacros[r];
            
            NSRange range = r.rangeValue;
            if (NSMaxRange(range) <= string.length)
                [string addAttribute:@"Macro" value:(resolvedMacro != nil) ? resolvedMacro : @"" range:range];
        }
    }
    
    // Revision attributes
    if (self.revisedRanges.count > 0) {
        NSDictionary* revisedRanges = self.revisedRanges;
        for (NSNumber* key in revisedRanges.allKeys) {
            if (![key isKindOfClass:NSNumber.class]) continue;
            
            [revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
                // Don't go out of range
                if (NSMaxRange(range) > string.length || range.length == 0 || range.location < 0 || range.length < 0 || range.location == NSNotFound || range.length == NSNotFound) return;
                
                if (NSMaxRange(range) > string.length)
                    range = NSMakeRange(range.location, string.length - range.location);
                if (range.location >= 0 && range.length > 0 && range.length != NSNotFound && NSMaxRange(range) <= string.length) {
                    [string addAttribute:@"Revision" value:key range:range];
                }
            }];
        }
    }
    
    // Loop through tags and apply. Not used in rendering, just for FDX exporting.
    for (NSDictionary *tag in self.tags) {
        NSString* tagValue = tag[@"tag"];
        if (!tagValue) continue;
        
        NSRange range = [(NSValue*)tag[@"range"] rangeValue];
        if (NSMaxRange(range) <= string.length)
            [string addAttribute:@"BeatTag" value:tagValue range:range];
    }
    
    return string;
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
        NSRange attrStringRange = NSMakeRange(result.length-range.length, range.length);
        
        if (attrStringRange.location >= 0 && NSMaxRange(attrStringRange) <= result.length) {
            [result addAttribute:@"BeatEditorRange" value:[NSValue valueWithRange:editorRange] range:attrStringRange];
        }
    }];
    
    // Replace macro ranges. All macros should be resolved by now.
    [result.copy enumerateAttribute:@"Macro" inRange:NSMakeRange(0,result.length) options:NSAttributedStringEnumerationReverse usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        if (value == nil) return;
        NSDictionary* attrs = [result attributesAtIndex:range.location effectiveRange:nil];
        
        // We'll create an intermediate Line object here to parse any possible formatting inside the macro. This is a little convoluted solution, but this is how it works for now, he he.
        Line* macroLine = [Line withString:(NSString*)value type:action];
        [macroLine resetFormatting];
        
        NSMutableAttributedString* attributedMacro = [macroLine attributedStringForOutputWith:settings].mutableCopy;
        [attributedMacro addAttributes:attrs range:NSMakeRange(0, attributedMacro.length)];
        
        [result replaceCharactersInRange:range withAttributedString:attributedMacro];
    }];
        
    return result;
}


@end
