//
//  BeatCheckboxCell.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.11.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatCheckboxCell.h"
#import <BeatPlugins/BeatPlugins.h>
#import <BeatCore/BeatColors.h>

@interface BeatCheckboxCell ()
@property (weak) BeatPluginManager *pluginManager;
@end

@implementation BeatCheckboxCell

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
    
    // Drawing code here.
}

-(void)setSize {
}

-(void)viewWillDraw {
	if (_localURL) {
		// Plugin is installed
		[_pluginName setTextColor:NSColor.labelColor];
		[_checkbox setHidden:NO];
	} else {
		// Plugin is downloadable
		[_pluginName setTextColor:NSColor.secondaryLabelColor];
		[_checkbox setHidden:YES];
	}
	
	if (_enabled) [_checkbox setState:NSOnState]; else [_checkbox setState:NSOffState];
	if (_name) [_pluginName setStringValue:_name];
	
	if (_updateAvailable) [_pluginName setTextColor:[BeatColors color:@"green"]];
	else [_pluginName setTextColor:NSColor.labelColor];
}

- (void)select {
	self.selected = YES;
}
- (void)deselect {
	self.selected = NO;
}

- (void)downloadComplete {
	[_pluginName setTextColor:NSColor.labelColor];
	[_checkbox setHidden:NO];
}

- (IBAction)togglePlugin:(id)sender {
	if (!_pluginManager) _pluginManager = BeatPluginManager.sharedManager;
	
	NSButton *checkBox = (NSButton*)sender;
	if (checkBox.state == NSOnState) [_pluginManager enablePlugin:self.name];
	else [_pluginManager disablePlugin:self.name];
}

- (NSImage*)buttonBackground:(NSColor*)color size:(CGSize)size {
	size = NSMakeSize(200, 200);
	NSImage *image = [[NSImage alloc] initWithSize:size];
	[image lockFocus];
	[color drawSwatchInRect:(NSRect){ 0, 0, size.width, size.height }];
	[image unlockFocus];
	return image;
}


@end
