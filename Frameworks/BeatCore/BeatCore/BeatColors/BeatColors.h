//
//  BeatColors.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//
#import <TargetConditionals.h>
#import <BeatCore/BeatCompatibility.h>
#import <JavaScriptCore/JavaScriptCore.h>

#if TARGET_OS_IOS
	#import <UIKit/UIKit.h>
	#define BXColor UIColor
#else
	#import <Cocoa/Cocoa.h>
	#define BXColor NSColor
#endif

@protocol BeatColorsExports <JSExport>
@end

@interface BeatColors : NSObject

@property (nonatomic) NSDictionary *colors;
+ (BXColor*)color:(NSString*)name;
+ (NSDictionary*)colors;
+ (NSString*)colorWith16bitHex:(NSString*)colorName;
+ (NSString*)get16bitHex:(BXColor*)color;
+ (NSString*)cssRGBFor:(BXColor*)color;
+ (BXImage*)labelImageForColor:(NSString*)colorName size:(CGSize)size;
+ (BXImage*)labelImageForColorValue:(BXColor*)color size:(CGSize)size;
@end
