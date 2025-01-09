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

/*
/// Creates and stores a string with style attributes. Please don't use in editor, only for static parsing.
/// TODO: This is an extremely bad getter name. Why?
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
*/
 
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
            [self addStyleAttr:ITALIC_STYLE toString:string range:range];
        }
    }];

    [self.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length > BOLD_PATTERN.length * 2) {
            [self addStyleAttr:BOLD_STYLE toString:string range:range];
        }
    }];
    
    [self.boldItalicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length > ITALIC_PATTERN.length * 2) {
            [self addStyleAttr:BOLDITALIC_STYLE toString:string range:range];
        }
    }];
    
    [self.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length > UNDERLINE_PATTERN.length * 2) {
            [self addStyleAttr:UNDERLINE_STYLE toString:string range:range];
        }
    }];
        
    [self.omittedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length > OMIT_PATTERN.length * 2) {
            [self addStyleAttr:OMIT_STYLE toString:string range:range];
        }
    }];
    
    [self.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length > NOTE_PATTERN.length * 2) {
            [self addStyleAttr:NOTE_STYLE toString:string range:range];
        }
    }];

    [self.escapeRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [self addStyleAttr:OMIT_STYLE toString:string range:range];
    }];
        
    [self.removalSuggestionRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [self addStyleAttr:@"RemovalSuggestion" toString:string range:range];
    }];
        
    // Add macro attributes
    if (self.macroRanges.count > 0) {
        for (NSValue* r in self.macros.allKeys) {
            NSString* resolvedMacro = self.resolvedMacros[r];
            
            NSRange range = r.rangeValue;
            [string addAttribute:@"Macro" value:(resolvedMacro) ? resolvedMacro : @"" range:range];
        }
    }
    
    // Revision attributes
    if (self.revisedRanges.count > 0) {
        NSDictionary* revisedRanges = self.revisedRanges;
        for (NSNumber* key in revisedRanges.allKeys) {
            [revisedRanges[key] enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
                // Don't go out of range
                if (NSMaxRange(range) > string.length) {
                    range = NSMakeRange(range.location, string.length - range.location);
                }
                if (range.length > 0 ) [string addAttribute:@"Revision" value:key range:range];
            }];
        }
    }
    
    // Loop through tags and apply. Not used export, just for FDX exporting.
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
    // Make sure we don't go out of range
    if (![self.string inRange:range]) return;
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


@end
