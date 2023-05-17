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
 write files, the operations have to be approved by the user.
 
 */

#import <BeatParsing/BeatParsing.h>
#import "BeatPluginManager.h"
#import "BeatAppDelegate.h"
#import "BeatCheckboxCell.h"
#import "UnzipKit.h"
#import "BeatPluginLibrary.h"
#import "NSString+VersionNumber.h"
#import "BeatPlugin.h"
#import "Beat-Swift.h"
#import <BeatCore/BeatLocalization.h>
#import <os/log.h>

// Hard-coded JSON file URL
#define PLUGIN_LIBRARY_URL @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Beat%20Plugins.json"

#define DOWNLOAD_URL_BASE @"raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/"
#define DOWNLOAD_URL_IMAGES @"https://raw.githubusercontent.com/lmparppei/BeatPlugins/master/Dist/Images/"
#define PLUGIN_FOLDER @"Plugins"
#define DISABLED_KEY @"Disabled Plugins"

@implementation BeatPluginData

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
		@"imagePath": (self.imagePath) ? self.imagePath : @"",
		@"image": [self imageDataOrURL], // sends either a base64 data or a URL
		@"html": (self.html) ? self.html : @"",

		// If a required version is set, we have already checked compatibility.
		// Otherwise, let's always assume the plugin is comppatible.
		@"compatible": (self.requiredVersion) ? @(self.compatible) : @(YES)
	};
}

- (NSString*)imageDataOrURL {
	NSString *imagePath;
	
	// No image
	if (self.imagePath.length == 0) return @"";
	
	// Return remote url
	else if ([self.imagePath rangeOfString:@"http"].location != NSNotFound) {
		return (self.imagePath) ? self.imagePath : @"";
	}
	
	// Return base64 representation
	else if (_localURL) {
		imagePath = [_bundleURL.path stringByAppendingPathComponent:self.imagePath];
		
		NSError *error;
		NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:imagePath] options:0 error:&error];
		
		if (!error) {
			NSString *imgData = [NSString stringWithFormat:@"data:image/png;base64, %@", [data base64EncodedStringWithOptions:0]];
			return imgData;
		}
	}
	
	return @"";
}
@end

@interface BeatPluginManager ()

@property (nonatomic, weak) IBOutlet NSMenu *pluginMenu;
@property (nonatomic, weak) IBOutlet NSMenu *exportMenu;
@property (nonatomic, weak) IBOutlet NSMenu *importMenu;

@property (nonatomic) NSDictionary *plugins;
@property (nonatomic) NSURL *pluginURL;
@property (nonatomic) NSMutableSet *incompleteDownloads;
@property (nonatomic) NSDictionary *externalLibrary;
@end

@implementation BeatPluginManager

// NB: Plugin manager is a singleton, and first loaded in MainMenu.xib

static BeatPluginManager *sharedManager;

+ (BeatPluginManager*)sharedManager
{
	if (!sharedManager) {
		sharedManager = [[BeatPluginManager alloc] init];
	}
	return sharedManager;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		NSLog(@"Initializing plugin manager...");
		initialized = YES;
		sharedManager = BeatPluginManager.new;
	}
}

- (BeatPluginManager*)init {
	self = [super init];
	
	if (sharedManager) return sharedManager;
		
	if (self) {
		_pluginURL = [BeatAppDelegate appDataPath:PLUGIN_FOLDER];
		[self loadPlugins];		
	}
	
	return self;
}


#pragma mark - UI Side (menu items)

- (void)setupPluginMenus {
	// Populate plugin menus at load
	[self setupPluginMenu:_pluginMenu];
	[self setupPluginMenu:_exportMenu];
	[self setupPluginMenu:_importMenu];
	 
	[self checkForUpdates];
}

-(void)menuWillOpen:(NSMenu *)menu {
	[self setupPluginMenu:menu];
}

-(void)setupPluginMenu:(NSMenu*)menu {
	BeatPluginType type = ToolPlugin;
	if (menu == _exportMenu) type = ExportPlugin;
	else if (menu == _importMenu) type = ImportPlugin;
	
	[self pluginMenuItemsFor:menu runningPlugins:[NSDocumentController.sharedDocumentController.currentDocument valueForKey:@"runningPlugins"] type:type];
}

