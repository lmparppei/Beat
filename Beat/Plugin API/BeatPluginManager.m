//
//  BeatPluginManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Provides a list of plugin names and a runnable JS script for the plugin.
 
 Also handles downloading plugins from the GitHub repository. The address is HARD-CODED.
 For now, I'm the only admin in that repository. There is a risk of it becoming an attack-vector
 for malicious purposes, but Beat is sandboxed, so even while the API allows the plugins to
 write files, the operations have to be approved by the user. So probably we are on safe
 waters for now.
 
 */


#import "BeatPluginManager.h"
#import "BeatAppDelegate.h"
#import "RegExCategories.h"
#import "BeatCheckboxCell.h"
#import "UnzipKit.h"
#import "BeatPluginLibrary.h"
#import "NSString+VersionNumber.h"
#import <os/log.h>

#define PLUGIN_LIBRARY_URL @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Beat%20Plugins.json"

#define DOWNLOAD_URL_BASE @"raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/"
#define DOWNLOAD_URL_IMAGES @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Images/"
#define PLUGIN_FOLDER @"Plugins"
#define DISABLED_KEY @"Disabled Plugins"

@implementation BeatPlugin

@end

@implementation BeatPluginInfo
- (NSDictionary*)json {
	return @{
		@"name": (self.name) ? self.name : @"",
		@"text": (self.text) ? self.text : @"",
		@"copyright": (self.copyright) ? self.copyright : @"",
		@"version": (self.version) ? self.version : @"",
		@"localURL": (self.localURL) ? self.localURL.path : @"",
		@"updateAvailable": (self.updateAvailable) ? self.updateAvailable : @"",
		@"image": (self.image) ? self.image : @"",
		@"html": (self.html) ? self.html : @"",

		// If a required version is set, we have already checked compatibility.
		// Otherwise, let's always assume the plugin is cmopatible.
		@"compatible": (self.requiredVersion) ? @(self.compatible) : @(YES)
	};
}
@end

@interface BeatPluginManager ()
@property (nonatomic) NSDictionary *plugins;
@property (nonatomic) NSURL *pluginURL;
@property (nonatomic) NSMutableSet *incompleteDownloads;
@property (nonatomic) NSDictionary *externalLibrary;
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
		_pluginURL = [(BeatAppDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
		[self loadPlugins];		
	}
	
	return self;
}

- (void)checkForUpdates {
	NSArray *disabled = [self disabledPlugins];
	
	[self updateAvailablePlugins];
	[self getPluginLibraryWithCallback:^{
		NSMutableArray *availableUpdates = [NSMutableArray array];
		
		for (NSString *name in self.availablePlugins.allKeys) {
			BeatPluginInfo *plugin = self.availablePlugins[name];
			
			// Don't check updates for disabled plugins
			if ([disabled containsObject:name]) continue;
			
			if (plugin.updateAvailable) {
				[availableUpdates addObject:name];
			}
		}
		
		if (availableUpdates.count > 0) {
			NSString *text = [NSString stringWithFormat:@"%@", [availableUpdates componentsJoinedByString:@", "]];
			[(BeatAppDelegate*)NSApp.delegate showNotification:@"Update Available" body:text identifier:@"PluginUpdates" oneTime:YES interval:5.0];
		}
	}];
}

#pragma mark - Disabling and enabling plugins

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

#pragma mark - Plugin library content

- (void)updateAvailablePlugins {
	self.availablePlugins = [NSMutableDictionary dictionary];
	
	for (NSString *pluginName in self.plugins.allKeys) {
		[_availablePlugins setValue:[self pluginInfoFor:pluginName] forKey:pluginName];
	}
}

