//
//  BeatFont.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 4.6.2023.
//

#import <TargetConditionals.h>
#import <BeatCore/BeatCompatibility.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#if TARGET_OS_IOS
    #define BXFontDescriptorSymbolicTraits UIFontDescriptorSymbolicTraits
    #define BXFontDescriptor UIFontDescriptor
    #define BXFontDescriptorTraitBold UIFontDescriptorTraitBold
    #define BXFontDescriptorTraitItalic UIFontDescriptorTraitItalic

    #define BXItalicFontMask 0x00000001
    #define BXBoldFontMask 0x00000002

    #define BXFontWeightRegular UIFontWeightRegular
    #define BXFontWeightBold UIFontWeightBold

#else
    #define BXFontDescriptorSymbolicTraits NSFontDescriptorSymbolicTraits
    #define BXFontDescriptor NSFontDescriptor
    #define BXFontDescriptorTraitBold NSFontDescriptorTraitBold
    #define BXFontDescriptorTraitItalic NSFontDescriptorTraitItalic

    #define BXItalicFontMask NSItalicFontMask
    #define BXBoldFontMask NSBoldFontMask

    #define BXFontWeightRegular NSFontWeightRegular
    #define BXFontWeightBold NSFontWeightBold
#endif


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BeatFontType) {
    BeatFontTypeFixed = 0,
    BeatFontTypeFixedSansSerif,
    BeatFontTypeVariableSerif,
    BeatFontTypeVariableSansSerif,
    BeatFontTypeLibertinus
};

@interface BeatFontSet : NSObject

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) BXFont *regular;
@property (nonatomic, readonly) BXFont *bold;
@property (nonatomic, readonly) BXFont *italic;
@property (nonatomic, readonly) BXFont *boldItalic;
@property (nonatomic, readonly) BXFont *section;
@property (nonatomic, readonly) BXFont *synopsis;
@property (nonatomic, readonly) BXFont *emojiFont;

+ (instancetype)name:(NSString *)name size:(CGFloat)size scale:(CGFloat)scale regular:(NSString *)regularFontName bold:(NSString *)boldFontName italic:(NSString *)italicFontName boldItalic:(NSString *)boldItalicFontName sectionFont:(NSString* _Nullable)sectionFontName synopsisFont:(NSString* _Nullable)synopsisFontName;
- (BXFont*)sectionFontWithSize:(CGFloat)size;
- (BXFont*)font:(BXFont*)font inScaledSize:(CGFloat)fontSize;

/// Cross-platform font trait creation. This should be a category.
+ (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits font:(BXFont*)originalFont;

@end

NS_ASSUME_NONNULL_END
