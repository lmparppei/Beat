//
//  BeatTextView+ForceElement.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 8.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+ForceElement.h"
#import "Beat-Swift.h"

@implementation BeatTextView (ForceElement)

#pragma mark - Force element

- (IBAction)showForceMenu:(id)sender
{
	[self showForceElementMenu];
}

- (void)showForceElementMenu
{
	[self.popoverController displayWithRange:self.selectedRange items:self.forceableTypes.allKeys callback:^BOOL(NSString * _Nonnull string, NSInteger index) {
		[self forceLineTypeWithName:string];
		// Prevent default
		return true;
	}];
}

- (void)forceLineTypeWithName:(NSString*)string
{
	NSDictionary *types = [self forceableTypes];
	NSNumber *val = types[string];
	
	// Do nothing if something went wrong
	if (val == nil) return;
	
	LineType type = (LineType)val.integerValue;
	[self.editorDelegate.textActions forceLineType:type];
}

/// The UI uses localized type names. This method provides a dictionary which has localized name as key and the actual raw `LineType` as `NSNumber`: `"Localized Name": (rawIntegerTypeValue)`
- (NSDictionary*)forceableTypes
{
	return @{
		[BeatLocalization localizedStringForKey:@"force.heading"]: @(heading),
		[BeatLocalization localizedStringForKey:@"force.character"]: @(character),
		[BeatLocalization localizedStringForKey:@"force.action"]: @(action),
		[BeatLocalization localizedStringForKey:@"force.lyrics"]: @(lyrics),
	};
}


@end
