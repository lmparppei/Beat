//
//  NSAttributedString+ConvertToFountain.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 8.10.2025.
//

#import "NSAttributedString+ConvertToFountain.h"
#import <BeatCore/BeatCompatibility.h>
#import __OS_KIT

typedef NS_OPTIONS(NSUInteger, PastedFragmentStyle) {
    PastedFragmentStyleBold      = 1 << 0,
    PastedFragmentStyleItalic    = 1 << 1,
    PastedFragmentStyleUnderline = 1 << 2,
};

static inline NSString *OpenMarkerForStyle(PastedFragmentStyle style) {
    switch (style) {
        case PastedFragmentStyleBold:      return @"**";
        case PastedFragmentStyleItalic:    return @"*";
        case PastedFragmentStyleUnderline: return @"_";
        default: return @"";
    }
}

static inline NSString *CloseMarkerForStyle(PastedFragmentStyle style) {
    // Same markers, but order matters
    return OpenMarkerForStyle(style);
}

static inline PastedFragmentStyle StyleFromAttributes(NSDictionary *attrs) {
    PastedFragmentStyle style = 0;

    BXFont *font = attrs[NSFontAttributeName];
    if (mask_contains(font.fontDescriptor.symbolicTraits, BXFontDescriptorTraitBold))
        style |= PastedFragmentStyleBold;

    if (mask_contains(font.fontDescriptor.symbolicTraits, BXFontDescriptorTraitItalic))
        style |= PastedFragmentStyleItalic;

    if ([attrs[NSUnderlineStyleAttributeName] intValue] != 0)
        style |= PastedFragmentStyleUnderline;

    return style;
}

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
        
        __block PastedFragmentStyle activeStyle = 0;
        
        [paragraphStr enumerateAttributesInRange:NSMakeRange(0, paragraphStr.length)
                                         options:0
                                      usingBlock:^(NSDictionary<NSAttributedStringKey,id> *attrs,
                                                   NSRange range,
                                                   BOOL *stop)
         {
            if (range.length == 0) return;
            
            NSString *text = [paragraphStr.string substringWithRange:range];
            if (text.length == 0) return;
            
            PastedFragmentStyle newStyle = StyleFromAttributes(attrs);
            
            // Close styles that are no longer active
            PastedFragmentStyle toClose = activeStyle & ~newStyle;
            if (mask_contains(toClose, PastedFragmentStyleUnderline))   [str appendString:@"_"];
            if (mask_contains(toClose, PastedFragmentStyleItalic))      [str appendString:@"*"];
            if (mask_contains(toClose, PastedFragmentStyleBold))        [str appendString:@"**"];
            
            // Open newly activated styles
            PastedFragmentStyle toOpen = newStyle & ~activeStyle;
            if (mask_contains(toOpen, PastedFragmentStyleBold))         [str appendString:@"**"];
            if (mask_contains(toClose, PastedFragmentStyleItalic))      [str appendString:@"*"];
            if (mask_contains(toClose, PastedFragmentStyleUnderline))   [str appendString:@"_"];
            
            [str appendString:text];
            
            activeStyle = newStyle;
        }];
        
        // Close anything left open at paragraph end
        if (activeStyle & PastedFragmentStyleUnderline) [str appendString:@"_"];
        if (activeStyle & PastedFragmentStyleItalic)    [str appendString:@"*"];
        if (activeStyle & PastedFragmentStyleBold)      [str appendString:@"**"];
        
        // Nothing to do here, just add a line break and continue.
        if (paragraphRange.length == 0 || str.length == 0) {
            [result appendString:@"\n"]; return;
        }
        
        // Get attributes and check the attributes for any extra spacing that we need for paragraph-wide plain-text conversion
        NSDictionary *attrs = [self attributesAtIndex:NSMaxRange(paragraphRange) - 1 effectiveRange:NULL];
        
        NSParagraphStyle *pStyle = attrs[NSParagraphStyleAttributeName];
        BXFont *font = attrs[NSFontAttributeName];
        CGFloat spacing = font.ascender;
                    
        // In sub-paragraphs, we might need to add line breaks to mimic paragraph spacing
        if (result.length > 0 && (pStyle.paragraphSpacingBefore > 0 || spacing > font.pointSize)) [result appendString:@"\n"];
        [result appendString:str];
        [result appendString:@"\n"];
        if (pStyle.paragraphSpacing > 0) [result appendString:@"\n"];
    }];
    
    return result;
}

@end
