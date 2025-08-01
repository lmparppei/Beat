//
//  Document+UI.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+UI.h"

@implementation Document (UI)

#pragma mark - Update UI with current scene

- (void)updateUIwithCurrentScene
{
	OutlineScene *currentScene = self.currentScene;
	NSInteger sceneIndex = [self.parser indexOfScene:currentScene];
	if (sceneIndex == NSNotFound) return;
	
	// Update any registered outline views
	for (id<BeatSceneOutlineView>view in self.registeredOutlineViews) {
		if (view.visible) [view didMoveToSceneIndex:sceneIndex];
	}
		
	// Update touch bar color if needed
	if (currentScene.color.length > 0) {
		NSColor* color = [BeatColors color:currentScene.color];
		if (color != nil) [self.colorPicker setColor:color];
	}
		
	[self.pluginAgent updatePluginsWithSceneIndex:sceneIndex];
}


#pragma mark - Tabs

/// Returns the currently visible "tab" in main window (meaning editor, preview, index cards, etc.)
- (NSTabViewItem*)currentTab
{
	return self.tabView.selectedTabViewItem;
}

/// Returns `true` when the editor view is visible. You can ignore the warning here.
- (bool)editorTabVisible
{
	return (self.currentTab == self.editorTab);
}


@end