- (IBAction)runStandalonePlugin:(id)sender {
	// This runs a plugin which is NOT tied to the document
	BeatPluginMenuItem *item = sender;
	NSString *pluginName = item.pluginName;
	
	BeatPlugin *parser = BeatPlugin.new;
	BeatPluginData *plugin = [BeatPluginManager.sharedManager pluginWithName:pluginName];

	BeatPluginInfo *info = [self pluginInfoFor:pluginName];
	[parser loadPlugin:plugin];
	
	// If the plugin was an export or import plugin, it might have not run any code, but registered a callback.
	if (info.type == ExportPlugin && parser.exportCallback != nil) {
		[self runExportPlugin:parser];
	}
	else if (info.type == ImportPlugin && parser.importCallback != nil) {
		[self runImportPlugin:parser];
	}
	
	parser = nil;
}

- (void)runExportPlugin:(BeatPlugin*)parser {
	NSSavePanel *panel = NSSavePanel.new;
	panel.allowedFileTypes = parser.exportedExtensions;
	
	[panel beginWithCompletionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[parser.exportCallback callWithArguments:@[panel.URL.path]];
		}
	}];
}

- (void)runImportPlugin:(BeatPlugin*)parser {
	NSOpenPanel *panel = NSOpenPanel.new;
	panel.allowedFileTypes = parser.importedExtensions;
	
	[panel beginWithCompletionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[parser.importCallback callWithArguments:@[panel.URL.path]];
		}
	}];
}


- (void)runPlugin:(id)plugin {
	// Faux placeholder method
}

- (void)pluginMenuItemsFor:(NSMenu*)parentMenu runningPlugins:(NSDictionary*)runningPlugins type:(BeatPluginType)type {
	// Remove existing plugin menu items
	NSArray *menuItems = parentMenu.itemArray.copy;
	for (NSMenuItem *item in menuItems) {
		if ([item isKindOfClass:BeatPluginMenuItem.class]) [parentMenu removeItem:item];
	}
		
	// Load existing plugins
	[self loadPlugins];
	NSArray *disabledPlugins = [self disabledPlugins];
	
	// Create plugin menu items
	for (NSString *pluginName in self.pluginNames) {
		BeatPluginInfo *plugin = [self pluginInfoFor:pluginName];
		
		// Backwards compatibility for old export/import plugins
		if ([pluginName rangeOfString:@"Export"].location == 0) plugin.type = ExportPlugin;
		else if ([pluginName rangeOfString:@"Import"].location == 0) plugin.type = ImportPlugin;
		
		// Skip if not correct type
		if (parentMenu == _exportMenu && plugin.type != ExportPlugin) continue;
		else if (parentMenu == _importMenu && plugin.type != ImportPlugin) continue;
		else if (parentMenu == _pluginMenu && (plugin.type == ExportPlugin || plugin.type == ImportPlugin)) continue;
		
		// Don't show disabled plugins in menu
		if ([disabledPlugins containsObject:pluginName]) continue;

		// String to be displayed
		NSString *displayName = pluginName.copy;
		
		// Clean up plugin names for import/export and localize if possible
		if (plugin.type == ExportPlugin && [pluginName rangeOfString:@"Export"].location != NSNotFound) {
			displayName = [NSString stringWithFormat:@"%@ %@...", [BeatLocalization localizedStringForKey:@"export.prefix"], [pluginName stringByReplacingOccurrencesOfString:@"Export " withString:@""]];
		}
		else if (plugin.type == ImportPlugin && [pluginName rangeOfString:@"Import"].location != NSNotFound) {
			displayName = [NSString stringWithFormat:@"%@ %@...", [BeatLocalization localizedStringForKey:@"import.prefix"], [pluginName stringByReplacingOccurrencesOfString:@"Import " withString:@""]];
		}
		
		// Create menu item
		BeatPluginMenuItem *item = [BeatPluginMenuItem.alloc initWithTitle:displayName pluginName:pluginName type:type];
		item.state = NSOffState;
		
		// Set correct target for standalone plugins
		if (plugin.type == ImportPlugin || plugin.type == ExportPlugin) {
			item.target = self;
			item.action = @selector(runStandalonePlugin:);
		}
		else {
			/*
			id<BeatScriptingDelegate> document = NSDocumentController.sharedDocumentController.currentDocument;
			if (document != nil) item.target = document;
			 */
			
			item.target = nil;
			item.action = @selector(runPlugin:);
		}
		
		// See if the plugin is currently running
		if (runningPlugins[pluginName]) item.state = NSOnState;
			
		// Finally, add to menu
		[parentMenu addItem:item];
	}
}

