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
        
        [l resolveMacrosWithParser:parser];
        
        if (l.isOutlineElement || l.type == synopse) {
            [self addUpdateToOutlineAtLine:l didChangeType:false];
        }
    }
}


@end
