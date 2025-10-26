//
//  BeatAppDelegate+Import.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate+Import.h"
#import "BeatFileImport.h"

@implementation BeatAppDelegate (Import)

#pragma mark - File Import

- (IBAction)importFDX:(id)sender
{
	[BeatFileImport.new fdx];
}
- (IBAction)importCeltx:(id)sender
{
	[BeatFileImport.new celtx];
}
- (IBAction)importHighland:(id)sender
{
	[BeatFileImport.new highland];
}
- (IBAction)importFadeIn:(id)sender
{
	[BeatFileImport.new fadeIn];
}
- (IBAction)importTrelby:(id)sender
{
	[BeatFileImport.new trelby];
}
- (IBAction)importPDF:(id)sender
{
	[BeatFileImport.new pdf];
}

@end
