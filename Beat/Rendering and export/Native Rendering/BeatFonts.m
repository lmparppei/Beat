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
		_courier = [NSFont fontWithName:@"Courier Prime" size:12.0];
		_boldCourier = [NSFont fontWithName:@"Courier Prime Bold" size:12.0];
		_boldItalicCourier = [NSFont fontWithName:@"Courier Prime Bold Italic" size:12.0];
		_italicCourier = [NSFont fontWithName:@"Courier Prime Italic" size:12.0];
	}
	return self;
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
