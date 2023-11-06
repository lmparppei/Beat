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
#import <UnzipKit/UnzipKit.h>
#import "BeatPlugin.h"
#import <BeatPlugins/BeatPlugins-Swift.h>
#import <BeatCore/BeatLocalization.h>
#import <BeatCore/BeatCore-Swift.h>
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

@property (nonatomic) NSDictionary *plugins;
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
		_pluginURL = [BeatPaths appDataPath:PLUGIN_FOLDER];
		[self loadPlugins];		
	}
	
	return self;
}


#pragma mark - Run plugins

- (void)runPlugin:(id)plugin {
	// Faux placeholder method
}

- (IBAction)runStandalonePlugin:(id)sender {
	// This runs a plugin which is NOT tied to the document
#if !TARGET_OS_IOS
	id<BeatPluginInfoUIItem> item = sender;
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
#endif
}

#pragma mark Export / Import plugins (macOS)

#if !TARGET_OS_IOS
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

#endif


#pragma mark - Plugin folder access

- (NSURL*)pluginFolderURL {
	return [BeatPaths appDataPath:PLUGIN_FOLDER];
}


#pragma mark - Check for plugin updates

- (void)checkForUpdates {
	bool autoUpdate = [BeatUserDefaults.sharedDefaults getBool:BeatSettingUpdatePluginsAutomatically];
	
	[self refreshAvailablePlugins];
	[self getPluginLibraryWithCallback:^{
		NSMutableArray *availableUpdates = NSMutableArray.new;
		
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
            #if !TARGET_OS_IOS
            // Show notification if there are updates available (on macOS)
            NSString *text = [NSString stringWithFormat:@"%@", [availableUpdates componentsJoinedByString:@", "]];
            id<BeatNotificationDelegate> notifications = (id<BeatNotificationDelegate>)NSApp.delegate;
            [notifications showNotification:@"Update Available" body:text identifier:@"PluginUpdates" oneTime:YES interval:5.0];
            #endif
		}
	}];
}

- (void)updatePlugins:(NSArray*)availableUpdates {
	for (NSString* name in availableUpdates) {
		[self downloadPlugin:name withCallback:^(NSString * _Nonnull pluginName) {
            #if !TARGET_OS_IOS
            id<BeatNotificationDelegate> notifications = (id<BeatNotificationDelegate>)NSApp.delegate;
			[notifications showNotification:@"Plugin Updated" body:pluginName identifier:@"PluginUpdates" oneTime:YES interval:3.0];
            #endif
        }];
	}
}

#pragma mark - Disabling and enabling plugins

