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
	NSFontDescriptor *fd = [self.courier.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
	NSFont *font = [NSFont fontWithDescriptor:fd size:self.courier.pointSize];
	
	if (font == nil) return self.courier;
	else return font;
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
