//
//  Document+Plugins.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 28.11.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+Plugins.h"
#import "BeatPluginManager.h"
#import "Beat-Swift.h"
#import "BeatWidgetView.h"
#import <os/log.h>

@implementation Document (Plugins)
@dynamic pluginManager;
/*
 
 Some explanation:
 
 Plugins are run inside document scope, unless they are standalone tools.
 If the plugins are "resident" (can be left running in the background),
 they are registered and deregistered when launching and shutting down.
 
 Some changes made to the document are sent to all of the running plugins,
 if they have any change listeners.
 
 This should be separated to its own class, something like PluginAgent or something.
 
 */

- (void)setupPlugins {
	self.pluginManager = BeatPluginManager.sharedManager;
}
- (IBAction)runPlugin:(id)sender {
	// Get plugin filename from menu item
	BeatPluginMenuItem *menuItem = (BeatPluginMenuItem*)sender;
	NSString *pluginName = menuItem.pluginName;
	
	[self runPluginWithName:pluginName];
}
- (void)runPluginWithName:(NSString*)pluginName {
	os_log(OS_LOG_DEFAULT, "# Run plugin: %@", pluginName);
	
	// See if the plugin is running and disable it if needed
	if (self.runningPlugins[pluginName]) {
		[(BeatPlugin*)self.runningPlugins[pluginName] forceEnd];
		[self.runningPlugins removeObjectForKey:pluginName];
		return;
	}

	// Run a new plugin
	BeatPlugin *pluginParser = [[BeatPlugin alloc] init];
	pluginParser.delegate = self;
	
	BeatPluginData *pluginData = [self.pluginManager pluginWithName:pluginName];
	[pluginParser loadPlugin:pluginData];
		
	// Null the local variable just in case.
	// If the plugin asks to stay in memory, it will call registerPlugin:
	pluginParser = nil;
}

- (void)registerPlugin:(id)plugin {
	BeatPlugin *parser = (BeatPlugin*)plugin;
	if (!self.runningPlugins) self.runningPlugins = NSMutableDictionary.new;
	
	self.runningPlugins[parser.pluginName] = parser;
}
- (void)deregisterPlugin:(id)plugin {
	BeatPlugin *parser = (BeatPlugin*)plugin;
	[self.runningPlugins removeObjectForKey:parser.pluginName];
	parser = nil;
}

- (void)updatePlugins:(NSRange)range {
	// Run resident plugins
	if (!self.runningPlugins) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin update:range];
	}
}

- (void)updatePluginsWithSelection:(NSRange)range {
	// Run resident plugins which are listening for selection changes
	if (!self.runningPlugins) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin updateSelection:range];
	}
}

- (void)updatePluginsWithSceneIndex:(NSInteger)index {
	// Run resident plugins which are listening for selection changes
	if (!self.runningPlugins) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin updateSceneIndex:index];
	}
}

- (void)updatePluginsWithOutline:(NSArray*)outline {
	// Run resident plugins which are listening for selection changes
	if (!self.runningPlugins) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin updateOutline:outline];
	}
}

- (void)notifyPluginsThatWindowBecameMain {
	if (!self.runningPlugins) return;
	
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin documentDidBecomeMain];
	}
}

- (void)addWidget:(id)widget {
	[self.widgetView addWidget:widget];
	[self showWidgets:nil];
}

// For those who REALLY, REALLY know what the fuck they are doing
- (void)setPropertyValue:(NSString*)key value:(id)value {
	[self setValue:value forKey:key];
}
- (id)getPropertyValue:(NSString*)key {
	return [self valueForKey:key];
}

@end
