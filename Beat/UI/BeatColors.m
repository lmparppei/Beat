//
//  BeatColors.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import "BeatColors.h"
#import "DynamicColor.h"

@implementation BeatColors
+ (NSDictionary *) colors {
	return @{
			 @"red" : [BeatColors colorWithRed:239 green:0 blue:73],
			 @"blue" : [BeatColors colorWithRed:0 green:129 blue:239],
			 @"green": [BeatColors colorWithRed:0 green:223 blue:121],
			 @"pink": [BeatColors colorWithRed:250 green:111 blue:193],
			 @"magenta": [BeatColors colorWithRed:236 green:0 blue:140],
			 @"gray": NSColor.grayColor,
			 @"grey": NSColor.grayColor, // for the illiterate
			 @"purple": [BeatColors colorWithRed:181 green:32 blue:218],
			 @"prince": [BeatColors colorWithRed:181 green:32 blue:218], // for the purple one
			 @"yellow": [BeatColors colorWithRed:251 green:193 blue:35],
			 @"cyan": [BeatColors colorWithRed:7 green:189 blue:235],
			 @"teal": [BeatColors colorWithRed:12 green:224 blue:227], // gotta have teal & orange
			 @"orange": [BeatColors colorWithRed:255 green:161 blue:13],
			 @"brown": [BeatColors colorWithRed:169 green:106 blue:7],
			 @"darkGray": [BeatColors colorWithRed:170 green:170 blue:170],
			 @"veryDarkGray": [BeatColors colorWithRed:100 green:100 blue:100]
    };
}
+ (NSColor *) colorWithRed: (CGFloat) red green:(CGFloat)green blue:(CGFloat)blue {
	return [NSColor colorWithDeviceRed:(red / 255) green:(green / 255) blue:(blue / 255) alpha:1.0f];
}
+ (NSColor *) color:(NSString*)name {
	DynamicColor *color = [BeatColors.colors valueForKey:name];
	if (color) {
		return color;
	} else {
		NSString *hexColor = [NSString stringWithString:name];
		if (name.length == 7 && [name characterAtIndex:0] == '#') {
			hexColor = [hexColor substringFromIndex: 1];
			return [BeatColors colorWithHexColorString:hexColor];
		}
		
		return nil;
	}

}

// Thanks to Zlatan @ stackoverflow
+ (NSColor*)colorWithHexColorString:(NSString*)inColorString
{
    NSColor* result = nil;
    unsigned colorCode = 0;
    unsigned char redByte, greenByte, blueByte;

    if (nil != inColorString)
    {
         NSScanner* scanner = [NSScanner scannerWithString:inColorString];
         (void) [scanner scanHexInt:&colorCode]; // ignore error
    }
    redByte = (unsigned char)(colorCode >> 16);
    greenByte = (unsigned char)(colorCode >> 8);
    blueByte = (unsigned char)(colorCode); // masks off high bits

    result = [NSColor
		colorWithCalibratedRed:(CGFloat)redByte / 0xff
		green:(CGFloat)greenByte / 0xff
		blue:(CGFloat)blueByte / 0xff
		alpha:1.0
	];
    return result;
}

@end
