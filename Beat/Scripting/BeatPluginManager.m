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
#import "BDMCheckboxCell.h"
#import <UnzipKit/UnzipKit.h>

#define PLUGIN_LIBRARY_URL @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Beat%20Plugins.json"
#define DOWNLOAD_URL_BASE @"raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/"
#define PLUGIN_FOLDER @"Plugins"
#define DISABLED_KEY @"Disabled Plugins"

@implementation BeatPlugin

@end

@interface BeatPluginManager ()
@property (nonatomic) NSDictionary *plugins;
@property (nonatomic) NSURL *pluginURL;
@property (nonatomic) NSMenuItem *menuItem;
@property (nonatomic) NSDictionary *externalLibrary;
@property (nonatomic) NSMutableDictionary *availablePlugins;
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
	static BeatPluginManager* sharedManager;
	if (sharedManager) return sharedManager;
	
	self = [super init];
	
	if (self) {
		_pluginURL = [(ApplicationDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
		[self loadPlugins];
	}
	
	return self;
}

- (NSArray*)disabledPlugins {
	return [NSUserDefaults.standardUserDefaults valueForKey:DISABLED_KEY];
}
- (void)disablePlugin:(NSString*)plugin {
	NSMutableArray *disabledPlugins = [NSMutableArray arrayWithArray:[NSUserDefaults.standardUserDefaults valueForKey:DISABLED_KEY]];
	[disabledPlugins addObject:plugin];
	[NSUserDefaults.standardUserDefaults setValue:disabledPlugins forKey:DISABLED_KEY];
}
- (void)enablePlugin:(NSString *)plugin {
	NSMutableArray *disabledPlugins = [NSMutableArray arrayWithArray:[NSUserDefaults.standardUserDefaults valueForKey:DISABLED_KEY]];
	if ([disabledPlugins containsObject:plugin]) [disabledPlugins removeObject:plugin];
	[NSUserDefaults.standardUserDefaults setValue:disabledPlugins forKey:DISABLED_KEY];
}

- (void)updateAvailablePlugins {
	self.availablePlugins = [NSMutableDictionary dictionary];
	for (NSString *pluginName in self.plugins.allKeys) {
		[_availablePlugins setValue:[self pluginInfoFor:pluginName] forKey:pluginName];
	}
}

- (void)updateAvailablePluginsWithExternalLibrary {
	for (NSString *pluginName in self.externalLibrary.allKeys) {
		NSDictionary *plugin = self.externalLibrary[pluginName];
		
		if (_availablePlugins[pluginName]) {
			// The plugin is already available, check for updates
			NSMutableDictionary *existingPlugin = [NSMutableDictionary dictionaryWithDictionary:_availablePlugins[pluginName]];
			
			if ([self isNewerVersion:plugin[@"version"] old:existingPlugin[@"version"]]) {
				existingPlugin[@"updateAvailable"] = plugin[@"version"];
			}
			[_availablePlugins setValue:existingPlugin forKey:pluginName];
		} else {
			[_availablePlugins setValue:plugin forKey:pluginName];
		}
	}
}

- (bool)isNewerVersion:(NSString*)current old:(NSString*)old {
	NSString *pad = @"0000";
	
	current = [current stringByReplacingOccurrencesOfString:@"." withString:@""];
	old = [old stringByReplacingOccurrencesOfString:@"." withString:@""];
	
	current = [pad stringByReplacingCharactersInRange:(NSRange){0, current.length} withString:current];
	old = [pad stringByReplacingCharactersInRange:(NSRange){0, old.length} withString:old];
	
	NSInteger currentVersion = [current integerValue];
	NSInteger oldVersion = [old integerValue];
	
	if (currentVersion > oldVersion) return YES;
	else return NO;
}

- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock {
	NSString *urlAsString = PLUGIN_LIBRARY_URL;

	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];


	[[session dataTaskWithURL:[NSURL URLWithString:urlAsString]
			completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		
		NSMutableDictionary *plugins = [NSMutableDictionary dictionary];
		NSDictionary *pluginData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		
		for (NSString *pluginName in pluginData.allKeys) {
			NSDictionary *data = pluginData[pluginName];
			NSString *name = pluginName.stringByDeletingPathExtension;
			
			// Never add stuff with no name
			if (!name) continue;
			
			NSDictionary *pluginInfo = @{
				@"name": name,
				@"version": data[@"version"],
				@"copyright": data[@"copyright"],
				@"description": data[@"description"],
				@"installed": @(NO)
			};
			[plugins setValue:pluginInfo forKey:name];
		}
		
		self.externalLibrary = plugins;
		[self updateAvailablePluginsWithExternalLibrary];
		
		dispatch_async(dispatch_get_main_queue(), ^(void){
			callbackBlock();
		});
	}] resume];
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

