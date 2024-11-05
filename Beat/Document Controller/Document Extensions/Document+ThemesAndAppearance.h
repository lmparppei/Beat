//
//  Document+ThemesAndAppearance.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"
#import <BeatThemes/BeatThemes.h>

@interface Document (ThemesAndAppearance) <BeatThemeManagedDocument>

/// Updates the UI to current scene
- (void)updateTheme;

/// Updates theme and reformats necessary lines.
/// @param type A list of types. These are predefined string values, not necessarily actual line type names, so for example `note` and `omit` are used.
- (void)updateThemeAndReformat:(NSArray*)types;

/// Redraws all UI elements to reliably update theme or appearance
- (void)updateUIColors;

/// Loads current theme (for all open documents if needed)
- (void)loadSelectedTheme:(bool)forAll;

/// Called when window switched from dark to light or vice-versa
- (void)didChangeAppearance;

@end
