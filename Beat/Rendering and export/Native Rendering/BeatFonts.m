//
//  BeatFonts.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatFonts.h"

@implementation BeatFonts

- (instancetype)init {
	self = [super init];
	
	if (self) {
		[self loadSerifFont];
	}
	
	return self;
}

- (void)loadFontStyles {
	self.boldCourier = [self fontWithTrait:NSFontDescriptorTraitBold];
	self.italicCourier = [self fontWithTrait:NSFontDescriptorTraitItalic];
	self.boldItalicCourier = [self fontWithTrait:NSFontDescriptorTraitBold | NSFontDescriptorTraitItalic];
}

- (void)loadSerifFont {
	self.courier = [NSFont fontWithName:@"Courier Prime" size:12.0];
	[self loadFontStyles];
}

- (void)loadSansSerifFont {
	self.courier = [NSFont fontWithName:@"Courier Prime Sans" size:12.0];
	[self loadFontStyles];
}

- (NSFont*)fontWithTrait:(NSFontDescriptorSymbolicTraits)traits {
	return [self fontWithTrait:traits font:self.courier];
}

- (NSFont*)fontWithTrait:(NSFontDescriptorSymbolicTraits)traits font:(NSFont*)originalFont {
	NSFontDescriptor *fd = [originalFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
	NSFont *font = [NSFont fontWithDescriptor:fd size:originalFont.pointSize];
	
	if (font == nil) return originalFont;
	else return font;
}

- (NSFont*)boldWithSize:(CGFloat)size {
	NSFont* f = [NSFont fontWithName:self.courier.fontName size:size];
	f = [self fontWithTrait:NSFontDescriptorTraitBold font:f];
	return f;
}
- (NSFont*)withSize:(CGFloat)size {
	NSFont* f = [NSFont fontWithName:self.courier.fontName size:size];
	return f;
}

+ (CGFloat)characterWidth {
	return 7.25;
}

+ (BeatFonts*)sharedFonts {
	static dispatch_once_t once;
	static id sharedInstance;
	dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

@end
