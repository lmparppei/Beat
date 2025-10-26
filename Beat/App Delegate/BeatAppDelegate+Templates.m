//
//  BeatAppDelegate+Templates.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate+Templates.h"
#import <BeatCore/BeatCore.h>

@implementation BeatAppDelegate (Templates)


#pragma mark - Tutorial and templates

- (IBAction)openTutorial:(id)sender
{
	[self showTemplate:@"Tutorial"];
}

- (IBAction)templateBeatSheet:(id)sender {
	[self showTemplate:@"Beat Sheet"];
}

- (void)showTemplate:(NSString*)name
{
	name = [name stringByReplacingOccurrencesOfString:@".fountain" withString:@""];
	
	NSURL* url = [BeatTemplates.shared getTemplateURLWithFilename:name];
	
	if (url) [[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:url copying:YES displayName:name error:nil];
	else NSLog(@"ERROR: Can't find template");
}



@end
