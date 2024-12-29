//
//  Line+SplitAndJoin.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.12.2024.
//

#import "Line+SplitAndJoin.h"

@implementation Line (SplitAndJoin)

#pragma mark - Splitting and joining

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
- (NSArray<Line*>*)splitAndFormatToFountainAt:(NSInteger)index
{
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
            
    // Set flags
    retain.changed = self.changed;
    retain.beginsNewParagraph = self.beginsNewParagraph;
    retain.paragraphIn = self.paragraphIn;
    retain.paragraphOut = true;

    split.changed = self.changed;
    split.paragraphIn = true;
    split.beginsNewParagraph = true;

    // Set identity (note that we're using the same UUID)
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
        
        for (NSNumber *key in self.revisedRanges.allKeys) {
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
    for (NSNumber* key in line.revisedRanges.allKeys) {
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


@end
