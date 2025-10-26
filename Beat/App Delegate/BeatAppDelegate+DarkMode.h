//
//  BeatAppDelegate+DarkMode.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatAppDelegate (DarkMode)

/** At all times, we have to check if OS is set to dark AND if the user has forced either mode. This is horribly dated, but seems to work ---- for now. It's here because I'm trying to keep up support for macOS 10.13. */
-(void)checkDarkMode;

/// Returns `true` when the app is running in dark mode – either simulated (10.13) or real (10.14+)
- (bool)isDark;

/// Toggles between (forced) light/dark mode
- (void)toggleDarkMode;

/// Returns `true` when the OS is set to dark mode
- (bool)OSisDark;

@end

NS_ASSUME_NONNULL_END
