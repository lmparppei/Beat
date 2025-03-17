//
//  BeatPlugin+Windows.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

#import <BeatPlugins/BeatPlugins.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

@protocol BeatPluginWindowsExports <JSExport>

@end

#if TARGET_OS_OSX
@interface BeatPlugin (Windows) <BeatPluginWindowsExports, NSWindowDelegate>
#else
@interface BeatPlugin (Windows) <BeatPluginWindowsExports>
#endif

#pragma mark Plugin window management
- (void)registerPluginWindow:(id)window;
- (void)closePluginWindow:(id)window;

@end
