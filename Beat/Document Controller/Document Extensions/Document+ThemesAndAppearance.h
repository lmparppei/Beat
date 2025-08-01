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

/// Redraws all UI elements to reliably update theme or appearance
/// - note: This method is NOT implemented by primary class, just appears so because it's inherited from `BeatEditorDelegate` definition. Objc selectors will sort this out.
- (void)updateUIColors;

/// Loads current theme (for all open documents if needed)
- (void)loadSelectedTheme:(bool)forAll;

/// Called when window switched from dark to light or vice-versa
- (void)didChangeAppearance;

@end
