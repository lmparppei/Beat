//
//  Document+AdditionalActions.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+AdditionalActions.h"
#import "Document+WindowManagement.h"
#import "ThemeEditor.h"
#import "BeatModalInput.h"
#import "Beat-Swift.h"
#import "BeatTimer.h"
#import "BeatTitlePageEditor.h"

@implementation Document (AdditionalActions)


#pragma mark - Plugin actions from menu (if you make the plugin agent a responder, this could be moved there)

/// Called from `BeatPluginMenuItem`, which contains the plugin name to be run in this window.
- (IBAction)runPlugin:(id)sender
{
	// Get plugin filename from menu item
	BeatPluginMenuItem *menuItem = (BeatPluginMenuItem*)sender;
	NSString *pluginName = menuItem.pluginName;
	
	[self.pluginAgent runPluginWithName:pluginName];
}


#pragma mark - Title page editor

- (IBAction)editTitlePage:(id)sender
{
	BeatTitlePageEditor* titlePageEditor = [[BeatTitlePageEditor alloc] initWithDelegate:self];
	self.sheetController = titlePageEditor;
	
	[self.documentWindow beginSheet:titlePageEditor.window completionHandler:^(NSModalResponse returnCode) {
		self.sheetController = nil;
	}];
}


#pragma mark - Timer

- (IBAction)showTimer:(id)sender {
	self.beatTimer.delegate = self;
	[self.beatTimer showTimer];
}


#pragma mark - Color Customization

- (IBAction)customizeColors:(id)sender {
	ThemeEditor* editor = ThemeEditor.sharedEditor;
	[editor showWindow:editor.window];
}


#pragma mark - Search for scene

- (IBAction)goToScene:(id)sender
{
	__block BeatSceneHeadingSearch *search = [BeatSceneHeadingSearch.alloc init];
	search.delegate = self;
	
	[self.documentWindow beginSheet:search.window completionHandler:^(NSModalResponse returnCode) {
		search = nil;
	}];
}


#pragma mark - Force Scene Numbering

- (IBAction)forceSceneNumberForScene:(id)sender
{
	BeatModalInput *input = BeatModalInput.new;
	
	[input inputBoxWithMessage:[BeatLocalization localizedStringForKey:@"editor.setSceneNumber"]
						  text:[BeatLocalization localizedStringForKey:@"editor.setSceneNumber.info"]
				   placeholder:@"123A" forWindow:self.documentWindow
					completion:^(NSString * _Nonnull result) {
		OutlineScene *scene = self.currentScene;
		if (result.length == 0 || scene == nil) return;

		if (scene.line.sceneNumberRange.length) {
			// Remove existing scene number
			NSRange range = NSMakeRange(scene.line.position + scene.line.sceneNumberRange.location, scene.line.sceneNumberRange.length);
			[self replaceRange:range withString:result];
		} else {
			// Add empty scene number
			[self addString:[NSString stringWithFormat:@" #%@#", result] atIndex:scene.line.position + scene.line.string.length];
		}
	}];
}


#pragma mark - Tag editor

- (IBAction)showTagEditor:(id)sender
{
	[BeatTagEditor openTagEditorWithDelegate:self];
}


@end
