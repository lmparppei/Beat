//
//  BeatPlugin+TextHighlighting.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

#import "BeatPlugin+TextHighlighting.h"

@implementation BeatPlugin (TextHighlighting)

#pragma mark - Temporary attributes

- (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len
{
#if !TARGET_OS_IOS
    NSColor *color = [BeatColors color:hexColor];
    if (color != nil && NSMaxRange(NSMakeRange(loc, len)) <= self.delegate.text.length)
        [self.delegate.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
#endif
}
- (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len
{
#if !TARGET_OS_IOS
    [self.delegate.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:(NSRange){ loc,len }];
#endif
}

- (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len
{
#if TARGET_OS_OSX
    NSColor *color = [BeatColors color:hexColor];
    if (color != nil && NSMaxRange(NSMakeRange(loc, len)) <= self.delegate.text.length)
        [self.delegate.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:color forCharacterRange:(NSRange){ loc,len }];
#endif
}

- (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len
{
#if !TARGET_OS_IOS
    [self.delegate.layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:(NSRange){ loc, len }];
#endif
}


@end
