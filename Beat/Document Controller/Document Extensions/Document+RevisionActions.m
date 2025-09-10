//
//  Document+RevisionActions.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+RevisionActions.h"

@implementation Document (RevisionActions)

#pragma mark - Revision Tracking

-(IBAction)toggleShowRevisions:(id)sender
{
	// Save user default
	[BeatUserDefaults.sharedDefaults toggleBool:BeatSettingShowRevisions];

	// Refresh layout + settings
	self.textView.needsLayout = true;
	self.textView.needsDisplay = true;
}

-(IBAction)toggleShowRevisedTextColor:(id)sender
{
	[BeatUserDefaults.sharedDefaults toggleBool:BeatSettingShowRevisedTextColor];
	[self.formatting refreshRevisionTextColorsInRange:NSMakeRange(0, self.text.length)];
}

-(IBAction)toggleRevisionMode:(id)sender
{
	self.revisionMode = !self.revisionMode;
	
	// Save document setting
	[self.documentSettings setBool:DocSettingRevisionMode as:self.revisionMode];
}

- (IBAction)toggleVisibleRevision:(NSMenuItem*)sender
{
	NSInteger i = sender.tag;
	NSMutableArray<NSNumber*>* hiddenRevisions = ((NSArray*)[self.documentSettings get:DocSettingHiddenRevisions]).mutableCopy;
	if (hiddenRevisions == nil) hiddenRevisions = NSMutableArray.new;
	
	if ([hiddenRevisions containsObject:@(i)]) {
		[hiddenRevisions removeObject:@(i)];
	} else {
		[hiddenRevisions addObject:@(i)];
	}
	[self.documentSettings set:DocSettingHiddenRevisions as:hiddenRevisions];
	
	[self resetPreview];
	[self updateLayout];
}

- (IBAction)markAddition:(id)sender
{
	if (self.contentLocked) return;
	
	NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
	[self.revisionTracking markerAction:RevisionAddition];
	[self.formatting refreshRevisionTextColorsInRange:range];
}

- (IBAction)markRemoval:(id)sender
{
	if (self.contentLocked) return;
	
	NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
	[self.revisionTracking markerAction:RevisionRemovalSuggestion];
	[self.formatting formatLinesInRange:range];
}

- (IBAction)clearMarkings:(id)sender
{
	// Remove markers
	if (self.contentLocked) return;
	
	NSRange range = self.selectedRange; // Revision tracking deselects the range, so let's store it
	[self.revisionTracking markerAction:RevisionNone];
	[self.formatting refreshRevisionTextColorsInRange:range];
}

- (IBAction)commitRevisions:(id)sender {
	[self.revisionTracking commitRevisions];
	[self.formatting refreshRevisionTextColors];
}

- (IBAction)selectRevisionColor:(id)sender {
	NSPopUpButton *button = sender;
	self.revisionLevel = button.indexOfSelectedItem;
}

@end
