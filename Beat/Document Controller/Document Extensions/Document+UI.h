//
//  Document+UI.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (UI)

#pragma mark Outline view updating

/// When the current scene has changed, some UI elements need to be updated. Add any required updates here.
- (void)updateUIwithCurrentScene;

#pragma mark Tabs

/// Returns the currently visible "tab" in main window (meaning editor, preview, index cards, etc.)
- (NSTabViewItem*)currentTab;
/// Returns `true` when the main editor view is visible
- (bool)editorTabVisible;


@end

NS_ASSUME_NONNULL_END
