//
//  NSAttributedString+ConvertToFountain.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 8.10.2025.
//

#import "NSAttributedString+ConvertToFountain.h"
#import <BeatCore/BeatCompatibility.h>
#import __OS_KIT

@implementation NSAttributedString (ConvertToFountain)

- (NSString*)convertToFountain
{
    // A basic attributed string. Here we'll check for some spacing etc.
    NSMutableString* result = NSMutableString.new;
    
    [self.string enumerateSubstringsInRange:NSMakeRange(0, self.length)
                                       options:NSStringEnumerationByParagraphs
                                    usingBlock:^(NSString * _Nullable paragraph,
                                                 NSRange paragraphRange,
                                                 NSRange enclosingRange,
                                                 BOOL * _Nonnull stop) {
        NSAttributedString* paragraphStr = [self attributedSubstringFromRange:paragraphRange];
        NSMutableString* str = NSMutableString.new;
        
        [paragraphStr enumerateAttributesInRange:NSMakeRange(0, paragraphStr.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            NSString* t = [paragraphStr.string substringWithRange:range];
            if (range.length == 0 || t.length == 0) return;
            
            NSMutableString* formatting = NSMutableString.new;
            BXFont* font = attrs[NSFontAttributeName];
            
            if (mask_contains(font.fontDescriptor.symbolicTraits, BXFontDescriptorTraitBold)) {
                [formatting appendString:@"**"];
            }
            if (mask_contains(font.fontDescriptor.symbolicTraits, BXFontDescriptorTraitItalic)) {
                [formatting appendString:@"*"];
            }
            if (((NSNumber*)attrs[NSUnderlineStyleAttributeName]).intValue != 0) {
                [formatting appendString:@"_"];
            }
            
            [str appendString:formatting];
            [str appendString:t];
            [str appendString:formatting];
        }];
        
        // Nothing to do here, just add a line break and continue.
        if (str.length == 0) {
            [result appendString:@"\n"]; return;
        }
        
        // Get attributes and check the attributes for any extra spacing that we need for paragraph-wide plain-text conversion
        NSDictionary *attrs = [self attributesAtIndex:NSMaxRange(paragraphRange) - 1 effectiveRange:NULL];
        
        NSParagraphStyle *pStyle = attrs[NSParagraphStyleAttributeName];
        BXFont *font = attrs[NSFontAttributeName];
        CGFloat spacing = font.ascender - font.descender;
                    
        if (pStyle.paragraphSpacingBefore > 0 || spacing > font.pointSize) [result appendString:@"\n"];
        [result appendString:str];
        [result appendString:@"\n"];
        if (pStyle.paragraphSpacing > 0) [result appendString:@"\n"];
    }];
    
    return result;
}

@end