- (BeatPlugin*)pluginWithName:(NSString*)name {
	BeatPlugin *plugin = [[BeatPlugin alloc] init];
	plugin.name = name;
	
	// Uh. Let's reload the plugin array. The user might have installed new ones.
	
	[self loadPlugins];
	NSString *filename = _plugins[name];
	
	// Check if it's a plugin folder
	BOOL isDir = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir] && isDir) {
		// If it's a plugin folder, we have to append the plugin name AGAIN to the path
		NSString *path = [filename stringByDeletingLastPathComponent];
		NSString *file = [NSString stringWithFormat:@"%@/%@", filename.lastPathComponent, filename.lastPathComponent];
		path = [path stringByAppendingPathComponent:file];
		plugin.script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
		
		// Also, read the folder contents and allow file access to the plugin
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *files = [fileManager contentsOfDirectoryAtPath:path.stringByDeletingLastPathComponent error:nil];
		NSMutableArray *pluginFiles = [NSMutableArray array];
		
		for (NSString* file in files) {
			// Don't include the plugin script
			if ([file.lastPathComponent isEqualTo:name]) continue;;
			[pluginFiles addObject:file];
		}
		plugin.files = [NSArray arrayWithArray:pluginFiles];
	} else {
		// Get script
		plugin.script = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:nil];
	}
	
	// Make the script a self-running function
	plugin.script = [NSString stringWithFormat:@"(function(){ %@ })();", plugin.script];

	return plugin;
}

- (NSString*)pathForPlugin:(NSString*)pluginName {
	return _plugins[pluginName];
}

- (NSString*)scriptForPlugin:(NSString*)pluginName {
	NSString *filename = _plugins[pluginName];
	if (!filename) return @"";
	
	NSString *script = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:nil];
	// Make it a self-running function
	script = [NSString stringWithFormat:@"(function(){ %@ })();", script];
	
	return script;
}

- (bool)isFolderPlugin:(NSString*)pluginName {
	BOOL isDir = NO;
	NSString *filename = _plugins[pluginName];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir] && isDir) return YES;
	else return NO;
}

