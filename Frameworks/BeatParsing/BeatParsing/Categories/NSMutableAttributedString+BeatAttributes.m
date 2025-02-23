//
//  NSMutableAttributedString+BeatAttributes.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 10.2.2025.
//

#import "NSMutableAttributedString+BeatAttributes.h"

@implementation NSMutableAttributedString (BeatAttributes)

/// N.B. Does NOT return a Cocoa-compatible attributed string. The attributes are used to create a string for both internal rendering and FDX conversion.
- (void)addBeatStyleAttr:(NSString*)name range:(NSRange)range
{
    @synchronized (self) {
        // Make sure we don't go out of range
        if (NSMaxRange(range) > self.length || range.length < 1 || range.location == NSNotFound) return;
        if (name == nil) NSLog(@"WARNING: Null value passed to attributes");
        
        // Make a copy and enumerate attributes.
        // Add style to the corresponding range while retaining the existing attributes, if applicable.
        [self.copy enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            NSMutableSet* style;
            
            if (attrs[@"Style"] != nil) {
                // We need to make a copy of the set, otherwise we'll add to the same set of attributes as earlier,
                // causing issues with overlapping attributes.
                style = ((NSMutableSet*)attrs[@"Style"]).mutableCopy;
                [style addObject:name];
            } else {
                style = [NSMutableSet.alloc initWithArray:@[name]];
            }
            
            if (NSMaxRange(range) <= self.length) {
                [self addAttribute:@"Style" value:style range:range];
            }
        }];
    }
}

@end
