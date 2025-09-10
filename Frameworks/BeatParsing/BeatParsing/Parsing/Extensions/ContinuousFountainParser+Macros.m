//
//  ContinuousFountainParser+Macros.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 2.9.2025.
//

#import "ContinuousFountainParser+Macros.h"
#import <BeatParsing/BeatParsing-Swift.h>

@implementation ContinuousFountainParser (Macros)

#pragma mark - Macros

- (void)updateMacros
{
    self.macrosNeedUpdate = false;
    
    BeatMacroParser* parser = BeatMacroParser.new;
    NSArray* lines = self.safeLines;
    
    for (NSInteger i=0; i<lines.count; i++) {
        Line* l = lines[i];
        if (l.type == section && l.sectionDepth == 1) [parser resetPanel];
        if (l.macroRanges.count == 0) continue;
        
        [self resolveMacrosOn:l parser:parser];
        if (l.isOutlineElement || l.type == synopse) {
            [self addUpdateToOutlineAtLine:l didChangeType:false];
        }
    }
}

/// Parses and resolves macros on a line and stores the parsed content in  `resolvedMacros` dictionary, mapped to macro range key. The actual values are stored as attributes and only replaced when rendering to attributed string.
/// TODO: Move this to line object maybe?
- (void)resolveMacrosOn:(Line*)line parser:(BeatMacroParser*)macroParser
{
    NSDictionary* macros = line.macros;
    line.resolvedMacros = NSMutableDictionary.new;
    
    NSArray<NSValue*>* keys = [macros.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSValue*  _Nonnull obj1, NSValue*  _Nonnull obj2) {
        if (obj1.rangeValue.location > obj2.rangeValue.location) return true;
        return false;
    }];
    
    for (NSValue* range in keys) {
        NSString* macro = macros[range];
        id value = [macroParser parseMacro:macro];
        
        if (value != nil) line.resolvedMacros[range] = [NSString stringWithFormat:@"%@", value];
    }
}

@end
