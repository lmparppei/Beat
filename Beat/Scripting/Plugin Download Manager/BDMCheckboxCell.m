//
//  BDMCheckboxCell.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.4.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BDMCheckboxCell.h"
#import "BeatPluginManager.h"

@interface BDMCheckboxCell ()
@property (weak) BeatPluginManager *pluginManager;
@end

@implementation BDMCheckboxCell

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}
-(void)viewWillDraw {
	if (_localURL) {
		// Plugin is installed
		[_pluginName setTextColor:NSColor.labelColor];
		[_downloadButton setHidden:YES];
		[_checkbox setHidden:NO];
	} else {
		// Plugin is downloadable
		[_pluginName setTextColor:NSColor.secondaryLabelColor];
		[_downloadButton setHidden:NO];
		[_checkbox setHidden:YES];
	}
	
	if (_updateAvailable) {
		NSLog(@"Check: update available");
		[_downloadButton setHidden:NO];
		[_downloadButton setTitle:@"Update"];
	} else {
		[_downloadButton setTitle:@"Download"];
	}
	
	if (_enabled) [_checkbox setState:NSOnState]; else [_checkbox setState:NSOffState];
	[_pluginName setStringValue:_name];
	(_info) ? [_pluginText setStringValue:_info] : [_pluginText setStringValue:@""];
	
	
	//NSString *copyrightAndVersion = [NSString stringWithFormat:@"%@ — %@", (_version) ? _version : @"", (_copyright) ? _copyright : @""];
	
}

- (IBAction)download:(id)sender {
	if (!_pluginManager) _pluginManager = [BeatPluginManager sharedManager];
	[_pluginManager downloadPlugin:_name sender:self];
}

- (void)downloadComplete {
	[_pluginName setTextColor:NSColor.labelColor];
	[_checkbox setHidden:NO];
	[_downloadButton setTitle:@"Success"];
	[_downloadButton setEnabled:NO];
}

- (IBAction)togglePlugin:(id)sender {
	if (!_pluginManager) _pluginManager = [BeatPluginManager sharedManager];
	
	NSButton *checkBox = (NSButton*)sender;
	if (checkBox.state == NSOnState) {
		NSLog(@"enable");
		[_pluginManager enablePlugin:self.name];
	} else {
		[_pluginManager disablePlugin:self.name];
	}
}

@end
