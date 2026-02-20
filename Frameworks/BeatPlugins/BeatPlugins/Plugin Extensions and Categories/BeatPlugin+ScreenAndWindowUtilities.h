//
//  BeatPlugin+ScreenAndWindowUtilities.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 12.2.2026.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginWindowAndScreenUtilityExports <JSExport>

/// Current screen dimensions
- (NSArray*)screen;

#if !TARGET_OS_IOS
    /// Window dimensions
    - (NSArray*)windowFrame;
    /// Alias for windowFrame
    - (NSArray*)getWindowFrame;
    /// Sets the window frame
    JSExportAs(setWindowFrame, - (void)setWindowFrameX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height);
#endif

@end

@interface BeatPlugin (ScreenAndWindowUtilities) <BeatPluginWindowAndScreenUtilityExports>

@end

