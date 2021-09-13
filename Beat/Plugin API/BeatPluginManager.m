//
//  BeatPluginManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.12.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
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
#import "BDMCheckboxCell.h"
#import "UnzipKit.h"

#define PLUGIN_LIBRARY_URL @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Beat%20Plugins.json"
#define DOWNLOAD_URL_BASE @"raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/"
#define PLUGIN_FOLDER @"Plugins"
#define DISABLED_KEY @"Disabled Plugins"

@implementation BeatPlugin

@end

@interface BeatPluginManager ()
@property (nonatomic) NSDictionary *plugins;
@property (nonatomic) NSURL *pluginURL;

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
			NSDictionary *plugin = self.availablePlugins[name];
			
			// Don't check updates for disabled plugins
			if ([disabled containsObject:name]) continue;
			
			if (plugin[@"updateAvailable"]) {
				[availableUpdates addObject:name];
			}
		}
		
		if (availableUpdates.count > 0) {
			NSString *text = [NSString stringWithFormat:@"%@", [availableUpdates componentsJoinedByString:@", "]];
			[(BeatAppDelegate*)NSApp.delegate showNotification:@"Update Available" body:text identifier:@"PluginUpdates" oneTime:YES interval:5.0];
		}
	}];
	
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
		NSDictionary *remotePlugin = self.externalLibrary[pluginName];
		
		if (_availablePlugins[pluginName]) {
			// The plugin is already available, check for updates
			NSMutableDictionary *existingPlugin = [NSMutableDictionary dictionaryWithDictionary:_availablePlugins[pluginName]];
			
			// Log version numbers for remote and local plugins for debugging
			// NSLog(@"%@ / %@ – %@", remotePlugin[@"version"], existingPlugin[@"version"], remotePlugin[@"name"]);
			
			if ([self isNewerVersion:remotePlugin[@"version"] old:existingPlugin[@"version"]]) {
				existingPlugin[@"updateAvailable"] = remotePlugin[@"version"];
			}
			[_availablePlugins setValue:existingPlugin forKey:pluginName];
		} else {
			[_availablePlugins setValue:remotePlugin forKey:pluginName];
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
	Rx* typeRx = [Rx rx:@"\nType:(.*)\n" options:NSRegularExpressionCaseInsensitive];
	
	RxMatch *matchVersion = [script firstMatchWithDetails:versionRx];
	RxMatch *matchCopyright = [script firstMatchWithDetails:copyrightRx];
	RxMatch *matchDescription = [script firstMatchWithDetails:descriptionRx];
	RxMatch *matchType = [script firstMatchWithDetails:typeRx];
		
	if (matchVersion) info[@"version"] = [[(RxMatchGroup*)matchVersion.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (matchCopyright) info[@"copyright"] = [[(RxMatchGroup*)matchCopyright.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	if (matchDescription) info[@"description"] = [[(RxMatchGroup*)matchDescription.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	if (matchType) {
		NSString *typeString = [[(RxMatchGroup*)matchDescription.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
		BeatPluginType type = ToolPlugin;
		if ([typeString isEqualToString:@"export"]) type = ExportPlugin;
		else if ([typeString isEqualToString:@"import"]) type = ImportPlugin;
	}
	
	return info;
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
	
	// Set local url for installed plugins, nil it for others
	bool installed = [(NSNumber*)pluginInfo[@"installed"] boolValue];
	if (installed) cell.localURL = pluginInfo[@"localURL"];
	else cell.localURL = nil;
	
	// Set update info
	if (pluginInfo[@"updateAvailable"]) { cell.updateAvailable = YES; }
	else cell.updateAvailable = NO;
	
	cell.name = pluginInfo[@"name"];
	cell.info = pluginInfo[@"description"];
	cell.copyright = pluginInfo[@"copyright"];
	cell.version = pluginInfo[@"version"];
	[cell setSize];

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
-(void)outlineViewSelectionDidChange:(NSNotification *)notification {
	NSOutlineView *outlineView = notification.object;
	if (!outlineView) return;
	
	
	
	id item = [outlineView itemAtRow:outlineView.selectedRow];
	BDMCheckboxCell *cell = (BDMCheckboxCell*)[self outlineView:outlineView viewForTableColumn:nil item:item];
	
	cell.selected = YES;
	[cell setNeedsDisplay:YES];
}

 
-(CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
	NSInteger row = [outlineView rowForItem:item];

	BDMCheckboxCell *cell;
	if (row != NSNotFound && row < outlineView.numberOfRows) cell = (BDMCheckboxCell*)[self outlineView:outlineView viewForTableColumn:nil item:item];
	
	if (outlineView.selectedRow == row && row != NSNotFound) {
		// Selected height
		return 100;
	} else {
		// Deselected height
		cell.selected = NO;
		return 62;
	}
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
	NSURL *pluginURL = [(BeatAppDelegate*)NSApp.delegate appDataPath:PLUGIN_FOLDER];
	
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
