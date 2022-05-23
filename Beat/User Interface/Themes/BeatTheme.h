//
//  Theme.h
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//


#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "DynamicColor.h"

@protocol BeatTheme
@property (nonatomic) NSDictionary<NSString*, NSString*> *propertyToValue;

@property (strong, nonatomic) DynamicColor* backgroundColor;
@property (strong, nonatomic) DynamicColor* selectionColor;
@property (strong, nonatomic) DynamicColor* textColor;
@property (strong, nonatomic) DynamicColor* invisibleTextColor;
@property (strong, nonatomic) DynamicColor* caretColor;
@property (strong, nonatomic) DynamicColor* commentColor;
@property (strong, nonatomic) DynamicColor* marginColor;
@property (strong, nonatomic) DynamicColor* outlineBackground;
@property (strong, nonatomic) DynamicColor* outlineHighlight;
@property (strong, nonatomic) DynamicColor* sectionTextColor;
@property (strong, nonatomic) DynamicColor* synopsisTextColor;
@property (strong, nonatomic) DynamicColor* pageNumberColor;
@property (strong, nonatomic) DynamicColor* highlightColor;

@property (strong, nonatomic) DynamicColor* genderWomanColor;
@property (strong, nonatomic) DynamicColor* genderManColor;
@property (strong, nonatomic) DynamicColor* genderOtherColor;
@property (strong, nonatomic) DynamicColor* genderUnspecifiedColor;

- (NSDictionary*)themeAsDictionaryWithName:(NSString*)name;
- (void)setValue:(id)value forKey:(NSString*)key;
- (id)valueForKey:(NSString*)key;
@end
