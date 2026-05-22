//
//  BeatPlugin+IndexCardPrinting.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 19.5.2026.
//

#import "BeatPlugin+IndexCardPrinting.h"

@implementation BeatPlugin (IndexCardPrinting)

/// This is a very silly hack to expose index card printing to plugins. I am very sorry for anyone reading this.
/// Index card printing module is a macOS-specific thing, but it has to be called from inside a plugin.
- (void)printIndexCards
{
#if TARGET_OS_OSX
    [self.delegate printIndexCards];
#endif
}

@end
