//
//  BeatPlugin+ScreenAndWindowUtilities.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 12.2.2026.
//

#import "BeatPlugin+ScreenAndWindowUtilities.h"
#import <BeatCore/BeatCompatibility.h>
#import __OS_KIT

@implementation BeatPlugin (ScreenAndWindowUtilities)

#pragma mark - Utilities

/// Returns screen frame as an array
/// - returns: `[x, y, width, height]`
- (NSArray*)screen
{
#if TARGET_OS_IOS
    CGRect screen = self.delegate.documentWindow.screen.bounds;
#else
    CGRect screen = self.delegate.documentWindow.screen.frame;
#endif
    return @[ @(screen.origin.x), @(screen.origin.y), @(screen.size.width), @(screen.size.height) ];
}

/// Returns window frame as an array
/// - returns: `[x, y, width, height]`
- (NSArray*)getWindowFrame
{
    return self.windowFrame;
}

/// Returns window frame as an array
/// - returns: `[x, y, width, height]`

- (NSArray*)windowFrame
{
    CGRect frame = self.delegate.documentWindow.frame;
    return @[ @(frame.origin.x), @(frame.origin.y), @(frame.size.width), @(frame.size.height) ];
}
/// Sets host document window frame
- (void)setWindowFrameX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height
{
#if !TARGET_OS_IOS
    NSRect frame = NSMakeRect(x, y, width, height);
    [self.delegate.documentWindow setFrame:frame display:true];
#endif
}


@end
