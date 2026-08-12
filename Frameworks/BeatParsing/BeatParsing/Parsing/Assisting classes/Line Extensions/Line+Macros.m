//
//  Line+Macros.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 10.8.2026.
//

#import "Line+Macros.h"
#import <BeatParsing/BeatParsing-Swift.h>

@implementation Line (Macros)

- (void)resolveMacrosWithParser:(BeatMacroParser*)macroParser
{    
    NSDictionary* macros = self.macros;
    self.resolvedMacros = NSMutableDictionary.new;
    
    NSArray<NSValue*>* keys = [macros.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSValue*  _Nonnull obj1, NSValue*  _Nonnull obj2) {
        if (obj1.rangeValue.location > obj2.rangeValue.location) return true;
        return false;
    }];
    
    for (NSValue* range in keys) {
        NSString* macro = macros[range];
        id value = [macroParser parseMacro:macro];
        
        if (value != nil) self.resolvedMacros[range] = [NSString stringWithFormat:@"%@", value];
    }
}

@end