- (IBAction)openPluginFolderAction:(id)sender {
	[self openPluginFolder];
}
- (void)openPluginFolder {
	NSURL *url = [BeatAppDelegate appDataPath:PLUGIN_FOLDER];
	[NSWorkspace.sharedWorkspace openURL:url];
}
- (NSURL*)pluginFolderURL {
	return [BeatAppDelegate appDataPath:PLUGIN_FOLDER];
}


#pragma mark - Check for plugin updates

- (void)checkForUpdates {
	NSArray *disabled = [self disabledPlugins];
	bool autoUpdate = [BeatUserDefaults.sharedDefaults getBool:BeatSettingUpdatePluginsAutomatically];
	
	[self refreshAvailablePlugins];
	[self getPluginLibraryWithCallback:^{
		NSMutableArray *availableUpdates = [NSMutableArray array];
		
		for (NSString *name in self.availablePlugins.allKeys) {
			BeatPluginInfo *plugin = self.availablePlugins[name];
			
			// Don't check updates for disabled plugins
			// if ([disabled containsObject:name]) continue;
			
			// If the plugin has a update available, add it to the list
			if (plugin.updateAvailable) [availableUpdates addObject:name];
		}
		
		
		if (availableUpdates.count == 0) return;
		
		// Update plugins automatically or show a notification
		if (autoUpdate) {
			[self updatePlugins:availableUpdates];
		} else {
			// Show notification if there are updates available
			NSString *text = [NSString stringWithFormat:@"%@", [availableUpdates componentsJoinedByString:@", "]];
			[(BeatAppDelegate*)NSApp.delegate showNotification:@"Update Available" body:text identifier:@"PluginUpdates" oneTime:YES interval:5.0];
		}
	}];
}

