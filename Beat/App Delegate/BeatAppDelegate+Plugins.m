//
//  BeatAppDelegate+Plugins.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate+Plugins.h"
#import <BeatPlugins/BeatPlugins.h>
#import "BeatPluginLibrary.h"

@implementation BeatAppDelegate (Plugins)

#pragma mark - Plugin support

- (IBAction)openPluginLibrary:(id)sender
{
	self.pluginLibrary = BeatPluginLibrary.alloc.init;
	self.pluginLibrary.window.delegate = self;
	[self.pluginLibrary show];
}

- (IBAction)runStandalonePlugin:(id)sender
{
	// This runs a plugin which is NOT tied to the document
	NSMenuItem *item = sender;
	NSString *pluginName = item.title;
	
	BeatPlugin *parser = BeatPlugin.new;
	BeatPluginData *plugin = [BeatPluginManager.sharedManager pluginWithName:pluginName];
	[parser loadPlugin:plugin];
	parser = nil;
}


@end
