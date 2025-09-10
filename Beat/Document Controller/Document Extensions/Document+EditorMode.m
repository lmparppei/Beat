//
//  Document+EditorMode.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+EditorMode.h"
#import "Beat-Swift.h"

@implementation Document (EditorMode)

#pragma mark - Editor modes

/// NOTE: This method is NOT implemented by super class despite the warning. It's just my sloppy protocols.
- (void)toggleMode:(BeatEditorMode)mode
{
	if (self.mode != mode) self.mode = EditMode;
	else self.mode = mode;
	[self updateEditorMode];
}

BeatEditorMode currentMode;

- (void)setMode:(BeatEditorMode)mode
{
	//[super setValue:@(mode) forKey:@"mode"];
	currentMode = mode;
	[self updateEditorMode];
}

- (BeatEditorMode)mode
{
	return currentMode;
}

- (void)updateEditorMode
{
	self.modeIndicator.hidden = (self.mode == EditMode);
	
	// Show mode indicator
	if (self.mode != EditMode) {
		NSString *modeName = @"";
		
		if (self.mode == TaggingMode) modeName = [BeatLocalization localizedStringForKey:@"mode.taggingMode"];
		else if (self.mode == ReviewMode) modeName = [BeatLocalization localizedStringForKey:@"mode.reviewMode"];
		
		[self.modeIndicator showModeWithModeName:modeName];
	}
	
	[self.documentWindow layoutIfNeeded];
	[self updateLayout];
}

@end

