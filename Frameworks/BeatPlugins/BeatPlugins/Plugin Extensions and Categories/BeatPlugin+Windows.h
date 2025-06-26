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
/// Makes the given window move along its parent document window. **Never use with standalone plugins.**
- (void)gangWithDocumentWindow:(NSWindow*)window;
/// Show all plugin windows.
- (void)showAllWindows;
/// Hides all plugin windows
- (void)hideAllWindows;
#else
@interface BeatPlugin (Windows) <BeatPluginWindowsExports>
#endif

#pragma mark Plugin window management
- (void)registerPluginWindow:(id)window;
- (void)closePluginWindow:(id)window;

@end
