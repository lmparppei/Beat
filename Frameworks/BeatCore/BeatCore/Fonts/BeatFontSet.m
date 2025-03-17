//
//  BeatFont.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 4.6.2023.
//

#import "BeatFontSet.h"
//#import "BeatFonts.h"

@implementation BeatFontSet

+ (instancetype)name:(NSString *)name size:(CGFloat)size scale:(CGFloat)scale regular:(NSString *)regularFontName bold:(NSString *)boldFontName italic:(NSString *)italicFontName boldItalic:(NSString *)boldItalicFontName sectionFont:(NSString* _Nullable)sectionFontName synopsisFont:(NSString* _Nullable)synopsisFontName
{
    return [BeatFontSet.alloc initWithFontName:name size:size scale:(CGFloat)scale regular:regularFontName bold:boldFontName italic:italicFontName boldItalic:boldItalicFontName sectionFont:sectionFontName synopsisFont:synopsisFontName];
}

- (instancetype)initWithFontName:(NSString*)name
                            size:(CGFloat)size
                           scale:(CGFloat)scale
                         regular:(NSString*)regularFontName
                            bold:(NSString*)boldFontName
                          italic:(NSString*)italicFontName
                      boldItalic:(NSString*)boldItalicFontName
                     sectionFont:(NSString* _Nullable)sectionFontName
                    synopsisFont:(NSString* _Nullable)synopsisFontName
 {
    self = [super init];
    
    if (self) {
        CGFloat fontSize = (size <= 0.0) ? 12.0 : size;
        fontSize *= scale;
        
        _name = name;
        _scale = scale;
        
        _regular = [BXFont fontWithName:regularFontName size:fontSize];
        _bold = [BXFont fontWithName:boldFontName size:fontSize];
        _italic = [BXFont fontWithName:italicFontName size:fontSize];
        _boldItalic = [BXFont fontWithName:boldItalicFontName size:fontSize];
        
        if (_regular == nil || _bold == nil || _italic == nil)
            NSLog(@"🆘 WARNING - font not found: %@", name);
            
        // Fonts for sections and synopsis lines. If something goes wrong, we'll load system font as a fallback.
        if (sectionFontName != nil) _section = [BXFont fontWithName:sectionFontName size:fontSize];
        if (_section == nil) _section = [BXFont boldSystemFontOfSize:size];
        
        if (synopsisFontName != nil) _synopsis = [BXFont fontWithName:synopsisFontName size:fontSize - 1.0];
        if (_synopsis == nil) _synopsis = [BeatFontSet fontWithTrait:BXFontDescriptorTraitItalic font:[BXFont systemFontOfSize:size - 1.0]];
        
        BXFont* emojis = [BXFont fontWithName:@"Noto Emoji" size:fontSize];
        if (emojis == nil) emojis = [BXFont fontWithName:@"NotoEmoji" size:fontSize]; // Fix for Mojave
        _emojiFont = emojis;

    }
     
    return self;
}

- (BXFont*)sectionFontWithSize:(CGFloat)size
{
    #if TARGET_OS_IOS
        // There's a weird bug in iOS with system fonts
        BXFont* font;
        if ([_section.familyName isEqualToString:[BXFont systemFontOfSize:12.0].familyName]) {
            font = [BXFont boldSystemFontOfSize:size];
        } else {
            font = [BXFont fontWithName:_section.fontName size:size];
        }
    #else
        // On macOS we can jsut use the normal system font name
        BXFont* font = [BXFont fontWithName:_section.fontName size:size];
    #endif
    
    return font;
}

+ (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits font:(BXFont*)originalFont
{
    BXFontDescriptor *fd = [originalFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    BXFont *font = [BXFont fontWithDescriptor:fd size:originalFont.pointSize];
    
    if (font == nil) return originalFont;
    else return font;
}

/// Returns the given font scaled to the font set size. For example, if you as for `Courier Prime` in `12pt` this method will return the font with the size `12pt * scale`
- (BXFont*)font:(BXFont*)font inScaledSize:(CGFloat)fontSize
{
    static NSMutableDictionary <NSString*,NSMutableDictionary<NSNumber*, BXFont*>*>* scaledFonts;
    CGFloat actualSize = fontSize * self.scale;
    
    if (scaledFonts[font.fontName][@(actualSize)] != nil) return scaledFonts[font.fontName][@(actualSize)];
        
    if (scaledFonts[font.fontName] == nil) scaledFonts[font.fontName] = NSMutableDictionary.new;
    scaledFonts[font.fontName][@(actualSize)] = [BXFont fontWithName:font.fontName size:actualSize];
    
    return scaledFonts[font.fontName][@(actualSize)];
}



@end