- (NSArray<NSString*>*)disabledPlugins {
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

/// Gets the plugin library JSON from GitHub repo. The JSON is stored into `.externalLibrary`.
- (void)getPluginLibraryWithCallback:(void (^)(void))callbackBlock
{
	NSString *urlAsString = PLUGIN_LIBRARY_URL;

	// Download external JSON data
	NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
	[[session dataTaskWithURL:[NSURL URLWithString:urlAsString]
			completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
				
		// No data available (we are offline)
		if (error || data == nil) return;
		
		// Read JSON data and init the local dictionary
		NSDictionary *pluginData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		NSMutableDictionary *plugins = NSMutableDictionary.new;
		
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

/// Loads the local plugins.
/// A plugin can be either a single file (`.js` or `.beatPlugin`) *or* a folder which contains one of these:
/// `FolderName.js`, `FolderName.beatPlugin`, `plugin.js`, `plugin.beatPlugin`
- (void)loadPlugins
{
	NSMutableArray *plugins = NSMutableArray.new;
	
	// Plugins from inside the bundle
	NSArray *bundledPlugins = [NSBundle.mainBundle URLsForResourcesWithExtension:@"beatPlugin" subdirectory:nil];
	for (NSURL *url in bundledPlugins) {
		[plugins addObject:url.path];
	}
		
	// Get user-installed plugins
	NSFileManager *fileManager = NSFileManager.defaultManager;
	NSArray *files = [fileManager contentsOfDirectoryAtPath:_pluginURL.path error:nil];
	
	for (NSString *file in files) {
		//if (![file.pathExtension isEqualToString:@"beatPlugin"]) continue;
		
		BOOL folder;
		NSString* extension = file.pathExtension;
		
		NSString *filepath = [_pluginURL.path stringByAppendingPathComponent:file];
		if ([fileManager fileExistsAtPath:filepath isDirectory:&folder]) {
			
			if (!folder) {
				// Extension has to be either .js or .beatPlugin
				if (![extension isEqualToString:@"beatPlugin"] && ![extension isEqualToString:@"js"]) continue;
				
				[plugins addObject:filepath];
			} else {
				// If it's a folder-type plugin, we need to check its contents for a file of the same name:
				// SamplePlugin.beatPlugin/SamplePlugin.beatPlugin
				NSString* pluginPath = [self pluginPathForPath:filepath];
				
				if (pluginPath != nil) [plugins addObject:filepath];
			}
		}
	}
	
	NSMutableDictionary *pluginsWithNames = NSMutableDictionary.new;
	for (NSString *plugin in plugins) {
		[pluginsWithNames setValue:plugin forKey:plugin.lastPathComponent.stringByDeletingPathExtension];
	}
	_plugins = pluginsWithNames;
}

/// Returns an array of plugin names
- (NSArray<NSString*>*)pluginNames {
	return [self.plugins.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

/// Returns plugin data, which means files and the actual script
- (BeatPluginData*)pluginWithName:(NSString*)name {
	BeatPluginData *plugin = [[BeatPluginData alloc] init];
	plugin.name = name;
	
	// Uh. Let's reload the plugin array. The user might have installed new ones.
	
	[self loadPlugins];
	NSString *filename = _plugins[name];
	
	NSFileManager* fileManager = NSFileManager.defaultManager;
	
    NSError* error;
    
	if ([self isFolderPlugin:name]) {
		// Check that the folder actually has a plugin file
		NSString* pluginPath = [self pluginPathForPath:filename];
		if (pluginPath == nil) return nil;
		
		plugin.script = [NSString stringWithContentsOfFile:pluginPath encoding:NSUTF8StringEncoding error:&error];
        plugin.url = [NSURL fileURLWithPath:pluginPath.stringByDeletingLastPathComponent];
        
		// Also, read the folder contents and allow file access to the plugin
		NSArray *files = [fileManager contentsOfDirectoryAtPath:pluginPath.stringByDeletingLastPathComponent error:nil];
		NSMutableArray *pluginFiles = [NSMutableArray array];
		
		for (NSString* file in files) {
			// Don't include the plugin script
			if ([file.lastPathComponent isEqualToString:pluginPath.lastPathComponent]) continue;
			[pluginFiles addObject:file];
		}
		
		plugin.files = [NSArray arrayWithArray:pluginFiles];
	} else {
		// Get script for a single file
		plugin.script = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:&error];
	}
    
    if (error != nil) {
        NSLog(@"Plugin manager error: %@ - %@", name, error);
    }
	
	// Make the script a self-running function. This allows us to avoid some namespacing issues in JS.
	plugin.script = [NSString stringWithFormat:@"(function(){ %@ })();", plugin.script];

	return plugin;
}

- (NSString*)pathForPlugin:(NSString*)pluginName
{
	return _plugins[pluginName];
}

/// Returns plugin info – name, version, copyright etc.
- (BeatPluginInfo*)pluginInfoFor:(NSString*)plugin
{
	// Info for LOCAL (installed) plugins
	BeatPluginInfo *pluginInfo = BeatPluginInfo.alloc.init;
	
	// Set correct path for folder and non-folder plugins
	NSString *path;
	if (![self isFolderPlugin:plugin]) path = _plugins[plugin];
	else path = [self pluginPathForPath:_plugins[plugin]];
	
	// No plugin found in the folder, or something else went wrong.
	if (path == nil) return pluginInfo;

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

/// Returns the actual file path for a folder plugin.
- (NSString*)pluginPathForPath:(NSString*)filepath
{
	NSString *pluginName = filepath.lastPathComponent;
	NSArray* possiblePlugins = @[
		[filepath stringByAppendingPathComponent:pluginName],
		[filepath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.beatPlugin", filepath.lastPathComponent.stringByDeletingPathExtension]],
		[filepath stringByAppendingPathComponent:@"plugin.js"],
		[filepath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.js", filepath.lastPathComponent.stringByDeletingPathExtension]],
	];
	
	NSFileManager* fileManager = NSFileManager.defaultManager;
	
	for (NSString* path in possiblePlugins) {
		if ([fileManager fileExistsAtPath:path]) {
			return path;
		}
	}
	
	return nil;
}

- (bool)isFolderPlugin:(NSString*)pluginName
{
	BOOL isDir = NO;
	NSString *filename = _plugins[pluginName];
	
	if ([NSFileManager.defaultManager fileExistsAtPath:filename isDirectory:&isDir] && isDir) return YES;
	else return NO;
}
 
#pragma mark - Plugin version checking

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
}

- (bool)isCompatible:(NSString*)requiredVersion {
	NSString * currentVersion = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
	currentVersion = currentVersion.shortenedVersionNumberString;
	return [self isCompatible:requiredVersion current:currentVersion];
}
 
- (NSArray*)availablePluginNames
{
	return [self.availablePlugins.allKeys sortedArrayUsingSelector:@selector(compare:)];
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
	NSURL *pluginURL = [BeatPaths appDataPath:PLUGIN_FOLDER];
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
