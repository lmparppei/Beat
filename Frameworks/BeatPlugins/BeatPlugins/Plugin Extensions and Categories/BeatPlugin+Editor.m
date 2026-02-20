//
//  BeatPlugin+Editor.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import "BeatPlugin+Editor.h"

@implementation BeatPlugin (Editor)

/// Give focus back to the editor
- (void)focusEditor {
    [self.delegate focusEditor];
}

#pragma mark - Scrolling

/// Scroll to given location in editor window
- (void)scrollTo:(NSInteger)location
{
    [self.delegate scrollTo:location];
}

/// Scroll to the given line in editor window
- (void)scrollToLine:(Line*)line
{
    @try {
        [self.delegate scrollToLine:line];
    } @catch (NSException *e) {
        [self reportError:@"Plugin tried to access an unknown line" withText:line.string];
    }
}

/// Scrolls to the given line index in editor window
- (void)scrollToLineIndex:(NSInteger)index
{
    [self.delegate scrollToLineIndex:index];
}

/// Scrolls to the given scene index in editor window
- (void)scrollToSceneIndex:(NSInteger)index
{
    [self.delegate scrollToSceneIndex:index];
}

/// Scrolls to the given scene in editor window
- (void)scrollToScene:(OutlineScene*)scene
{
    @try {
        [self.delegate scrollToScene:scene];
    }
    @catch (NSException *e) {
        [self reportError:@"Can't find scene" withText:@"Plugin tried to access an unknown scene"];
    }
}


#pragma mark - Text I/O

- (NSString*)getText
{
    return self.delegate.text;
}

/// Adds a string into the editor at given index (location)
- (void)addString:(NSString*)string toIndex:(NSUInteger)index
{
    [self.delegate.textActions addString:string atIndex:index];
}

/// Replaces the given range with a string
- (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string
{
    NSRange range = NSMakeRange(from, length);
    @try {
        [self.delegate.textActions replaceRange:range withString:string];
    }
    @catch (NSException *e) {
        [self reportError:@"Selection out of range" withText:@"Plugin tried to select something that was out of range. Further errors might ensue."];
    }
}

/// Returns the selected range in editor
- (NSRange)selectedRange
{
    return self.delegate.selectedRange;
}

/// Sets  the selected range in editor
- (void)setSelectedRange:(NSInteger)start to:(NSInteger)length
{
    NSRange range = NSMakeRange(start, length);
    range = CLAMP_RANGE(range, self.delegate.text.length);
    [self.delegate setSelectedRange:range];
}

/// Sets given color for the line. Supports both outline elements and lines for the second parameter.
- (void)setColor:(NSString *)color forScene:(id)scene
{
    if ([scene isKindOfClass:OutlineScene.class]) {
        [self.delegate.textActions setColor:color forScene:scene];
    } else if ([scene isKindOfClass:Line.class]) {
        [self.delegate.textActions setColor:color forLine:scene];
    }
}

#pragma mark - Window interface

- (void)nextTab
{
#if TARGET_OS_OSX
    for (NSWindow* w in self.pluginWindows) [w resignKeyWindow];
    [self.delegate.documentWindow selectNextTab:nil];
#endif
}
- (void)previousTab
{
#if TARGET_OS_OSX
    for (NSWindow* w in self.pluginWindows) [w resignKeyWindow];
    [self.delegate.documentWindow selectPreviousTab:nil];
#endif
}


@end
