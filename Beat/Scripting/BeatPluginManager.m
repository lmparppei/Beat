//
//  BeatPluginManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 Provides a list of plugin names and a runnable JS script for the plugin.
 
 Future considerations:
 - Add plugin types. Type specification could be located either inside the
   files (Plugin Type: ...) or in the filename: "Plugin [Import].beatPlugin"
 - Plugin could be a simple XML file with both the JS and some HTML content
 
 */


#import "BeatPluginManager.h"
#import "ApplicationDelegate.h"
#import "RegExCategories.h"

@interface BeatPluginManager ()
@property (nonatomic) NSDictionary *plugins;
@property (nonatomic) NSURL *pluginURL;
@end
@implementation BeatPluginManager

+ (BeatPluginManager*)sharedManager
{
	static BeatPluginManager* sharedManager;
	if (!sharedManager) {
		sharedManager = [[BeatPluginManager alloc] init];
	}
	return sharedManager;
}

- (BeatPluginManager*)init {
	self = [super init];
	
	if (self) {
		_pluginURL = [(ApplicationDelegate*)NSApp.delegate appDataPath:@"Plugins"];
		[self loadPlugins];
	}
	
	return self;
}

- (void)loadPlugins {
	NSMutableArray *plugins = [NSMutableArray array];
	
	// Plugins from inside the bundle
	NSArray *bundledPlugins = [NSBundle.mainBundle URLsForResourcesWithExtension:@"beatPlugin" subdirectory:nil];
	for (NSURL *url in bundledPlugins) {
		[plugins addObject:url.path];
	}
	
	// Get user-installed plugins
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *files = [fileManager contentsOfDirectoryAtPath:_pluginURL.path error:nil];
	
	for (NSString *file in files) {
		if (![file.pathExtension isEqualToString:@"beatPlugin"]) continue;
		
		NSString *filepath = [_pluginURL.path stringByAppendingPathComponent:file];
		[plugins addObject:filepath];
	}
	
	NSMutableDictionary *pluginsWithNames = [NSMutableDictionary dictionary];
	for (NSString *plugin in plugins) {
		[pluginsWithNames setValue:plugin forKey:plugin.lastPathComponent.stringByDeletingPathExtension];
	}
	_plugins = pluginsWithNames;
}
- (NSArray*)pluginNames {
	return [self.plugins.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSString*)scriptForPlugin:(NSString*)pluginName {
	NSString *filename = _plugins[pluginName];
	if (!filename) return @"";
	
	NSString *script = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:nil];
	// Make it a self-running function
	script = [NSString stringWithFormat:@"(function(){ %@ })();", script];
	
	return script;
}

- (BeatPluginType)pluginTypeFor:(NSString*)plugin {
	NSString *path = _plugins[plugin];
	
	NSError *error;
	NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if (error) return GenericPlugin;
	
	Rx* rx = [Rx rx:@"\nPlugin type:([\\w|\\s]+)\n" options:NSRegularExpressionCaseInsensitive];
	RxMatch* match = [script firstMatchWithDetails:rx];
	
	if (match) {
		NSString *type = [[[(RxMatchGroup*)match.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] lowercaseString];
		
		if ([type isEqualToString:@"import"]) return ImportPlugin;
		else if ([type isEqualToString:@"standalone"]) return StandalonePlugin;
		else if ([type isEqualToString:@"tool"]) return ToolPlugin;
		else return GenericPlugin;
	} else {
		return GenericPlugin;
	}
}

@end
