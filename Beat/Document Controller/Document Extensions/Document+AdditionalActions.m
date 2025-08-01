//
//  Document+AdditionalActions.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+AdditionalActions.h"
#import "Document+WindowManagement.h"
#import "Document+EditorMode.h"
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


#pragma mark - Card view

- (IBAction)toggleCards: (id)sender {
	if (self.currentTab != self.cardsTab) {
		[self showTab:self.cardsTab];
	} else {
		// Reload outline + timeline (in case there were any changes in outline while in card view)
		[self updateOutlineViews];
		[self returnToEditor];
	}
}


#pragma mark - Review mode

- (IBAction)toggleReview:(id)sender
{
	if (self.mode == ReviewMode) self.mode = EditMode;
	else self.mode = ReviewMode;
}

- (IBAction)reviewSelectedRange:(id)sender
{
	if (self.selectedRange.length == 0) return;
	[self.review showReviewIfNeededWithRange:self.selectedRange forEditing:YES];
}


#pragma mark - Tagging Mode

- (IBAction)toggleTagging:(id)sender
{
	self.mode = (self.mode == TaggingMode) ? EditMode : TaggingMode;
	
	if (self.mode == TaggingMode) {
		[self.tagTextView.enclosingScrollView setHasHorizontalScroller:NO];
		//[_sideViewCostraint setConstant:180];
	} else {
		[self.tagTextView.enclosingScrollView setHasHorizontalScroller:NO];
		//self.sideViewCostraint setConstant:0;
				
		[self toggleMode:TaggingMode];
	}
	
	[self updateEditorMode];
}



#pragma mark - Selecting fonts

- (IBAction)selectSerif:(id)sender
{
	NSMenuItem* item = sender;
	[BeatUserDefaults.sharedDefaults saveBool:(item.state == NSOnState) forKey:BeatSettingUseSansSerif];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc reloadFonts];
	}
}

- (IBAction)selectSansSerif:(id)sender
{
	NSMenuItem* item = sender;
	bool sansSerif = (item.state != NSOnState);

	[BeatUserDefaults.sharedDefaults saveBool:sansSerif forKey:BeatSettingUseSansSerif];
	
	for (Document* doc in NSDocumentController.sharedDocumentController.documents) {
		[doc reloadFonts];
	}
}


#pragma mark - Pagination manager methods

- (IBAction)togglePageNumbers:(id)sender
{
	self.showPageNumbers = !self.showPageNumbers;
	
	((BeatLayoutManager*)self.layoutManager).pageBreaksMap = nil;
	[self.previewController resetPreview];
	
	self.textView.needsDisplay = true;
}

#pragma mark - Hiding markup

- (IBAction)toggleHideFountainMarkup:(id)sender {
	[BeatUserDefaults.sharedDefaults toggleBool:BeatSettingHideFountainMarkup];
	self.hideFountainMarkup = [BeatUserDefaults.sharedDefaults getBool:BeatSettingHideFountainMarkup];
	
	[self.textView toggleHideFountainMarkup];
		
	[self updateLayout];
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

- (IBAction)showTimer:(id)sender
{
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
	// Check that there are no tag manager instances open...
	if (self.tagManager == nil) {
		self.tagManager = [BeatTagManager openTagEditorWithDelegate:self];
	} else {
		[self.tagManager close];
		self.tagManager = nil;
	}
}


#pragma mark - Formatting

- (IBAction)toggleDisableFormatting:(id)sender
{
	[BeatUserDefaults.sharedDefaults toggleBool:BeatSettingDisableFormatting];
	[self.formatting forceFormatChangesInRange:NSMakeRange(0, self.text.length)];
}


#pragma mark - Zooming

- (IBAction)zoomIn:(id)sender
{
	if (self.currentTab == self.editorTab) {
		[self.textView zoom:YES];
	} else if (self.currentTab == self.nativePreviewTab) {
		self.previewController.scrollView.magnification += .05;
	}
}
- (IBAction)zoomOut:(id)sender
{
	if (self.currentTab == self.editorTab) {
		[self.textView zoom:NO];
	} else if (self.currentTab == self.nativePreviewTab) {
		self.previewController.scrollView.magnification -= .05;
	}
}

- (IBAction)resetZoom:(id)sender
{
	if (self.currentTab == self.editorTab) {
		[self.textView resetZoom];
	} else if (self.currentTab == self.nativePreviewTab) {
		self.previewController.scrollView.magnification = 1.0;
	}
}


#pragma mark - Document settings

- (IBAction)openDocumentSettings:(id)sender
{
	BeatDocumentSettingWindow* settings = [BeatDocumentSettingWindow.alloc init];;
	settings.editorDelegate = self;	
	self.sheetController = settings;
	
	[self.documentWindow beginSheet:settings.window completionHandler:^(NSModalResponse returnCode) {
		self.sheetController = nil;
	}];
}

@end
