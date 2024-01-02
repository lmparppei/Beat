//
//  BeatFonts.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>
#import <BeatCore/BeatFont.h>

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #define BXFont UIFont
#else
    #import <Cocoa/Cocoa.h>
    #define BXFont NSFont
#endif

#if TARGET_OS_IOS
    #define BXFontDescriptorSymbolicTraits UIFontDescriptorSymbolicTraits
    #define BXFontDescriptor UIFontDescriptor
    #define BXFontDescriptorTraitBold UIFontDescriptorTraitBold
    #define BXFontDescriptorTraitItalic UIFontDescriptorTraitItalic

    #define BXItalicFontMask 0x00000001
    #define BXBoldFontMask 0x00000002

#else
    #define BXFontDescriptorSymbolicTraits NSFontDescriptorSymbolicTraits
    #define BXFontDescriptor NSFontDescriptor
    #define BXFontDescriptorTraitBold NSFontDescriptorTraitBold
    #define BXFontDescriptorTraitItalic NSFontDescriptorTraitItalic

    #define BXItalicFontMask NSItalicFontMask
    #define BXBoldFontMask NSBoldFontMask
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BeatFontType) {
    BeatFontTypeFixed = 0,
    BeatFontTypeFixedSansSerif,
    BeatFontTypeVariableSerif,
    BeatFontTypeVariableSansSerif
};

@interface BeatFonts : NSObject
@property (nonatomic) NSString* name;

@property (nonatomic) BXFont* regular;
@property (nonatomic) BXFont* bold;
@property (nonatomic) BXFont* italic;
@property (nonatomic) BXFont* boldItalic;

@property (nonatomic) BXFont* emojis;

@property (nonatomic) BXFont* synopsisFont;
@property (nonatomic) BXFont* sectionFont;

+ (BeatFonts*)forType:(BeatFontType)type;
+ (BeatFonts*)forType:(BeatFontType)type mobile:(bool)mobile;
+ (BeatFonts*)sharedFonts;
+ (BeatFonts*)sharedMobileFonts;
+ (BeatFonts*)sharedSansSerifFonts;
+ (BeatFonts*)sharedVariableFonts;
+ (CGFloat)characterWidth;

- (BXFont*)withSize:(CGFloat)size;
- (BXFont*)boldWithSize:(CGFloat)size;

+ (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits font:(BXFont*)originalFont;

- (BXFont*)sectionFontWithSize:(CGFloat)size;
@end

NS_ASSUME_NONNULL_END
