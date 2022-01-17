//
//  BeatColorMenuItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
//  A simple class for providing additional colorKey value in menu items.
//  Created for localization reasons: you can set the color key as "metadata" for
//  each of the menu items, while displaying a localized version of the color name.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatColorMenuItem : NSMenuItem
@property (nonatomic) IBInspectable NSString* colorKey;
@end

NS_ASSUME_NONNULL_END
