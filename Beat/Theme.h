//
//  Theme.h
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DynamicColor.h"

@interface Theme : NSObject

@property (strong, nonatomic) DynamicColor* backgroundColor;
@property (strong, nonatomic) DynamicColor* selectionColor;
@property (strong, nonatomic) DynamicColor* textColor;
@property (strong, nonatomic) DynamicColor* invisibleTextColor;
@property (strong, nonatomic) DynamicColor* caretColor;
@property (strong, nonatomic) DynamicColor* commentColor;
@property (strong, nonatomic) DynamicColor* marginColor;
@property (strong, nonatomic) DynamicColor* outlineBackground;
@property (strong, nonatomic) DynamicColor* outlineHighlight;

@property (strong, nonatomic) NSString* name;

@end
