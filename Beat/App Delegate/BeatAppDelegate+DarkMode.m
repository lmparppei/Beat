//
//  BeatAppDelegate+DarkMode.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate+DarkMode.h"
#import <BeatCore/BeatCore.h>

@implementation BeatAppDelegate (DarkMode)


#pragma mark - Dark mode stuff

/**
 At all times, we have to check if OS is set to dark AND if the user has forced either mode.
 This is horribly dated, but seems to work ---- for now. It's here because I'm trying to keep up support for macOS 10.13.
 I've simplified my previous approach a LOT.
 */
-(void)checkDarkMode
{
	// We only recall the *forced* appearance, this integer will be zero if there's no reason to enforce the appearance
	BeatForcedAppearance forcedAppearance = [BeatUserDefaults.sharedDefaults getInteger:BeatSettingForcedAppearance];
	
	if (@available(macOS 10.14, *)) {
		// If the OS is set to dark mode, we'll force light mode and vice-versa
		if (self.OSisDark) {
			self.darkMode = !(forcedAppearance == ForcedLightAppearance);
		} else {
			self.darkMode = (forcedAppearance == ForcedDarkAppearance);
		}
	} else {
		self.darkMode = (forcedAppearance == ForcedDarkAppearance);
	}
}

/// This is an old getter, nowadays you can just access `.darkMode` to get this value.
- (bool)isDark
{
	return self.darkMode;
}

/// Returnds `true` when the actual OS is set to dark. Mojave gets false every time.
- (bool)OSisDark
{
	if (@available(macOS 10.14, *)) {
		NSAppearance *appearance = NSApp.effectiveAppearance;
		if (!appearance) appearance = NSAppearance.currentAppearance;
		
		NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		return [appearanceName isEqualToString:NSAppearanceNameDarkAqua];
	} else {
		return NO;
	}
}

- (BeatForcedAppearance)forcedAppearance
{
	if (self.OSisDark && !self.darkMode) return ForcedLightAppearance;
	else if (!self.OSisDark && self.darkMode) return ForcedDarkAppearance;
	else return NoForcedAppearance;
}

- (void)toggleDarkMode
{
	self.darkMode = !self.darkMode;
	
	// Wwe only store the FORCED appearance. If the user is using dark mode in dark mode, no need to store that.
	[BeatUserDefaults.sharedDefaults saveInteger:self.forcedAppearance forKey:BeatSettingForcedAppearance];
	
	NSArray* openDocuments = NSDocumentController.sharedDocumentController.documents;
	for (id<BeatEditorDelegate> doc in openDocuments) {
		[doc updateUIColors];
	}
}

@end