- (void)updatePlugins:(NSArray*)availableUpdates {
	for (NSString* name in availableUpdates) {
		[self downloadPlugin:name withCallback:^(NSString * _Nonnull pluginName) {
			[(BeatAppDelegate*)NSApp.delegate showNotification:@"Plugin Updated" body:pluginName identifier:@"PluginUpdates" oneTime:YES interval:3.0];
		}];
	}
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

- (void)refreshAvailablePlugins {
	self.availablePlugins = NSMutableDictionary.new;
	
	for (NSString *pluginName in self.plugins.allKeys) {
		[_availablePlugins setValue:[self pluginInfoFor:pluginName] forKey:pluginName];
	}
}

- (void)refreshAvailablePluginsWithExternalLibrary {
	for (NSString *pluginName in self.externalLibrary.allKeys) {
		BeatPluginInfo *remotePlugin = self.externalLibrary[pluginName];
		
		if (_availablePlugins[pluginName]) {
			// The plugin is already available, check for updates
			BeatPluginInfo *existingPlugin = _availablePlugins[pluginName];
			
			// Log version numbers for remote and local plugins for debugging
			// NSLog(@"%@ / %@ – %@", remotePlugin[@"version"], existingPlugin[@"version"], remotePlugin[@"name"]);
			
			if ([self isNewerVersion:remotePlugin.version old:existingPlugin.version]) {
				// There's an update available, so show the remote info instead
				existingPlugin.updateAvailable = remotePlugin.version;
				existingPlugin.text = (remotePlugin.text) ? remotePlugin.text : @"";
				existingPlugin.html = (remotePlugin.html) ? remotePlugin.html : @"";
				existingPlugin.imagePath = (remotePlugin.imagePath) ? remotePlugin.imagePath : @"";
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
		
		if (v1 < v2) {
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
	return [currentVersion isNewerVersionThan:requiredVersion];
	/*
	if ([requiredVersion compare:currentVersion options:NSNumericSearch] == NSOrderedDescending) {
	  // actualVersion is lower than the requiredVersion
		return NO;
	} else return YES;
	*/
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

	// Download external JSON data
	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
	[[session dataTaskWithURL:[NSURL URLWithString:urlAsString]
			completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
				
		// No data available (we are offline)
		if (error || data == nil) return;
		
		// Read JSON data and init the local dictionary
		NSDictionary *pluginData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		NSMutableDictionary *plugins = [NSMutableDictionary dictionary];
		
		// Iterate through remote plugin data
		for (NSString *pluginName in pluginData.allKeys) {
			NSDictionary *data = pluginData[pluginName];
			NSString *name = pluginName.stringByDeletingPathExtension;
			
			// Never add stuff with no name
			if (name.length == 0) continue;
			
			// Plugin image URL
			NSString *imageURL = @"";
			if ([(NSString*)data[@"image"] length]) imageURL = [NSString stringWithFormat:@"%@%@", DOWNLOAD_URL_IMAGES, data[@"image"]];
			
			BeatPluginInfo *info = BeatPluginInfo.alloc.init;
			[info setValuesForKeysWithDictionary:@{
				@"name": name,
				@"version": (data[@"version"]) ? data[@"version"] : @"",
				@"copyright": (data[@"copyright"]) ? data[@"copyright"] : @"",
				@"text": (data[@"description"]) ? data[@"description"] : @"",
				@"imagePath": imageURL,
				@"html": (data[@"html"]) ? data[@"html"] : @"",
				@"installed": @(NO)
			}];
			
			[plugins setValue:info forKey:name];
		}
		
		// Save the downloaded data and append it to local plugin information
		self.externalLibrary = plugins;
		[self refreshAvailablePluginsWithExternalLibrary];
		
		// Run callback
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
	NSFileManager *fileManager = NSFileManager.defaultManager;
	NSArray *files = [fileManager contentsOfDirectoryAtPath:_pluginURL.path error:nil];
	
	for (NSString *file in files) {
		if (![file.pathExtension isEqualToString:@"beatPlugin"]) continue;
		
		BOOL folderPlugin;
		
		NSString *filepath = [_pluginURL.path stringByAppendingPathComponent:file];
		if ([fileManager fileExistsAtPath:filepath isDirectory:&folderPlugin]) {
			if (!folderPlugin) [plugins addObject:filepath];
			else {
				// If it's a folder-type plugin, we need to check its contents for a file of the same name:
				// SamplePlugin.beatPlugin/SamplePlugin.beatPlugin
				NSString *pluginName = filepath.lastPathComponent;
				NSString *fullpath = [filepath stringByAppendingPathComponent:pluginName];
				
				if ([fileManager fileExistsAtPath:fullpath]) [plugins addObject:filepath];
			}
		}
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

- (BeatPluginData*)pluginWithName:(NSString*)name {
	BeatPluginData *plugin = [[BeatPluginData alloc] init];
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
	pluginInfo.bundleURL = [NSURL fileURLWithPath:_plugins[plugin]];
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
	
	// Check compatibility
	pluginInfo.compatible = YES;
	if (matchCompatibility) {
		pluginInfo.requiredVersion = [[(RxMatchGroup*)matchCompatibility.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		pluginInfo.requiredVersion = [pluginInfo.requiredVersion stringByReplacingOccurrencesOfString:@"+" withString:@""];
		
		if (pluginInfo.requiredVersion.length && ![self isCompatible:pluginInfo.requiredVersion]) pluginInfo.compatible = NO;
	}
	
	if (matchImage) {
		
		NSString *image = [[(RxMatchGroup*)matchImage.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		pluginInfo.imagePath = image;
		
		/*
		NSError *error;
		NSString *imagePath = [(NSString*)_plugins[plugin] stringByAppendingPathComponent:image];
		NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:imagePath] options:0 error:&error];
		
		if (!error) {
			// Create base64 representation
			NSString *imgData = [NSString stringWithFormat:@"data:image/png;base64, %@", [data base64EncodedStringWithOptions:0]];
			pluginInfo.image = imgData;
		}
		*/
		
	}
	
	if (matchType) {
		NSString *typeString = [[(RxMatchGroup*)matchType.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
		BeatPluginType type = ToolPlugin;
		
		if ([typeString isEqualToString:@"export"]) type = ExportPlugin;
		else if ([typeString isEqualToString:@"import"]) type = ImportPlugin;
		else if ([typeString isEqualToString:@"standalone"]) type = StandalonePlugin;
		
		pluginInfo.type = type;
	}
	
	return pluginInfo;
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

- (void)downloadPlugin:(NSString*)pluginName withCallback:(void (^)(NSString* pluginName))callbackBlock {
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
	NSURL *pluginURL = [BeatAppDelegate appDataPath:PLUGIN_FOLDER];
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
