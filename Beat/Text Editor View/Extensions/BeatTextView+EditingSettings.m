//
//  BeatTextView+EditingSettings.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.4.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView+EditingSettings.h"

@implementation BeatTextView (EditingSettings)

- (IBAction)toggleAutomaticQuoteSubstitution:(id)sender
{
	[super toggleAutomaticQuoteSubstitution:sender];
	[BeatUserDefaults.sharedDefaults saveBool:self.automaticQuoteSubstitutionEnabled forKey:BeatSettingSmartQuotes];
}

@end
