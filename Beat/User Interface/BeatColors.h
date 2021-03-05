//
//  BeatColors.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DynamicColor.h"

@interface BeatColors : NSObject
+ (NSColor*)color:(NSString*)name;
+ (NSDictionary*)colors;
+ (NSString*)colorWith16bitHex:(NSString*)colorName;
+ (NSString*)get16bitHex:(NSColor*)color;
@end
