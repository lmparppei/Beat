//
//  BeatFonts.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//


#import "BeatFonts.h"
#import <TargetConditionals.h>

#if TARGET_OS_IOS
    #define BXFontDescriptorSymbolicTraits UIFontDescriptorSymbolicTraits
    #define BXFontDescriptor UIFontDescriptor
    #define BXFontDescriptorTraitBold UIFontDescriptorTraitBold
    #define BXFontDescriptorTraitItalic UIFontDescriptorTraitItalic
#else
    #define BXFontDescriptorSymbolicTraits NSFontDescriptorSymbolicTraits
    #define BXFontDescriptor NSFontDescriptor
    #define BXFontDescriptorTraitBold NSFontDescriptorTraitBold
    #define BXFontDescriptorTraitItalic NSFontDescriptorTraitItalic
#endif

@implementation BeatFonts

+ (BeatFonts*)sharedFonts {
	static dispatch_once_t once;
	static id sharedInstance;
	dispatch_once(&once, ^{
		sharedInstance = [[self alloc] initWithSansSerif:false];
	});
	return sharedInstance;
}

+ (BeatFonts*)sharedSansSerifFonts {
	static dispatch_once_t once;
	static id sharedSansSerifInstance;
	dispatch_once(&once, ^{
		sharedSansSerifInstance = [[self alloc] initWithSansSerif:true];
	});
	return sharedSansSerifInstance;
}

- (instancetype)initWithSansSerif:(bool)sansSerif {
	self = [super init];
	
	if (self) {
		if (sansSerif) [self loadSansSerifFont];
		else [self loadSerifFont];
        
        self.synopsisFont = [self fontWithTrait:BXFontDescriptorTraitItalic font:[BXFont systemFontOfSize:11.0]];
        
        self.emojis = [BXFont fontWithName:@"Noto Emoji" size:12.0];
        if (_emojis == nil) self.emojis = [BXFont fontWithName:@"NotoEmoji" size:12.0]; // Fix for Mojave
	}
	
	return self;
}

#pragma mark - macOS fonts
/*
 
 I used to have a more clever approach:
 self.boldCourier = [self fontWithTrait:BXFontDescriptorTraitBold];
 self.italicCourier = [self fontWithTrait:BXFontDescriptorTraitItalic];
 self.boldItalicCourier = [self fontWithTrait:BXFontDescriptorTraitBold | BXFontDescriptorTraitItalic];

 However, this caused *extremely* weird issues on Mojave, such as the fonts transforming into something
 completely different. We'll use hard-coded font names, instead.
 
 */

- (void)loadSerifFont {
	self.courier = [BXFont fontWithName:@"Courier Prime" size:12.0];
    if (_courier == nil) self.courier = [BXFont fontWithName:@"CourierPrime" size:12.0];
    
    self.boldCourier = [BXFont fontWithName:@"CourierPrime-Bold" size:12.0];
    self.italicCourier = [BXFont fontWithName:@"CourierPrime-Italic" size:12.0];
    self.boldItalicCourier = [BXFont fontWithName:@"CourierPrime-BoldItalic" size:12.0];
}

- (void)loadSansSerifFont {
    self.courier = [BXFont fontWithName:@"Courier Prime Sans" size:12.0];
    if (_courier == nil) self.courier = [BXFont fontWithName:@"CourierPrimeSans-Regular" size:12.0];
    
    self.boldCourier = [BXFont fontWithName:@"CourierPrimeSans-Bold" size:12.0];
    self.italicCourier = [BXFont fontWithName:@"CourierPrimeSans-Italic" size:12.0];
    self.boldItalicCourier = [BXFont fontWithName:@"CourierPrimeSans-BoldItalic" size:12.0];
}

- (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits {
	return [self fontWithTrait:traits font:self.courier];
}

- (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits font:(BXFont*)originalFont {
	BXFontDescriptor *fd = [originalFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
	BXFont *font = [BXFont fontWithDescriptor:fd size:originalFont.pointSize];
	
	if (font == nil) return originalFont;
	else return font;
}

- (BXFont*)boldWithSize:(CGFloat)size {
	BXFont* f = [BXFont fontWithName:self.courier.fontName size:size];
	f = [self fontWithTrait:BXFontDescriptorTraitBold font:f];
	return f;
}
- (BXFont*)withSize:(CGFloat)size {
	BXFont* f = [BXFont fontWithName:self.courier.fontName size:size];
	return f;
}

+ (CGFloat)characterWidth {
	return 7.25;
}

@end