- (void)updateAvailablePluginsWithExternalLibrary {
	for (NSString *pluginName in self.externalLibrary.allKeys) {
		BeatPluginInfo *remotePlugin = self.externalLibrary[pluginName];
		
		if (_availablePlugins[pluginName]) {
			// The plugin is already available, check for updates
			BeatPluginInfo *existingPlugin = _availablePlugins[pluginName];
			
			// Log version numbers for remote and local plugins for debugging
			// NSLog(@"%@ / %@ – %@", remotePlugin[@"version"], existingPlugin[@"version"], remotePlugin[@"name"]);
			
			if ([self isNewerVersion:remotePlugin.version old:existingPlugin.version]) {
				existingPlugin.updateAvailable = remotePlugin.version;
			}
			[_availablePlugins setValue:existingPlugin forKey:pluginName];
		} else {
			[_availablePlugins setValue:remotePlugin forKey:pluginName];
		}
	}
}

- (bool)isNewerVersion:(NSString*)current old:(NSString*)old {
	NSArray* newComp = [current componentsSeparatedByString:@"."];
	NSArray* oldComp = [old componentsSeparatedByString:@"."];

	NSInteger pos = 0;

	while (newComp.count > pos || oldComp.count > pos) {
		NSInteger v1 = newComp.count > pos ? [[newComp objectAtIndex:pos] integerValue] : 0;
		NSInteger v2 = oldComp.count > pos ? [[oldComp objectAtIndex:pos] integerValue] : 0;
		if (v1 <= v2) {
			return NO;
		}
		else if (v1 > v2) {
			return YES;
		}
		pos++;
	}
	
	return NO;
}

- (bool)isCompatible:(NSString*)requiredVersion current:(NSString*)currentVersion {
	if ([requiredVersion compare:currentVersion options:NSNumericSearch] == NSOrderedDescending) {
	  // actualVersion is lower than the requiredVersion
		return NO;
	} else return YES;
}
- (bool)isCompatible:(NSString*)requiredVersion {
	NSString * currentVersion = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
	currentVersion = currentVersion.shortenedVersionNumberString;
	return [self isCompatible:requiredVersion current:currentVersion];
}

/*
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
 */

- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock {
	NSString *urlAsString = PLUGIN_LIBRARY_URL;

	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
	[[session dataTaskWithURL:[NSURL URLWithString:urlAsString]
			completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
				
		// No data available (we are offline)
		if (error || data == nil) return;
		
		NSMutableDictionary *plugins = [NSMutableDictionary dictionary];
		NSDictionary *pluginData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		
		for (NSString *pluginName in pluginData.allKeys) {
			NSDictionary *data = pluginData[pluginName];
			NSString *name = pluginName.stringByDeletingPathExtension;
			
			// Never add stuff with no name
			if (!name) continue;
			
			// Plugin image URL
			NSString *imageURL = @"";
			if ([(NSString*)data[@"image"] length]) imageURL = [NSString stringWithFormat:@"%@%@", DOWNLOAD_URL_IMAGES, data[@"image"]];
			
			BeatPluginInfo *info = BeatPluginInfo.alloc.init;
			[info setValuesForKeysWithDictionary:@{
				@"name": name,
				@"version": (data[@"version"]) ? data[@"version"] : @"",
				@"copyright": (data[@"copyright"]) ? data[@"copyright"] : @"",
				@"text": (data[@"description"]) ? data[@"description"] : @"",
				@"image": imageURL,
				@"html": (data[@"html"]) ? data[@"html"] : @"",
				@"installed": @(NO)
			}];
			
			[plugins setValue:info forKey:name];
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

- (BeatPluginInfo*)pluginInfoFor:(NSString*)plugin {
	// Info for LOCAL (installed) plugins
	BeatPluginInfo *pluginInfo = BeatPluginInfo.alloc.init;
	
	// Set correct path for folder and non-folder plugins
	NSString *path;
	if (![self isFolderPlugin:plugin]) path = _plugins[plugin];
	else path = [[(NSString*)_plugins[plugin] stringByAppendingPathComponent:plugin] stringByAppendingPathExtension:@"beatPlugin"];

	// Get plugin script contents
	NSError *error;
	NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	if (error) {
		NSLog(@"%@ / ERROR %@", path, error);
		return pluginInfo;
	}
	
	pluginInfo.name = plugin;
	pluginInfo.localURL = [NSURL fileURLWithPath:path];
	pluginInfo.installed = YES;

	// Regexes for getting plugin info
	Rx* versionRx = [Rx rx:@"\nVersion:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* copyrightRx = [Rx rx:@"\nCopyright:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* descriptionRx = [Rx rx:@"\nDescription:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* typeRx = [Rx rx:@"\nType:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* imageRx = [Rx rx:@"\nImage:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* compatibilityRx = [Rx rx:@"\nCompatibility:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	Rx* htmlRx = [Rx rx:@"<Description>((.|\n)*)</Description>" options:NSRegularExpressionCaseInsensitive];
	
	RxMatch *matchVersion = [script firstMatchWithDetails:versionRx];
	RxMatch *matchCopyright = [script firstMatchWithDetails:copyrightRx];
	RxMatch *matchDescription = [script firstMatchWithDetails:descriptionRx];
	RxMatch *matchType = [script firstMatchWithDetails:typeRx];
	RxMatch *matchImage = [script firstMatchWithDetails:imageRx];
	RxMatch *matchHTML = [script firstMatchWithDetails:htmlRx];
	RxMatch *matchCompatibility = [script firstMatchWithDetails:compatibilityRx];
		
	if (matchVersion) pluginInfo.version = [[(RxMatchGroup*)matchVersion.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (matchCopyright) pluginInfo.copyright = [[(RxMatchGroup*)matchCopyright.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (matchDescription) pluginInfo.text = [[(RxMatchGroup*)matchDescription.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (matchHTML) pluginInfo.html = [[(RxMatchGroup*)matchHTML.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	// Check cmopatibility
	pluginInfo.compatible = YES;
	if (matchCompatibility) {
		pluginInfo.requiredVersion = [[(RxMatchGroup*)matchCompatibility.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		pluginInfo.requiredVersion = [pluginInfo.requiredVersion stringByReplacingOccurrencesOfString:@"+" withString:@""];
		
		NSString * currentVersion = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
		currentVersion = currentVersion.shortenedVersionNumberString;
		
		if (pluginInfo.requiredVersion.length && ![self isCompatible:pluginInfo.requiredVersion]) pluginInfo.compatible = NO;
	}
	
	if (matchImage) {
		NSString *image = [[(RxMatchGroup*)matchImage.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		NSString *imagePath = [(NSString*)_plugins[plugin] stringByAppendingPathComponent:image];
		NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:imagePath]];
		
		// Create base64 representation
		NSString *imgData = [NSString stringWithFormat:@"data:image/png;base64, %@", [data base64EncodedStringWithOptions:0]];
		pluginInfo.image = imgData;
	}
	
	if (matchType) {
		NSString *typeString = [[(RxMatchGroup*)matchDescription.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
		BeatPluginType type = ToolPlugin;
		if ([typeString isEqualToString:@"export"]) type = ExportPlugin;
		else if ([typeString isEqualToString:@"import"]) type = ImportPlugin;
		
		pluginInfo.type = type;
	}
	
	return pluginInfo;
}

/*
- (BeatPluginType)pluginTypeFor:(NSString*)plugin {
	NSString *path = _plugins[plugin];
	
	NSError *error;
	NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if (error) return ToolPlugin;
	
	Rx* rx = [Rx rx:@"\nPlugin type:([\\w|\\s]+)\n" options:NSRegularExpressionCaseInsensitive];
	RxMatch* match = [script firstMatchWithDetails:rx];
	
	if (match) {
		NSString *type = [[[(RxMatchGroup*)match.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] lowercaseString];
		
		if ([type isEqualToString:@"import"]) return ImportPlugin;
		else if ([type isEqualToString:@"export"]) return ExportPlugin;
		else return ToolPlugin;
	} else {
		return ToolPlugin;
	}
}
*/
 
#pragma mark - Provide Menu Items

- (void)pluginMenuItemsFor:(NSMenu*)parentMenu runningPlugins:(NSDictionary*)runningPlugins type:(BeatPluginType)type {
	// Remove existing plugin menu items
	NSArray *menuItems = [NSArray arrayWithArray:parentMenu.itemArray];
	for (NSMenuItem *item in menuItems) {
		if (item.tag == 1) {
			// Save prototype for plugin type
			if (type == ToolPlugin && !_menuItem) _menuItem = item;
			else if (type == ImportPlugin && !_importMenuItem) _importMenuItem = item;
			else if (type == ExportPlugin && !_exportMenuItem) _exportMenuItem = item;
			
			[parentMenu removeItem:item];
		}
	}
	
	NSString *filter;
	if (type == ExportPlugin) filter = @"Export";
	else if (type == ImportPlugin) filter = @"Import";
	
	[self loadPlugins];
	
	NSArray *disabledPlugins = [self disabledPlugins];
	
	for (NSString *pluginName in self.pluginNames) {
		if (filter.length) {
			if ([pluginName rangeOfString:filter].location != 0) continue;
		}
		
		// Don't show this plugin in menu
		if ([disabledPlugins containsObject:pluginName]) continue;
		
		NSMenuItem *item = [_menuItem copy];
		item.state = NSOffState;
		item.title = pluginName;
		
		// If the plugin is running, display a tick next to it
		if (runningPlugins[pluginName]) item.state = NSOnState;
		
		[parentMenu addItem:item];
	}
}

- (IBAction)openPluginFolderAction:(id)sender {
	[self openPluginFolder];
}
- (void)openPluginFolder {
	NSURL *url = [(BeatAppDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
	[NSWorkspace.sharedWorkspace openURL:url];
}
- (NSURL*)pluginFolderURL {
	return [(BeatAppDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
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
	if (error) os_log(OS_LOG_DEFAULT, "Error deleting plugin: %@", name);
}

- (void)downloadPlugin:(NSString*)pluginName library:(BeatPluginLibrary*)library withCallback:(void (^)(NSString* pluginName))callbackBlock {
	if (!_incompleteDownloads) _incompleteDownloads = NSMutableSet.set;
	[_incompleteDownloads addObject:pluginName];
	
	__block NSString *pluginFileName = [NSString stringWithFormat:@"%@.beatPlugin.zip", pluginName];
	
	NSString *downloadPath = [NSString stringWithFormat:@"%@%@", DOWNLOAD_URL_BASE, pluginFileName];
	downloadPath = [downloadPath stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
	downloadPath = [NSString stringWithFormat:@"https://%@", downloadPath];
	
	NSURL *url = [NSURL URLWithString:downloadPath];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	
	[[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSError *writeError;
		NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:pluginFileName];
		NSLog(@"TEMP DIR: %@", tempDir);
		
		[data writeToURL:[NSURL fileURLWithPath:tempDir] options:0 error:&writeError];
		
		if (writeError) {
			os_log(OS_LOG_DEFAULT, "Error writing temporary zip file: %@", writeError);
		} else {
			dispatch_async(dispatch_get_main_queue(), ^(void){
				NSLog(@"Installing plugin...");
				@try {
					[self installPlugin:tempDir];
					[self.availablePlugins setValue:[self pluginInfoFor:pluginName] forKey:pluginName];
					callbackBlock(pluginName);
				}
				@catch (NSException* e) {
					os_log(OS_LOG_DEFAULT, "Error installing plugin %@", pluginName);
				}
				@finally {
					[self.incompleteDownloads removeObject:pluginName];
				}
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
	NSURL *pluginURL = [(BeatAppDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
	[container extractFilesTo:pluginURL.path overwrite:YES error:&error];
	
	// Reload installed plugins
	[self loadPlugins];
}


@end
/*
 
 when it is truly time
 and if you have been chosen
 it will do it by
 itself and it will keep on doing it
 until you die or it dies in you.
 
 */