- (NSDictionary*)pluginInfoFor:(NSString*)plugin {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	NSString *path;
	
	if (![self isFolderPlugin:plugin]) {
		path = _plugins[plugin];
	} else {
		path = [[(NSString*)_plugins[plugin] stringByAppendingPathComponent:plugin] stringByAppendingPathExtension:@"beatPlugin"];
	}
		
	info[@"name"] = plugin;
	info[@"localURL"] = [NSURL fileURLWithPath:path];
	info[@"installed"] = @(YES);

	NSError *error;
	NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

	//Rx* versionRx = RX(@"^Version:");
	Rx* versionRx = [Rx rx:@"\nVersion:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* copyrightRx = [Rx rx:@"\nCopyright:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* descriptionRx = [Rx rx:@"\nDescription:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	
	RxMatch *matchVersion = [script firstMatchWithDetails:versionRx];
	RxMatch *matchCopyright = [script firstMatchWithDetails:copyrightRx];
	RxMatch *matchDescription = [script firstMatchWithDetails:descriptionRx];
		
	if (matchVersion) info[@"version"] = [[(RxMatchGroup*)matchVersion.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (matchCopyright) info[@"copyright"] = [[(RxMatchGroup*)matchCopyright.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (matchDescription) info[@"description"] = [[(RxMatchGroup*)matchDescription.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	return info;
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

#pragma mark - Provide Menu Items

- (void)pluginMenuItemsFor:(NSMenu*)parentMenu runningPlugins:(NSDictionary*)runningPlugins {
	// Remove existing plugin menu items
	NSArray *menuItems = [NSArray arrayWithArray:parentMenu.itemArray];
	for (NSMenuItem *item in menuItems) {
		if (item.tag == 1) {
			// Save prototype
			if (!_menuItem) _menuItem = item;
			[parentMenu removeItem:item];
		}
	}
		
	[self loadPlugins];
	
	NSArray *disabledPlugins = [self disabledPlugins];
	
	for (NSString *pluginName in self.pluginNames) {
		// Don't show this plugin in menu
		if ([disabledPlugins containsObject:pluginName]) continue;
		
		NSMenuItem *item = [_menuItem copy];
		item.state = NSOffState;
		item.title = pluginName;
		
		if (runningPlugins[pluginName]) item.state = NSOnState;
		
		[parentMenu addItem:item];
	}
}

- (IBAction)openPluginFolderAction:(id)sender {
	[self openPluginFolder];
}
- (void)openPluginFolder {
	NSURL *url = [(ApplicationDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
	[NSWorkspace.sharedWorkspace openURL:url];
}

#pragma mark - Data Source

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if (!item) return [self availablePluginNames].count;
	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	return [self availablePluginNames][index];
}

-(BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return NO;
}

-(NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	NSInteger index = [[self availablePluginNames] indexOfObject:(NSString*)item];
	
	NSString *name = [self availablePluginNames][index];
	
	//BDMCheckboxCell *cell = [[BDMCheckboxCell alloc] initWithName:name url:url];
	BDMCheckboxCell *cell = [outlineView makeViewWithIdentifier:@"PluginCell" owner:self];
	
	if ([[self disabledPlugins] containsObject:name]) cell.enabled = NO; else cell.enabled = YES;
	
	NSDictionary *pluginInfo = _availablePlugins[name];
	
	bool installed = [(NSNumber*)pluginInfo[@"installed"] boolValue];
	if (installed) {
		cell.localURL = pluginInfo[@"localURL"];
	} else {
		NSLog(@"Not installed: %@", pluginInfo[@"name"]);
		cell.localURL = nil;
	}
	
	if (pluginInfo[@"updateAvailable"]) { cell.updateAvailable = YES; }
	
	cell.name = pluginInfo[@"name"];
	cell.info = pluginInfo[@"description"];
	cell.copyright = pluginInfo[@"copyright"];
	cell.version = pluginInfo[@"version"];
	
	return cell;
}

- (NSArray*)availablePluginNames {
	return [self.availablePlugins.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

#pragma mark - Outlineview delegate

-(BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item {
	return YES;
}
-(BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
	return NO;
}
-(BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	return YES;
}

#pragma mark - File Access

- (void)deletePlugin:(NSString*)name {
	NSString *path = _plugins[name];
	NSURL *url = [NSURL fileURLWithPath:path];
	
	NSError *error;
	[NSFileManager.defaultManager removeItemAtURL:url error:&error];
	if (error) {
		NSLog(@"Error deleting plugin: %@", name);
	}
}

- (void)downloadPlugin:(NSString*)pluginName sender:(id)sender {
	BDMCheckboxCell *cell = (BDMCheckboxCell*)sender;
	[cell.downloadButton setEnabled:NO];
	[cell.downloadButton setTitle:@"Downloading..."];
	
	// Plugins are wrapped in a zip
	__block NSString *pluginFileName = [NSString stringWithFormat:@"%@.beatPlugin.zip", pluginName];
	
	NSString *downloadPath = [NSString stringWithFormat:@"%@%@", DOWNLOAD_URL_BASE, pluginFileName];
	downloadPath = [downloadPath stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
	downloadPath = [NSString stringWithFormat:@"https://%@", downloadPath];
	
	NSURL *url = [NSURL URLWithString:downloadPath];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	
	[[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSError *writeError;
		NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:pluginFileName];
		
		[data writeToURL:[NSURL fileURLWithPath:tempDir] options:0 error:&writeError];
		
		if (writeError) {
			NSLog(@"Error writing temporary zip file: %@", writeError);
		} else {
			dispatch_async(dispatch_get_main_queue(), ^(void){
				[cell downloadComplete];
				NSLog(@"Installing plugin...");
				[self installPlugin:tempDir];
			});
		}
	}] resume];
}

- (void)installPlugin:(NSString*)path {
	NSURL *url = [NSURL fileURLWithPath:path];
	
	NSError *error;
	UZKArchive *container = [[UZKArchive alloc] initWithURL:url error:&error];
	if (error || !container) return;
	
	// Get & create plugin path
	NSURL *pluginURL = [(ApplicationDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
	
	[container extractFilesTo:pluginURL.path overwrite:YES error:&error];
}


@end
/*
 
 when it is truly time
 and if you have been chosen
 it will do it by
 itself and it will keep on doing it
 until you die or it dies in you.
 
 */
